import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:vector_math/vector_math.dart' as vm;

import 'app.dart';
import 'cutscene/timeline.dart';
import 'ambient/creatures.dart';
import 'render/stage.dart';
import 'settings.dart';
import 'sim/geo.dart';

/// `VILLAGE_CINEMATIC=<shots.json>` (with `VILLAGE_PLAYBACK=<session>`):
/// renders a replayed game offline for a trailer. The game steps exactly
/// 1/60 s per frame whatever the frame costs; between shots it runs ahead
/// without drawing every step, and during a shot every step is drawn and
/// saved as a PNG (`<out>/<shot>/00000.png`) at the window's logical size
/// times `scale` (1280x720 at 1.5 for 1080p, 540x960 at 2 for a vertical
/// cut). Each shot starts at an anchor in the game and can fly its own
/// camera (an eased orbit, dolly, crane or follow around a subject) and
/// show only the overlays it asks for. The effects the soundscape plays and
/// the music loop levels are logged per frame for the soundtrack.
///
/// The shot list:
///
/// ```json
/// {"out": "/tmp/frames", "scale": 1.5, "shots": [
///   {"name": "s03_talk", "start": {"ui": 418000}, "frames": 300,
///    "camera": {"subject": "Pip,Mo", "az": [20, 55], "el": [8, 10],
///               "dist": [7, 5.5], "look": [1.2, 1.2], "fov": [30, 28]},
///    "hud": ["bubbles"], "select": "June"}]}
/// ```
///
/// Anchors: `{"ui": ms}` (the village's pause-aware clock), `{"tick": n}`,
/// `{"cutscene": "night", "n": 1, "at": 3.5}` (the nth scene of that name,
/// at that scene time) or `{"stage": "story", "at": 2}` (the post-week
/// tour: epilogue, results, story, gallery). `"preview": 30` saves only
/// every 30th frame, for planning.
class CinematicCapture {
  CinematicCapture(this.home, this.path);
  final VillageHomeState home;
  final String path;

  bool running = false;

  /// What the current shot shows over the 3D view: bubbles, options,
  /// inspector, cutscene, letterbox; the storybook and menus always show.
  Set<String> hud = const {};

  /// Scrolls the inspector during a shot (`"inspectorScroll": [from, to]`
  /// in pixels, eased, clamped to the panel's length).
  final ScrollController inspectorScroll = ScrollController();

  late final List<_Shot> _shots;
  late final String _out;
  late final double _scale;
  late final int _preview;
  final List<Future<void>> _writes = [];
  final Map<String, int> _cutscenesSeen = {};
  String? _lastCutscene;
  IOSink? _frames;
  IOSink? _audio;
  int _saved = 0;
  _Shot? _current;
  int _shotFrame = 0;

  void start() {
    final spec = (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, Object?>();
    _out = spec['out'] as String;
    _scale = (spec['scale'] as num?)?.toDouble() ?? 1.5;
    _preview = (spec['preview'] as int?) ?? 1;
    final size = TextSize.values.where((t) => t.name == spec['textSize']).firstOrNull;
    if (size != null) home.settings.textSize = size;
    _shots = [for (final s in spec['shots'] as List) _Shot((s as Map).cast<String, Object?>())];
    Directory(_out).createSync(recursive: true);
    _frames = File('$_out/frames.jsonl').openWrite();
    _audio = File('$_out/audio.jsonl').openWrite();
    home.audioTap = (name, volume, speed, pan) {
      final s = _current;
      if (s == null) return;
      _audio?.writeln(jsonEncode({'shot': s.name, 'f': _shotFrame, 'play': name, 'vol': volume, 'speed': speed, 'pan': pan}));
    };
    home.loopTap = (name, volume) {
      final s = _current;
      if (s != null) _audio?.writeln(jsonEncode({'shot': s.name, 'f': _shotFrame, 'loop': name, 'vol': volume}));
    };
    home.test.log('CINE ${_shots.length} shots into $_out at x$_scale');
    unawaited(_run());
  }

  Future<void> _run() async {
    running = true;
    final replay = home.replay!;
    var next = 0;
    var stepsSinceFrame = 0;
    const ahead = 30;
    try {
      while (next < _shots.length) {
        final shot = _shots[next];
        if (_due(shot)) {
          await _capture(shot);
          next++;
          continue;
        }
        if (home.session?.stage == 'done') {
          home.test.log('CINE shot ${shot.name} never started');
          next++;
          continue;
        }
        home.stepFixed();
        _noteCutscene();
        await replay.pump();
        if (++stepsSinceFrame >= ahead) {
          stepsSinceFrame = 0;
          await _frame();
        }
      }
      await Future.wait(_writes);
      await _frames?.close();
      await _audio?.close();
      home.test.log('CINE done: $_saved frames saved');
    } catch (e, st) {
      home.test.log('CINE failed: $e\n$st');
    }
    running = false;
    unawaited(home.quit());
  }

  void _noteCutscene() {
    final name = home.director?.player?.scene.name;
    if (name != null && name != _lastCutscene) _cutscenesSeen[name] = (_cutscenesSeen[name] ?? 0) + 1;
    _lastCutscene = name;
  }

  bool _due(_Shot s) {
    final a = s.start;
    if (a['tick'] != null) return home.ticks >= (a['tick'] as int);
    if (a['ui'] != null) {
      final v = home.village;
      return v != null && home.phase == Phase.playing && !v.paused && v.uiMs >= (a['ui'] as num);
    }
    if (a['cutscene'] != null) {
      final p = home.director?.player;
      return p != null &&
          p.scene.name == a['cutscene'] &&
          (_cutscenesSeen[p.scene.name] ?? 0) == ((a['n'] as int?) ?? 1) &&
          p.time >= ((a['at'] as num?) ?? 0);
    }
    if (a['stage'] != null) {
      final d = home.session;
      return d != null && d.stage == a['stage'] && d.stageTime >= ((a['at'] as num?) ?? 0);
    }
    return false;
  }

  Future<void> _capture(_Shot s) async {
    final dir = Directory('$_out/${s.name}')..createSync(recursive: true);
    _current = s;
    hud = s.hud;
    home.cinematicChanged();
    final select = s.json['select'] as String?;
    if (select != null) home.select(select);
    home.test.log('CINE shot ${s.name} at tick ${home.ticks} ${home.village?.now.label} for ${s.frames} frames');
    final cam = s.camera == null ? null : _CameraPath(s.camera!, home.stage);
    for (_shotFrame = 0; _shotFrame < s.frames; _shotFrame++) {
      home.stepFixed();
      _noteCutscene();
      await home.replay!.pump();
      final t = _shotFrame / math.max(1, s.frames - 1);
      if (cam != null) home.stage.rig.override = cam.at(t, 1 / 60);
      final scroll = (s.json['inspectorScroll'] as List?)?.cast<num>();
      if (scroll != null && inspectorScroll.hasClients) {
        final at = scroll[0] + (scroll[1] - scroll[0]) * applyEase(Ease.inOut, t);
        inspectorScroll.jumpTo(at.toDouble().clamp(0.0, inspectorScroll.position.maxScrollExtent));
      }
      if (_shotFrame % _preview != 0) continue;
      await _frame();
      final v = home.village;
      _frames?.writeln(
        jsonEncode({
          'shot': s.name,
          'f': _shotFrame,
          'tick': home.ticks,
          'now': v?.now.label,
          'cut': home.director?.player?.scene.name,
          'cutT': home.director?.player?.time,
          'stage': home.session?.stage,
        }),
      );
      final image = await _grab();
      if (image == null) continue;
      _writes.add(_save(image, '${dir.path}/${_shotFrame.toString().padLeft(5, '0')}.png'));
      if (_writes.length > 6) await _writes.removeAt(0);
      _saved++;
    }
    if (select != null) home.select(null);
    if (cam != null) home.stage.rig.override = null;
    hud = const {};
    home.cinematicChanged();
    _current = null;
  }

  /// Draws a frame now rather than on the next vsync, which a sleeping
  /// display or a locked screen never sends.
  Future<void> _frame() async {
    final drawn = SchedulerBinding.instance.endOfFrame;
    SchedulerBinding.instance.scheduleWarmUpFrame();
    await drawn;
  }

  Future<ui.Image?> _grab() async {
    final boundary = home.test.boundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;
    return boundary.toImage(pixelRatio: _scale);
  }

  Future<void> _save(ui.Image image, String name) async {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await File(name).writeAsBytes(png!.buffer.asUint8List());
  }
}

class _Shot {
  _Shot(this.json)
    : name = json['name'] as String,
      start = (json['start'] as Map).cast<String, Object?>(),
      frames = json['frames'] as int,
      camera = (json['camera'] as Map?)?.cast<String, Object?>(),
      hud = {...((json['hud'] as List?) ?? const []).cast<String>()};
  final Map<String, Object?> json;
  final String name;
  final Map<String, Object?> start;
  final int frames;
  final Map<String, Object?>? camera;
  final Set<String> hud;
}

/// An eased camera move around a subject: the eye sits at azimuth `az`
/// and elevation `el` (degrees) and distance `dist` from the subject,
/// looking at it `look` metres up, with `fov` degrees vertical; each is a
/// number or a [from, to] pair eased over the shot. `subject` is llama
/// names (their centre), "Dash", or a world point; with `"follow": false`
/// it stays where it was when the shot began, and `lag` sets how quickly
/// a followed subject is caught up with. `azFrom` makes the azimuth
/// relative to that actor's heading, `side` shifts the subject off centre
/// and `rise` lifts the eye.
class _CameraPath {
  _CameraPath(this.spec, this.stage) {
    _fixed = _subject();
    final names = spec['subject'];
    if (spec['pair'] == true && names is String && names.contains(',')) {
      final [a, b] = [for (final n in names.split(',').take(2)) _actor(n.trim())];
      final d = b - a;
      _pairAz = math.atan2(d.x, d.z) + math.pi / 2;
    }
  }
  final Map<String, Object?> spec;
  final VillageStage stage;
  late final vm.Vector3 _fixed;

  /// With `"pair": true`, the azimuth is measured from the side-on view of
  /// the first two subjects as they stood when the shot began.
  double _pairAz = 0;
  vm.Vector3? _smooth;

  bool get _follow => spec['follow'] as bool? ?? true;

  vm.Vector3 _subject() {
    final s = spec['subject'];
    if (s is List) return vm.Vector3((s[0] as num).toDouble(), (s[1] as num).toDouble(), (s[2] as num).toDouble());
    final names = (s as String).split(',').map((n) => n.trim()).toList();
    final sum = vm.Vector3.zero();
    for (final n in names) {
      sum.add(_actor(n));
    }
    return sum / names.length.toDouble();
  }

  /// A llama, "Dash", or an animal as "cat:0", "chicken:2", "duck:1".
  vm.Vector3 _actor(String n) {
    if (n == 'Dash') return stage.dash.position;
    final colon = n.indexOf(':');
    if (colon < 0) return stage.llamas[n]!.position;
    final species = Species.values.byName(n.substring(0, colon));
    final c = stage.life.of(species).elementAt(int.parse(n.substring(colon + 1)));
    final (x, z) = c.pos;
    return vm.Vector3(x, groundHeight(x, z) + c.lift, z);
  }

  double _v(String key, double t, double fallback) {
    final r = spec[key];
    if (r == null) return fallback;
    if (r is num) return r.toDouble();
    final pair = (r as List).cast<num>();
    final ease = switch (spec['ease']) {
      'linear' => Ease.linear,
      'out' => Ease.out,
      _ => Ease.inOut,
    };
    return pair[0] + (pair[1] - pair[0]) * applyEase(ease, t);
  }

  PerspectiveCamera at(double t, double dt) {
    final raw = _follow ? _subject() : _fixed;
    final last = _smooth;
    final s = _smooth = last == null ? raw : last + (raw - last) * math.min(1.0, dt * ((spec['lag'] as num?)?.toDouble() ?? 4));
    var az = _v('az', t, 0) * math.pi / 180 + _pairAz;
    final from = spec['azFrom'] as String?;
    if (from != null) az += from == 'Dash' ? stage.dash.yaw : stage.llamas[from]!.yaw;
    final el = _v('el', t, 10) * math.pi / 180, dist = _v('dist', t, 8);
    final eye = s + vm.Vector3(math.sin(az) * math.cos(el), math.sin(el), math.cos(az) * math.cos(el)) * dist;
    var target = s + vm.Vector3(0, _v('look', t, 1.2), 0);
    final side = _v('side', t, 0);
    if (side != 0) {
      final forward = (target - eye)..normalize();
      final right = forward.cross(vm.Vector3(0, 1, 0))..normalize();
      target = target - right * side;
    }
    return PerspectiveCamera(
      position: eye + vm.Vector3(0, _v('rise', t, 0), 0),
      target: target,
      fovRadiansY: _v('fov', t, 28) * math.pi / 180,
      fovNear: 0.3,
      fovFar: 400,
    );
  }
}

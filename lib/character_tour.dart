import 'dart:math' as math;

import 'package:vector_math/vector_math.dart' as vm;

import 'app.dart';
import 'render/llama_rig.dart';
import 'sim/dash.dart';
import 'sim/geo.dart';
import 'sim/village.dart';

/// `VILLAGE_TOUR=chars` (with `VILLAGE_CAPTURE=1`): stages the llamas and
/// Dash for the character captures, then quits. A lineup in a neutral pose
/// (and with the inspector open), an expression sheet, each llama walking (and one galloping), Dash
/// flying, hovering, landing, cheering and drooping, and a conversation
/// with heads turning to the speaker.
class CharacterTour {
  CharacterTour(this.home);
  final VillageHomeState home;

  static const List<String> _names = ['Pip', 'Mo', 'June', 'Bramble', 'Clover'];
  static const double _cx = 2, _cz = 24;

  final List<_Step> _steps = [];
  int _next = 0;
  double _t = 0, _since = 0;
  Future<void>? _shooting;
  bool _done = false;

  /// Llamas walking in place for the walk shots: name -> (start x, speed).
  final Map<String, (double, double, double)> _walkers = {};
  double _walkT = 0;

  void start() {
    home.setSpeed(4);
    _plan();
  }

  /// Aims the orbit camera at [target] (the rig itself looks 1.2 m above
  /// its target).
  void _view(vm.Vector3 target, {double yaw = 0, double pitch = 0.25, double distance = 14}) {
    home.stage.rig
      ..follow = null
      ..followName = null
      ..target = target - vm.Vector3(0, 1.2, 0)
      ..yaw = yaw
      ..pitch = pitch
      ..distance = distance;
  }

  vm.Vector3 _at(double x, double z, [double up = 0]) => vm.Vector3(x, groundHeight(x, z) + up, z);

  void _lineup({double spacing = 2.4, FaceTargets? face, vm.Vector3? look}) {
    _walkers.clear();
    for (final (i, n) in _names.indexed) {
      home.stage.llamas[n]!
        ..staged = (x: _cx + (i - 2) * spacing, z: _cz, yaw: math.pi, look: look)
        ..forcedFace = face;
    }
  }

  void _unstage() {
    _walkers.clear();
    for (final a in home.stage.llamas.values) {
      a
        ..staged = null
        ..forcedFace = null;
    }
  }

  void _plan() {
    final v = home.village!;
    void dashAway() => v.dash.flyTo((_cx + 30, _cz + 25));
    _steps.addAll([
      // Early, so Pip still has her scarf.
      _Step(null, 0, () {}, until: () => v.now.minute >= 7 * 60 + 50),
      _Step(null, 0, () {
        home.setSpeed(0.02);
        home.stage.scarfOverride = true;
        dashAway();
        _lineup(face: const FaceTargets());
        _view(_at(_cx, _cz, 1.0), yaw: 0.25, pitch: 0.16, distance: 16);
      }),
      _Step('lineup_neutral', 2.5, () {}),
      _Step('lineup_front', 1.8, () => _view(_at(_cx, _cz, 1.0), yaw: 0.0, pitch: 0.05, distance: 15)),
      _Step('lineup_inspector', 1.2, () => home.select('June')),
      _Step(null, 0, () => home.select(null)),
      _Step(null, 0, () {
        for (final (i, n) in _names.indexed) {
          home.stage.llamas[n]!.staged = (x: _cx + (i - 2) * 2.7, z: _cz, yaw: math.pi / 2, look: null);
        }
        _view(_at(_cx, _cz, 1.0), yaw: 0.02, pitch: 0.05, distance: 17);
      }),
      _Step('lineup_profiles', 2.5, () {}),
      for (final (name, face) in const [
        ('neutral', FaceTargets()),
        ('happy', FaceTargets(happy: 1)),
        ('sulky', FaceTargets(sulky: 1)),
        ('surprised', FaceTargets(surprised: 1)),
        ('sleepy', FaceTargets(sleepy: 1)),
        ('eyes_shut', FaceTargets(shut: 1)),
        ('talking', FaceTargets(talk: 0.9)),
      ])
        _Step('expr_$name', 1.4, () {
          _lineup(spacing: 1.9, face: face);
          _view(_at(_cx, _cz, 1.45), yaw: 0.1, pitch: 0.06, distance: 11);
        }),
      // Each llama walking at its in-game pace, followed side-on.
      for (final n in _names) ...[
        _Step(null, 0, () {
          _unstageAllBut(n);
          _walkers[n] = (_cx - 6, _cz, v.byName(n).walkPace);
          _walkT = 0;
        }),
        for (var k = 0; k < 3; k++) _Step('walk_${n.toLowerCase()}_$k', k == 0 ? 1.6 : llamaSpecs[n]!.walkSeconds / 3, () {}),
      ],
      _Step(null, 0, () {
        _unstageAllBut('Pip');
        _walkers['Pip'] = (_cx - 14, _cz, 6.5);
        _walkT = 0;
      }),
      _Step('gallop_pip', 1.6, () {}),
      // Dash.
      _Step(null, 0, () {
        _unstage();
        home.stage.scarfOverride = null;
        home.setSpeed(1);
        v.dash.flyTo((_cx - 16, _cz + 2));
      }, until: () => dist(v.dash.pos, (_cx - 16, _cz + 2)) < 1.5),
      _Step(null, 0.8, () {
        v.dash.flyTo((_cx + 18, _cz + 6));
        home.stage.rig
          ..follow = (() => home.stage.dash.position - vm.Vector3(0, 1.2, 0))
          ..followName = 'Dash'
          ..yaw = 0.25
          ..pitch = 0.12
          ..distance = 5.5;
      }),
      _Step('dash_fly', 1.3, () {}),
      _Step('dash_fly_2', 0.11, () {}),
      _Step('dash_bank', 0.3, () => v.dash.flyTo((_cx + 10, _cz - 10))),
      _Step('dash_land', 0.07, () {}, until: () => !v.dash.moving),
      _Step('dash_hover', 1.5, () {}),
      _Step('dash_hover_2', 0.3, () {}),
      // Round to face him.
      _Step('dash_face', 1.6, () => home.stage.rig.yaw = home.stage.dash.yaw + math.pi),
      _Step('dash_face_34', 1.4, () => home.stage.rig.yaw = home.stage.dash.yaw + math.pi + 0.7),
      _Step('dash_happy', 0.5, () {
        home.stage.rig.yaw = home.stage.dash.yaw + math.pi + 0.3;
        home.stage.dash.react(4);
      }),
      _Step('dash_sad', 3.0, () => home.stage.dash.react(0)),
      // A conversation: wait for two llamas talking, frame them side-on.
      _Step(null, 0, () {
        home.stage.rig.follow = null;
        home.setSpeed(1);
      }, until: () => _pair(v) != null),
      for (var k = 0; k < 4; k++) _Step('talk_$k', k == 0 ? 1.5 : 1.6, _frameTalk),
      // Dash drops in on a llama: it turns to look at him.
      _Step(null, 0, () {
        final l = v.cast.firstWhere((l) => !l.asleep && l.activity.kind != 'walk' && !l.busyTalking, orElse: () => v.cast.first);
        home.talkTo(l.name);
        home.stage.rig
          ..follow = (() => home.stage.llamas[l.name]!.position.clone())
          ..followName = l.name
          ..yaw = 0.9
          ..pitch = 0.22
          ..distance = 9;
      }, until: () => v.dash.visit?.stage == VisitStage.choosing),
      _Step('dash_visit', 1.4, () {}),
    ]);
  }

  void _unstageAllBut(String name) {
    _walkers.clear();
    for (final n in _names) {
      final a = home.stage.llamas[n]!;
      a.forcedFace = null;
      // The others stand well out of shot.
      a.staged = n == name ? null : (x: _cx + 30, z: _cz + 30 + _names.indexOf(n) * 3.0, yaw: 0, look: null);
    }
  }

  /// A llama speaking to another llama, and its listener.
  (String, String)? _pair(Village v) {
    for (final sp in v.speech.values) {
      final to = sp.to;
      if (sp.kind != SpeechKind.say || sp.text == null || to == null || to == 'Dash' || sp.who == 'Dash') continue;
      if (home.stage.llamas[sp.who]!.visible && home.stage.llamas[to]!.visible) return (sp.who, to);
    }
    return null;
  }

  (String, String)? _talking;

  void _frameTalk() {
    final v = home.village!;
    final pair = _pair(v) ?? _talking;
    if (pair == null) return;
    _talking = pair;
    final a = home.stage.llamas[pair.$1]!.position, b = home.stage.llamas[pair.$2]!.position;
    final d = b - a;
    home.test.log('TOUR talk ${pair.$1} to ${pair.$2}');
    _view(
      (a + b) * 0.5 + vm.Vector3(0, 1.1, 0),
      yaw: math.atan2(d.x, d.z) + math.pi / 2 + 0.35,
      pitch: 0.16,
      distance: math.max(7, d.length * 2.4),
    );
  }

  void tick(double dt) {
    if (_done) return;
    _t += dt;
    _since += dt;
    _walkT += dt;
    for (final MapEntry(key: n, value: (x0, z, speed)) in _walkers.entries) {
      final x = x0 + speed * _walkT;
      home.stage.llamas[n]!.staged = (x: x, z: z, yaw: -math.pi / 2, look: null);
      home.stage.rig
        ..follow = null
        ..target = _at(x, z, -0.45)
        ..yaw = 0.05
        ..pitch = 0.1
        ..distance = n == 'June' ? 7.5 : 9.5;
    }
    if (_shooting != null) return;
    while (_next < _steps.length) {
      final s = _steps[_next];
      if (!s.started) {
        s.started = true;
        s.setup();
        _since = 0;
      }
      if (s.until != null && !s.until!()) {
        if (_since > 90) home.test.log('TOUR gave up waiting at step $_next');
        if (_since <= 90) return;
      }
      if (_since < s.wait) return;
      _next++;
      _since = 0;
      final name = s.shot;
      if (name != null) {
        _shooting = home.test.shot(name).whenComplete(() => _shooting = null);
        return;
      }
    }
    _finish();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _unstage();
    home.stage.scarfOverride = null;
    home.test.log('TOUR done in ${_t.toStringAsFixed(0)} s');
    if (home.test.exitWhenDone) home.quit();
  }
}

class _Step {
  _Step(this.shot, this.wait, this.setup, {this.until});
  final String? shot;
  final double wait;
  final void Function() setup;
  final bool Function()? until;
  bool started = false;
}

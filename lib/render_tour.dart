import 'dart:io';
import 'dart:math' as math;

import 'package:vector_math/vector_math.dart' as vm;

import 'ambient/creatures.dart';
import 'ambient/layout.dart';
import 'app.dart';
import 'character_tour.dart';
import 'render/quality.dart';
import 'sim/dash.dart';
import 'sim/geo.dart';
import 'sim/village.dart';

/// The env-gated rendering tour, a sibling of the autoplay script:
///
/// * `VILLAGE_TOUR=shots` follows one day and captures the looks (sunrise,
///   midday, the storm, the golden and blue hours, night with fireflies),
///   the animals (chickens by the bakery, ducks on the pond, cats on a
///   roof) and a crowded conversation's bubbles, then quits.
/// * `VILLAGE_TOUR=chars` stages the characters for their captures (see
///   `character_tour.dart`).
/// * `VILLAGE_TOUR=perf` measures the frame rate and the p95 time between
///   rendered frames at each graphics quality (or those in
///   `VILLAGE_PERF_QUALITY`), with the model generating and with the
///   village paused (idle).
///
/// It starts a new game from the title screen and plays it without the
/// week's cutscenes, so the clock runs straight through the day. The storm
/// comes on day 3: add `VILLAGE_JUMP_DAY=3` to capture it.
///
/// Needs `VILLAGE_CAPTURE=1` for shots and frame timings.
class RenderTour {
  RenderTour(this.home, this.mode);
  final VillageHomeState home;
  final String mode;

  static String? get requested => Platform.environment['VILLAGE_TOUR'];

  final List<_Shot> _shots = [];
  int _next = 0;
  double _t = 0, _since = 0;
  Future<void>? _shooting;
  bool _crowdTaken = false;
  bool _done = false;
  bool _gameRequested = false;
  bool _started = false;

  CharacterTour? _chars;

  void start() {
    home.test.log('TOUR start $mode');
    if (mode == 'chars') {
      _chars = CharacterTour(home)..start();
      return;
    }
    home.setSpeed(mode == 'perf' ? 1 : 2);
    if (mode == 'perf') {
      _perfPlan();
    } else {
      _shotPlan();
    }
  }

  void _shotPlan() {
    final stage = home.stage;
    void view(vm.Vector3 target, {double yaw = 0, double pitch = 0.74, double distance = 64}) {
      stage.rig
        ..follow = null
        ..followName = null
        ..target = target
        ..yaw = yaw
        ..pitch = pitch
        ..distance = distance;
    }

    _shots.addAll([
      _Shot('sunrise', 6.55, () => view(vm.Vector3(1, 0, -4), yaw: -0.45, pitch: 0.38, distance: 55)),
      _Shot('midday', 11.4, () => stage.rig.overview()),
      _Shot('chickens_bakery', 11.9, () => _aimAt(Species.chicken, distance: 8)),
      _Shot('ducks_pond', 12.4, () => view(vm.Vector3(-18.5, 0, 13.5), yaw: 0.35, pitch: 0.55, distance: 15)),
      _Shot('storm', -1, () => stage.rig.overview(), when: () => home.village!.storm && _stormFor > 6),
      _Shot(
        'storm_bakery',
        -1,
        () => view(vm.Vector3(-1, 0.5, 4), yaw: 0.25, pitch: 0.4, distance: 18),
        when: () => home.village!.storm && _stormFor > 12,
      ),
      _Shot('after_storm', 17.9, () => view(vm.Vector3(-2, 0, 4), yaw: 0.3, pitch: 0.5, distance: 30)),
      _Shot('golden_hour', 19.05, () => view(vm.Vector3(1, 0, -5), yaw: 0.85, pitch: 0.42, distance: 58)),
      _Shot('golden_close', 19.35, () => view(vm.Vector3(-2, 0.5, 1), yaw: 0.6, pitch: 0.3, distance: 30)),
      _Shot('blue_hour', 20.75, () => view(vm.Vector3(1, 0, -5), yaw: 0.2, pitch: 0.62, distance: 60)),
      _Shot('night', 22.4, () => view(vm.Vector3(1, 0, -5), yaw: 0.35, pitch: 0.5, distance: 60)),
      _Shot('night_fireflies', 22.7, () => view(vm.Vector3(-10, 0.5, 9), yaw: 0.55, pitch: 0.28, distance: 24)),
    ]);
  }

  double _stormFor = 0;

  /// Frames one visible animal of [species], from the side away from the
  /// building it is nearest, so the building is backdrop, not foreground.
  void _aimAt(Species species, {double distance = 10}) {
    final all = home.stage.life.of(species).where((c) => c.visible).toList();
    if (all.isEmpty) return;
    final c = all.first;
    final away = math.atan2(c.pos.$1 - AmbientLayout.coop.$1, c.pos.$2 - AmbientLayout.coop.$2);
    home.stage.rig
      ..follow = null
      ..target = vm.Vector3(c.pos.$1, -0.7, c.pos.$2)
      ..yaw = away
      ..pitch = 0.4
      ..distance = distance;
  }

  void _sendCatsUp() {
    final cats = home.stage.life.of(Species.cat).toList();
    for (final (i, c) in cats.indexed) {
      home.stage.life.sendToRoof(c, "Pip's hut", side: i);
    }
  }

  bool _catsTaken = false;
  double _catsSent = -1;
  double _catAimed = -1;

  /// Sends the cats up Pip's roof by day and, once one is up, frames it
  /// from outside the hut.
  void _watchCats(double hour) {
    final life = home.stage.life;
    if (hour >= 9 && (_catsSent < 0 || hour - _catsSent > 3)) {
      _catsSent = hour;
      _sendCatsUp();
    }
    final up = life.of(Species.cat).where((c) => c.perched && c.act == Act.perch).toList();
    if (up.isEmpty) {
      _catAimed = -1;
      return;
    }
    final cat = up.first;
    if (_catAimed < 0) {
      _catAimed = _t;
      final (hx, hz) = placeAnchor("Pip's hut");
      home.stage.rig
        ..follow = null
        ..target = vm.Vector3(cat.pos.$1, 1.4, cat.pos.$2)
        ..yaw = math.atan2(cat.pos.$1 - hx, cat.pos.$2 - hz) + 0.5
        ..pitch = 0.3
        ..distance = 9;
      home.setSpeed(0.25);
      return;
    }
    if (_t - _catAimed < 1.5) return;
    _catsTaken = true;
    home.test.log('TOUR cats ${[for (final c in life.of(Species.cat)) '${c.act.name} up=${c.perched} lift=${c.lift.toStringAsFixed(2)}']}');
    _shooting = home.test.shot('cats_roof').whenComplete(() {
      _shooting = null;
      home.setSpeed(2);
    });
  }

  void tick(double dt) {
    if (_done) return;
    if (!_started) {
      if (!_gameRequested && home.phase == Phase.menu && home.busy == null) {
        _gameRequested = true;
        home.newGame();
      }
      if (home.village == null || home.phase != Phase.playing) return;
      _started = true;
      start();
    }
    final chars = _chars;
    if (chars != null) {
      chars.tick(dt);
      return;
    }
    _t += dt;
    _since += dt;
    if (_shooting != null) return;
    final v = home.village!;
    _stormFor = v.storm ? _stormFor + dt : 0;
    if (mode == 'perf') {
      _perf(v, dt);
      return;
    }
    final hour = (v.now.minute + v.minuteFrac) / 60;
    if (!_crowdTaken && hour < 18) _watchCrowd(v);
    if (!_catsTaken && hour >= 9 && hour < 17) {
      _watchCats(hour);
      if (_catAimed >= 0 || _shooting != null) return;
    }
    while (_next < _shots.length) {
      final s = _shots[_next];
      final due = s.when != null ? s.when!() : hour >= s.hour;
      // A shot whose moment passed (a storm that never came) is skipped.
      if (s.when != null && hour >= 18 && !due) {
        home.test.log('TOUR skipped ${s.name}');
        _next++;
        continue;
      }
      if (!due) break;
      if (!s.aimed) {
        s.aimed = true;
        s.aim();
        _since = 0;
        home.setSpeed(0.25);
        break;
      }
      if (_since < 2.2) break;
      _shooting = home.test.shot(s.name).whenComplete(() {
        _shooting = null;
        home.setSpeed(2);
      });
      _next++;
      break;
    }
    if (_next >= _shots.length && _shooting == null) _finish(v);
  }

  /// Waits for a crowd (three speakers with bubbles close together, or two
  /// beside a third llama), then frames it for the crowded-bubbles shot.
  void _watchCrowd(Village v) {
    final out = [
      for (final l in v.cast)
        if (home.stage.llamas[l.name]!.visible) (l.name, home.stage.llamas[l.name]!.position, v.speech[l.name]?.text != null),
      (('Dash', home.stage.dash.position, v.speech['Dash']?.text != null)),
    ];
    for (final (name, at, _) in out) {
      final near = out.where((o) => (o.$2 - at).length < 7).toList();
      final talking = near.where((o) => o.$3).length;
      if (talking < 2 || near.length < 3) continue;
      _crowdTaken = true;
      final c = near.map((o) => o.$2).reduce((a, b) => a + b) / near.length.toDouble();
      home.test.log('TOUR crowd around $name: ${near.map((o) => '${o.$1}${o.$3 ? '*' : ''}').join(', ')}');
      home.stage.rig
        ..follow = null
        ..target = c
        ..pitch = 0.6
        ..distance = 48;
      home.setSpeed(0.25);
      _shooting = Future<void>.delayed(const Duration(milliseconds: 900), () => home.test.shot('bubbles_crowd')).whenComplete(() {
        _shooting = null;
        home.setSpeed(2);
      });
      return;
    }
  }

  // ------------------------------------------------------------ perf

  /// Scenes to measure: the sunrise (god rays on High), a morning
  /// overview, the golden hour and the storm (rain, fog, wet ground), each
  /// at every quality,
  /// first with the model kept busy, then paused and idle.
  static const List<(String, double)> _scenes = [('sunrise', 6.3), ('morning', 8), ('golden', 18.4), ('storm', 15.3)];
  final List<(String, GraphicsQuality, bool)> _phases = [];
  int _phase = -1;
  int _windowStart = 0;
  double _phaseTime = 0;
  bool _waitingIdle = false;
  bool _travelling = false;
  final Map<(String, GraphicsQuality, bool), List<(double, double, List<double>)>> _results = {};

  /// `VILLAGE_PERF_QUALITY=high,low` measures only those qualities.
  static List<GraphicsQuality> get _qualities {
    final only = Platform.environment['VILLAGE_PERF_QUALITY']?.split(',');
    return [
      for (final q in [GraphicsQuality.high, GraphicsQuality.medium, GraphicsQuality.low])
        if (only == null || only.contains(q.name)) q,
    ];
  }

  void _perfPlan() {
    final scenes = [..._scenes]..sort((a, b) => a.$2.compareTo(b.$2));
    for (final (scene, _) in scenes) {
      for (final q in _qualities) {
        _phases
          ..add((scene, q, true))
          ..add((scene, q, false));
      }
    }
  }

  void _perf(Village v, double dt) {
    final hour = (v.now.minute + v.minuteFrac) / 60;
    if (_phase < 0) {
      _startPhase(0);
      return;
    }
    final (scene, q, generating) = _phases[_phase];
    if (_travelling) {
      final start = _scenes.firstWhere((s) => s.$1 == scene).$2;
      if (hour < start) return;
      _travelling = false;
      _beginMeasuring();
      return;
    }
    _phaseTime += dt;
    if (!generating && _waitingIdle) {
      if (home.test.generating() && _phaseTime < 20) return;
      _waitingIdle = false;
      _phaseTime = 0;
      _windowStart = home.test.windows.length + 1;
      return;
    }
    if (generating) _keepModelBusy(v);
    if (_phaseTime < (generating ? 24 : 12)) return;
    _results[(scene, q, generating)] = home.test.windows.sublist(math.min(_windowStart, home.test.windows.length));
    if (_phase + 1 < _phases.length) {
      _startPhase(_phase + 1);
    } else {
      _report();
      _finish(v);
    }
  }

  /// Keeps Dash chatting with one llama: pick a line, hear the reply, ask
  /// for more, so the model writes options and replies back to back.
  void _keepModelBusy(Village v) {
    final visit = v.dash.visit;
    if (visit == null) {
      final free = v.cast.where((l) => !l.asleep && !l.busyTalking && l.activity.kind != 'walk').firstOrNull;
      if (free != null) home.talkTo(free.name);
    } else if (visit.stage == VisitStage.choosing && visit.options != null) {
      home.choose(0);
    } else if (visit.stage == VisitStage.done) {
      v.dash.sayMore();
    }
  }

  void _startPhase(int i) {
    final previous = _phase < 0 ? null : _phases[_phase].$1;
    _phase = i;
    final (scene, q, _) = _phases[i];
    home.stage.quality = q;
    if (scene != previous) {
      // Run the clock forward to the scene, then measure.
      _travelling = true;
      home.village!
        ..paused = false
        ..dash.leave();
      home.setSpeed(4);
      return;
    }
    _beginMeasuring();
  }

  void _beginMeasuring() {
    final (scene, q, generating) = _phases[_phase];
    _phaseTime = 0;
    final v = home.village!;
    final rig = home.stage.rig;
    if (scene == 'golden' || scene == 'sunrise') {
      // The same views as the golden-hour and sunrise shots.
      final sunrise = scene == 'sunrise';
      rig
        ..follow = null
        ..target = sunrise ? vm.Vector3(1, 0, -4) : vm.Vector3(1, 0, -5)
        ..yaw = sunrise ? -0.45 : 0.85
        ..pitch = sunrise ? 0.38 : 0.42
        ..distance = sunrise ? 55 : 58;
    } else {
      rig.overview();
    }
    if (generating) {
      v.paused = false;
      // The clock runs at a tenth of the default 500 ms a minute under the
      // VILLAGE_MS_PER_MINUTE=100 the perf run uses, so a scene's light
      // holds while the model works.
      home.setSpeed(0.02);
    } else {
      v.dash.leave();
      v.paused = true;
      _waitingIdle = true;
    }
    // Skip the window that straddles the switch.
    _windowStart = home.test.windows.length + 1;
    home.test.log('TOUR phase $scene ${q.name} ${generating ? 'generating' : 'idle'} at ${v.now.hhmm}');
  }

  void _report() {
    String median(Iterable<double> v) {
      final s = v.toList()..sort();
      return s.isEmpty ? '-' : '${s[s.length ~/ 2].toStringAsFixed(1)} (n=${s.length}, min ${s.first.toStringAsFixed(1)})';
    }

    String p95(Iterable<(double, double, List<double>)> windows) {
      final s = [for (final w in windows) ...w.$3]..sort();
      return s.isEmpty ? '-' : '${s[(0.95 * (s.length - 1)).round()].toStringAsFixed(1)} ms';
    }

    for (final (scene, _) in _scenes) {
      for (final q in GraphicsQuality.values.reversed) {
        final gen = _results[(scene, q, true)] ?? const [];
        final idle = _results[(scene, q, false)] ?? const [];
        final busy = gen.where((w) => w.$2 >= 0.7);
        final quiet = idle.where((w) => w.$2 <= 0.1);
        home.test.log(
          'PERF_TABLE $scene ${q.name}: idle ${median(quiet.map((w) => w.$1))} p95 ${p95(quiet)}; '
          'generating ${median(busy.map((w) => w.$1))} p95 ${p95(busy)}; '
          'all generating-phase windows ${median(gen.map((w) => w.$1))} p95 ${p95(gen)}',
        );
      }
    }
  }

  void _finish(Village v) {
    if (_done) return;
    _done = true;
    home.test.log('TOUR animals ${home.stage.life.all.map((c) => '${c.species.name}${c.index}:${c.act.name}').join(' ')}');
    home.test.log('TOUR sounds ${home.animalSounds.played}');
    home.test.log('TOUR done in ${_t.toStringAsFixed(0)} s at ${v.now.label}');
    if (home.test.exitWhenDone) home.quit();
  }
}

class _Shot {
  _Shot(this.name, this.hour, this.aim, {this.when});
  final String name;
  final double hour;
  final void Function() aim;
  final bool Function()? when;
  bool aimed = false;
}

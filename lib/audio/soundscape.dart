import 'dart:math' as math;

import 'package:vector_math/vector_math.dart' as vm;

import '../sim/village.dart';

/// Where sounds are played: a mixer with named one-shot effects and named
/// looping tracks.
abstract interface class SoundOut {
  void play(String name, {double volume, double speed, double pan});
  void setLoopVolume(String name, double volume);
}

/// What the soundscape needs to know about the 3D view.
abstract interface class SoundView {
  vm.Vector3 get eye;
  vm.Vector3 get dash;

  /// A visible llama's position, or null while it is hidden indoors.
  vm.Vector3? llama(String name);

  /// Stereo pan (-1 left to 1 right) of a world point on screen.
  double panOf(vm.Vector3 p);
}

/// The music loops and when each effect fires, read from the sim each frame.
class Soundscape {
  Soundscape(this.out, {math.Random? rng, this.onPlay}) : _rng = rng ?? math.Random();

  final SoundOut out;
  final math.Random _rng;

  /// Called with each effect played and its volume, for the self-test log.
  final void Function(String name, double volume)? onPlay;

  static const List<String> loops = ['music_day', 'music_night', 'rain'];

  /// Per-llama pitch for the murmur blip.
  static const Map<String, double> voices = {'Pip': 1.24, 'Mo': 0.84, 'June': 1.1, 'Bramble': 0.74, 'Clover': 0.97};

  double musicVolume = 0.5;
  double sfxVolume = 0.7;

  final Map<String, double> _loopLevel = {for (final l in loops) l: 0};
  final Map<int, Speech> _bubbles = {};
  final Map<String, vm.Vector3> _lastPos = {};
  final Map<String, double> _stepTimer = {};
  final Map<String, int> _stepFoot = {};
  Village? _village;
  bool _dashMoving = false;
  double _flight = 0;
  double _flapTimer = 0;
  double _sinceChirp = 10;
  double _sinceSparkle = 10;
  double _ambientTimer = 4;

  /// Counts of effects played, for the self-test summary.
  final Map<String, int> played = {};

  /// How much of the day loop (vs. the night loop) plays at [hour].
  static double dayness(double hour) {
    double ramp(double x, double a, double b) => ((x - a) / (b - a)).clamp(0.0, 1.0);
    final up = ramp(hour, 5.2, 7.0);
    final down = 1 - ramp(hour, 19.6, 21.3);
    final d = math.min(up, down);
    return d * d * (3 - 2 * d);
  }

  /// Target loop levels (before the music volume) for the time and weather.
  static Map<String, double> mix(double hour, {required bool storm}) {
    final day = dayness(hour);
    final duck = storm ? 0.45 : 1.0;
    return {'music_day': day * duck, 'music_night': (1 - day) * 0.85 * duck, 'rain': storm ? 1.0 : 0.0};
  }

  void attach(Village v) {
    if (_village == v) return;
    _village = v;
    v.events.listeners.add(_onEvent);
  }

  void _onEvent(Map<String, Object?> e) {
    final v = _village;
    if (v == null || e['type'] != 'learn' || e['who'] == 'Dash') return;
    final fact = v.kb.facts[e['fact']];
    final byDash = e['from'] == 'Dash' || fact?.origin == 'Dash' || (e['fact'] as String? ?? '').startsWith('gift');
    if (!byDash || _sinceSparkle < 1.5) return;
    _sinceSparkle = 0;
    _play('sparkle', 0.8);
  }

  void click() => _play('click', 0.6);

  void update(Village v, SoundView view, double dt) {
    attach(v);
    _sinceChirp += dt;
    _sinceSparkle += dt;
    _music(v, dt);
    _dash(v, view, dt);
    _speech(v, view);
    _steps(v, view, dt);
    _ambient(v, dt);
  }

  void _music(Village v, double dt) {
    final hour = (v.now.minute + v.minuteFrac) / 60;
    final target = mix(hour, storm: v.storm);
    // About three seconds to cross between loops.
    final k = 1 - math.exp(-dt / 1.2);
    for (final name in loops) {
      final level = _loopLevel[name]! + (target[name]! - _loopLevel[name]!) * k;
      _loopLevel[name] = level;
      out.setLoopVolume(name, level * (name == 'rain' ? sfxVolume * 0.8 : musicVolume));
    }
  }

  double _near(vm.Vector3 p, vm.Vector3 eye, {double full = 18, double silent = 90}) {
    final d = (p - eye).length;
    return (1 - (d - full) / (silent - full)).clamp(0.25, 1.0);
  }

  void _dash(Village v, SoundView view, double dt) {
    final moving = v.dash.moving;
    final gain = _near(view.dash, view.eye);
    final pan = view.panOf(view.dash);
    if (moving) {
      _flight += dt;
      _flapTimer -= dt;
      if (!_dashMoving || _flapTimer <= 0) {
        _flapTimer = 1.1 + _rng.nextDouble() * 0.3;
        _play('flap', 0.55 * gain, speed: 0.95 + _rng.nextDouble() * 0.1, pan: pan);
      }
    } else if (_dashMoving && _flight > 0.6 && _sinceChirp > 1.5) {
      _sinceChirp = 0;
      _play('chirp', 0.6 * gain, speed: 0.97 + _rng.nextDouble() * 0.08, pan: pan);
    }
    if (!moving) _flight = 0;
    _dashMoving = moving;
  }

  void _speech(Village v, SoundView view) {
    final live = <int>{};
    for (final s in v.speech.values) {
      if (s.text == null) continue;
      live.add(s.id);
      if (_bubbles.containsKey(s.id)) continue;
      _bubbles[s.id] = s;
      if (s.kind != SpeechKind.say) continue;
      final p = s.who == 'Dash' ? view.dash : view.llama(s.who);
      final gain = p == null ? 0.4 : _near(p, view.eye);
      final pan = p == null ? 0.0 : view.panOf(p);
      if (s.who == 'Dash') {
        _play('chirp', 0.45 * gain, speed: 1.1, pan: pan);
      } else {
        final pitch = (voices[s.who] ?? 1) * (0.97 + _rng.nextDouble() * 0.06);
        _play('hum', 0.75 * gain, speed: pitch, pan: pan);
      }
    }
    final gone = _bubbles.keys.where((id) => !live.contains(id)).toList();
    for (final id in gone) {
      final s = _bubbles.remove(id)!;
      final p = s.who == 'Dash' ? view.dash : view.llama(s.who);
      final gain = p == null ? 0.4 : _near(p, view.eye);
      _play(
        'pop',
        (s.kind == SpeechKind.say ? 0.5 : 0.35) * gain,
        speed: 0.92 + _rng.nextDouble() * 0.16,
        pan: p == null ? 0 : view.panOf(p),
      );
    }
  }

  /// Footsteps for llamas that are moving and close to the camera.
  void _steps(Village v, SoundView view, double dt) {
    const hearing = 30.0;
    for (final l in v.cast) {
      final p = view.llama(l.name);
      if (p == null || dt <= 0) {
        _lastPos.remove(l.name);
        continue;
      }
      final last = _lastPos[l.name];
      _lastPos[l.name] = p.clone();
      if (last == null) continue;
      final speed = (p - last).length / dt;
      final d = (p - view.eye).length;
      if (speed < 0.4 || d > hearing) {
        _stepTimer[l.name] = 0;
        continue;
      }
      final t = (_stepTimer[l.name] ?? 0) - dt;
      if (t > 0) {
        _stepTimer[l.name] = t;
        continue;
      }
      // About a stride of 1.1 m per footfall.
      _stepTimer[l.name] = (1.1 / speed).clamp(0.22, 0.6);
      final foot = _stepFoot[l.name] = 1 - (_stepFoot[l.name] ?? 0);
      final near = 1 - d / hearing;
      _play(foot == 0 ? 'step1' : 'step2', 0.32 * near * near, speed: 0.9 + _rng.nextDouble() * 0.2, pan: view.panOf(p), log: false);
    }
  }

  /// Birds by day and crickets at night, now and then.
  void _ambient(Village v, double dt) {
    _ambientTimer -= dt;
    if (_ambientTimer > 0 || v.paused) return;
    final day = dayness((v.now.minute + v.minuteFrac) / 60);
    if (v.storm) {
      _ambientTimer = 5;
    } else if (day > 0.6) {
      _ambientTimer = 7 + _rng.nextDouble() * 10;
      _play(_rng.nextBool() ? 'birds1' : 'birds2', 0.3, speed: 0.92 + _rng.nextDouble() * 0.16, pan: _rng.nextDouble() * 1.4 - 0.7);
    } else if (day < 0.4) {
      _ambientTimer = 3 + _rng.nextDouble() * 6;
      _play('crickets', 0.22, speed: 0.95 + _rng.nextDouble() * 0.1, pan: _rng.nextDouble() * 1.6 - 0.8);
    } else {
      _ambientTimer = 4;
    }
  }

  void _play(String name, double volume, {double speed = 1, double pan = 0, bool log = true}) {
    final vol = volume * sfxVolume;
    played[name] = (played[name] ?? 0) + 1;
    if (vol <= 0.001) return;
    out.play(name, volume: vol, speed: speed, pan: pan.clamp(-1.0, 1.0));
    if (log) onPlay?.call(name, vol);
  }
}

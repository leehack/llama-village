import 'dart:math' as math;

import 'package:vector_math/vector_math.dart' as vm;

import '../audio/soundscape.dart';
import '../sim/geo.dart';

/// Plays the animals' meows, clucks, quacks and woofs: sparsely, quieter
/// with distance from the camera, panned to where they are on screen, and
/// scaled by the effects volume.
class AnimalSounds {
  AnimalSounds(this.out, {math.Random? rng, this.onPlay}) : _rng = rng ?? math.Random();

  final SoundOut out;
  final math.Random _rng;

  /// Called with each sound played and its volume, for the self-test log.
  final void Function(String name, double volume)? onPlay;

  static const List<String> sounds = ['meow', 'cluck', 'quack', 'woof'];
  static const Map<String, double> _loudness = {'meow': 0.42, 'cluck': 0.3, 'quack': 0.38, 'woof': 0.4};

  /// Sounds are not heard beyond this distance from the camera.
  static const double hearing = 45;

  double sfxVolume = 0.7;
  final Map<String, double> _since = {for (final s in sounds) s: 99};
  double _sinceAny = 99;

  /// Counts of sounds played, for the self-test summary.
  final Map<String, int> played = {};

  /// Plays some of this frame's [calls] (sound name and ground position).
  void update(List<(String, P2)> calls, SoundView view, double dt, {double Function(double x, double z)? groundAt}) {
    _sinceAny += dt;
    for (final s in sounds) {
      _since[s] = _since[s]! + dt;
    }
    for (final (name, (x, z)) in calls) {
      // At most one animal sound a second, and no species repeating within
      // a few seconds, so a coop full of hens never turns into a din.
      if (_sinceAny < 1.0 || (_since[name] ?? 0) < 3.0) continue;
      final p = vm.Vector3(x, groundAt?.call(x, z) ?? 0, z);
      final d = (p - view.eye).length;
      if (d > hearing) continue;
      final near = 1 - d / hearing;
      final vol = (_loudness[name] ?? 0.3) * near * near * sfxVolume;
      _sinceAny = 0;
      _since[name] = 0;
      played[name] = (played[name] ?? 0) + 1;
      if (vol <= 0.001) continue;
      out.play(name, volume: vol, speed: 0.92 + _rng.nextDouble() * 0.16, pan: view.panOf(p).clamp(-1.0, 1.0));
      onPlay?.call(name, vol);
    }
  }
}

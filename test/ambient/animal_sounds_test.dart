import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/ambient/animal_sounds.dart';
import 'package:llama_village/audio/soundscape.dart';
import 'package:vector_math/vector_math.dart' as vm;

class FakeOut implements SoundOut {
  final List<(String, double, double)> plays = [];

  @override
  void play(String name, {double volume = 1, double speed = 1, double pan = 0}) => plays.add((name, volume, pan));

  @override
  void setLoopVolume(String name, double volume) {}
}

class FakeView implements SoundView {
  @override
  vm.Vector3 eye = vm.Vector3(0, 0, 0);
  @override
  vm.Vector3 dash = vm.Vector3.zero();

  @override
  vm.Vector3? llama(String name) => null;

  @override
  double panOf(vm.Vector3 p) => p.x.sign * 0.5;
}

void main() {
  test('a call plays quieter with distance and is not heard far away', () {
    final out = FakeOut();
    final s = AnimalSounds(out, rng: math.Random(1))..sfxVolume = 1;
    s.update([('meow', (5, 0))], FakeView(), 2);
    s.update([('meow', (30, 0))], FakeView(), 4);
    s.update([('meow', (60, 0))], FakeView(), 4);
    expect(out.plays.map((p) => p.$1), ['meow', 'meow']);
    expect(out.plays[0].$2, greaterThan(out.plays[1].$2));
    expect(out.plays[0].$3, 0.5, reason: 'panned to its side of the screen');
  });

  test('calls are sparse: one a second, and a species waits a few seconds', () {
    final out = FakeOut();
    final s = AnimalSounds(out, rng: math.Random(1));
    s.update([('cluck', (1, 1)), ('cluck', (2, 1)), ('quack', (1, 2))], FakeView(), 0.1);
    expect(out.plays, hasLength(1));
    s.update([('quack', (1, 2))], FakeView(), 0.5);
    expect(out.plays, hasLength(1), reason: 'under a second since the last call');
    s.update([('cluck', (1, 1))], FakeView(), 1.0);
    expect(out.plays, hasLength(1), reason: 'the hen called under three seconds ago');
    s.update([('quack', (1, 2))], FakeView(), 0.1);
    expect(out.plays.map((p) => p.$1), ['cluck', 'quack']);
  });

  test('the effects volume scales the calls and zero silences them', () {
    final out = FakeOut();
    final s = AnimalSounds(out, rng: math.Random(1))..sfxVolume = 0.5;
    s.update([('woof', (1, 0))], FakeView(), 5);
    final half = out.plays.single.$2;
    s
      ..sfxVolume = 1
      ..update([('woof', (1, 0))], FakeView(), 5);
    expect(out.plays.last.$2, closeTo(half * 2, 1e-9));
    s
      ..sfxVolume = 0
      ..update([('woof', (1, 0))], FakeView(), 5);
    expect(out.plays, hasLength(2));
  });
}

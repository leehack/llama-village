import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/audio/soundscape.dart';
import 'package:llama_village/sim/clock.dart';
import 'package:llama_village/sim/village.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../sim/harness.dart';

class FakeOut implements SoundOut {
  final List<(String, double, double)> plays = [];
  final Map<String, double> loops = {};

  @override
  void play(String name, {double volume = 1, double speed = 1, double pan = 0}) => plays.add((name, volume, speed));

  @override
  void setLoopVolume(String name, double volume) => loops[name] = volume;

  List<String> get names => [for (final p in plays) p.$1];
}

class FakeView implements SoundView {
  @override
  vm.Vector3 eye = vm.Vector3(0, 10, 10);
  @override
  vm.Vector3 dash = vm.Vector3.zero();
  final Map<String, vm.Vector3> llamas = {};

  @override
  vm.Vector3? llama(String name) => llamas[name] ?? vm.Vector3.zero();

  @override
  double panOf(vm.Vector3 p) => 0;
}

void main() {
  test('day, night and storm mixes', () {
    expect(Soundscape.mix(12, storm: false), {'music_day': 1.0, 'music_night': 0.0, 'rain': 0.0});
    expect(Soundscape.mix(1, storm: false)['music_night'], greaterThan(0.8));
    expect(Soundscape.mix(1, storm: false)['music_day'], 0);
    final storm = Soundscape.mix(12, storm: true);
    expect(storm['rain'], 1);
    expect(storm['music_day'], lessThan(0.5));
    expect(Soundscape.dayness(6.1), inExclusiveRange(0, 1), reason: 'dawn crossfades');
  });

  test('loops ease toward the mix scaled by the music volume', () {
    final out = FakeOut();
    final s = Soundscape(out)..musicVolume = 0.5;
    final v = testVillage();
    for (var i = 0; i < 300; i++) {
      s.update(v, FakeView(), 1 / 30);
    }
    expect(v.now.minute ~/ 60, 6);
    expect(
      out.loops['music_day']! + out.loops['music_night']!,
      closeTo(0.5 * Soundscape.mix(6, storm: false).values.take(2).reduce((a, b) => a + b), 0.02),
    );
    expect(out.loops['rain'], 0);
  });

  test('a new speech bubble hums at the speaker pitch, and pops when it goes', () {
    final out = FakeOut();
    final s = Soundscape(out);
    final v = testVillage();
    final view = FakeView();
    v.sayNow('Bramble', 'Hello there.', to: 'Pip');
    s.update(v, view, 1 / 60);
    final hum = out.plays.singleWhere((p) => p.$1 == 'hum');
    expect(hum.$3, closeTo(Soundscape.voices['Bramble']!, 0.04));
    s.update(v, view, 1 / 60);
    expect(out.names.where((n) => n == 'hum'), hasLength(1), reason: 'once per bubble');
    v.speech.remove('Bramble');
    s.update(v, view, 1 / 60);
    expect(out.names, contains('pop'));
  });

  test('Dash flaps while flying and chirps on arrival', () {
    final out = FakeOut();
    final s = Soundscape(out);
    final v = testVillage();
    final view = FakeView();
    v.dash.moving = true;
    for (var i = 0; i < 60; i++) {
      s.update(v, view, 1 / 30);
    }
    expect(out.names.where((n) => n == 'flap').length, greaterThanOrEqualTo(2));
    v.dash.moving = false;
    s.update(v, view, 1 / 30);
    expect(out.names.last, 'chirp');
  });

  test('a fact spread by Dash sparkles; one learned otherwise does not', () {
    final out = FakeOut();
    final s = Soundscape(out);
    final v = testVillage();
    s.attach(v);
    final fact = v.kb.facts.keys.firstWhere((id) => !v.kb.knows('Mo', id) && !v.kb.knows('June', id));
    v.kb.learn('June', fact, 'saw', v.now);
    expect(out.names, isNot(contains('sparkle')));
    v.kb.learn('Mo', fact, 'told', v.now, from: 'Dash');
    expect(out.names, contains('sparkle'));
  });

  test('effects scale with the effects volume and go silent at zero', () {
    final out = FakeOut();
    final s = Soundscape(out)..sfxVolume = 0;
    s.click();
    expect(out.plays, isEmpty);
    s.sfxVolume = 1;
    s.click();
    expect(out.plays.single.$2, closeTo(0.6, 1e-9));
  });

  test('a speech kind other than say does not hum', () {
    final out = FakeOut();
    final s = Soundscape(out);
    final v = testVillage();
    v.sayNow('Mo', 'Hi.');
    v.speech['Mo'] = Speech(999, 'Mo', 'hmm, berries', SpeechKind.thought, v.uiMs);
    s.update(v, FakeView(), 1 / 60);
    expect(out.names, isNot(contains('hum')));
  });

  test('birds sing by day and crickets chirp at night', () {
    for (final (hour, expected) in [(12, 'birds'), (23, 'crickets')]) {
      final out = FakeOut();
      final s = Soundscape(out);
      final v = testVillage()..now = GameTime(1, hour * 60);
      for (var i = 0; i < 30 * 40; i++) {
        s.update(v, FakeView(), 1 / 30);
      }
      expect(out.names.where((n) => n.startsWith(expected)).length, greaterThanOrEqualTo(2), reason: 'hour $hour');
      expect(out.names.where((n) => n.startsWith(expected == 'birds' ? 'crickets' : 'birds')), isEmpty);
    }
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/render/llama_rig.dart';
import 'package:llama_village/sim/cast.dart';
import 'package:llama_village/sim/clock.dart';
import 'package:llama_village/sim/geo.dart';
import 'package:llama_village/sim/places.dart';
import 'package:llama_village/sim/village.dart';

import 'harness.dart';

/// On-screen speed at 1x of [l]'s current walk, in m/s.
double speedOf(Llama l) {
  final a = l.activity;
  return walkMetres(l.place, a.dest!, l.slot) / (a.until.minutesSince(a.start) * secondsPerMinuteAt1x);
}

GaitMix gaitOf(Llama l) => gaitMix(llamaSpecs[l.name]!, speedOf(l));

/// Runs the minute logic one minute at a time up to [t], calling [each]
/// after every minute.
void stepTo(Village v, GameTime t, [void Function()? each]) {
  while (v.now.compareTo(t) < 0) {
    v.skipTo(v.now.plus(1));
    each?.call();
  }
}

void main() {
  test('every walk is a walk at the llama\'s own pace, and every hurried one a gallop', () {
    for (final l in buildCast()) {
      final spec = llamaSpecs[l.name]!;
      for (final from in allPlaces) {
        for (final to in [...publicPlaces, l.home]) {
          if (from == to) continue;
          final metres = walkMetres(from, to, l.slot);
          final walk = metres / (travelMinutes(metres, l.walkPace) * secondsPerMinuteAt1x);
          final why = '${l.name} $from -> $to';
          expect(walk, inInclusiveRange(1.2, 1.8), reason: why);
          final walking = gaitMix(spec, walk);
          expect(walking.gallop, 0, reason: why);
          expect(walking.walkRate * spec.strideMetres / spec.walkSeconds, closeTo(walk, 1e-9), reason: '$why: hooves slide');
          final hurried = metres / (travelMinutes(metres, hurryPace) * secondsPerMinuteAt1x);
          final galloping = gaitMix(spec, hurried);
          expect(galloping.gallop, 1, reason: why);
          expect(galloping.gallopRate, closeTo(hurried / hurryPace, 1e-9), reason: '$why: hooves slide');
        }
      }
    }
  });

  test('an ordinary day is walked; only the dawn errand with a deadline hurries', () async {
    final v = testVillage(seed: 4);
    await v.begin();
    final seen = <Object>{};
    var walks = 0;
    while (v.now.compareTo(const GameTime(1, 21 * 60)) < 0) {
      await runMinutes(v, 1);
      for (final l in v.cast) {
        final a = l.activity;
        if (a.kind != 'walk' || !seen.add((l.name, a.start))) continue;
        walks++;
        if (a.hurry) {
          expect((l.name, a.dest, a.start.minute < 7 * 60), ('Bramble', 'berry bushes', true), reason: a.label);
          expect(gaitOf(l).gallop, 1);
        } else {
          expect(gaitOf(l).gallop, 0, reason: '${l.name} to ${a.dest}');
        }
      }
    }
    expect(walks, greaterThan(20));
  });

  test('the storm breaks walks in progress, and every walk in it, into a gallop', () async {
    final v = testVillage();
    await v.begin();
    await v.jumpTo(stormDay);
    v.offline = true;
    stepTo(v, const GameTime(stormDay, 14 * 60 + 50));
    final pip = v.byName('Pip')
      ..place = 'bakery'
      ..activity = Activity('walk', const GameTime(stormDay, 15 * 60 + 15), dest: 'pond', start: const GameTime(stormDay, 14 * 60 + 50));
    stepTo(v, const GameTime(stormDay, 14 * 60 + 59));
    expect(pip.activity.hurry, isFalse);
    final (before, _, _) = v.llamaPose(pip);
    stepTo(v, const GameTime(stormDay, 15 * 60));
    expect(v.storm, isTrue);
    expect(pip.activity.hurry, isTrue);
    expect(gaitOf(pip).gallop, greaterThan(0.9));
    final (after, _, _) = v.llamaPose(pip);
    expect(dist(before, after), lessThan(2.5), reason: 'Pip breaks into a gallop from where she is');

    final stormy = <String>[];
    stepTo(v, const GameTime(stormDay, 16 * 60), () {
      for (final l in v.cast.where((l) => l.activity.kind == 'walk' && l.activity.start.minute >= 15 * 60)) {
        expect(l.activity.hurry, isTrue, reason: l.name);
        stormy.add(l.name);
      }
    });
    expect(stormy, isNotEmpty);
  });

  test('a straggler gallops up at the festival call and every singer is on the hilltop by 16:00', () async {
    final v = testVillage();
    await v.begin();
    await v.jumpTo(festivalDay);
    v.offline = true;
    final pip = v.byName('Pip');
    expect(v.festival.contestants, contains('Pip'));
    stepTo(v, const GameTime(festivalDay, festivalCall - 1));
    pip
      ..place = 'berry bushes'
      ..activity = Activity('idle', v.now)
      ..hunger = 0
      ..energy = 1;
    stepTo(v, const GameTime(festivalDay, festivalCall));
    expect(pip.activity.kind, 'walk');
    expect(pip.activity.dest, 'hilltop');
    expect(pip.activity.hurry, isTrue);
    expect(gaitOf(pip).gallop, 1);
    expect(pip.activity.until.minute, lessThanOrEqualTo(festivalMinute));

    stepTo(v, const GameTime(festivalDay, festivalMinute - 1));
    for (final n in v.festival.contestants) {
      expect(v.byName(n).place, 'hilltop', reason: n);
    }
    stepTo(v, const GameTime(festivalDay, festivalMinute));
    expect(v.festival.performances.map((p) => p.$1), containsAll(v.festival.contestants));
  });
}

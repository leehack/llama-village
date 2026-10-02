import 'dart:math' as math;

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

  test('a walking llama moves without jumps, at one steady speed, across minutes and walk ends', () async {
    final v = testVillage(seed: 4);
    await v.begin();
    v.offline = true;
    const frames = 12;
    // Per llama: last frame's pose, and the walk it was on with its metres per game minute.
    final last = <String, (P2, P2, bool, Activity, double)>{};
    final speeds = <(String, GameTime), double>{};
    var walkFrames = 0, starts = 0, ends = 0, minuteEdges = 0;
    while (v.now.compareTo(const GameTime(1, 20 * 60)) < 0) {
      for (var f = 0; f < frames; f++) {
        final minute = v.now;
        v.advance(v.msPerMinute / frames);
        if (v.now != minute) minuteEdges++;
        for (final l in v.cast) {
          final (p, dir, walking) = v.llamaPose(l);
          final a = l.activity;
          final before = last[l.name];
          final pace = walking ? smoothWalk(l.place, a.dest!, l.slot).plannedLength / math.max(1, a.until.minutesSince(a.start)) : 0.0;
          last[l.name] = (p, dir, walking, a, walking ? pace : (before?.$5 ?? 0));
          if (before == null) continue;
          final (q, qDir, wasWalking, was, wasPace) = before;
          final why =
              '${l.name} at ${v.now.label} ${v.minuteFrac} ${was.kind}(${was.dest},${was.start.label},${was.hurry})->${a.kind}(${a.dest},${a.start.label},${a.hurry}) at ${l.place}';
          if (walking) {
            walkFrames++;
            final speed = speeds.putIfAbsent((l.name, a.start), () => v.walkSpeed(l));
            expect(v.walkSpeed(l), speed, reason: '$why: one steady speed for a whole walk');
          }
          if (walking && !wasWalking) starts++;
          if (wasWalking && !walking) ends++;
          if (!walking && !wasWalking) {
            expect(dist(p, q), 0, reason: '$why: a standing llama moved');
            continue;
          }
          // One frame of walking at most, with room for the keep-right sway.
          final step = math.max(pace, wasPace) / frames;
          expect(dist(p, q), lessThan(step * 1.8 + 1e-6), reason: '$why: jumped ${dist(p, q)} m');
          if (walking && identical(was, a)) {
            final turn = math.atan2(dir.$1 * qDir.$2 - dir.$2 * qDir.$1, dir.$1 * qDir.$1 + dir.$2 * qDir.$2).abs();
            expect(turn, lessThan(step * 6 + 0.05), reason: '$why: heading snapped $turn rad');
          }
        }
      }
      await settle();
    }
    expect(walkFrames, greaterThan(1000));
    expect(starts, greaterThan(10));
    expect(ends, greaterThan(10));
    expect(minuteEdges, greaterThan(800));
  });
}

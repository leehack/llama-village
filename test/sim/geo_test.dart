import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/sim/geo.dart';
import 'package:llama_village/sim/places.dart';

void main() {
  test('every place can reach every other place along the paths', () {
    for (final a in placeCoordinates.keys) {
      for (final b in placeCoordinates.keys) {
        final r = route(a, b);
        expect(r.first, a == b ? standPoint(a) : standPoint(a));
        expect(r.last, standPoint(b));
        if (a != b) expect(r.length, greaterThanOrEqualTo(2));
      }
    }
  });

  test('a route only enters a hut doorstep when it is the destination', () {
    final r = route('bakery', 'hilltop');
    for (final hut in placeCoordinates.keys.where(isHut)) {
      expect(r.contains(standPoint(hut)), isFalse, reason: hut);
    }
  });

  group('SmoothPath', () {
    double turn(P2 a, P2 b) => math.atan2(a.$1 * b.$2 - a.$2 * b.$1, a.$1 * b.$1 + a.$2 * b.$2).abs();

    test('walks by length from the first corner to the last', () {
      final path = SmoothPath(const [(0, 0), (10, 0)]);
      expect(path.at(0).$1, (0.0, 0.0));
      expect(path.at(0.25).$1, (2.5, 0.0));
      expect(path.at(1).$1, (10.0, 0.0));
      expect(path.at(0.5).$2, (1.0, 0.0));
      final bent = SmoothPath(const [(0, 0), (10, 0), (10, 10)]);
      expect(bent.at(0).$1, (0.0, 0.0));
      expect(bent.at(1).$1, (10.0, 10.0));
      expect(bent.length, lessThan(20));
      expect(bent.length, greaterThan(19));
    });

    test('rounds a corner so the heading turns gradually', () {
      final path = SmoothPath(const [(0, 0), (10, 0), (10, 10)]);
      var (last, lastDir) = path.at(0);
      var maxTurn = 0.0;
      for (var i = 1; i <= 2000; i++) {
        final (p, dir) = path.at(i / 2000);
        expect(dist(p, last), lessThan(path.length / 2000 * 1.01));
        maxTurn = math.max(maxTurn, turn(lastDir, dir));
        (last, lastDir) = (p, dir);
      }
      // A right angle spread over the rounded corner, not snapped in one step.
      expect(maxTurn, lessThan(0.02));
    });

    test('every walk starts and ends on its slots with a continuous heading', () {
      for (final from in allPlaces) {
        for (final to in allPlaces) {
          if (from == to) continue;
          for (var slot = 0; slot < 6; slot++) {
            final why = '$from -> $to slot $slot';
            final path = smoothWalk(from, to, slot);
            expect(dist(path.at(0).$1, slotPoint(from, slot)), lessThan(1e-9), reason: why);
            expect(dist(path.at(1).$1, slotPoint(to, slot)), lessThan(1e-9), reason: why);
            expect(path.length, lessThanOrEqualTo(walkMetres(from, to, slot) + 1e-9), reason: why);
            expect(path.plannedLength, closeTo(walkMetres(from, to, slot), 1e-9), reason: why);
            // Between the slot legs the walk still passes every junction.
            final route = walkPath(from, to, slot);
            final samples = [for (var i = 0; i <= 400; i++) path.at(i / 400).$1];
            for (final node in route.sublist(2, route.length - 2)) {
              expect(samples.map((p) => dist(p, node)).reduce(math.min), lessThan(1.0), reason: '$why misses $node');
            }
            var (_, lastDir) = path.at(0);
            final steps = (path.length / 0.02).ceil();
            for (var i = 1; i <= steps; i++) {
              final (_, dir) = path.at(i / steps);
              // 2 cm along the path never turns the heading more than ~6 degrees.
              expect(turn(lastDir, dir), lessThan(0.1), reason: '$why at ${i / steps}');
              lastDir = dir;
            }
          }
        }
      }
    });
  });

  test('slots at a place never overlap', () {
    for (final p in placeCoordinates.keys) {
      final slots = [for (var i = 0; i < 6; i++) slotPoint(p, i)];
      for (var i = 0; i < slots.length; i++) {
        for (var j = i + 1; j < slots.length; j++) {
          expect(dist(slots[i], slots[j]), greaterThan(1.5), reason: '$p $i $j');
        }
      }
    }
  });

  test('the hilltop is a hill and the pond a dip', () {
    final (hx, hz) = placeCoordinates['hilltop']!;
    final (px, pz) = placeCoordinates['pond']!;
    expect(groundHeight(hx, hz), greaterThan(4));
    expect(groundHeight(px, pz), lessThan(-0.5));
    expect(groundHeight(0, 0).abs(), lessThan(1));
  });

  test('placeNear finds the place a point stands at', () {
    expect(placeNear(standPoint('pond')), 'pond');
    expect(placeNear(slotPoint('bakery', 5)), 'bakery');
    expect(placeNear((45, 30)), isNull);
  });
}

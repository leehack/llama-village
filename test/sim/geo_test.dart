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

  test('along() walks a polyline by length', () {
    final pts = <P2>[(0, 0), (10, 0), (10, 10)];
    expect(along(pts, 0).$1, (0.0, 0.0));
    expect(along(pts, 0.25).$1, (5.0, 0.0));
    expect(along(pts, 0.75).$1, (10.0, 5.0));
    expect(along(pts, 0.75).$2, (0.0, 1.0));
    expect(along(pts, 1).$1, (10.0, 10.0));
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

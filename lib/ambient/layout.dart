import 'dart:math' as math;

import '../sim/geo.dart';
import '../sim/places.dart';

/// A round area walking creatures stay out of.
class Blocker {
  const Blocker(this.at, this.radius);
  final P2 at;
  final double radius;

  bool contains(P2 p, [double margin = 0]) => dist(p, at) < radius + margin;
}

/// A point in [place]'s local frame (x across, z towards its door), the
/// frame the scene builds each place in.
P2 placeLocal(String place, double x, double z) {
  final (ax, az) = placeAnchor(place);
  final (fx, fz) = placeFacing(place);
  return (ax + fz * x + fx * z, az - fx * x + fz * z);
}

/// Where the ambient dressing and the animals' haunts are, shared by the
/// scene (which builds them) and the creatures (which use them).
abstract final class AmbientLayout {
  static P2 get pond => placeAnchor('pond');

  /// Open water the ducks paddle in, around [pond].
  static const double waterRadius = 6.1;

  /// Land animals keep this far from the pond's centre.
  static const double shoreRadius = 8.6;

  /// The dock runs from the shore into the pond along the pond's facing.
  static (P2, P2) get dock {
    final (px, pz) = pond;
    final (fx, fz) = placeFacing('pond');
    return ((px + fx * 3.6, pz + fz * 3.6), (px + fx * 9.0, pz + fz * 9.0));
  }

  /// Where the ducks tuck in among the reeds at night and in a storm.
  static P2 duckRoost(int i) {
    final a = 3.05 + i * 0.22;
    final (px, pz) = pond;
    return (px + math.cos(a) * 5.4, pz - math.sin(a) * 5.4);
  }

  static const P2 coop = (7.0, 13.5);

  /// Yaw of the coop; its door faces the bakery square (-x).
  static const double coopYaw = -math.pi / 2;
  static const P2 coopDoor = (5.6, 13.5);

  static const P2 doghouse = (-8.6, 13.2);
  static const double doghouseYaw = 0.6;
  static P2 get doghouseDoor => (doghouse.$1 + math.sin(doghouseYaw) * 1.1, doghouse.$2 + math.cos(doghouseYaw) * 1.1);

  static const P2 well = (-4.5, 10.5);

  /// Laundry lines, pole to pole.
  static const List<(P2, P2)> laundry = [((19.5, 6.5), (23.2, 7.6)), ((-25.6, -7.6), (-24.4, -3.9))];

  /// Post-and-rail fence runs.
  static const List<List<P2>> fences = [
    [(9.6, 11.2), (10.0, 16.2), (4.6, 16.8)],
    [(6.4, -14.0), (6.4, -10.4), (10.8, -10.4), (10.8, -14.0), (8.4, -14.0)],
    [(-9.4, 15.2), (-7.8, 20.4)],
  ];

  /// Mo's vegetable patch, inside the second fence.
  static const P2 vegPatch = (8.6, -12.2);

  /// Lanterns along the paths, on top of the four street lamps.
  static List<P2> get pathLanterns {
    final segs = pathSegments();
    P2 beside(int edge, double t, double side) {
      final ((ax, az), (bx, bz)) = segs[edge];
      final dx = bx - ax, dz = bz - az;
      final l = math.sqrt(dx * dx + dz * dz);
      return (ax + dx * t - dz / l * 1.9 * side, az + dz * t + dx / l * 1.9 * side);
    }

    return [
      beside(4, 0.55, 1),
      beside(6, 0.5, -1),
      beside(7, 0.45, 1),
      beside(9, 0.5, 1),
      beside(10, 0.55, -1),
      beside(13, 0.5, 1),
      beside(16, 0.5, -1),
    ];
  }

  /// Under the bakery awning, where cats wait out a storm.
  static const List<P2> catShelters = [(-2.4, 3.45), (-1.6, 3.5)];

  /// Warm open patches for afternoon naps.
  static const List<P2> sunnySpots = [(-2.0, 15.5), (3.5, 19.0), (-6.5, 15.8), (9.5, 22.5), (-13.0, 21.0), (14.0, 7.6)];

  /// Huts whose eaves the cats climb onto.
  static const List<String> roofHuts = ["Pip's hut", "Mo's hut", "June's hut"];

  /// Where a cat sits on [hut]'s eave (height from the hut's base), and the
  /// ground spot it jumps from.
  static (P2, double, P2) roofPerch(String hut, int side) {
    final a = side.isEven ? 1.9 : -2.1;
    final on = placeLocal(hut, math.sin(a) * 2.75, math.cos(a) * 2.75);
    final from = placeLocal(hut, math.sin(a) * 3.7, math.cos(a) * 3.7);
    // The roof cone: eaves at 2.35 m and radius 3.05, apex at 4.65 m.
    return (on, 2.35 + 2.3 * (1 - 2.75 / 3.05), from);
  }

  /// Round no-go areas for walking creatures: buildings, bushes, the pond
  /// and the dressing.
  static final List<Blocker> blockers = [
    for (final p in placeCoordinates.keys)
      if (isHut(p)) Blocker(placeAnchor(p), 3.2),
    for (final x in const [-2.6, 0.0, 2.6])
      for (final z in const [-1.2, 1.2]) Blocker((x, z), 1.9),
    const Blocker((2.4, 3.9), 1.1),
    const Blocker((-3.3, 3.3), 0.75),
    for (final (x, z) in const [(-3.5, -1.2), (0.0, -2.0), (3.5, -1.2), (-5.0, 1.2), (5.0, 1.4)])
      Blocker(placeLocal('berry bushes', x, z), 1.9),
    Blocker(pond, shoreRadius),
    const Blocker(coop, 1.4),
    const Blocker(doghouse, 0.8),
    const Blocker(well, 1.1),
    Blocker(placeLocal('hilltop', 0, -2.6), 4.0),
  ];

  /// The island's walkable radius around its centre (0, -6).
  static const double islandRadius = 52;
}

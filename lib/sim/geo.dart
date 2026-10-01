import 'dart:math' as math;

import 'places.dart';

/// A point on the ground plane, in metres.
typedef P2 = (double, double);

P2 _add(P2 a, P2 b) => (a.$1 + b.$1, a.$2 + b.$2);
P2 _sub(P2 a, P2 b) => (a.$1 - b.$1, a.$2 - b.$2);
P2 _scale(P2 a, double k) => (a.$1 * k, a.$2 * k);
double dist(P2 a, P2 b) => math.sqrt((a.$1 - b.$1) * (a.$1 - b.$1) + (a.$2 - b.$2) * (a.$2 - b.$2));
P2 _norm(P2 a) {
  final l = math.sqrt(a.$1 * a.$1 + a.$2 * a.$2);
  return l < 1e-9 ? (0, 1) : (a.$1 / l, a.$2 / l);
}

P2 placeAnchor(String place) => placeCoordinates[place]!;

/// Unit vector a building's door faces: huts face the square, the bakery
/// faces south, open places face the square.
P2 placeFacing(String place) {
  if (place == 'bakery') return (0, 1);
  if (place == 'hilltop') return (0, 1);
  return _norm(_sub((0, 4), placeAnchor(place)));
}

/// Where llamas gather at [place]: in front of a door, on a shore.
P2 standPoint(String place) {
  final a = placeAnchor(place);
  final reach = switch (place) {
    'bakery' => 5.5,
    'pond' => 7.5,
    'berry bushes' => 4.0,
    'hilltop' => 3.5,
    _ => 4.5,
  };
  return _add(a, _scale(placeFacing(place), reach));
}

/// Fixed standing spots around a stand point, one per cast member plus
/// Dash, so llamas never shuffle when someone leaves.
const List<P2> _slotOffsets = [(0, 0), (-2.4, 0.6), (2.4, 0.6), (-1.2, 2.4), (1.2, 2.4), (0, -1.6), (-3.4, 2.6)];

P2 slotPoint(String place, int slot) {
  final f = placeFacing(place);
  final right = (-f.$2, f.$1);
  final o = _slotOffsets[slot % _slotOffsets.length];
  return _add(standPoint(place), _add(_scale(right, o.$1), _scale(f, o.$2)));
}

/// Path junctions; place stand points join through [_edges].
const Map<String, P2> _junctions = {'W': (-7, 5), 'E': (8, 6), 'NW': (-2, -10), 'CW': (-16, 1), 'H1': (1, -22), 'H2': (5, -27)};

const List<(String, String)> _edges = [
  ('bakery', 'W'),
  ('W', 'NW'),
  ('bakery', 'E'),
  ('W', "Pip's hut"),
  ('W', 'pond'),
  ('W', 'CW'),
  ('CW', "Clover's hut"),
  ('CW', 'pond'),
  ("Pip's hut", 'NW'),
  ('E', "June's hut"),
  ('E', 'berry bushes'),
  ('E', "Mo's hut"),
  ("Mo's hut", 'NW'),
  ('NW', "Bramble's hut"),
  ("Bramble's hut", 'H1'),
  ('NW', 'H1'),
  ('H1', 'H2'),
  ('H2', 'hilltop'),
];

P2 _node(String id) => _junctions[id] ?? standPoint(id);

/// Path segments for drawing the dirt paths.
List<(P2, P2)> pathSegments() => [for (final (a, b) in _edges) (_node(a), _node(b))];

final Map<(String, String), List<P2>> _routeCache = {};

/// The path from [from]'s stand point to [to]'s, through the junctions.
List<P2> route(String from, String to) {
  if (from == to) return [standPoint(from)];
  return _routeCache.putIfAbsent((from, to), () {
    final nodes = {..._junctions.keys, ...placeCoordinates.keys};
    final best = {for (final n in nodes) n: double.infinity};
    final prev = <String, String>{};
    best[from] = 0;
    final open = {...nodes};
    while (open.isNotEmpty) {
      final u = open.reduce((a, b) => best[a]! <= best[b]! ? a : b);
      open.remove(u);
      if (u == to) break;
      for (final (a, b) in _edges) {
        final v = a == u ? b : (b == u ? a : null);
        if (v == null || !open.contains(v)) continue;
        // Paths pass through huts' doorsteps only to reach that hut.
        if (isHut(v) && v != to) continue;
        final d = best[u]! + dist(_node(u), _node(v));
        if (d < best[v]!) {
          best[v] = d;
          prev[v] = u;
        }
      }
    }
    final ids = <String>[to];
    while (ids.last != from) {
      final p = prev[ids.last];
      if (p == null) return [standPoint(from), standPoint(to)];
      ids.add(p);
    }
    return [for (final id in ids.reversed) _node(id)];
  });
}

/// The full walk from slot to slot.
List<P2> walkPath(String from, String to, int slot) => [slotPoint(from, slot), ...route(from, to), slotPoint(to, slot)];

double polylineLength(List<P2> pts) {
  var total = 0.0;
  for (var i = 1; i < pts.length; i++) {
    total += dist(pts[i - 1], pts[i]);
  }
  return total;
}

/// The point a fraction [t] (0-1) of the way along [pts], and the heading
/// there as a unit vector.
(P2, P2) along(List<P2> pts, double t) {
  if (pts.length == 1) return (pts.first, (0, 1));
  final total = polylineLength(pts);
  var left = t.clamp(0.0, 1.0) * total;
  for (var i = 1; i < pts.length; i++) {
    final d = dist(pts[i - 1], pts[i]);
    if (left <= d || i == pts.length - 1) {
      final k = d < 1e-9 ? 0.0 : (left / d).clamp(0.0, 1.0);
      final dir = _norm(_sub(pts[i], pts[i - 1]));
      return (_add(pts[i - 1], _scale(_sub(pts[i], pts[i - 1]), k)), dir);
    }
    left -= d;
  }
  return (pts.last, (0, 1));
}

/// Height of the ground: a hill under the hilltop and a dip for the pond.
double groundHeight(double x, double z) {
  final (hx, hz) = placeCoordinates['hilltop']!;
  final dh = (x - hx) * (x - hx) + (z - hz) * (z - hz);
  final hill = 6.5 * math.exp(-dh / (2 * 9.0 * 9.0));
  final ridge = 2.2 * math.exp(-((x + 18) * (x + 18) + (z + 30) * (z + 30)) / (2 * 10.0 * 10.0));
  final (px, pz) = placeCoordinates['pond']!;
  final dp = math.sqrt((x - px) * (x - px) + (z - pz) * (z - pz));
  final pond = dp < 7.5 ? -1.1 * math.pow(math.cos(dp / 7.5 * math.pi / 2), 0.7) : 0.0;
  return hill + ridge + pond;
}

/// The place nearest to [p] within [radius] metres of its stand point.
String? placeNear(P2 p, {double radius = 7}) {
  String? best;
  var bestD = radius;
  for (final place in placeCoordinates.keys) {
    final d = math.min(dist(p, standPoint(place)), dist(p, placeAnchor(place)));
    if (d < bestD) {
      bestD = d;
      best = place;
    }
  }
  return best;
}

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

/// Real seconds a game minute lasts at 1x (`Village.msPerMinute`).
const double secondsPerMinuteAt1x = 0.5;

/// A hurried walk's speed in m/s at 1x: the Gallop clip's own pace.
const double hurryPace = 4.5;

/// Length of [walkPath], in metres.
double walkMetres(String from, String to, int slot) => from == to ? 0 : polylineLength(walkPath(from, to, slot));

/// Game minutes to cover [metres] at [pace] m/s on screen at 1x. Walks are
/// timed from the path so the llama on screen moves at that pace.
int travelMinutes(double metres, double pace) => metres <= 0 ? 0 : math.max(1, (metres / (pace * secondsPerMinuteAt1x)).ceil());

/// A walk drawn through [corners] with each corner rounded off, walked
/// by length. A polyline's heading, and the keep-right offset that hangs
/// off it, would snap at every corner; along this one both turn smoothly.
class SmoothPath {
  factory SmoothPath(List<P2> corners, {double? plannedLength, double radius = 1.8, int samples = 8}) {
    final pts = <P2>[];
    for (final p in corners) {
      if (pts.isEmpty || dist(pts.last, p) > 1e-6) pts.add(p);
    }
    final planned = plannedLength ?? polylineLength(pts);
    if (pts.length < 2) return SmoothPath._([pts.isEmpty ? (0, 0) : pts.first], const [(0, 1)], const [0], planned);
    final out = <P2>[pts.first], tangents = <P2>[_norm(_sub(pts[1], pts[0]))];
    for (var i = 1; i < pts.length - 1; i++) {
      final v = pts[i], dIn = _norm(_sub(v, pts[i - 1])), dOut = _norm(_sub(pts[i + 1], v));
      final r = math.min(radius, math.min(dist(pts[i - 1], v), dist(v, pts[i + 1])) / 2);
      final a = _add(v, _scale(dIn, -r)), b = _add(v, _scale(dOut, r));
      // A quadratic Bezier from a to b about the corner: its tangent runs
      // from dIn to dOut, so the heading is continuous through the turn.
      for (var k = 0; k <= samples; k++) {
        final u = k / samples;
        out.add(_add(_add(_scale(a, (1 - u) * (1 - u)), _scale(v, 2 * u * (1 - u))), _scale(b, u * u)));
        tangents.add(_norm(_add(_scale(dIn, 1 - u), _scale(dOut, u))));
      }
    }
    out.add(pts.last);
    tangents.add(_norm(_sub(pts.last, pts[pts.length - 2])));
    final at = <double>[0];
    for (var i = 1; i < out.length; i++) {
      at.add(at.last + dist(out[i - 1], out[i]));
    }
    return SmoothPath._(out, tangents, at, planned);
  }

  SmoothPath._(this._points, this._tangents, this._at, this.plannedLength);
  final List<P2> _points, _tangents;
  final List<double> _at;

  double get length => _at.last;

  /// The length walks along it are timed by: the corners' polyline unless
  /// given; rounded corners make [length] shorter.
  final double plannedLength;

  /// The point a fraction [t] (0-1) of the way along by length, and the
  /// unit heading there.
  (P2, P2) at(double t) {
    if (_points.length == 1) return (_points.first, _tangents.first);
    final s = t.clamp(0.0, 1.0) * length;
    var lo = 0, hi = _at.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (_at[mid] <= s) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final span = _at[hi] - _at[lo];
    final k = span < 1e-9 ? 0.0 : ((s - _at[lo]) / span).clamp(0.0, 1.0);
    final p = _add(_points[lo], _scale(_sub(_points[hi], _points[lo]), k));
    return (p, _norm(_add(_scale(_tangents[lo], 1 - k), _scale(_tangents[hi], k))));
  }
}

double _dot(P2 a, P2 b) => a.$1 * b.$1 + a.$2 * b.$2;

final Map<(String, String, int), SmoothPath> _smoothWalks = {};

/// [walkPath] with its corners rounded, as a llama walks it on screen,
/// timed by the full [walkMetres]. A slot just past its stand point would
/// have the walk double back on the spot, so that leg goes straight on.
SmoothPath smoothWalk(String from, String to, int slot) => _smoothWalks.putIfAbsent((from, to, slot), () {
  final pts = walkPath(from, to, slot);
  final planned = polylineLength(pts);
  bool doublesBack(P2 a, P2 b, P2 c) => dist(a, b) > 1e-6 && dist(b, c) > 1e-6 && _dot(_norm(_sub(b, a)), _norm(_sub(c, b))) < -0.34;
  if (pts.length > 2 && doublesBack(pts[0], pts[1], pts[2])) pts.removeAt(1);
  final n = pts.length;
  if (n > 2 && doublesBack(pts[n - 1], pts[n - 2], pts[n - 3])) pts.removeAt(n - 2);
  return SmoothPath(pts, plannedLength: planned);
});

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

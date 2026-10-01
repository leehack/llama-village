import 'dart:math' as math;

/// An axis-aligned screen rectangle, in logical pixels (y grows down).
class Box {
  const Box(this.left, this.top, this.width, this.height);
  final double left, top, width, height;

  double get right => left + width;
  double get bottom => top + height;

  Box shift(double dx, double dy) => Box(left + dx, top + dy, width, height);

  bool overlaps(Box o, double gap) => left < o.right + gap && o.left < right + gap && top < o.bottom + gap && o.top < bottom + gap;

  @override
  String toString() =>
      'Box(${left.toStringAsFixed(1)}, ${top.toStringAsFixed(1)}, ${width.toStringAsFixed(1)} x ${height.toStringAsFixed(1)})';
}

/// A bubble to place: its preferred rectangle (bottom centre on its
/// speaker's head) and who says it.
class BubbleRequest {
  const BubbleRequest(this.id, this.box);
  final String id;
  final Box box;
}

/// Places speech bubbles so none overlap each other or the name tags in
/// [keepClear]: the lowest bubble on screen (usually the nearest speaker)
/// keeps its spot and the others stack above or slide aside, whichever
/// moves them less, while staying inside [screen] when they can.
/// Returns each bubble's (dx, dy) offset from its preferred spot, by id
/// (dy is upwards).
Map<String, (double, double)> layoutBubbles(List<BubbleRequest> bubbles, {List<Box> keepClear = const [], Box? screen, double gap = 6}) {
  final order = [...bubbles]
    ..sort((a, b) {
      final byBottom = b.box.bottom.compareTo(a.box.bottom);
      return byBottom != 0 ? byBottom : a.box.left.compareTo(b.box.left);
    });
  final placed = <Box>[];
  final out = <String, (double, double)>{};
  for (final r in order) {
    final b = r.box;
    var best = (0.0, 0.0);
    var bestCost = double.infinity;
    for (final share in const [0.0, -0.25, 0.25, -0.5, 0.5, -0.75, 0.75, -1.0, 1.0]) {
      final dx = share * b.width;
      // Rise just above whatever is in the way until nothing is.
      var dy = 0.0;
      for (var pass = 0; pass < placed.length + keepClear.length + 1; pass++) {
        final at = b.shift(dx, -dy);
        double? need;
        for (final o in [...placed, ...keepClear]) {
          if (!at.overlaps(o, gap)) continue;
          final rise = b.bottom - (o.top - gap);
          need = need == null ? rise : math.max(need, rise);
        }
        if (need == null) break;
        dy = math.max(dy + 0.5, need);
      }
      var cost = dy + dx.abs() * 1.2;
      if (screen != null) {
        final at = b.shift(dx, -dy);
        final outside = math.max(0.0, screen.top - at.top) + math.max(0.0, screen.left - at.left) + math.max(0.0, at.right - screen.right);
        if (outside > 0) cost += 200 + outside * 4;
      }
      if (cost < bestCost - 1e-9) {
        bestCost = cost;
        best = (dx, dy);
      }
    }
    placed.add(b.shift(best.$1, -best.$2));
    out[r.id] = best;
  }
  return out;
}

/// Eases each bubble towards its laid-out offset, so bubbles glide rather
/// than jump as speakers move.
class BubbleSmoother {
  final Map<String, (double, double)> _now = {};

  Map<String, (double, double)> step(Map<String, (double, double)> target, double dt) {
    final k = 1 - math.exp(-dt * 12);
    _now.removeWhere((id, _) => !target.containsKey(id));
    for (final MapEntry(key: id, value: (tx, ty)) in target.entries) {
      final (x, y) = _now[id] ?? (tx, ty);
      _now[id] = (x + (tx - x) * k, y + (ty - y) * k);
    }
    return Map.of(_now);
  }
}

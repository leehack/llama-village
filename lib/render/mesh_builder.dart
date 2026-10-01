import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Linear colour from an sRGB hex value, for vertex colours.
vm.Vector3 rgb(int hex, [double scale = 1]) {
  double ch(int shift) {
    final c = ((hex >> shift) & 0xff) / 255;
    return math.pow(c, 2.2).toDouble() * scale;
  }

  return vm.Vector3(ch(16), ch(8), ch(0));
}

/// Merges low-poly boxes, cylinders, cones and spheres with baked vertex
/// colours into one geometry, so a hut or a grove is a single draw call.
class MeshBuilder {
  final List<double> _pos = [], _nrm = [], _col = [];
  final List<int> _idx = [];

  bool get isEmpty => _idx.isEmpty;

  int _vertex(vm.Vector3 p, vm.Vector3 n, vm.Vector3 c) {
    _pos.addAll([p.x, p.y, p.z]);
    _nrm.addAll([n.x, n.y, n.z]);
    _col.addAll([c.x, c.y, c.z, 1]);
    return _pos.length ~/ 3 - 1;
  }

  /// Adds a triangle, wound so its face points along [outward].
  void _tri(int a, int b, int c, vm.Vector3 outward) {
    vm.Vector3 p(int i) => vm.Vector3(_pos[i * 3], _pos[i * 3 + 1], _pos[i * 3 + 2]);
    final n = (p(b) - p(a)).cross(p(c) - p(a));
    _idx.addAll(n.dot(outward) >= 0 ? [a, b, c] : [a, c, b]);
  }

  /// A box centred at [c] with [size], turned [yaw] radians about Y.
  void box(vm.Vector3 c, vm.Vector3 size, vm.Vector3 color, {double yaw = 0}) {
    final rot = vm.Matrix3.rotationY(yaw);
    final h = size * 0.5;
    const faces = <List<double>>[
      [1, 0, 0],
      [-1, 0, 0],
      [0, 1, 0],
      [0, -1, 0],
      [0, 0, 1],
      [0, 0, -1],
    ];
    for (final f in faces) {
      final n = vm.Vector3(f[0], f[1], f[2]);
      final (u, v) = n.x != 0
          ? (vm.Vector3(0, 1, 0), vm.Vector3(0, 0, 1))
          : n.y != 0
          ? (vm.Vector3(1, 0, 0), vm.Vector3(0, 0, 1))
          : (vm.Vector3(1, 0, 0), vm.Vector3(0, 1, 0));
      final centre = vm.Vector3(n.x * h.x, n.y * h.y, n.z * h.z);
      final du = vm.Vector3(u.x * h.x, u.y * h.y, u.z * h.z);
      final dv = vm.Vector3(v.x * h.x, v.y * h.y, v.z * h.z);
      final wn = rot.transformed(n);
      final ids = [
        for (final (su, sv) in const [(-1, -1), (1, -1), (1, 1), (-1, 1)])
          _vertex(c + rot.transformed(centre + du * su.toDouble() + dv * sv.toDouble()), wn, color),
      ];
      _tri(ids[0], ids[1], ids[2], wn);
      _tri(ids[0], ids[2], ids[3], wn);
    }
  }

  /// A capped cylinder centred at [c] along [axis] (0 = X, 1 = Y, 2 = Z).
  void cylinder(vm.Vector3 c, double radius, double length, int axis, vm.Vector3 color, {int segments = 8, vm.Vector3? capColor}) {
    vm.Vector3 orient(double a, double r, double along) => switch (axis) {
      0 => vm.Vector3(along, math.cos(a) * r, math.sin(a) * r),
      1 => vm.Vector3(math.cos(a) * r, along, math.sin(a) * r),
      _ => vm.Vector3(math.cos(a) * r, math.sin(a) * r, along),
    };
    final half = length / 2;
    for (var i = 0; i < segments; i++) {
      final a0 = 2 * math.pi * i / segments;
      final a1 = 2 * math.pi * (i + 1) / segments;
      final n = orient((a0 + a1) / 2, 1, 0);
      final q = [
        _vertex(c + orient(a0, radius, -half), n, color),
        _vertex(c + orient(a1, radius, -half), n, color),
        _vertex(c + orient(a1, radius, half), n, color),
        _vertex(c + orient(a0, radius, half), n, color),
      ];
      _tri(q[0], q[1], q[2], n);
      _tri(q[0], q[2], q[3], n);
    }
    for (final s in [-1.0, 1.0]) {
      final n = orient(0, 0, s);
      final cc = capColor ?? color;
      final mid = _vertex(c + orient(0, 0, half * s), n, cc);
      final ring = [for (var i = 0; i < segments; i++) _vertex(c + orient(2 * math.pi * i / segments, radius, half * s), n, cc)];
      for (var i = 0; i < segments; i++) {
        _tri(mid, ring[i], ring[(i + 1) % segments], n);
      }
    }
  }

  /// An ellipsoid centred at [c] with [radii], faceted.
  void sphere(vm.Vector3 c, vm.Vector3 radii, vm.Vector3 color, {int segments = 10, int rings = 7}) {
    final grid = <List<int>>[];
    for (var r = 0; r <= rings; r++) {
      final lat = math.pi * r / rings;
      final row = <int>[];
      for (var s = 0; s <= segments; s++) {
        final lon = 2 * math.pi * s / segments;
        final unit = vm.Vector3(math.sin(lat) * math.cos(lon), math.cos(lat), math.sin(lat) * math.sin(lon));
        final p = vm.Vector3(unit.x * radii.x, unit.y * radii.y, unit.z * radii.z);
        final n = vm.Vector3(unit.x / radii.x, unit.y / radii.y, unit.z / radii.z)..normalize();
        row.add(_vertex(c + p, n, color));
      }
      grid.add(row);
    }
    for (var r = 0; r < rings; r++) {
      for (var s = 0; s < segments; s++) {
        final a = grid[r][s], b = grid[r][s + 1];
        final d = grid[r + 1][s], e = grid[r + 1][s + 1];
        vm.Vector3 out(int i) => vm.Vector3(_pos[i * 3], _pos[i * 3 + 1], _pos[i * 3 + 2]) - c;
        _tri(a, b, e, out(a) + out(e));
        _tri(a, e, d, out(a) + out(e));
      }
    }
  }

  /// A flat-shaded triangle with its own colour.
  void triangle(vm.Vector3 a, vm.Vector3 b, vm.Vector3 c, vm.Vector3 color) {
    final n = (b - a).cross(c - a)..normalize();
    final up = n.y < 0 ? -n : n;
    final ia = _vertex(a, up, color), ib = _vertex(b, up, color), ic = _vertex(c, up, color);
    _tri(ia, ib, ic, up);
  }

  /// A cone or frustum standing on [base] along +Y, faceted.
  void cone(vm.Vector3 base, double radiusBottom, double radiusTop, double height, vm.Vector3 color, {int segments = 8, double yaw = 0}) {
    final top = base + vm.Vector3(0, height, 0);
    vm.Vector3 ring(double r, double y, int i) {
      final a = yaw + 2 * math.pi * i / segments;
      return vm.Vector3(base.x + math.cos(a) * r, y, base.z + math.sin(a) * r);
    }

    for (var i = 0; i < segments; i++) {
      final b0 = ring(radiusBottom, base.y, i), b1 = ring(radiusBottom, base.y, i + 1);
      final t0 = ring(radiusTop, top.y, i), t1 = ring(radiusTop, top.y, i + 1);
      final mid = (b0 + b1 + t0 + t1) * 0.25;
      final outward = vm.Vector3(mid.x - base.x, 0, mid.z - base.z);
      final n = (b1 - b0).cross(t0 - b0)..normalize();
      final face = n.dot(outward) < 0 ? -n : n;
      final ids = [_vertex(b0, face, color), _vertex(b1, face, color), _vertex(t1, face, color), _vertex(t0, face, color)];
      _tri(ids[0], ids[1], ids[2], face);
      if (radiusTop > 1e-4) _tri(ids[0], ids[2], ids[3], face);
    }
    if (radiusTop > 1e-4) {
      final up = vm.Vector3(0, 1, 0);
      final mid = _vertex(top, up, color);
      final ids = [for (var i = 0; i < segments; i++) _vertex(ring(radiusTop, top.y, i), up, color)];
      for (var i = 0; i < segments; i++) {
        _tri(mid, ids[i], ids[(i + 1) % segments], up);
      }
    }
  }

  /// A gable roof: two slopes over a [width] (x) by [depth] (z) footprint
  /// whose eaves sit at [eaveY] and ridge (along z) at [ridgeY].
  void gable(
    vm.Vector3 c,
    double width,
    double depth,
    double eaveY,
    double ridgeY,
    vm.Vector3 color, {
    vm.Vector3? gableColor,
    double yaw = 0,
  }) {
    final rot = vm.Matrix3.rotationY(yaw);
    vm.Vector3 p(double x, double y, double z) => c + rot.transformed(vm.Vector3(x, y - c.y, z));
    final hw = width / 2, hd = depth / 2;
    final l0 = p(-hw, eaveY, -hd), l1 = p(-hw, eaveY, hd);
    final r0 = p(hw, eaveY, -hd), r1 = p(hw, eaveY, hd);
    final t0 = p(0, ridgeY, -hd), t1 = p(0, ridgeY, hd);
    void quad(vm.Vector3 a, vm.Vector3 b, vm.Vector3 cc, vm.Vector3 d, vm.Vector3 col, vm.Vector3 outward) {
      final n = (b - a).cross(d - a)..normalize();
      final face = n.dot(outward) < 0 ? -n : n;
      final ids = [_vertex(a, face, col), _vertex(b, face, col), _vertex(cc, face, col), _vertex(d, face, col)];
      _tri(ids[0], ids[1], ids[2], face);
      _tri(ids[0], ids[2], ids[3], face);
    }

    quad(l0, l1, t1, t0, color, rot.transformed(vm.Vector3(-1, 1, 0)));
    quad(r0, t0, t1, r1, color, rot.transformed(vm.Vector3(1, 1, 0)));
    final g = gableColor ?? color;
    for (final (a, b, t, out) in [
      (l0, r0, t0, rot.transformed(vm.Vector3(0, 0, -1))),
      (l1, r1, t1, rot.transformed(vm.Vector3(0, 0, 1))),
    ]) {
      final n = (b - a).cross(t - a)..normalize();
      final face = n.dot(out) < 0 ? -n : n;
      _tri(_vertex(a, face, g), _vertex(b, face, g), _vertex(t, face, g), face);
    }
  }

  MeshGeometry build() => MeshGeometry.fromArrays(
    positions: Float32List.fromList(_pos),
    normals: Float32List.fromList(_nrm),
    colors: Float32List.fromList(_col),
    indices: _idx,
  );
}

import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../ambient/layout.dart';
import '../sim/geo.dart';
import '../sim/places.dart';
import 'look.dart';
import 'mesh_builder.dart';

/// Wool and accent colours per llama, also used for their huts.
const Map<String, (int wool, int accent)> llamaColors = {
  'Pip': (0xF6F0E6, 0xC8372D),
  'Mo': (0xC99A6B, 0xE0A93B),
  'June': (0xE6C9A3, 0x8E4FB0),
  'Bramble': (0x6A625C, 0x4E7A3E),
  'Clover': (0x6E4A33, 0x3F7BC9),
};

/// Radius of the round diorama the village sits on.
const double islandRadius = 58;
final vm.Vector2 _centre = vm.Vector2(0, -6);

vm.Vector3 _v(double x, double y, double z) => vm.Vector3(x, y, z);

/// A light that comes on after dark: an emissive material plus an
/// optional point light.
class NightLight {
  NightLight(this.material, this.on, {this.light, this.owner, this.power = 26});
  final PhysicallyBasedMaterial material;
  final vm.Vector3 on;
  final PointLight? light;

  /// Point-light intensity when fully on.
  final double power;

  /// The llama whose hut this is, if any.
  final String? owner;
  double level = 0;

  void set(double v) {
    level = v;
    material.emissiveFactor = vm.Vector4(on.x, on.y, on.z, 1);
    material.emissiveStrength = 0.15 + v * 5.5;
    light?.intensity = v * power;
  }
}

/// The static village: ground, paths, pond, huts, bakery, berry bushes,
/// hilltop stage and trees, plus handles for what changes over time.
class VillageWorld {
  VillageWorld(this.scene);
  final Scene scene;

  final List<NightLight> windows = [];
  final List<NightLight> lamps = [];
  late final Node scarfInReeds;
  late final Node wildflowers;
  late final Node festivalDecor;

  /// Tree trunks (position, radius), for the scatter and the animals.
  final List<(P2, double)> treeTrunks = [];

  /// Round tree crowns (centre, radius), where leaves fall from.
  final List<(vm.Vector3, double)> crowns = [];

  /// The ground and paths, which a storm wets.
  late final PhysicallyBasedMaterial ground = pbr(rough: 0.9);

  late final PhysicallyBasedMaterial _matte = pbr(rough: 0.9);
  late final PhysicallyBasedMaterial _soft = pbr(rough: 0.7);
  late final PhysicallyBasedMaterial _gloss = pbr(rough: 0.35);

  void build() {
    _groundAndPaths();
    for (final place in placeCoordinates.keys) {
      if (isHut(place)) _hut(place);
    }
    _bakery();
    _berryBushes();
    _hilltop();
    _pondProps();
    _lamps();
    _trees();
  }

  Node _add(MeshGeometry g, Material m, {vm.Matrix4? at, bool shadows = true}) {
    final n = Node(mesh: Mesh(g, m), localTransform: at ?? vm.Matrix4.identity())..castsShadows = shadows;
    scene.add(n);
    return n;
  }

  vm.Matrix4 _placeAt(String place, {double lift = 0}) {
    final (x, z) = placeAnchor(place);
    final (fx, fz) = placeFacing(place);
    return vm.Matrix4.translation(_v(x, groundHeight(x, z) + lift, z))..rotateY(math.atan2(fx, fz));
  }

  // ------------------------------------------------------------ ground

  /// Distance from (x, z) to the nearest path.
  double pathDistance(double x, double z) => _pathDistance(x, z, _segments);
  late final List<(P2, P2)> _segments = pathSegments();

  static double _pathDistance(double x, double z, List<(P2, P2)> segs) {
    var best = double.infinity;
    for (final ((ax, az), (bx, bz)) in segs) {
      final dx = bx - ax, dz = bz - az;
      final len2 = dx * dx + dz * dz;
      final t = len2 == 0 ? 0.0 : (((x - ax) * dx + (z - az) * dz) / len2).clamp(0.0, 1.0);
      final px = ax + dx * t - x, pz = az + dz * t - z;
      best = math.min(best, px * px + pz * pz);
    }
    return math.sqrt(best);
  }

  /// Wets the ground and paths: glossier and darker as [wetness] rises.
  set wetness(double wetness) {
    final k = 1 - 0.3 * wetness;
    ground
      ..roughnessFactor = 0.9 - 0.62 * wetness
      ..baseColorFactor = vm.Vector4(k, k, k, 1);
  }

  /// The meadow, the dirt paths and the diorama's soil skirt. The ground
  /// is split into tiles so each tile only gathers the lamps near it.
  void _groundAndPaths() {
    const tiles = 4;
    const lo = -62.0, hi = 56.0;
    final chunks = [for (var i = 0; i < tiles * tiles; i++) MeshBuilder()];
    MeshBuilder chunkAt(vm.Vector3 c) {
      int cell(double v) => (((v - lo) / (hi - lo)) * tiles).floor().clamp(0, tiles - 1);
      return chunks[cell(c.x) * tiles + cell(c.z)];
    }

    _ground(chunkAt);
    _paths(chunkAt);
    for (final b in chunks) {
      if (!b.isEmpty) _add(b.build(), ground, shadows: false);
    }
  }

  void _ground(MeshBuilder Function(vm.Vector3 centroid) chunkAt) {
    final grassA = rgb(0x84BD4C), grassB = rgb(0x6FAA42), lush = rgb(0x5E9E3C), dry = rgb(0xA9BE5A), hill = rgb(0xA6CE66);
    final trodden = rgb(0x9DB05E);
    final sand = rgb(0xE0CB93), mud = rgb(0x6E8F5A);
    final (px, pz) = placeCoordinates['pond']!;
    const cell = 1.25;
    const lo = -62.0, hi = 56.0;
    final n = ((hi - lo) / cell).round();
    vm.Vector3 vert(int i, int j) {
      var x = lo + i * cell, z = lo + j * cell;
      final d = vm.Vector2(x, z) - _centre;
      if (d.length > islandRadius) {
        d.scale(islandRadius / d.length);
        x = _centre.x + d.x;
        z = _centre.y + d.y;
      }
      return _v(x, groundHeight(x, z), z);
    }

    final grid = [
      for (var i = 0; i <= n; i++) [for (var j = 0; j <= n; j++) vert(i, j)],
    ];
    int hash(int a, int b) => ((a * 73856093) ^ (b * 19349663)) & 0x7fffffff;
    vm.Vector3 colorAt(vm.Vector3 c, int salt) {
      final pond = math.sqrt((c.x - px) * (c.x - px) + (c.z - pz) * (c.z - pz));
      if (pond < 7.6) return mud;
      if (pond < 8.9) return sand;
      // Meadow patches at two scales, lusher by the water, sun-dried in
      // places, trodden pale beside the paths and lighter up the hill.
      final patch = 0.5 + 0.5 * math.sin(c.x * 0.11 + math.sin(c.z * 0.17) * 1.7) * math.cos(c.z * 0.09 - c.x * 0.04);
      final fine = 0.5 + 0.5 * math.sin(c.x * 0.37 + c.z * 0.23) * math.sin(c.z * 0.41 - c.x * 0.19);
      var grass = grassB + (grassA - grassB) * patch;
      grass += (dry - grass) * (math.max(0.0, fine - 0.62) * 1.6);
      grass += (lush - grass) * ((1 - (pond - 8.9) / 9).clamp(0.0, 1.0) * 0.7);
      final path = _pathDistance(c.x, c.z, _segments);
      grass += (trodden - grass) * ((1 - (path - 1.1) / 1.6).clamp(0.0, 1.0) * 0.55);
      final up = ((c.y - 1.2) / 3.5).clamp(0.0, 1.0);
      final base = grass + (hill - grass) * up;
      return base * (0.95 + 0.1 * ((salt % 7) / 6));
    }

    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        final a = grid[i][j], bb = grid[i + 1][j], c = grid[i + 1][j + 1], d = grid[i][j + 1];
        for (final (t, k) in [((a, bb, c), 0), ((a, c, d), 1)]) {
          final area = (t.$2 - t.$1).cross(t.$3 - t.$1).length;
          if (area < 1e-3) continue;
          final centroid = (t.$1 + t.$2 + t.$3) / 3;
          chunkAt(centroid).triangle(t.$1, t.$2, t.$3, colorAt(centroid, hash(i * 2 + k, j)));
        }
      }
    }
    // The diorama's soil skirt.
    final b = MeshBuilder();
    const segments = 160;
    final soil = rgb(0x7A5233), soilDark = rgb(0x5A3B24), rim = rgb(0x6FA542);
    for (var s = 0; s < segments; s++) {
      final a0 = 2 * math.pi * s / segments, a1 = 2 * math.pi * (s + 1) / segments;
      vm.Vector3 at(double a, double y) {
        final x = _centre.x + math.cos(a) * islandRadius, z = _centre.y + math.sin(a) * islandRadius;
        return _v(x, y.isNaN ? groundHeight(x, z) : y, z);
      }

      final t0 = at(a0, double.nan), t1 = at(a1, double.nan);
      final m0 = at(a0, t0.y - 0.35), m1 = at(a1, t1.y - 0.35);
      final b0 = at(a0, -5), b1 = at(a1, -5);
      b
        ..triangle(t0, t1, m1, rim)
        ..triangle(t0, m1, m0, rim)
        ..triangle(m0, m1, b1, s.isEven ? soil : soilDark)
        ..triangle(m0, b1, b0, s.isEven ? soil : soilDark);
    }
    _add(b.build(), _matte, shadows: false);
  }

  /// Dirt paths as ribbons draped over the ground, with round joints and
  /// small plazas in front of every place. One colour, so overlaps never
  /// flicker.
  void _paths(MeshBuilder Function(vm.Vector3 centroid) chunkAt) {
    final dirt = rgb(0xC9A36B);
    const lift = 0.07, half = 1.15;
    vm.Vector3 at(double x, double z) => _v(x, groundHeight(x, z) + lift, z);
    void tri(vm.Vector3 a, vm.Vector3 b, vm.Vector3 c) => chunkAt((a + b + c) / 3).triangle(a, b, c, dirt);
    void disc(P2 c, double r) {
      const seg = 14;
      for (var i = 0; i < seg; i++) {
        final a0 = 2 * math.pi * i / seg, a1 = 2 * math.pi * (i + 1) / seg;
        tri(at(c.$1, c.$2), at(c.$1 + math.cos(a0) * r, c.$2 + math.sin(a0) * r), at(c.$1 + math.cos(a1) * r, c.$2 + math.sin(a1) * r));
      }
    }

    for (final ((ax, az), (bx, bz)) in _segments) {
      final len = dist((ax, az), (bx, bz));
      final steps = math.max(1, (len / 0.9).ceil());
      final nx = -(bz - az) / len * half, nz = (bx - ax) / len * half;
      for (var i = 0; i < steps; i++) {
        final t0 = i / steps, t1 = (i + 1) / steps;
        final x0 = ax + (bx - ax) * t0, z0 = az + (bz - az) * t0;
        final x1 = ax + (bx - ax) * t1, z1 = az + (bz - az) * t1;
        final l0 = at(x0 + nx, z0 + nz), r0 = at(x0 - nx, z0 - nz), l1 = at(x1 + nx, z1 + nz), r1 = at(x1 - nx, z1 - nz);
        tri(l0, r0, r1);
        tri(l0, r1, l1);
      }
      disc((ax, az), half);
      disc((bx, bz), half);
    }
    for (final p in placeCoordinates.keys) {
      if (p == 'pond' || p == 'hilltop') continue;
      disc(standPoint(p), p == 'bakery' ? 5.0 : 2.4);
    }
  }

  // ------------------------------------------------------------ huts

  NightLight _window(String? owner, vm.Vector3 at) {
    final m = pbr(rough: 0.4)..baseColorFactor = vm.Vector4(0.95, 0.82, 0.55, 1);
    final light = PointLight(color: vm.Vector3(1.0, 0.72, 0.42), intensity: 0, range: 11);
    scene.add(Node(localTransform: vm.Matrix4.translation(at))..addComponent(PointLightComponent(light)));
    final w = NightLight(m, vm.Vector3(1.0, 0.7, 0.35), light: light, owner: owner)..set(0);
    windows.add(w);
    return w;
  }

  void _hut(String place) {
    final owner = place.replaceAll("'s hut", '');
    final (_, accentHex) = llamaColors[owner]!;
    final accent = rgb(accentHex), wall = rgb(0xF2E6D0), stone = rgb(0x9A958C), wood = rgb(0x7B5131), dark = rgb(0x4A3020);
    final b = MeshBuilder()
      ..cylinder(_v(0, 0.12, 0), 2.6, 0.5, 1, stone, segments: 12)
      ..cylinder(_v(0, 1.35, 0), 2.3, 2.2, 1, wall, segments: 12)
      ..cone(_v(0, 2.35, 0), 3.05, 0.0, 2.3, accent, segments: 12)
      ..cone(_v(0, 2.3, 0), 3.1, 2.95, 0.12, accent * 0.75, segments: 12)
      ..sphere(_v(0, 4.7, 0), _v(0.22, 0.22, 0.22), accent * 0.8)
      ..box(_v(0, 1.05, 2.3), _v(1.1, 1.95, 0.18), dark)
      ..box(_v(0, 0.98, 2.36), _v(0.86, 1.78, 0.1), wood)
      ..sphere(_v(0.28, 1.0, 2.43), _v(0.05, 0.05, 0.05), rgb(0xE8C35A))
      ..box(_v(1.25, 3.4, -0.9), _v(0.45, 1.4, 0.45), rgb(0x9C5A3C))
      ..box(_v(0, 0.06, 3.0), _v(1.4, 0.12, 1.0), stone);
    for (final s in [-1.0, 1.0]) {
      final a = s * 0.75;
      b.box(_v(math.sin(a) * 2.33, 1.45, math.cos(a) * 2.33), _v(0.95, 0.95, 0.12), dark, yaw: a);
    }
    switch (owner) {
      case 'Pip':
        b
          ..cylinder(_v(-1.6, 0.25, 2.7), 0.38, 0.5, 1, rgb(0xB98A55), segments: 8)
          ..sphere(_v(-1.7, 0.6, 2.65), _v(0.17, 0.17, 0.17), rgb(0xD8343A))
          ..sphere(_v(-1.45, 0.58, 2.8), _v(0.15, 0.15, 0.15), rgb(0xF29BB6));
      case 'Mo':
        b
          ..box(_v(-1.7, 0.3, 2.6), _v(0.9, 0.6, 0.6), wood)
          ..sphere(_v(-1.85, 0.68, 2.6), _v(0.28, 0.14, 0.18), rgb(0xD99A4E))
          ..sphere(_v(-1.5, 0.68, 2.62), _v(0.26, 0.13, 0.17), rgb(0xC9853E));
      case 'June':
        b
          ..cylinder(_v(-1.6, 0.25, 2.7), 0.42, 0.5, 1, rgb(0xA87A45), segments: 8)
          ..sphere(_v(-1.6, 0.52, 2.7), _v(0.34, 0.12, 0.34), rgb(0x6B2E8A));
      case 'Bramble':
        b
          ..cylinder(_v(0, 5.2, 0), 0.05, 1.2, 1, rgb(0x3A3A3A))
          ..box(_v(0, 5.7, 0), _v(1.1, 0.06, 0.1), rgb(0x3A3A3A))
          ..cone(_v(0.55, 5.62, 0), 0.12, 0, 0.18, rgb(0xD9534F), segments: 4);
      case 'Clover':
        b
          ..box(_v(-1.8, 0.7, 2.6), _v(0.1, 1.4, 0.1), wood)
          ..box(_v(-1.8, 1.35, 2.62), _v(0.9, 0.7, 0.08), wood)
          ..box(_v(-1.8, 1.37, 2.68), _v(0.6, 0.45, 0.02), rgb(0xF5F1E6));
    }
    final at = _placeAt(place);
    _add(b.build(), _soft, at: at);
    // Two glowing windows per hut, sharing one material.
    final lightPos = at.transformed3(_v(0, 1.5, 1.2));
    final glow = _window(owner, lightPos);
    final wb = MeshBuilder();
    for (final s in [-1.0, 1.0]) {
      final a = s * 0.75;
      wb.box(_v(math.sin(a) * 2.38, 1.45, math.cos(a) * 2.38), _v(0.72, 0.72, 0.08), rgb(0xFFE7B0), yaw: a);
    }
    _add(wb.build(), glow.material, at: at, shadows: false);
  }

  // ------------------------------------------------------------ bakery

  void _bakery() {
    final plaster = rgb(0xF3E3C3), beam = rgb(0x6B4226), roof = rgb(0xB5533C), brick = rgb(0xA4553A), stone = rgb(0x9A958C);
    final b = MeshBuilder()
      ..box(_v(0, 0.2, 0), _v(7.6, 0.4, 6.2), stone)
      ..box(_v(0, 1.95, 0), _v(7.0, 3.1, 5.6), plaster)
      ..gable(_v(0, 0, 0), 6.6, 7.8, 3.45, 5.6, roof, gableColor: plaster, yaw: math.pi / 2)
      ..box(_v(2.2, 5.3, -1.2), _v(0.8, 2.0, 0.8), brick)
      ..box(_v(0, 1.25, 2.83), _v(1.3, 2.1, 0.12), beam)
      ..box(_v(0, 1.2, 2.88), _v(1.05, 1.9, 0.08), rgb(0x8E5A34));
    for (final x in [-3.45, 3.45]) {
      b.box(_v(x, 1.95, 2.82), _v(0.22, 3.1, 0.18), beam);
    }
    b.box(_v(0, 3.4, 2.82), _v(7.1, 0.22, 0.18), beam);
    // Striped awning over the shop window.
    for (var i = 0; i < 7; i++) {
      final x = -3.1 + i * 0.36 - 0.0;
      b.box(_v(x - 0.1, 2.75, 3.3), _v(0.36, 0.08, 1.1), i.isEven ? rgb(0xD9443A) : rgb(0xF6EFE4), yaw: 0);
    }
    // Bread table and barrels out front.
    b
      ..box(_v(2.4, 0.75, 3.9), _v(1.8, 0.1, 0.9), beam)
      ..box(_v(1.7, 0.37, 3.9), _v(0.1, 0.75, 0.8), beam)
      ..box(_v(3.1, 0.37, 3.9), _v(0.1, 0.75, 0.8), beam);
    for (var i = 0; i < 4; i++) {
      b.sphere(_v(1.8 + i * 0.4, 0.93, 3.85 + (i.isEven ? 0.12 : -0.12)), _v(0.2, 0.12, 0.13), rgb(0xD39448));
    }
    for (final (x, z) in [(-3.0, 3.6), (-3.6, 3.0)]) {
      b.cylinder(_v(x, 0.5, z), 0.42, 1.0, 1, rgb(0x8A5A33), segments: 9, capColor: rgb(0x6B4226));
    }
    final at = _placeAt('bakery');
    _add(b.build(), _soft, at: at);
    final glow = _window(null, at.transformed3(_v(0, 1.6, 3.6)));
    final wb = MeshBuilder()
      ..box(_v(-2.2, 1.55, 2.84), _v(1.5, 1.1, 0.1), rgb(0xFFE2A8))
      ..box(_v(2.2, 1.85, 2.84), _v(1.1, 0.9, 0.1), rgb(0xFFE2A8));
    _add(wb.build(), glow.material, at: at, shadows: false);
  }

  // ------------------------------------------------------------ places

  void _berryBushes() {
    final r = math.Random(7);
    final b = MeshBuilder();
    final leaf = [rgb(0x3F8A3A), rgb(0x4C9A40), rgb(0x357A33)];
    final berry = [rgb(0xC42B4A), rgb(0x4B3B9A), rgb(0xD94060)];
    // Local frame: +z faces the square; llamas stand at z = 4.
    final at = _placeAt('berry bushes');
    final base = at.getTranslation().y;
    double ground(double x, double z) {
      final w = at.transformed3(_v(x, 0, z));
      return groundHeight(w.x, w.z) - base;
    }

    const spots = <(double, double)>[
      (-4.2, -1.0),
      (-2.4, -2.8),
      (0.0, -3.4),
      (2.4, -2.8),
      (4.2, -1.0),
      (-1.2, -0.6),
      (1.4, -0.4),
      (5.2, 1.4),
      (-5.4, 1.2),
    ];
    for (final (x, z) in spots) {
      final s = 0.75 + r.nextDouble() * 0.45;
      final g = ground(x, z);
      b.sphere(_v(x, g + s * 0.75, z), _v(s * 1.1, s * 0.85, s * 1.0), leaf[r.nextInt(3)], segments: 9, rings: 6);
      b.sphere(_v(x + 0.4 * s, g + s * 1.15, z + 0.2), _v(s * 0.7, s * 0.6, s * 0.7), leaf[r.nextInt(3)], segments: 8, rings: 5);
      for (var k = 0; k < 10; k++) {
        final a = r.nextDouble() * 2 * math.pi, h = 0.4 + r.nextDouble() * 0.9;
        b.sphere(
          _v(x + math.cos(a) * s * 1.02, g + s * h, z + math.sin(a) * s * 0.95),
          _v(0.09, 0.09, 0.09),
          berry[r.nextInt(3)],
          segments: 5,
          rings: 3,
        );
      }
    }
    final wood = rgb(0x8A5A33);
    for (var i = 0; i < 7; i++) {
      final x = -5.4 + i * 1.8;
      b.box(_v(x, ground(x, -5.0) + 0.5, -5.0), _v(0.14, 1.0, 0.14), wood);
    }
    b
      ..box(_v(0, ground(0, -5) + 0.75, -5.0), _v(11, 0.1, 0.08), wood)
      ..box(_v(0, ground(0, -5) + 0.4, -5.0), _v(11, 0.1, 0.08), wood)
      ..cylinder(_v(-2.6, ground(-2.6, 2.0) + 0.25, 2.0), 0.4, 0.5, 1, rgb(0xB0824D), segments: 9)
      ..sphere(_v(-2.6, ground(-2.6, 2.0) + 0.52, 2.0), _v(0.33, 0.12, 0.33), rgb(0xB72E48));
    _add(b.build(), _soft, at: at);

    final fb = MeshBuilder();
    for (var i = 0; i < 7; i++) {
      final a = i * 0.9;
      fb
        ..box(_v(math.cos(a) * 0.25, 0.2, math.sin(a) * 0.25), _v(0.03, 0.4, 0.03), rgb(0x3E8A35))
        ..sphere(
          _v(math.cos(a) * 0.25, 0.42, math.sin(a) * 0.25),
          _v(0.1, 0.07, 0.1),
          [rgb(0xF6D447), rgb(0xF08AC0), rgb(0xFFFFFF)][i % 3],
        );
    }
    wildflowers = _add(fb.build(), _soft, at: at.clone()..translateByVector3(_v(2.6, ground(2.6, 1.6), 1.6)))..visible = false;
  }

  void _hilltop() {
    final wood = rgb(0x9C6B3E), plank = rgb(0xB98450), dark = rgb(0x6B4226);
    final b = MeshBuilder()
      ..box(_v(0, 0.45, -2.6), _v(6.5, 0.7, 4.0), plank)
      ..box(_v(0, 0.1, -0.35), _v(2.0, 0.3, 0.6), wood);
    for (final (x, z) in [(-3.0, -4.4), (3.0, -4.4), (-3.0, -0.8), (3.0, -0.8)]) {
      b.box(_v(x, 1.6, z), _v(0.18, 3.2, 0.18), dark);
    }
    b
      ..box(_v(0, 3.15, -4.4), _v(6.2, 0.16, 0.16), dark)
      ..box(_v(0, 1.4, -4.5), _v(6.0, 1.9, 0.08), rgb(0x7E3B6A));
    // Bramble's weather mast and a bench.
    b
      ..cylinder(_v(4.8, 2.2, 1.2), 0.07, 4.4, 1, rgb(0x5A5A5A))
      ..cone(_v(4.8, 4.0, 1.2), 0.1, 0.32, 0.8, rgb(0xF08A3C), segments: 8, yaw: 0)
      ..box(_v(-4.2, 0.45, 1.6), _v(1.8, 0.12, 0.5), wood)
      ..box(_v(-4.9, 0.22, 1.6), _v(0.12, 0.44, 0.45), dark)
      ..box(_v(-3.5, 0.22, 1.6), _v(0.12, 0.44, 0.45), dark);
    final at = _placeAt('hilltop', lift: -0.15);
    _add(b.build(), _soft, at: at);
    // Bunting, shown from the festival announcement on: along the back and
    // down both sides, so it frames whoever is on stage instead of hanging
    // across their face in front.
    final flags = MeshBuilder();
    final colors = [rgb(0xE84A5F), rgb(0xF6C343), rgb(0x3D8BE6), rgb(0x3CC3A5), rgb(0xF08A3C)];
    for (var i = 0; i < 12; i++) {
      final x = -2.9 + i * 0.53;
      final sag = 0.18 * math.sin(math.pi * i / 11);
      flags.cone(_v(x, 3.02 - sag, -4.22), 0.22, 0, -0.42, colors[i % colors.length], segments: 3);
    }
    for (final x in [-3.05, 3.05]) {
      for (var i = 0; i < 7; i++) {
        final z = -1.0 - i * 0.55;
        final sag = 0.22 * math.sin(math.pi * i / 6);
        flags.cone(_v(x, 3.08 - sag, z), 0.2, 0, -0.38, colors[(i + 2) % colors.length], segments: 3, yaw: math.pi / 2);
      }
    }
    festivalDecor = _add(flags.build(), _soft, at: at, shadows: false)..visible = false;
    for (final x in [-3.0, 3.0]) {
      final p = at.transformed3(_v(x, 3.4, -0.8));
      lamps.add(lantern(p, range: 9));
    }
  }

  void _pondProps() {
    final r = math.Random(3);
    final (px, pz) = placeCoordinates['pond']!;
    final b = MeshBuilder();
    final reed = rgb(0x4E7A35), tip = rgb(0x6B4A2A);
    for (var i = 0; i < 26; i++) {
      final a = 2.5 + r.nextDouble() * 1.4, d = 6.4 + r.nextDouble() * 1.4;
      final x = math.cos(a) * d, z = math.sin(a) * d * -1;
      final h = 1.0 + r.nextDouble() * 0.8;
      b.box(_v(x, -0.3 + h / 2, z), _v(0.05, h, 0.05), reed);
      if (i.isEven) b.cylinder(_v(x, -0.3 + h, z), 0.07, 0.3, 1, tip, segments: 5);
    }
    for (var i = 0; i < 7; i++) {
      final a = r.nextDouble() * 2 * math.pi, d = 1.5 + r.nextDouble() * 4.5;
      b.cylinder(_v(math.cos(a) * d, -0.26, math.sin(a) * d), 0.45, 0.03, 1, rgb(0x4FA046), segments: 9);
      if (i % 3 == 0) b.sphere(_v(math.cos(a) * d, -0.18, math.sin(a) * d), _v(0.12, 0.08, 0.12), rgb(0xF6A6C8));
    }
    for (var i = 0; i < 9; i++) {
      final a = r.nextDouble() * 2 * math.pi, d = 8.0 + r.nextDouble() * 0.9;
      final s = 0.3 + r.nextDouble() * 0.45;
      b.sphere(
        _v(math.cos(a) * d, groundHeight(px + math.cos(a) * d, pz + math.sin(a) * d) - pz * 0 + 0.05, math.sin(a) * d),
        _v(s, s * 0.6, s),
        rgb(0x8D8A84),
        segments: 6,
        rings: 4,
      );
    }
    _add(b.build(), _soft, at: vm.Matrix4.translation(_v(px, 0, pz)));
    final scarf = MeshBuilder()
      ..box(_v(0, 0, 0), _v(0.9, 0.12, 0.28), rgb(0xC8372D), yaw: 0.4)
      ..box(_v(0.35, 0.05, 0.25), _v(0.25, 0.1, 0.5), rgb(0xB02A22), yaw: 0.9);
    scarfInReeds = _add(scarf.build(), _soft, at: vm.Matrix4.translation(_v(px + math.cos(3.1) * 6.6, -0.22, pz - math.sin(3.1) * 6.6)));
  }

  /// A glowing lantern with a warm point light of [range] metres.
  NightLight lantern(vm.Vector3 at, {double range = 12, double power = 26, double size = 1}) {
    final m = pbr(rough: 0.3)..baseColorFactor = vm.Vector4(1, 0.85, 0.55, 1);
    final light = PointLight(color: vm.Vector3(1.0, 0.75, 0.45), intensity: 0, range: range);
    final glow = MeshBuilder()..sphere(_v(0, 0, 0), _v(0.2, 0.26, 0.2) * size, rgb(0xFFE6A8), segments: 8, rings: 6);
    _add(glow.build(), m, at: vm.Matrix4.translation(at), shadows: false);
    scene.add(Node(localTransform: vm.Matrix4.translation(at))..addComponent(PointLightComponent(light)));
    return NightLight(m, vm.Vector3(1.0, 0.72, 0.38), light: light, power: power)..set(0);
  }

  void _lamps() {
    final b = MeshBuilder();
    for (final (x, z) in const [(-5.5, 7.0), (6.5, 8.0), (-3.5, -11.0), (2.5, -22.0)]) {
      final g = groundHeight(x, z);
      b
        ..cylinder(_v(x, g + 1.4, z), 0.08, 2.8, 1, rgb(0x3B3B40))
        ..box(_v(x, g + 2.85, z), _v(0.42, 0.08, 0.42), rgb(0x3B3B40))
        ..cone(_v(x, g + 3.3, z), 0.34, 0.0, 0.3, rgb(0x3B3B40), segments: 4);
      lamps.add(lantern(_v(x, g + 3.08, z)));
    }
    _add(b.build(), _gloss, at: vm.Matrix4.identity());
  }

  // ------------------------------------------------------------ trees

  void _trees() {
    final r = math.Random(42);
    final b = MeshBuilder();
    final segs = pathSegments();
    final avoid = [
      for (final p in placeCoordinates.keys)
        (
          placeAnchor(p),
          switch (p) {
            'pond' => 11.0,
            'bakery' => 9.0,
            'hilltop' => 8.0,
            'berry bushes' => 8.0,
            _ => 6.0,
          },
        ),
      for (final p in placeCoordinates.keys) (standPoint(p), 4.5),
      for (final b in AmbientLayout.blockers) (b.at, b.radius + 1.8),
      for (final (a, c) in AmbientLayout.laundry) ...[(a, 2.0), (c, 2.0), (((a.$1 + c.$1) / 2, (a.$2 + c.$2) / 2), 2.2)],
      for (final run in AmbientLayout.fences)
        for (final p in run) (p, 2.4),
      (AmbientLayout.vegPatch, 3.6),
      for (final p in AmbientLayout.pathLanterns) (p, 1.5),
      for (final p in AmbientLayout.sunnySpots) (p, 2.5),
    ];
    final trunk = rgb(0x6E4526), pine = [rgb(0x2F6E3A), rgb(0x2A6334), rgb(0x387A40)];
    final round = [rgb(0x5DA64A), rgb(0x6DB352), rgb(0x4E9A44), rgb(0xD9A23C)];
    var placed = 0;
    for (var i = 0; i < 900 && placed < 95; i++) {
      final a = r.nextDouble() * 2 * math.pi;
      final d = math.sqrt(r.nextDouble()) * (islandRadius - 2.5);
      final x = _centre.x + math.cos(a) * d, z = _centre.y + math.sin(a) * d;
      if (_pathDistance(x, z, segs) < 3.4) continue;
      if (avoid.any((e) => dist((x, z), e.$1) < e.$2)) continue;
      // Keep the camera's usual view of the square open.
      if (z > 12 && x.abs() < 10) continue;
      final y = groundHeight(x, z);
      final s = 0.8 + r.nextDouble() * 0.6;
      treeTrunks.add(((x, z), 0.3 * s));
      if (r.nextDouble() < 0.5) {
        b.cylinder(_v(x, y + 0.6 * s, z), 0.22 * s, 1.2 * s, 1, trunk, segments: 6);
        final c = pine[r.nextInt(3)];
        for (var k = 0; k < 3; k++) {
          b.cone(_v(x, y + (1.0 + k * 1.05) * s, z), (1.6 - k * 0.4) * s, 0, 1.7 * s, c * (1 + k * 0.06), segments: 7, yaw: r.nextDouble());
        }
      } else {
        b.cylinder(_v(x, y + 0.9 * s, z), 0.24 * s, 1.8 * s, 1, trunk, segments: 6);
        final c = round[r.nextDouble() < 0.12 ? 3 : r.nextInt(3)];
        crowns.add((_v(x, y + 2.5 * s, z), 1.45 * s));
        b
          ..sphere(_v(x, y + 2.5 * s, z), _v(1.45 * s, 1.3 * s, 1.45 * s), c, segments: 8, rings: 6)
          ..sphere(_v(x + 0.5 * s, y + 3.2 * s, z - 0.3 * s), _v(0.9 * s, 0.8 * s, 0.9 * s), c * 1.08, segments: 7, rings: 5);
      }
      placed++;
    }
    // Rocks and flower patches.
    for (var i = 0; i < 60; i++) {
      final a = r.nextDouble() * 2 * math.pi;
      final d = math.sqrt(r.nextDouble()) * (islandRadius - 3);
      final x = _centre.x + math.cos(a) * d, z = _centre.y + math.sin(a) * d;
      if (_pathDistance(x, z, segs) < 1.8 || avoid.any((e) => dist((x, z), e.$1) < e.$2 * 0.6)) continue;
      final y = groundHeight(x, z);
      if (i % 3 == 0) {
        final s = 0.25 + r.nextDouble() * 0.4;
        b.sphere(_v(x, y + s * 0.3, z), _v(s * 1.2, s * 0.7, s), rgb(0x9A968F), segments: 6, rings: 4);
      } else {
        final c = [rgb(0xF6D447), rgb(0xF08AC0), rgb(0xFFFFFF), rgb(0xB18CF0)][i % 4];
        for (var k = 0; k < 5; k++) {
          final ox = (r.nextDouble() - 0.5) * 1.4, oz = (r.nextDouble() - 0.5) * 1.4;
          b.sphere(_v(x + ox, y + 0.18, z + oz), _v(0.09, 0.06, 0.09), c, segments: 5, rings: 3);
        }
      }
    }
    _add(b.build(), _soft);
  }
}

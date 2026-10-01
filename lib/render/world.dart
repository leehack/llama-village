import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../sim/geo.dart';
import '../sim/places.dart';
import 'look.dart';
import 'mesh_builder.dart';

/// Wool and accent colours per llama, also used for their huts.
const Map<String, (int wool, int accent)> llamaColors = {
  'Pip': (0xF4EDE2, 0xC8372D),
  'Mo': (0xC99A6B, 0xE0A93B),
  'June': (0xE6C9A3, 0x8E4FB0),
  'Bramble': (0x9C9A96, 0x4E7A3E),
  'Clover': (0x6E4A33, 0x3F7BC9),
};

/// Radius of the round diorama the village sits on.
const double islandRadius = 58;
final vm.Vector2 _centre = vm.Vector2(0, -6);

vm.Vector3 _v(double x, double y, double z) => vm.Vector3(x, y, z);

/// A light that comes on after dark: an emissive material plus an
/// optional point light.
class NightLight {
  NightLight(this.material, this.on, {this.light, this.owner});
  final PhysicallyBasedMaterial material;
  final vm.Vector3 on;
  final PointLight? light;

  /// The llama whose hut this is, if any.
  final String? owner;
  double level = 0;

  void set(double v) {
    level = v;
    material.emissiveFactor = vm.Vector4(on.x, on.y, on.z, 1);
    material.emissiveStrength = 0.15 + v * 5.5;
    light?.intensity = v * 26;
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
  late final PhysicallyBasedMaterial water;

  late final PhysicallyBasedMaterial _matte = pbr(rough: 0.9);
  late final PhysicallyBasedMaterial _soft = pbr(rough: 0.7);
  late final PhysicallyBasedMaterial _gloss = pbr(rough: 0.35);

  void build() {
    _ground();
    _water();
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

  void _ground() {
    final b = MeshBuilder();
    final segs = pathSegments();
    final grassA = rgb(0x86BF4E), grassB = rgb(0x7AB345), grassC = rgb(0x93C957);
    final hill = rgb(0xA3CC63), dirt = rgb(0xC7A26A), dirtDark = rgb(0xB48F5A), sand = rgb(0xE0CB93), mud = rgb(0x6E8F5A);
    final (px, pz) = placeCoordinates['pond']!;
    final plazas = [for (final p in placeCoordinates.keys) (standPoint(p), p == 'bakery' ? 5.5 : 2.6)];
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
      final pd = _pathDistance(c.x, c.z, segs);
      if (pd < 1.05) return salt % 3 == 0 ? dirtDark : dirt;
      for (final ((sx, sz), r) in plazas) {
        if ((c.x - sx) * (c.x - sx) + (c.z - sz) * (c.z - sz) < r * r) return salt % 3 == 0 ? dirtDark : dirt;
      }
      if (c.y > 2.5) return salt % 2 == 0 ? hill : grassC;
      return switch (salt % 5) {
        0 => grassB,
        1 => grassC,
        _ => grassA,
      };
    }

    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        final a = grid[i][j], bb = grid[i + 1][j], c = grid[i + 1][j + 1], d = grid[i][j + 1];
        for (final (t, k) in [((a, bb, c), 0), ((a, c, d), 1)]) {
          final area = (t.$2 - t.$1).cross(t.$3 - t.$1).length;
          if (area < 1e-3) continue;
          final centroid = (t.$1 + t.$2 + t.$3) / 3;
          b.triangle(t.$1, t.$2, t.$3, colorAt(centroid, hash(i * 2 + k, j)));
        }
      }
    }
    // The diorama's soil skirt.
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

  void _water() {
    final (x, z) = placeCoordinates['pond']!;
    water = pbr(rough: 0.08)..baseColorFactor = vm.Vector4(0.16, 0.42, 0.62, 1);
    final b = MeshBuilder()..cylinder(_v(0, 0, 0), 7.7, 0.06, 1, rgb(0x5DB0DC), segments: 36);
    _add(b.build(), water, at: vm.Matrix4.translation(_v(x, -0.32, z)), shadows: false);
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
    final spots = <(double, double)>[
      (-2.8, -2.2),
      (-0.6, -3.4),
      (1.8, -2.6),
      (3.6, -0.8),
      (-3.8, 0.4),
      (0.6, -1.0),
      (3.0, 1.6),
      (-1.6, 1.4),
    ];
    for (final (x, z) in spots) {
      final s = 0.7 + r.nextDouble() * 0.45;
      final g = groundHeight(16 + x, 16 + z) - groundHeight(16, 16);
      b.sphere(_v(x, g + s * 0.75, z), _v(s * 1.1, s * 0.85, s * 1.0), leaf[r.nextInt(3)], segments: 9, rings: 6);
      b.sphere(_v(x + 0.4 * s, g + s * 1.15, z + 0.2), _v(s * 0.7, s * 0.6, s * 0.7), leaf[r.nextInt(3)], segments: 8, rings: 5);
      for (var k = 0; k < 9; k++) {
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
    for (var i = 0; i < 6; i++) {
      final x = -4.5 + i * 1.8;
      b.box(_v(x, 0.5, -4.6), _v(0.14, 1.0, 0.14), wood);
    }
    b
      ..box(_v(0, 0.75, -4.6), _v(9.2, 0.1, 0.08), wood)
      ..box(_v(0, 0.4, -4.6), _v(9.2, 0.1, 0.08), wood)
      ..cylinder(_v(1.6, 0.25, 2.6), 0.4, 0.5, 1, rgb(0xB0824D), segments: 9)
      ..sphere(_v(1.6, 0.52, 2.6), _v(0.33, 0.12, 0.33), rgb(0xB72E48));
    final (ax, az) = placeCoordinates['berry bushes']!;
    _add(b.build(), _soft, at: vm.Matrix4.translation(_v(ax, groundHeight(ax, az), az)));

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
    final (sx, sz) = standPoint('berry bushes');
    wildflowers = _add(fb.build(), _soft, at: vm.Matrix4.translation(_v(sx + 1.4, groundHeight(sx + 1.4, sz - 1.8), sz - 1.8)))
      ..visible = false;
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
    // Bunting, shown from the festival announcement on.
    final flags = MeshBuilder();
    final colors = [rgb(0xE84A5F), rgb(0xF6C343), rgb(0x3D8BE6), rgb(0x3CC3A5), rgb(0xF08A3C)];
    for (var i = 0; i < 12; i++) {
      final x = -2.9 + i * 0.53;
      final sag = 0.25 * math.sin(math.pi * i / 11);
      flags.cone(_v(x, 2.75 - sag, -0.8), 0.22, 0, -0.42, colors[i % colors.length], segments: 3);
    }
    festivalDecor = _add(flags.build(), _soft, at: at, shadows: false)..visible = false;
    for (final x in [-3.0, 3.0]) {
      final p = at.transformed3(_v(x, 3.4, -0.8));
      lamps.add(_lantern(p, festival: true));
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
    // A little jetty towards the square.
    final f = placeFacing('pond');
    final yaw = math.atan2(f.$1, f.$2);
    for (var i = 0; i < 6; i++) {
      final d = 4.6 + i * 0.5;
      b.box(_v(f.$1 * d, -0.05, f.$2 * d), _v(1.3, 0.08, 0.42), rgb(0xA67646), yaw: yaw);
    }
    _add(b.build(), _soft, at: vm.Matrix4.translation(_v(px, 0, pz)));
    final scarf = MeshBuilder()
      ..box(_v(0, 0, 0), _v(0.9, 0.12, 0.28), rgb(0xC8372D), yaw: 0.4)
      ..box(_v(0.35, 0.05, 0.25), _v(0.25, 0.1, 0.5), rgb(0xB02A22), yaw: 0.9);
    scarfInReeds = _add(scarf.build(), _soft, at: vm.Matrix4.translation(_v(px + math.cos(3.1) * 6.6, -0.22, pz - math.sin(3.1) * 6.6)));
  }

  NightLight _lantern(vm.Vector3 at, {bool festival = false}) {
    final m = pbr(rough: 0.3)..baseColorFactor = vm.Vector4(1, 0.85, 0.55, 1);
    final light = PointLight(color: vm.Vector3(1.0, 0.75, 0.45), intensity: 0, range: festival ? 9 : 12);
    final glow = MeshBuilder()..sphere(_v(0, 0, 0), _v(0.2, 0.26, 0.2), rgb(0xFFE6A8), segments: 8, rings: 6);
    _add(glow.build(), m, at: vm.Matrix4.translation(at), shadows: false);
    scene.add(Node(localTransform: vm.Matrix4.translation(at))..addComponent(PointLightComponent(light)));
    return NightLight(m, vm.Vector3(1.0, 0.72, 0.38), light: light)..set(0);
  }

  void _lamps() {
    final b = MeshBuilder();
    for (final (x, z) in const [(-5.5, 7.0), (6.5, 8.0), (-3.5, -11.0), (2.5, -22.0)]) {
      final g = groundHeight(x, z);
      b
        ..cylinder(_v(x, g + 1.4, z), 0.08, 2.8, 1, rgb(0x3B3B40))
        ..box(_v(x, g + 2.85, z), _v(0.42, 0.08, 0.42), rgb(0x3B3B40))
        ..cone(_v(x, g + 3.3, z), 0.34, 0.0, 0.3, rgb(0x3B3B40), segments: 4);
      lamps.add(_lantern(_v(x, g + 3.08, z)));
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
      if (r.nextDouble() < 0.5) {
        b.cylinder(_v(x, y + 0.6 * s, z), 0.22 * s, 1.2 * s, 1, trunk, segments: 6);
        final c = pine[r.nextInt(3)];
        for (var k = 0; k < 3; k++) {
          b.cone(_v(x, y + (1.0 + k * 1.05) * s, z), (1.6 - k * 0.4) * s, 0, 1.7 * s, c * (1 + k * 0.06), segments: 7, yaw: r.nextDouble());
        }
      } else {
        b.cylinder(_v(x, y + 0.9 * s, z), 0.24 * s, 1.8 * s, 1, trunk, segments: 6);
        final c = round[r.nextDouble() < 0.12 ? 3 : r.nextInt(3)];
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

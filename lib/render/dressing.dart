import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../ambient/layout.dart';
import '../sim/geo.dart';
import '../sim/places.dart';
import 'look.dart';
import 'mesh_builder.dart';
import 'quality.dart';
import 'world.dart';

vm.Vector3 _v(double x, double y, double z) => vm.Vector3(x, y, z);

/// The small things that make the village lived in: grass tufts and
/// flowers, fences, a well, a chicken coop, a doghouse, laundry lines, a
/// vegetable patch, lanterns along the paths, drifting clouds and the
/// puddles a storm leaves. Repeated pieces are instanced.
class VillageDressing {
  VillageDressing(this.scene, this.world);
  final Scene scene;
  final VillageWorld world;

  late final InstancedMesh _grass, _stems, _blooms, _cloth, _clouds, _puddles;
  final List<vm.Matrix4> _clothRest = [];
  final List<vm.Vector3> _cloudRest = [];
  final List<double> _cloudScale = [];
  final List<vm.Matrix4> _puddleRest = [];
  int _grassAll = 0, _flowersAll = 0;
  double _cloudDrift = 0;

  late final PhysicallyBasedMaterial _soft = pbr(rough: 0.75);
  late final PhysicallyBasedMaterial _grassMaterial = pbr(rough: 0.85)..doubleSided = true;
  late final PhysicallyBasedMaterial _cloudMaterial = pbr(rough: 1)
    ..baseColorFactor = vm.Vector4(1, 1, 1, 1)
    ..emissiveFactor = vm.Vector4(0.55, 0.6, 0.7, 1)
    ..emissiveStrength = 0.12;
  late final PhysicallyBasedMaterial _puddleMaterial = pbr(rough: 0.05)..baseColorFactor = vm.Vector4(0.24, 0.2, 0.15, 1);

  void build() {
    _scatterGrass();
    _fences();
    _well();
    _coop();
    _doghouse();
    _laundry();
    _vegPatch();
    _dock();
    _pathLanterns();
    _cloudBank();
    _puddleSpots();
  }

  Node _add(MeshGeometry g, Material m, {vm.Matrix4? at, bool shadows = true}) {
    final n = Node(mesh: Mesh(g, m), localTransform: at ?? vm.Matrix4.identity())..castsShadows = shadows;
    scene.add(n);
    return n;
  }

  Node _addInstanced(InstancedMesh mesh, {bool shadows = false}) {
    final n = Node()
      ..addComponent(InstancedMeshComponent(mesh))
      ..castsShadows = shadows;
    scene.add(n);
    return n;
  }

  set quality(GraphicsQuality q) {
    // Instances are scattered in random order, so a prefix is an even thin-out.
    void show(InstancedMesh m, int all, double share) {
      final keep = (all * share).round();
      for (var i = 0; i < all; i++) {
        final t = i < keep ? _grassPlacements[m]![i] : _hidden;
        m.setInstanceTransform(i, t);
      }
    }

    show(_grass, _grassAll, q.foliage);
    show(_stems, _flowersAll, q.foliage);
    show(_blooms, _flowersAll, q.foliage);
  }

  final Map<InstancedMesh, List<vm.Matrix4>> _grassPlacements = {};
  static final vm.Matrix4 _hidden = vm.Matrix4.translation(_v(0, -60, 0))..scaleByDouble(0.001, 0.001, 0.001, 1);

  // ------------------------------------------------------------ grass

  bool _open(double x, double z, {double path = 1.6}) {
    if (dist((x, z), (0, -6)) > islandRadius - 1.5) return false;
    if (world.pathDistance(x, z) < path) return false;
    if (dist((x, z), AmbientLayout.pond) < 8.4) return false;
    for (final p in placeCoordinates.keys) {
      final r = switch (p) {
        'bakery' => 5.0,
        'hilltop' => 5.0,
        'berry bushes' => 6.0,
        'pond' => 0.0,
        _ => 3.4,
      };
      if (dist((x, z), placeAnchor(p)) < r) return false;
    }
    for (final (t, r) in world.treeTrunks) {
      if (dist((x, z), t) < r + 0.3) return false;
    }
    return !AmbientLayout.blockers.any((b) => b.contains((x, z), 0.2));
  }

  void _scatterGrass() {
    final r = math.Random(21);
    final tuft = MeshBuilder();
    final root = rgb(0x4E8A34), tip = rgb(0xA8D46A);
    for (var k = 0; k < 7; k++) {
      final a = k / 7 * 2 * math.pi + r.nextDouble() * 0.5;
      final lean = 0.06 + r.nextDouble() * 0.12;
      final h = 0.22 + r.nextDouble() * 0.2;
      final ox = math.cos(a) * 0.05, oz = math.sin(a) * 0.05;
      final side = _v(-math.sin(a), 0, math.cos(a)) * 0.028;
      final base = _v(ox, -0.02, oz);
      tuft.blade(base - side, base + side, _v(ox + math.cos(a) * lean, h, oz + math.sin(a) * lean), root, tip);
    }
    _grass = InstancedMesh(geometry: tuft.build(), material: _grassMaterial);
    final grassAt = <vm.Matrix4>[];
    var tries = 0;
    while (grassAt.length < 2600 && tries++ < 40000) {
      final a = r.nextDouble() * 2 * math.pi, d = math.sqrt(r.nextDouble()) * (islandRadius - 1);
      // Clumps: most tufts sit near another.
      var x = math.cos(a) * d, z = -6 + math.sin(a) * d;
      if (grassAt.isNotEmpty && r.nextDouble() < 0.55) {
        final near = grassAt[r.nextInt(grassAt.length)].getTranslation();
        x = near.x + (r.nextDouble() - 0.5) * 1.6;
        z = near.z + (r.nextDouble() - 0.5) * 1.6;
      }
      if (!_open(x, z)) continue;
      final s = 0.7 + r.nextDouble() * 0.7;
      grassAt.add(
        vm.Matrix4.translation(_v(x, groundHeight(x, z), z))
          ..rotateY(r.nextDouble() * 6.3)
          ..scaleByDouble(s, s * (0.8 + r.nextDouble() * 0.5), s, 1),
      );
    }
    for (final m in grassAt) {
      final dry = r.nextDouble();
      _grass.addInstance(m, color: vm.Vector4(0.85 + dry * 0.35, 0.9 + r.nextDouble() * 0.15, 0.7 + dry * 0.2, 1));
    }
    _grassAll = grassAt.length;
    _grassPlacements[_grass] = grassAt;
    _addInstanced(_grass);

    // Wildflowers in loose drifts: a stem and a bloom per flower.
    final stem = MeshBuilder()
      ..cylinder(_v(0, 0.16, 0), 0.012, 0.32, 1, rgb(0x3E8A35), segments: 4)
      ..blade(_v(-0.01, 0.06, 0), _v(0.01, 0.06, 0), _v(0.09, 0.14, 0.02), rgb(0x3E8A35), rgb(0x6DB352));
    final bloom = MeshBuilder()
      ..sphere(_v(0, 0.34, 0), _v(0.065, 0.025, 0.065), rgb(0xFFFFFF), segments: 6, rings: 3)
      ..sphere(_v(0, 0.355, 0), _v(0.025, 0.018, 0.025), rgb(0xF6C343, 0.9), segments: 5, rings: 3);
    _stems = InstancedMesh(geometry: stem.build(), material: _grassMaterial);
    _blooms = InstancedMesh(geometry: bloom.build(), material: _soft);
    final palette = [rgb(0xFFFFFF), rgb(0xF6D447), rgb(0xF08AC0), rgb(0xB18CF0), rgb(0xF2A65A), rgb(0x9ED0FF)];
    final flowerAt = <vm.Matrix4>[];
    final tints = <vm.Vector4>[];
    var drifts = 0;
    while (drifts < 70 && tries++ < 80000) {
      final a = r.nextDouble() * 2 * math.pi, d = math.sqrt(r.nextDouble()) * (islandRadius - 2);
      final cx = math.cos(a) * d, cz = -6 + math.sin(a) * d;
      if (!_open(cx, cz, path: 2.2)) continue;
      drifts++;
      final c = palette[r.nextInt(palette.length)];
      for (var k = 0; k < 6 + r.nextInt(8); k++) {
        final x = cx + (r.nextDouble() - 0.5) * 2.4, z = cz + (r.nextDouble() - 0.5) * 2.4;
        if (!_open(x, z, path: 1.8)) continue;
        final s = 0.8 + r.nextDouble() * 0.5;
        flowerAt.add(
          vm.Matrix4.translation(_v(x, groundHeight(x, z), z))
            ..rotateY(r.nextDouble() * 6.3)
            ..scaleByDouble(s, s, s, 1),
        );
        tints.add(vm.Vector4(c.x * 1.3, c.y * 1.3, c.z * 1.3, 1));
      }
    }
    for (var i = 0; i < flowerAt.length; i++) {
      _stems.addInstance(flowerAt[i]);
      _blooms.addInstance(flowerAt[i], color: tints[i]);
    }
    _flowersAll = flowerAt.length;
    _grassPlacements[_stems] = flowerAt;
    _grassPlacements[_blooms] = flowerAt;
    _addInstanced(_stems);
    _addInstanced(_blooms);
  }

  // ------------------------------------------------------------ props

  void _fences() {
    final b = MeshBuilder();
    final post = rgb(0x8A5A33), rail = rgb(0xA87A4E);
    for (final run in AmbientLayout.fences) {
      for (var i = 0; i + 1 < run.length; i++) {
        final (ax, az) = run[i];
        final (bx, bz) = run[i + 1];
        final len = dist(run[i], run[i + 1]);
        final yaw = math.atan2(bx - ax, bz - az);
        final posts = math.max(1, (len / 1.6).round());
        for (var k = 0; k <= posts; k++) {
          if (k == 0 && i > 0) continue;
          final x = ax + (bx - ax) * k / posts, z = az + (bz - az) * k / posts;
          b
            ..box(_v(x, groundHeight(x, z) + 0.45, z), _v(0.12, 0.9, 0.12), post, yaw: yaw)
            ..cone(_v(x, groundHeight(x, z) + 0.9, z), 0.085, 0, 0.1, post, segments: 4, yaw: yaw + math.pi / 4);
        }
        final mx = (ax + bx) / 2, mz = (az + bz) / 2;
        final g = groundHeight(mx, mz);
        for (final h in [0.38, 0.7]) {
          b.box(_v(mx, g + h, mz), _v(0.06, 0.09, len), rail, yaw: yaw);
        }
      }
    }
    _add(b.build(), _soft);
  }

  void _well() {
    final (x, z) = AmbientLayout.well;
    final stone = rgb(0x9A958C), dark = rgb(0x2A2E33), wood = rgb(0x7B5131), roof = rgb(0xB5533C);
    final b = MeshBuilder()
      ..cylinder(_v(0, 0.4, 0), 0.85, 0.8, 1, stone, segments: 12, capColor: dark)
      ..cylinder(_v(0, 0.82, 0), 0.92, 0.08, 1, stone * 1.1, segments: 12, capColor: dark)
      ..box(_v(-0.78, 1.25, 0), _v(0.12, 1.7, 0.12), wood)
      ..box(_v(0.78, 1.25, 0), _v(0.12, 1.7, 0.12), wood)
      ..cylinder(_v(0, 1.45, 0), 0.07, 1.5, 0, wood * 0.8, segments: 6)
      ..box(_v(0.9, 1.45, 0.12), _v(0.05, 0.05, 0.3), wood * 0.7)
      ..gable(_v(0, 0, 0), 2.0, 1.3, 2.05, 2.55, roof, gableColor: wood)
      ..cylinder(_v(0.25, 1.05, 0), 0.13, 0.22, 1, wood * 1.1, segments: 8, capColor: rgb(0x5DB0DC, 0.6));
    final g = groundHeight(x, z);
    _add(b.build(), _soft, at: vm.Matrix4.translation(_v(x, g, z))..rotateY(0.4));
  }

  void _coop() {
    final (x, z) = AmbientLayout.coop;
    final wall = rgb(0xE8D7B5), wood = rgb(0x8A5A33), roof = rgb(0xC8372D), dark = rgb(0x3A2618), straw = rgb(0xE6C35C);
    final b = MeshBuilder();
    for (final (px, pz) in const [(-0.9, -0.6), (0.9, -0.6), (-0.9, 0.6), (0.9, 0.6)]) {
      b.box(_v(px, 0.25, pz), _v(0.12, 0.5, 0.12), wood);
    }
    b
      ..box(_v(0, 0.95, 0), _v(2.0, 0.9, 1.4), wall)
      ..gable(_v(0, 0, 0), 1.7, 2.3, 1.4, 1.95, roof, gableColor: wall, yaw: math.pi / 2)
      ..box(_v(0, 0.8, 0.71), _v(0.42, 0.5, 0.04), dark)
      ..box(_v(0, 0.55, 1.05), _v(0.42, 0.04, 0.8), wood, yaw: 0)
      ..box(_v(0.55, 1.05, 0.71), _v(0.3, 0.22, 0.03), straw)
      ..box(_v(0, 0.3, 1.25), _v(0.46, 0.04, 0.5), wood);
    // The ramp tilts down from the door.
    final ramp = MeshBuilder()..box(_v(0, 0, 0.35), _v(0.4, 0.04, 0.8), wood * 1.15);
    for (var k = 0; k < 4; k++) {
      ramp.box(_v(0, 0.03, 0.1 + k * 0.18), _v(0.36, 0.025, 0.03), wood * 0.8);
    }
    final at = vm.Matrix4.translation(_v(x, groundHeight(x, z), z))..rotateY(AmbientLayout.coopYaw);
    _add(b.build(), _soft, at: at);
    _add(
      ramp.build(),
      _soft,
      at: at.clone()
        ..translateByVector3(_v(0, 0.55, 0.72))
        ..rotateX(0.62),
    );
  }

  void _doghouse() {
    final (x, z) = AmbientLayout.doghouse;
    final wall = rgb(0x6FA0C8), roof = rgb(0x7E3B2C), dark = rgb(0x221A14), bowl = rgb(0xC8372D);
    final b = MeshBuilder()
      ..box(_v(0, 0.45, 0), _v(1.1, 0.9, 1.3), wall)
      ..gable(_v(0, 0, 0), 1.35, 1.5, 0.88, 1.4, roof, gableColor: wall)
      ..box(_v(0, 0.36, 0.66), _v(0.5, 0.62, 0.03), dark)
      ..cylinder(_v(0.75, 0.05, 0.9), 0.16, 0.1, 1, bowl, segments: 10, capColor: rgb(0x8A5A33));
    _add(b.build(), _soft, at: vm.Matrix4.translation(_v(x, groundHeight(x, z), z))..rotateY(AmbientLayout.doghouseYaw));
  }

  void _laundry() {
    final pole = rgb(0x8A5A33), line = rgb(0xE8E2D2);
    final colors = [rgb(0xF4EDE2), rgb(0xE84A5F), rgb(0x3D8BE6), rgb(0xF6C343), rgb(0xA6CE66), rgb(0xF08AC0)];
    final b = MeshBuilder();
    final clothAt = <(vm.Matrix4, vm.Vector3)>[];
    final r = math.Random(4);
    for (final (a, c) in AmbientLayout.laundry) {
      final ga = groundHeight(a.$1, a.$2), gc = groundHeight(c.$1, c.$2);
      for (final (p, g) in [(a, ga), (c, gc)]) {
        b
          ..cylinder(_v(p.$1, g + 1.1, p.$2), 0.06, 2.2, 1, pole, segments: 6)
          ..box(_v(p.$1, g + 2.15, p.$2), _v(0.5, 0.06, 0.06), pole, yaw: math.atan2(c.$1 - a.$1, c.$2 - a.$2) + math.pi / 2);
      }
      final yaw = math.atan2(c.$1 - a.$1, c.$2 - a.$2);
      final len = dist(a, c);
      final mx = (a.$1 + c.$1) / 2, mz = (a.$2 + c.$2) / 2;
      b.box(_v(mx, (ga + gc) / 2 + 2.05, mz), _v(0.015, 0.015, len), line, yaw: yaw);
      final n = 4;
      for (var k = 0; k < n; k++) {
        final t = (k + 0.7) / (n + 0.4);
        final x = a.$1 + (c.$1 - a.$1) * t, z = a.$2 + (c.$2 - a.$2) * t;
        final sag = 0.12 * math.sin(math.pi * t);
        final m = vm.Matrix4.translation(_v(x, ga + (gc - ga) * t + 2.05 - sag, z))..rotateY(yaw + math.pi / 2);
        clothAt.add((m, colors[r.nextInt(colors.length)]));
      }
    }
    _add(b.build(), _soft);
    // A cloth hangs from its top edge, so it can swing about the line.
    final cloth = MeshBuilder()..box(_v(0, -0.32, 0), _v(0.5, 0.62, 0.02), rgb(0xFFFFFF));
    _cloth = InstancedMesh(geometry: cloth.build(), material: pbr(rough: 0.8)..doubleSided = true);
    for (final (m, c) in clothAt) {
      _cloth.addInstance(m, color: vm.Vector4(c.x, c.y, c.z, 1));
      _clothRest.add(m);
    }
    _addInstanced(_cloth, shadows: true);
  }

  void _vegPatch() {
    final (x, z) = AmbientLayout.vegPatch;
    final soil = rgb(0x6B4A2E), leaf = rgb(0x4C9A40), carrot = rgb(0xF08A3C), cabbage = rgb(0x9CCB6A);
    final b = MeshBuilder()..box(_v(0, 0.05, 0), _v(3.6, 0.12, 2.8), soil);
    for (var row = 0; row < 4; row++) {
      for (var k = 0; k < 6; k++) {
        final px = -1.4 + k * 0.56, pz = -1.0 + row * 0.66;
        if (row.isEven) {
          b
            ..sphere(_v(px, 0.2, pz), _v(0.18, 0.14, 0.18), cabbage, segments: 7, rings: 5)
            ..sphere(_v(px, 0.24, pz), _v(0.1, 0.1, 0.1), leaf, segments: 6, rings: 4);
        } else {
          b
            ..cone(_v(px, 0.08, pz), 0.05, 0, 0.1, carrot, segments: 5)
            ..cone(_v(px, 0.16, pz), 0.06, 0, 0.22, leaf, segments: 4);
        }
      }
    }
    _add(b.build(), _soft, at: vm.Matrix4.translation(_v(x, groundHeight(x, z), z)));
  }

  /// A plank dock on posts out into the pond, with a rowing boat.
  void _dock() {
    final (a, c) = AmbientLayout.dock;
    final yaw = math.atan2(c.$1 - a.$1, c.$2 - a.$2);
    final len = dist(a, c);
    final plank = rgb(0xA67646), post = rgb(0x6B4226);
    final b = MeshBuilder();
    final n = (len / 0.42).floor();
    for (var k = 0; k < n; k++) {
      final along = 0.21 + k * 0.42 - len / 2;
      b.box(_v(0, 0, along), _v(1.5, 0.07, 0.38), plank * (0.92 + (k % 3) * 0.05));
    }
    for (final along in [-len / 2 + 0.3, 0.0, len / 2 - 0.3]) {
      for (final s in [-1.0, 1.0]) {
        b.cylinder(_v(0.72 * s, -0.4, along), 0.08, 1.0, 1, post, segments: 6);
      }
    }
    b
      ..box(_v(0, -0.07, 0), _v(0.12, 0.08, len), post)
      ..cylinder(_v(0.62, 0.15, -len / 2 + 0.3), 0.07, 0.3, 1, post, segments: 6);
    final mx = (a.$1 + c.$1) / 2, mz = (a.$2 + c.$2) / 2;
    final at = vm.Matrix4.translation(_v(mx, -0.04, mz))..rotateY(yaw);
    _add(b.build(), _soft, at: at);
    // A little rowing boat tied up by the dock.
    final boat = MeshBuilder()
      ..sphere(_v(0, 0.08, 0), _v(0.55, 0.22, 1.25), rgb(0xF4EDE2), segments: 10, rings: 5)
      ..box(_v(0, 0.2, 0), _v(0.85, 0.08, 1.7), rgb(0x8A5A33))
      ..box(_v(0, 0.24, 0.1), _v(0.9, 0.05, 0.22), rgb(0xA67646));
    _add(
      boat.build(),
      _soft,
      at: at.clone()
        ..translateByVector3(_v(1.6, -0.2, -len / 2 + 1.8))
        ..rotateY(0.15),
    );
  }

  void _pathLanterns() {
    final b = MeshBuilder();
    final iron = rgb(0x3B3B40);
    for (final (x, z) in AmbientLayout.pathLanterns) {
      final g = groundHeight(x, z);
      b
        ..cylinder(_v(x, g + 0.75, z), 0.05, 1.5, 1, iron, segments: 6)
        ..box(_v(x, g + 1.55, z), _v(0.3, 0.05, 0.3), iron)
        ..cone(_v(x, g + 1.92, z), 0.24, 0, 0.2, iron, segments: 4, yaw: math.pi / 4);
      world.lamps.add(world.lantern(_v(x, g + 1.75, z), range: 8, power: 12, size: 0.6));
    }
    _add(b.build(), pbr(rough: 0.35));
  }

  // ------------------------------------------------------------ sky

  void _cloudBank() {
    final r = math.Random(17);
    final puff = MeshBuilder();
    for (final (x, y, z, s) in const [
      (0.0, 0.0, 0.0, 1.0),
      (1.3, -0.2, 0.3, 0.75),
      (-1.2, -0.25, -0.2, 0.7),
      (0.4, 0.35, -0.3, 0.7),
      (-0.4, -0.1, 0.8, 0.6),
      (2.2, -0.35, -0.2, 0.5),
    ]) {
      puff.sphere(_v(x * 3, y * 2, z * 3), _v(3.2 * s, 1.7 * s, 2.6 * s), rgb(0xFFFFFF), segments: 9, rings: 6);
    }
    _clouds = InstancedMesh(geometry: puff.build(), material: _cloudMaterial);
    for (var i = 0; i < 14; i++) {
      final p = _v(-90 + r.nextDouble() * 180, 32 + r.nextDouble() * 12, -95 + r.nextDouble() * 150);
      final s = 0.8 + r.nextDouble() * 0.9;
      _cloudRest.add(p);
      _cloudScale.add(s);
      _clouds.addInstance(_cloudAt(p, s, i));
    }
    _addInstanced(_clouds);
  }

  vm.Matrix4 _cloudAt(vm.Vector3 p, double s, int i) => vm.Matrix4.translation(p)
    ..rotateY(i * 1.3)
    ..scaleByDouble(s * (1 + (i % 3) * 0.2), s * 0.8, s, 1);

  void _puddleSpots() {
    final r = math.Random(12);
    final disc = MeshBuilder()..cylinder(_v(0, 0, 0), 1, 0.01, 1, rgb(0xFFFFFF), segments: 14);
    _puddles = InstancedMesh(geometry: disc.build(), material: _puddleMaterial);
    final segs = pathSegments();
    for (var i = 0; i < 26; i++) {
      final ((ax, az), (bx, bz)) = segs[r.nextInt(segs.length)];
      final t = r.nextDouble();
      final x = ax + (bx - ax) * t + (r.nextDouble() - 0.5) * 1.2, z = az + (bz - az) * t + (r.nextDouble() - 0.5) * 1.2;
      final m = vm.Matrix4.translation(_v(x, groundHeight(x, z) + 0.085, z))
        ..rotateY(r.nextDouble() * 3)
        ..scaleByDouble(0.25 + r.nextDouble() * 0.4, 1, 0.18 + r.nextDouble() * 0.3, 1);
      _puddleRest.add(m);
      _puddles.addInstance(_hidden);
    }
    _addInstanced(_puddles);
  }

  double _wetShown = -1;

  /// Sways the laundry, drifts the clouds and fills or dries the puddles.
  void update(double wall, double dt, {required double storm, required double wetness}) {
    final wind = 0.25 + storm * 1.2;
    _cloth.updateInstanceTransforms((list) {
      for (var i = 0; i < list.length; i++) {
        final swing = wind * (0.25 * math.sin(wall * (1.7 + i * 0.13) + i) + 0.12 * math.sin(wall * 4.1 + i * 2.0));
        list[i]
          ..setFrom(_clothRest[i])
          ..rotateX(swing + storm * 0.5);
      }
    }, recomputeWinding: false);

    _cloudDrift += dt * (1.2 + storm * 4);
    _clouds.updateInstanceTransforms((list) {
      for (var i = 0; i < list.length; i++) {
        final p = _cloudRest[i].clone();
        p.x = (p.x + _cloudDrift * (0.8 + (i % 4) * 0.15) + 90) % 180 - 90;
        list[i].setFrom(_cloudAt(p, _cloudScale[i] * (1 + storm * 0.6), i));
      }
    }, recomputeWinding: false);
    final grey = 1 - storm * 0.55;
    _cloudMaterial.baseColorFactor = vm.Vector4(grey, grey, grey * 1.04, 1);

    if ((wetness - _wetShown).abs() > 0.02) {
      _wetShown = wetness;
      final k = math.min(1.0, wetness * 1.6);
      for (var i = 0; i < _puddleRest.length; i++) {
        final show = k > 0.03 && i < (_puddleRest.length * math.min(1.0, wetness * 2.5)).ceil();
        _puddles.setInstanceTransform(i, show ? (_puddleRest[i].clone()..scaleByDouble(k, 1, k, 1)) : _hidden);
      }
    }
  }
}

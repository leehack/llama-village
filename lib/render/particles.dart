import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../ambient/layout.dart';
import '../sim/geo.dart';
import 'look.dart';
import 'mesh_builder.dart';
import 'water.dart';

vm.Vector3 _v(double x, double y, double z) => vm.Vector3(x, y, z);

final vm.Matrix4 _hidden = vm.Matrix4.translation(_v(0, -60, 0))..scaleByDouble(0.001, 0.001, 0.001, 1);

/// Fireflies over the meadows and the pond after dark: one instanced draw
/// of tiny glowing beads that drift and blink.
class Fireflies {
  Fireflies(this.scene, {this.count = 56});
  final Scene scene;
  final int count;

  late final InstancedMesh _mesh;
  final List<vm.Vector3> _home = [];
  final List<double> _seed = [];
  int _shown = 0;
  bool _hiddenAll = false;

  void build() {
    final r = math.Random(31);
    final bead = MeshBuilder()..sphere(_v(0, 0, 0), _v(0.07, 0.07, 0.07), rgb(0xFFFFFF), segments: 6, rings: 4);
    final glow = UnlitMaterial()..baseColorFactor = vm.Vector4(9, 8.2, 2.2, 1);
    _mesh = InstancedMesh(geometry: bead.build(), material: glow);
    final (px, pz) = AmbientLayout.pond;
    final haunts = <(P2, double)>[((px, pz), 11), ((16, 16), 7), ((-2, 16), 9), ((12, 22), 8), ((-12, -12), 8)];
    for (var i = 0; i < count; i++) {
      final (c, spread) = haunts[i % haunts.length];
      final a = r.nextDouble() * 2 * math.pi, d = math.sqrt(r.nextDouble()) * spread;
      final x = c.$1 + math.cos(a) * d, z = c.$2 + math.sin(a) * d;
      final g = math.max(groundHeight(x, z), -0.25);
      _home.add(_v(x, g + 0.5 + r.nextDouble() * 1.4, z));
      _seed.add(r.nextDouble() * 100);
      _mesh.addInstance(_hidden);
    }
    scene.add(
      Node()
        ..addComponent(InstancedMeshComponent(_mesh))
        ..castsShadows = false,
    );
    _shown = count;
  }

  /// Shows [share] of the fireflies.
  set share(double share) => _shown = (count * share).round();

  void update(double wall, {required double night}) {
    if (night < 0.05) {
      if (!_hiddenAll) {
        _mesh.updateInstanceTransforms((list) {
          for (final m in list) {
            m.setFrom(_hidden);
          }
        }, recomputeWinding: false);
        _hiddenAll = true;
      }
      return;
    }
    _hiddenAll = false;
    _mesh.updateInstanceTransforms((list) {
      for (var i = 0; i < list.length; i++) {
        if (i >= _shown) {
          list[i].setFrom(_hidden);
          continue;
        }
        final s = _seed[i], t = wall * 0.35 + s;
        final h = _home[i];
        final p = _v(
          h.x + math.sin(t * 0.9) * 1.4 + math.sin(t * 2.3) * 0.3,
          h.y + math.sin(t * 1.3 + s) * 0.35,
          h.z + math.cos(t * 0.7) * 1.4 + math.cos(t * 1.9) * 0.3,
        );
        // Each one blinks on for a moment every few seconds.
        final cycle = (wall / (2.6 + (s % 1.7)) + s) % 1.0;
        final blink = cycle < 0.35 ? math.sin(cycle / 0.35 * math.pi) : 0.0;
        final size = night * (0.45 + 0.85 * blink);
        list[i]
          ..setFrom(vm.Matrix4.translation(p))
          ..scaleByDouble(size, size, size, 1);
      }
    }, recomputeWinding: false);
  }
}

/// A few leaves drifting down from the round trees by day; a storm tears
/// more loose and blows them sideways.
class FallingLeaves {
  FallingLeaves(this.scene, this.crowns, {this.count = 36});
  final Scene scene;
  final List<(vm.Vector3, double)> crowns;
  final int count;

  late final InstancedMesh _mesh;
  final List<vm.Vector3> _pos = [];
  final List<double> _spin = [], _rest = [];
  final math.Random _rng = math.Random(13);
  int _shown = 0;

  void build() {
    final leaf = MeshBuilder()
      ..triangle(_v(-0.07, 0, 0), _v(0, 0, 0.12), _v(0.07, 0, 0), rgb(0xFFFFFF))
      ..triangle(_v(-0.07, 0, 0), _v(0.07, 0, 0), _v(0, 0, -0.07), rgb(0xFFFFFF));
    final material = pbr(rough: 0.8)..doubleSided = true;
    _mesh = InstancedMesh(geometry: leaf.build(), material: material);
    final tints = [rgb(0xE8A23A), rgb(0xD9622B), rgb(0xF2C94C), rgb(0x8DBA4A), rgb(0xC0472D)];
    for (var i = 0; i < count; i++) {
      final t = tints[i % tints.length];
      _mesh.addInstance(_hidden, color: vm.Vector4(t.x, t.y, t.z, 1));
      _pos.add(vm.Vector3.zero());
      _spin.add(_rng.nextDouble() * 6);
      _rest.add(-1 - _rng.nextDouble() * 8);
    }
    scene.add(
      Node()
        ..addComponent(InstancedMeshComponent(_mesh))
        ..castsShadows = false,
    );
    _shown = crowns.isEmpty ? 0 : count;
  }

  set share(double share) => _shown = crowns.isEmpty ? 0 : (count * share).round();

  void _respawn(int i) {
    final (c, r) = crowns[_rng.nextInt(crowns.length)];
    final a = _rng.nextDouble() * 2 * math.pi;
    _pos[i].setValues(c.x + math.cos(a) * r * 0.8, c.y - r * 0.3, c.z + math.sin(a) * r * 0.8);
    _rest[i] = 0;
  }

  void update(double wall, double dt, {required double day, required double storm}) {
    final wind = 0.3 + storm * 3.5;
    _mesh.updateInstanceTransforms((list) {
      for (var i = 0; i < list.length; i++) {
        if (i >= _shown || day < 0.3) {
          list[i].setFrom(_hidden);
          continue;
        }
        final p = _pos[i];
        if (_rest[i] < 0) {
          // Waiting its turn to fall; a storm shortens the wait.
          _rest[i] += dt * (1 + storm * 4);
          if (_rest[i] >= 0) _respawn(i);
          list[i].setFrom(_hidden);
          continue;
        }
        final ground = math.max(groundHeight(p.x, p.z), pondSurface) + 0.02;
        if (p.y > ground) {
          final s = _spin[i] + wall;
          p
            ..x += (math.sin(s * 1.7) * 0.5 + wind) * dt
            ..z += math.cos(s * 1.3) * 0.4 * dt
            ..y = math.max(ground, p.y - (0.55 + storm * 1.2) * dt);
          list[i]
            ..setFrom(vm.Matrix4.translation(p))
            ..rotateY(s * 1.1)
            ..rotateX(math.sin(s * 2.3) * 1.1)
            ..rotateZ(math.cos(s * 1.9) * 0.8);
        } else {
          // Lies on the grass for a while, then goes round again.
          _rest[i] += dt;
          if (_rest[i] > 4) _rest[i] = -2 - _rng.nextDouble() * 10;
          list[i]
            ..setFrom(vm.Matrix4.translation(p))
            ..rotateY(_spin[i]);
        }
      }
    }, recomputeWinding: false);
  }
}

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Water surface height of the pond, where the ducks float.
const double pondSurface = -0.27;

/// The pond: a glossy disc whose ripples are two tiling normal maps (the
/// base layer and a clear coat) scrolling different ways, so the
/// reflections shimmer without any per-vertex work.
class PondWater {
  PondWater(this.scene, this.centre, this.radius);
  final Scene scene;
  final vm.Vector2 centre;
  final double radius;

  late final PhysicallyBasedMaterial material;
  double _t = 0;

  void build(double y) {
    final (ripples, shimmer) = _rippleTextures(128);
    material = PhysicallyBasedMaterial(normalTexture: ripples, baseColorTexture: shimmer)
      ..baseColorFactor = vm.Vector4(1, 1, 1, 1)
      ..metallicFactor = 0
      ..roughnessFactor = 0.05
      ..normalScale = 0.8
      ..clearcoat = 1
      ..clearcoatRoughness = 0.03
      ..clearcoatNormalTexture = ripples
      ..clearcoatNormalScale = vm.Vector2.all(0.3);
    scene.add(
      Node(mesh: Mesh(_disc(radius, 48), material), localTransform: vm.Matrix4.translation(vm.Vector3(centre.x, y, centre.y)))
        ..castsShadows = false,
    );
  }

  /// Scrolls the ripples; [wind] (0-1) chops them up in a storm.
  void update(double dt, {double wind = 0}) {
    _t += dt * (1 + wind * 2.5);
    final scale = vm.Vector2.all(0.36);
    final base = TextureTransform(offset: vm.Vector2(_t * 0.021, _t * 0.013), scale: scale);
    material
      ..normalTextureTransform = base
      ..baseColorTextureTransform = base
      ..clearcoatNormalTextureTransform = TextureTransform(offset: vm.Vector2(-_t * 0.017, _t * 0.024), scale: scale * 1.6, rotation: 0.7)
      ..normalScale = 0.8 + wind * 0.6
      ..roughnessFactor = 0.05 + wind * 0.08;
  }

  static MeshGeometry _disc(double r, int segments) {
    final pos = <double>[0, 0, 0], uv = <double>[0, 0];
    for (var i = 0; i < segments; i++) {
      final a = 2 * math.pi * i / segments;
      final x = math.cos(a) * r, z = math.sin(a) * r;
      pos.addAll([x, 0, z]);
      // World-scale UVs, so the ripples tile at a fixed size.
      uv.addAll([x, z]);
    }
    final count = segments + 1;
    final idx = <int>[];
    for (var i = 0; i < segments; i++) {
      idx.addAll([0, 1 + (i + 1) % segments, 1 + i]);
    }
    return MeshGeometry.fromArrays(
      positions: Float32List.fromList(pos),
      normals: Float32List.fromList([
        for (var i = 0; i < count; i++) ...[0.0, 1.0, 0.0],
      ]),
      texCoords: Float32List.fromList(uv),
      tangents: Float32List.fromList([
        for (var i = 0; i < count; i++) ...[1.0, 0.0, 0.0, 1.0],
      ]),
      // Deeper and darker in the middle, a shallow teal at the shore.
      colors: Float32List.fromList([
        0.55,
        0.62,
        0.7,
        1.0,
        for (var i = 1; i < count; i++) ...[1.25, 1.3, 1.15, 1.0],
      ]),
      indices: idx,
    );
  }

  /// A tiling normal map from a few crossing sine swells, and a matching
  /// water colour that is lighter on the crests, so the ripples show even
  /// where the reflected sky is plain.
  static (Texture2D, Texture2D) _rippleTextures(int n) {
    const waves = <(int, int, double)>[(3, 1, 1.0), (-2, 3, 0.7), (5, -4, 0.35), (1, 7, 0.25), (-7, -2, 0.2)];
    final normals = Uint8List(n * n * 4), colors = Uint8List(n * n * 4);
    const deep = (0.07, 0.26, 0.34), crest = (0.2, 0.47, 0.52);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        var dx = 0.0, dy = 0.0, h = 0.0;
        for (final (fx, fy, amp) in waves) {
          final phase = 2 * math.pi * (fx * x + fy * y) / n + fx * 0.7;
          final c = math.cos(phase) * amp;
          h += math.sin(phase) * amp;
          dx += c * fx;
          dy += c * fy;
        }
        final nrm = vm.Vector3(-dx * 0.05, -dy * 0.05, 1)..normalize();
        final o = (y * n + x) * 4;
        normals[o] = ((nrm.x * 0.5 + 0.5) * 255).round();
        normals[o + 1] = ((nrm.y * 0.5 + 0.5) * 255).round();
        normals[o + 2] = ((nrm.z * 0.5 + 0.5) * 255).round();
        normals[o + 3] = 255;
        final k = math.pow(((h + 2.5) / 5).clamp(0.0, 1.0), 2.2).toDouble();
        int srgb(double a, double b) => (math.pow(a + (b - a) * k, 1 / 2.2) * 255).round().clamp(0, 255);
        colors[o] = srgb(deep.$1, crest.$1);
        colors[o + 1] = srgb(deep.$2, crest.$2);
        colors[o + 2] = srgb(deep.$3, crest.$3);
        colors[o + 3] = 255;
      }
    }
    return (Texture2D.fromPixels(normals, n, n, content: TextureContent.normal), Texture2D.fromPixels(colors, n, n));
  }
}

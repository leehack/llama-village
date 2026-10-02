import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'look.dart';
import 'mesh_builder.dart';

vm.Vector3 _v(double x, double y, double z) => vm.Vector3(x, y, z);

/// The festival's stage props: a warm spotlight on centre stage (a spot
/// light, a soft beam and a bright pool on the boards) and the Golden
/// Bell. Built once and hidden; the festival scene shows and moves them.
class FestivalProps {
  FestivalProps(this.scene);
  final Scene scene;

  static const double _pool = 1.25;

  // A registered spot light is shaded wherever its range reaches, lit or
  // not, so while off it waits far below the island where light culling
  // drops it.
  static final vm.Matrix4 _parked = vm.Matrix4.translation(_v(0, -500, 0));

  final SpotLight _light = SpotLight(color: _v(1.0, 0.82, 0.55), intensity: 0, range: 16, innerConeAngle: 0.08, outerConeAngle: 0.18);
  late final Node _lamp;
  late final Node _beam, _disc, _bell;
  late final UnlitMaterial _beamGlow, _discGlow;
  double _lit = -1;

  void build() {
    // Nested cones draw a beam that is brighter in its core.
    final beam = MeshBuilder();
    for (final k in [1.0, 0.72, 0.45]) {
      beam.cone(_v(0, 0, 0), _pool * k, 0.12 * k, 1, rgb(0xFFFFFF), segments: 20);
    }
    _beamGlow = UnlitMaterial()..alphaMode = AlphaMode.blend;
    _beam = Node(mesh: Mesh(beam.build(), _beamGlow))
      ..castsShadows = false
      ..visible = false;
    final disc = MeshBuilder();
    for (final k in [1.0, 0.7, 0.42]) {
      disc.cylinder(_v(0, 0.012 + 0.002 * k, 0), _pool * k, 0.004, 1, rgb(0xFFFFFF), segments: 24);
    }
    _discGlow = UnlitMaterial()..alphaMode = AlphaMode.blend;
    _disc = Node(mesh: Mesh(disc.build(), _discGlow))
      ..castsShadows = false
      ..visible = false;
    _lamp = Node(localTransform: _parked)..addComponent(SpotLightComponent(_light));
    _bell = Node(mesh: Mesh(_bellMesh(), _gold()))..visible = false;
    scene
      ..add(_beam)
      ..add(_disc)
      ..add(_lamp)
      ..add(_bell);
  }

  /// A hand bell hanging from its handle at the origin, mouth down.
  static MeshGeometry _bellMesh() {
    final gold = rgb(0xF4C64F), deep = rgb(0xC99A2E), clapper = rgb(0x8C6A28);
    return (MeshBuilder()
          ..cylinder(_v(0, -0.02, 0), 0.025, 0.1, 1, deep, segments: 6)
          ..sphere(_v(0, -0.1, 0), _v(0.125, 0.085, 0.125), gold, segments: 14, rings: 8)
          ..cone(_v(0, -0.38, 0), 0.215, 0.118, 0.29, gold, segments: 18)
          ..cylinder(_v(0, -0.385, 0), 0.232, 0.04, 1, deep, segments: 18)
          ..sphere(_v(0, -0.42, 0), _v(0.05, 0.05, 0.05), clapper, segments: 8, rings: 5))
        .build();
  }

  static PhysicallyBasedMaterial _gold() =>
      pbr(rough: 0.26, metal: 1, emissive: _v(1.0, 0.72, 0.28), emissiveStrength: 0.35)..baseColorFactor = vm.Vector4(1, 0.92, 0.75, 1);

  /// The spotlight at [level] (0 is off) on the stage at [pool], hung
  /// above and in front of it toward [front].
  void spotlight(double level, vm.Vector3 pool, vm.Vector3 front) {
    final on = level > 0.001;
    _beam.visible = on;
    _disc.visible = on;
    if (!on) {
      if (_lit != 0) {
        _light.intensity = 0;
        _lamp.localTransform = _parked;
      }
      _lit = 0;
      return;
    }
    final lamp = pool + front * 3.0 + _v(0, 7.2, 0);
    final axis = (lamp - pool)..normalize();
    final along = (lamp - pool).length;
    _lamp.localTransform = vm.Matrix4.translation(lamp);
    _light
      ..direction = -axis
      ..intensity = 170 * level;
    // The beam stands on the pool and leans toward the lamp.
    final tilt = vm.Quaternion.fromTwoVectors(_v(0, 1, 0), axis);
    _beam.localTransform = vm.Matrix4.compose(pool, tilt, _v(1, along * 0.96, 1));
    _disc.localTransform = vm.Matrix4.translation(pool);
    if ((level - _lit).abs() > 0.002) {
      _beamGlow.baseColorFactor = vm.Vector4(1.6, 1.25, 0.75, 0.045 * level);
      _discGlow.baseColorFactor = vm.Vector4(2.2, 1.75, 1.0, 0.16 * level);
      _lit = level;
    }
  }

  /// The Golden Bell at [scale] (0 hides it) hanging from [at], swinging
  /// [swing] radians across [front].
  void bell(double scale, vm.Vector3 at, vm.Vector3 front, double swing) {
    _bell.visible = scale > 0.001;
    if (!_bell.visible) return;
    final across = math.atan2(front.x, front.z);
    _bell.localTransform = vm.Matrix4.translation(at)
      ..rotateY(across)
      ..rotateZ(swing)
      ..scaleByDouble(scale, scale, scale, 1);
  }

  void hide() {
    spotlight(0, vm.Vector3.zero(), vm.Vector3.zero());
    _bell.visible = false;
  }
}

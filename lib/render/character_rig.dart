import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// A bone the game drives itself (the clips never key it): look-at, lids,
/// ears, tail, breathing. Turns are given in the model's frame (Y up, the
/// character facing -Z) and applied on top of the bone's rest pose.
class ProceduralBone {
  ProceduralBone._(this.node, Node model) : _rest = node.localTransform.clone() {
    var m = node.localTransform.clone();
    for (var p = node.parent; p != null && p != model; p = p.parent) {
      m = p.localTransform.multiplied(m);
    }
    m.decompose(vm.Vector3.zero(), _frame, vm.Vector3.zero());
    _frameInverse = _frame.conjugated();
  }

  /// The bone called [name] under [model], read while it is in its rest pose.
  static ProceduralBone? find(Node model, String name) {
    final n = model.getChildByName(name);
    return n == null ? null : ProceduralBone._(n, model);
  }

  final Node node;
  final vm.Matrix4 _rest;
  final vm.Quaternion _frame = vm.Quaternion.identity();
  late final vm.Quaternion _frameInverse;

  /// Turns the bone by [q] (model frame) and scales it uniformly.
  void turn(vm.Quaternion q, {double scale = 1}) {
    final local = _frameInverse * q * _frame;
    node.localTransform = _rest.multiplied(vm.Matrix4.compose(vm.Vector3.zero(), local, vm.Vector3.all(scale)));
  }

  /// Turns the bone by [angle] radians about its own Y axis, which runs
  /// along the bone (the lids' hinge).
  void turnAboutOwnAxis(double angle) {
    node.localTransform = _rest.multiplied(vm.Matrix4.rotationY(angle));
  }
}

/// Yaw about +Y, then pitch about +X, as one model-frame rotation.
vm.Quaternion yawPitch(double yaw, double pitch, [double roll = 0]) =>
    vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), yaw) *
    vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), pitch) *
    vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), roll);

/// Index of each of [names] among [node]'s (or its mesh descendants')
/// morph targets, as (node, index) pairs per name.
Map<String, List<(Node, int)>> morphSlots(Node model, List<String> names) {
  final out = {for (final n in names) n: <(Node, int)>[]};
  for (final node in [model, ...model.meshNodes]) {
    final targets = node.morphTargetNames;
    for (final n in names) {
      final i = targets.indexOf(n);
      if (i >= 0) out[n]!.add((node, i));
    }
  }
  return out;
}

/// Swaps the plain glTF materials of a character for tuned PBR ones, by
/// material name. Colours come from the meshes' vertex colours; [sheen] is
/// the soft-fuzz colour for wool or feathers.
void tuneCharacter(Node model, {required vm.Vector3 sheen}) {
  final made = <String, PhysicallyBasedMaterial>{};
  for (final node in model.meshNodes) {
    for (final prim in node.mesh!.primitives) {
      final src = prim.material;
      if (src is! PhysicallyBasedMaterial) continue;
      prim.material = made.putIfAbsent(src.name, () => _tuned(src.name, sheen));
    }
  }
}

PhysicallyBasedMaterial _tuned(String name, vm.Vector3 sheen) {
  final m = PhysicallyBasedMaterial()
    ..name = name
    ..baseColorFactor = vm.Vector4(1, 1, 1, 1)
    ..metallicFactor = 0
    ..roughnessFactor = 0.8;
  void withSheen(vm.Vector3 c, double roughness) => m
    ..sheenColor = vm.Vector4(c.x, c.y, c.z, 1)
    ..sheenRoughness = roughness;
  switch (name) {
    case 'Wool':
      // A broad, bright sheen reads as fuzz catching the light at the
      // silhouette, which is what makes wool look soft.
      m.roughnessFactor = 0.93;
      withSheen(sheen * 1.15 + vm.Vector3.all(0.07), 0.55);
    case 'Feather':
      m
        ..roughnessFactor = 0.5
        ..clearcoat = 0.25
        ..clearcoatRoughness = 0.35;
      withSheen(sheen * 1.2 + vm.Vector3.all(0.08), 0.45);
    case 'Cloth':
      m.roughnessFactor = 0.86;
      withSheen(vm.Vector3.all(0.32), 0.5);
    case 'Face':
      m.roughnessFactor = 0.72;
      withSheen(vm.Vector3.all(0.18), 0.5);
    case 'EyeGloss':
      m
        ..roughnessFactor = 0.12
        ..clearcoat = 1
        ..clearcoatRoughness = 0.03;
    case 'EyeShine':
      m
        ..roughnessFactor = 0.1
        ..emissiveFactor = vm.Vector4(1, 1, 1, 1)
        ..emissiveStrength = 2.2;
    case 'Gloss':
      m
        ..roughnessFactor = 0.22
        ..clearcoat = 0.8
        ..clearcoatRoughness = 0.08;
    case 'Hoof':
      m
        ..roughnessFactor = 0.38
        ..clearcoat = 0.5
        ..clearcoatRoughness = 0.12;
  }
  return m;
}

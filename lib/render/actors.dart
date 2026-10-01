import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'look.dart';
import 'mesh_builder.dart';

export 'dash_actor.dart';
export 'llama_actor.dart';

/// A soft ring marking the selected llama.
MeshGeometry selectionRing() {
  final b = MeshBuilder();
  const n = 28;
  for (var i = 0; i < n; i++) {
    final a = 2 * math.pi * i / n;
    b.box(vm.Vector3(math.cos(a) * 1.25, 0.04, math.sin(a) * 1.25), vm.Vector3(0.22, 0.05, 0.1), rgb(0xFFF2B0), yaw: -a + math.pi / 2);
  }
  return b.build();
}

/// Material for the selection ring: bright enough to read at night.
PhysicallyBasedMaterial ringMaterial() => pbr(rough: 0.5, emissive: vm.Vector3(1, 0.9, 0.5), emissiveStrength: 1.6);

/// Height of one rain curtain.
const double rainHeight = 26;

/// A slab of falling rain streaks over the village.
MeshGeometry rainCurtain() {
  final r = math.Random(5);
  final b = MeshBuilder();
  final c = rgb(0xDCE8F5);
  for (var i = 0; i < 900; i++) {
    final x = (r.nextDouble() - 0.5) * 100, z = (r.nextDouble() - 0.5) * 100;
    b.box(vm.Vector3(x + 0.0, r.nextDouble() * rainHeight, z), vm.Vector3(0.03, 0.7, 0.03), c);
  }
  return b.build();
}

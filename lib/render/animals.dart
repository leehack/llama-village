import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../ambient/creatures.dart';
import '../sim/geo.dart';
import 'look.dart';
import 'mesh_builder.dart';
import 'quality.dart';
import 'water.dart';

vm.Vector3 _v(double x, double y, double z) => vm.Vector3(x, y, z);

/// One body part shared by every animal of a species: a single instanced
/// draw, posed per instance each frame.
class _Part {
  _Part(MeshGeometry geometry, Material material, List<vm.Vector4> tints) : mesh = InstancedMesh(geometry: geometry, material: material) {
    for (final t in tints) {
      mesh.addInstance(_hidden, color: t);
    }
    node = Node()..addComponent(InstancedMeshComponent(mesh));
  }

  final InstancedMesh mesh;
  late final Node node;

  static final vm.Matrix4 _hidden = vm.Matrix4.translation(_v(0, -60, 0))..scaleByDouble(0.001, 0.001, 0.001, 1);

  void hide(int i) => mesh.setInstanceTransform(i, _hidden);
}

/// Low-poly cats, chickens, ducks, a dog and butterflies, drawn from an
/// [AmbientLife] with a few instanced draws per species and animated
/// procedurally: walk cycles from limb swings, pecks, tail sways, bobbing.
class AnimalActors {
  AnimalActors(this.scene, this.life);
  final Scene scene;
  final AmbientLife life;

  final Map<Species, List<Creature>> _bySpecies = {};
  final Map<Species, Map<String, _Part>> _parts = {};
  late final _Part _wings;
  final List<Node> _nodes = [];
  final PhysicallyBasedMaterial _fur = pbr(rough: 0.88)
    ..sheenColor = vm.Vector4(0.9, 0.85, 0.8, 1)
    ..sheenRoughness = 0.55;
  final PhysicallyBasedMaterial _feathers = pbr(rough: 0.7);
  final PhysicallyBasedMaterial _wingMaterial = pbr(rough: 0.6)..doubleSided = true;

  void build() {
    for (final s in Species.values) {
      _bySpecies[s] = life.of(s).toList();
    }
    final cats = _bySpecies[Species.cat]!.length;
    final catTints = [for (var i = 0; i < cats; i++) _catTints[i % _catTints.length]];
    _species(Species.cat, _fur, {
      'body': (_catBody(), catTints),
      'head': (_catHead(), catTints),
      'tail': (_catTail(), catTints),
      'leg': (_catLeg(), [for (final t in catTints) ...List.filled(4, t)]),
    });
    final hens = _bySpecies[Species.chicken]!.length;
    final henTints = [for (var i = 0; i < hens; i++) _henTints[i % _henTints.length]];
    _species(Species.chicken, _feathers, {
      'body': (_henBody(), henTints),
      'head': (_henHead(), henTints),
      'wing': (_henWing(), [for (final t in henTints) ...List.filled(2, t)]),
      'leg': (_henLeg(), List.filled(hens * 2, _white)),
    });
    final ducks = _bySpecies[Species.duck]!.length;
    final duckTints = [for (var i = 0; i < ducks; i++) _duckTints[i % _duckTints.length]];
    _species(Species.duck, _feathers, {'body': (_duckBody(), duckTints), 'head': (_duckHead(), duckTints)});
    final dogs = _bySpecies[Species.dog]!.length;
    if (dogs > 0) {
      final dogTints = List.filled(dogs, _white);
      _species(Species.dog, _fur, {
        'body': (_dogBody(), dogTints),
        'head': (_dogHead(), dogTints),
        'tail': (_dogTail(), dogTints),
        'leg': (_dogLeg(), List.filled(dogs * 4, _white)),
      });
    }
    _wings = _Part(_butterflyWing(), _wingMaterial, [
      for (var i = 0; i < life.butterflies.length; i++) ...List.filled(2, _butterflyTints[i % _butterflyTints.length]),
    ]);
    _wings.node.castsShadows = false;
    _nodes.add(_wings.node);
    scene.add(_wings.node);
  }

  void _species(Species s, Material m, Map<String, (MeshGeometry, List<vm.Vector4>)> parts) {
    if (_bySpecies[s]!.isEmpty) return;
    final made = <String, _Part>{};
    for (final MapEntry(key: name, value: (g, tints)) in parts.entries) {
      final p = _Part(g, m, tints);
      made[name] = p;
      _nodes.add(p.node);
      scene.add(p.node);
    }
    _parts[s] = made;
  }

  set quality(GraphicsQuality q) {
    for (final n in _nodes) {
      n.castsShadows = q.animalShadows && n != _wings.node;
    }
  }

  void update(double wall) {
    _poseCats(wall);
    _poseHens(wall);
    _poseDucks(wall);
    _poseDogs(wall);
    _poseButterflies(wall);
  }

  static vm.Matrix4 _base(Creature c, double scale, {double? y}) {
    final ground = y ?? groundHeight(c.pos.$1, c.pos.$2) + c.lift;
    return vm.Matrix4.translation(_v(c.pos.$1, ground, c.pos.$2))
      ..rotateY(c.heading)
      ..scaleByDouble(scale, scale, scale, 1);
  }

  static vm.Matrix4 _at(vm.Matrix4 parent, vm.Vector3 pivot, {double rx = 0, double ry = 0, double rz = 0}) {
    final m = parent.clone()..translateByVector3(pivot);
    if (ry != 0) m.rotateY(ry);
    if (rx != 0) m.rotateX(rx);
    if (rz != 0) m.rotateZ(rz);
    return m;
  }

  // ------------------------------------------------------------ cats

  void _poseCats(double wall) {
    final parts = _parts[Species.cat];
    if (parts == null) return;
    final cats = _bySpecies[Species.cat]!;
    for (var i = 0; i < cats.length; i++) {
      final c = cats[i];
      final ph = wall * 1.3 + i * 2.1;
      var bodyY = 0.0, pitch = 0.0, headPitch = 0.0, headYaw = 0.0, tailYaw = 0.35 * math.sin(ph * 1.6), tailPitch = 0.0;
      var legSwing = 0.0, fold = 0.0, frontFold = 0.0, raise = 0.0;
      final gait = c.stride * (c.speed > 2 ? 2.4 : 3.2);
      switch (c.act) {
        case Act.walk || Act.run || Act.flee || Act.chase:
          final fast = c.speed > 2;
          legSwing = fast ? 0.85 : 0.55;
          bodyY = (fast ? 0.035 : 0.015) * math.sin(gait * 2).abs();
          tailPitch = fast ? 0.9 : 0.2;
          headPitch = c.act == Act.chase ? -0.15 : 0.05 * math.sin(gait * 2);
        case Act.sit || Act.perch || Act.idle:
          pitch = -0.5;
          fold = -0.9;
          bodyY = -0.02;
          headPitch = -0.05 + 0.08 * math.sin(ph * 0.7);
          headYaw = 0.5 * math.sin(ph * 0.31);
          tailYaw = 1.5 + 0.25 * math.sin(ph * 1.3);
        case Act.groom:
          pitch = -0.5;
          fold = -0.9;
          headPitch = 0.6 + 0.2 * math.sin(ph * 7);
          headYaw = 0.45;
          raise = 1.1 + 0.25 * math.sin(ph * 7);
          tailYaw = 1.4;
        case Act.nap || Act.sleep:
          bodyY = -0.1 + 0.006 * math.sin(ph * 1.4);
          fold = -1.45;
          frontFold = -1.45;
          headPitch = 0.6;
          headYaw = 0.7;
          tailYaw = 2.3;
          tailPitch = -0.9;
        case Act.hide:
          bodyY = -0.07;
          fold = -1.2;
          frontFold = -1.0;
          headPitch = 0.15;
          tailYaw = 2.0;
          tailPitch = -0.8;
        case Act.climb || Act.hop:
          pitch = -0.25;
          legSwing = 0;
          fold = 0.7;
          frontFold = -0.9;
          tailPitch = 1.0;
        default:
          break;
      }
      final base = _base(c, 1.35);
      final body = _at(base, _v(0, bodyY, 0))
        ..translateByVector3(_v(0, 0.2, -0.17))
        ..rotateX(pitch)
        ..translateByVector3(_v(0, -0.2, 0.17));
      parts['body']!.mesh.setInstanceTransform(i, body);
      parts['head']!.mesh.setInstanceTransform(i, _at(body, _v(0, 0.33, 0.21), ry: headYaw, rx: headPitch - pitch));
      parts['tail']!.mesh.setInstanceTransform(i, _at(body, _v(0, 0.3, -0.24), ry: tailYaw, rx: -tailPitch));
      for (var k = 0; k < 4; k++) {
        final front = k < 2, left = k.isEven;
        final swing = legSwing * math.sin(gait + (front ? 0 : math.pi) + (left ? 0 : math.pi * 0.5));
        var rx = swing + (front ? frontFold - pitch : fold);
        if (front && left && raise > 0) rx = -raise;
        final leg = _at(body, _v(left ? 0.075 : -0.075, 0.2, front ? 0.15 : -0.15), rx: rx);
        parts['leg']!.mesh.setInstanceTransform(i * 4 + k, leg);
      }
    }
  }

  // ------------------------------------------------------------ chickens

  void _poseHens(double wall) {
    final parts = _parts[Species.chicken];
    if (parts == null) return;
    final hens = _bySpecies[Species.chicken]!;
    for (var i = 0; i < hens.length; i++) {
      final c = hens[i];
      if (!c.visible) {
        for (final p in parts.values) {
          p.hide(i);
        }
        for (final k in [0, 1]) {
          parts['wing']!.hide(i * 2 + k);
          parts['leg']!.hide(i * 2 + k);
        }
        continue;
      }
      final ph = wall + i * 1.7;
      var pitch = 0.0, headPitch = 0.0, wing = 0.05, legSwing = 0.0, bodyY = 0.0;
      final gait = c.stride * 7;
      switch (c.act) {
        case Act.peck:
          // Quick jabs at the ground in bursts.
          final burst = math.sin(ph * 1.3) > 0;
          final jab = burst ? math.max(0.0, math.sin(ph * 11)) : 0.0;
          pitch = 0.25 + 0.1 * jab;
          headPitch = 0.2 + 0.9 * jab;
        case Act.flutter:
          wing = 0.6 + 0.6 * math.sin(ph * 40);
          legSwing = 0.8;
          pitch = -0.15;
        case Act.walk || Act.run:
          legSwing = 0.7;
          bodyY = 0.012 * math.sin(gait * 2).abs();
          headPitch = 0.15 * math.sin(gait * 2);
        default:
          headPitch = 0.1 * math.sin(ph * 0.9);
      }
      final base = _base(c, 1.25);
      final body = _at(base, _v(0, 0.12 + bodyY, 0), rx: pitch);
      parts['body']!.mesh.setInstanceTransform(i, body);
      parts['head']!.mesh.setInstanceTransform(
        i,
        _at(body, _v(0, 0.14, 0.1), rx: headPitch, ry: c.act == Act.idle ? 0.6 * math.sin(ph * 0.8) : 0),
      );
      for (final k in [0, 1]) {
        final s = k == 0 ? 1.0 : -1.0;
        parts['wing']!.mesh.setInstanceTransform(i * 2 + k, _at(body, _v(0.1 * s, 0.07, 0.0), rz: s * wing));
        parts['leg']!.mesh.setInstanceTransform(
          i * 2 + k,
          _at(base, _v(0.045 * s, 0.13, 0), rx: legSwing * math.sin(gait + k * math.pi) - pitch * 0.3),
        );
      }
    }
  }

  // ------------------------------------------------------------ ducks

  void _poseDucks(double wall) {
    final parts = _parts[Species.duck];
    if (parts == null) return;
    final ducks = _bySpecies[Species.duck]!;
    for (var i = 0; i < ducks.length; i++) {
      final c = ducks[i];
      final ph = wall + i * 2.3;
      final bob = 0.012 * math.sin(ph * 2.1);
      var pitch = 0.025 * math.sin(ph * 1.7), headPitch = 0.0, headYaw = 0.0, roll = 0.02 * math.sin(ph * 1.3);
      switch (c.act) {
        case Act.dabble:
          final k = math.min(1.0, c.time * 4) * math.min(1.0, (c.until - c.time) * 4).clamp(0.0, 1.0);
          pitch = 1.25 * k;
          headPitch = 0.6 * k;
        case Act.sleep || Act.hide:
          headPitch = 0.35;
          headYaw = 2.4;
        case Act.paddle || Act.run:
          pitch = -0.05;
          headPitch = 0.1 * math.sin(ph * 4);
        default:
          headYaw = 0.5 * math.sin(ph * 0.4);
      }
      final base = _base(c, 1.3, y: pondSurface + bob);
      final body = _at(base, _v(0, 0, 0), rx: pitch, rz: roll);
      parts['body']!.mesh.setInstanceTransform(i, body);
      parts['head']!.mesh.setInstanceTransform(i, _at(body, _v(0, 0.13, 0.15), ry: headYaw, rx: headPitch));
    }
  }

  // ------------------------------------------------------------ the dog

  void _poseDogs(double wall) {
    final parts = _parts[Species.dog];
    if (parts == null) return;
    final dogs = _bySpecies[Species.dog]!;
    for (var i = 0; i < dogs.length; i++) {
      final c = dogs[i];
      if (!c.visible) {
        parts['body']!.hide(i);
        parts['head']!.hide(i);
        parts['tail']!.hide(i);
        for (var k = 0; k < 4; k++) {
          parts['leg']!.hide(i * 4 + k);
        }
        continue;
      }
      final ph = wall + i;
      var bodyY = 0.0, pitch = 0.0, headPitch = 0.0, headYaw = 0.0, legSwing = 0.0, fold = 0.0, frontFold = 0.0;
      var wag = 0.3 * math.sin(ph * 3), tailUp = 0.6;
      final gait = c.stride * (c.speed > 2.5 ? 2.0 : 2.6);
      switch (c.act) {
        case Act.walk || Act.run || Act.sniff || Act.follow when c.speed > 0:
          legSwing = c.speed > 2.5 ? 0.8 : 0.5;
          bodyY = 0.02 * math.sin(gait * 2).abs();
          wag = 0.6 * math.sin(ph * 14);
          tailUp = 0.9;
          headPitch = c.act == Act.sniff ? 0.55 + 0.1 * math.sin(ph * 9) : 0;
        case Act.follow:
          pitch = -0.45;
          fold = -1.0;
          wag = 0.8 * math.sin(ph * 16);
          headPitch = -0.2;
          tailUp = 0.2;
        case Act.sit:
          pitch = -0.45;
          fold = -1.0;
          headYaw = 0.4 * math.sin(ph * 0.4);
        case Act.lie || Act.sleep:
          bodyY = -0.2;
          fold = -1.5;
          frontFold = -1.45;
          headPitch = c.act == Act.sleep ? 0.35 : 0.1;
          headYaw = c.act == Act.sleep ? 0.5 : 0.3 * math.sin(ph * 0.3);
          wag = c.act == Act.sleep ? 0 : 0.2 * math.sin(ph * 2);
          tailUp = -0.4;
        default:
          break;
      }
      final base = _base(c, 1.25);
      final body = _at(base, _v(0, bodyY, 0))
        ..translateByVector3(_v(0, 0.3, -0.2))
        ..rotateX(pitch)
        ..translateByVector3(_v(0, -0.3, 0.2));
      parts['body']!.mesh.setInstanceTransform(i, body);
      parts['head']!.mesh.setInstanceTransform(i, _at(body, _v(0, 0.5, 0.3), ry: headYaw, rx: headPitch - pitch));
      parts['tail']!.mesh.setInstanceTransform(i, _at(body, _v(0, 0.46, -0.3), ry: wag, rx: -tailUp));
      for (var k = 0; k < 4; k++) {
        final front = k < 2, left = k.isEven;
        final swing = legSwing * math.sin(gait + (front ? 0 : math.pi) + (left ? 0 : math.pi * 0.5));
        final rx = swing + (front ? frontFold - pitch : fold);
        parts['leg']!.mesh.setInstanceTransform(i * 4 + k, _at(body, _v(left ? 0.1 : -0.1, 0.3, front ? 0.2 : -0.2), rx: rx));
      }
    }
  }

  // ------------------------------------------------------------ butterflies

  void _poseButterflies(double wall) {
    for (var i = 0; i < life.butterflies.length; i++) {
      final b = life.butterflies[i];
      if (!b.visible) {
        _wings
          ..hide(i * 2)
          ..hide(i * 2 + 1);
        continue;
      }
      final flap = 0.15 + 1.1 * (0.5 + 0.5 * math.sin(b.flap));
      final base = vm.Matrix4.translation(_v(b.pos.$1, groundHeight(b.pos.$1, b.pos.$2) + b.height, b.pos.$2))..rotateY(b.heading);
      _wings.mesh.setInstanceTransform(i * 2, _at(base, _v(0.01, 0, 0), rz: flap));
      _wings.mesh.setInstanceTransform(i * 2 + 1, _at(base, _v(-0.01, 0, 0), rz: -flap)..scaleByDouble(-1, 1, 1, 1));
    }
  }
}

final vm.Vector4 _white = vm.Vector4(1, 1, 1, 1);
final List<vm.Vector4> _catTints = [vm.Vector4(1.0, 0.6, 0.28, 1), vm.Vector4(0.42, 0.42, 0.47, 1), vm.Vector4(0.2, 0.18, 0.18, 1)];
final List<vm.Vector4> _henTints = [
  vm.Vector4(1, 1, 1, 1),
  vm.Vector4(0.82, 0.5, 0.26, 1),
  vm.Vector4(1, 0.93, 0.78, 1),
  vm.Vector4(0.55, 0.32, 0.18, 1),
];
final List<vm.Vector4> _duckTints = [vm.Vector4(1, 1, 1, 1), vm.Vector4(0.78, 0.66, 0.5, 1), vm.Vector4(1, 0.97, 0.88, 1)];
final List<vm.Vector4> _butterflyTints = [
  vm.Vector4(1.0, 0.82, 0.2, 1),
  vm.Vector4(1, 1, 1, 1),
  vm.Vector4(1.0, 0.5, 0.15, 1),
  vm.Vector4(0.45, 0.65, 1.0, 1),
  vm.Vector4(1.0, 0.6, 0.85, 1),
];

// ------------------------------------------------------------ models
// Each part is built facing +z around its pivot, in metres.

MeshGeometry _catBody() {
  final fur = rgb(0xF4F0EA), cream = rgb(0xFFF8EE, 1.15);
  return (MeshBuilder()
        ..sphere(_v(0, 0.27, -0.01), _v(0.12, 0.12, 0.24), fur, segments: 10, rings: 7)
        ..sphere(_v(0, 0.24, 0.1), _v(0.1, 0.1, 0.13), cream, segments: 8, rings: 6))
      .build();
}

MeshGeometry _catHead() {
  final fur = rgb(0xF4F0EA), cream = rgb(0xFFF8EE, 1.15), dark = rgb(0x1A1A1A, 0.2), pink = rgb(0xF2A0A8);
  final b = MeshBuilder()
    ..sphere(_v(0, 0.06, 0.06), _v(0.12, 0.105, 0.11), fur, segments: 10, rings: 7)
    ..sphere(_v(0, 0.025, 0.14), _v(0.06, 0.042, 0.04), cream, segments: 7, rings: 5)
    ..sphere(_v(0, 0.045, 0.175), _v(0.016, 0.012, 0.01), pink, segments: 5, rings: 3);
  for (final s in [-1.0, 1.0]) {
    b
      ..cone(_v(0.065 * s, 0.13, 0.04), 0.045, 0, 0.09, fur, segments: 4, yaw: math.pi / 4)
      ..sphere(_v(0.045 * s, 0.075, 0.155), _v(0.02, 0.024, 0.012), dark, segments: 6, rings: 4);
  }
  return b.build();
}

MeshGeometry _catTail() {
  final fur = rgb(0xF4F0EA);
  final b = MeshBuilder();
  for (var k = 0; k < 6; k++) {
    final t = k / 5;
    b.sphere(_v(0, 0.03 + t * 0.26, -0.03 - math.sin(t * 2.4) * 0.1), _v(0.034, 0.034, 0.034) * (1 - t * 0.25), fur, segments: 6, rings: 4);
  }
  return b.build();
}

MeshGeometry _catLeg() {
  final fur = rgb(0xF4F0EA), paw = rgb(0xFFF8EE, 1.1);
  return (MeshBuilder()
        ..cylinder(_v(0, -0.09, 0), 0.032, 0.18, 1, fur, segments: 6)
        ..sphere(_v(0, -0.18, 0.012), _v(0.038, 0.025, 0.045), paw, segments: 6, rings: 4))
      .build();
}

MeshGeometry _henBody() {
  final white = rgb(0xF7F3EA), tail = rgb(0xE9E2D2);
  final b = MeshBuilder()
    ..sphere(_v(0, 0.06, 0), _v(0.12, 0.12, 0.15), white, segments: 9, rings: 7)
    ..sphere(_v(0, 0.08, 0.1), _v(0.085, 0.1, 0.07), white, segments: 7, rings: 5);
  for (final (x, y, z) in const [(0.0, 0.17, -0.13), (0.04, 0.14, -0.14), (-0.04, 0.14, -0.14)]) {
    b.sphere(_v(x, y, z), _v(0.03, 0.08, 0.05), tail, segments: 6, rings: 4);
  }
  return b.build();
}

MeshGeometry _henHead() {
  final white = rgb(0xF7F3EA), red = rgb(0xD8343A), beak = rgb(0xF2A63B), dark = rgb(0x111111, 0.2);
  final b = MeshBuilder()
    ..sphere(_v(0, 0.05, 0.02), _v(0.062, 0.07, 0.065), white, segments: 8, rings: 6)
    ..box(_v(0, 0.045, 0.1), _v(0.035, 0.025, 0.05), beak)
    ..sphere(_v(0, 0.0, 0.07), _v(0.018, 0.03, 0.018), red, segments: 5, rings: 3);
  for (final (z, h) in const [(-0.01, 0.04), (0.02, 0.05), (0.05, 0.035)]) {
    b.box(_v(0, 0.12 + h / 2 - 0.02, z), _v(0.016, h, 0.026), red);
  }
  for (final s in [-1.0, 1.0]) {
    b.sphere(_v(0.05 * s, 0.065, 0.055), _v(0.012, 0.014, 0.01), dark, segments: 5, rings: 3);
  }
  return b.build();
}

MeshGeometry _henWing() => (MeshBuilder()..sphere(_v(0, -0.01, -0.02), _v(0.025, 0.07, 0.1), rgb(0xEEE8DA), segments: 7, rings: 5)).build();

MeshGeometry _henLeg() {
  final leg = rgb(0xF0A43A);
  return (MeshBuilder()
        ..cylinder(_v(0, -0.06, 0), 0.012, 0.12, 1, leg, segments: 5)
        ..box(_v(0, -0.125, 0.02), _v(0.05, 0.012, 0.06), leg))
      .build();
}

MeshGeometry _duckBody() {
  final white = rgb(0xF6F4EE), tail = rgb(0xEDEAE0);
  return (MeshBuilder()
        ..sphere(_v(0, 0.06, 0), _v(0.13, 0.09, 0.2), white, segments: 10, rings: 7)
        ..sphere(_v(0, 0.08, 0.1), _v(0.1, 0.08, 0.09), white, segments: 8, rings: 5)
        ..cone(_v(0, 0.06, -0.17), 0.05, 0, 0.12, tail, segments: 5))
      .build();
}

MeshGeometry _duckHead() {
  final white = rgb(0xF6F4EE), beak = rgb(0xF2A23A), dark = rgb(0x111111, 0.2);
  final b = MeshBuilder()
    ..cylinder(_v(0, 0.03, 0), 0.04, 0.08, 1, white, segments: 7)
    ..sphere(_v(0, 0.1, 0.025), _v(0.06, 0.06, 0.07), white, segments: 8, rings: 6)
    ..box(_v(0, 0.085, 0.105), _v(0.05, 0.022, 0.08), beak);
  for (final s in [-1.0, 1.0]) {
    b.sphere(_v(0.045 * s, 0.115, 0.06), _v(0.011, 0.013, 0.01), dark, segments: 5, rings: 3);
  }
  return b.build();
}

MeshGeometry _dogBody() {
  final coat = rgb(0xD9A56A), belly = rgb(0xF5E7D2);
  return (MeshBuilder()
        ..sphere(_v(0, 0.4, 0), _v(0.15, 0.15, 0.3), coat, segments: 10, rings: 7)
        ..sphere(_v(0, 0.36, 0.16), _v(0.12, 0.13, 0.14), belly, segments: 8, rings: 6))
      .build();
}

MeshGeometry _dogHead() {
  final coat = rgb(0xD9A56A), belly = rgb(0xF5E7D2), ear = rgb(0x8A5A33), dark = rgb(0x151515, 0.2);
  final b = MeshBuilder()
    ..sphere(_v(0, 0.07, 0.06), _v(0.12, 0.115, 0.12), coat, segments: 10, rings: 7)
    ..sphere(_v(0, 0.03, 0.17), _v(0.07, 0.06, 0.08), belly, segments: 8, rings: 5)
    ..sphere(_v(0, 0.06, 0.245), _v(0.03, 0.022, 0.018), dark, segments: 6, rings: 4);
  for (final s in [-1.0, 1.0]) {
    b
      ..sphere(_v(0.11 * s, 0.05, 0.04), _v(0.03, 0.09, 0.06), ear, segments: 6, rings: 5)
      ..sphere(_v(0.05 * s, 0.1, 0.16), _v(0.018, 0.02, 0.012), dark, segments: 5, rings: 3);
  }
  return b.build();
}

MeshGeometry _dogTail() => (MeshBuilder()..cylinder(_v(0, 0.0, -0.12), 0.03, 0.24, 2, rgb(0xD9A56A), segments: 6)).build();

MeshGeometry _dogLeg() {
  final coat = rgb(0xD9A56A), paw = rgb(0xF5E7D2);
  return (MeshBuilder()
        ..cylinder(_v(0, -0.14, 0), 0.042, 0.28, 1, coat, segments: 6)
        ..sphere(_v(0, -0.28, 0.015), _v(0.05, 0.03, 0.06), paw, segments: 6, rings: 4))
      .build();
}

MeshGeometry _butterflyWing() {
  final c = rgb(0xFFFFFF);
  return (MeshBuilder()
        ..box(_v(0.07, 0, 0.03), _v(0.12, 0.004, 0.1), c)
        ..box(_v(0.055, 0, -0.045), _v(0.09, 0.004, 0.07), c * 0.85))
      .build();
}

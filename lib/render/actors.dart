import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../sim/cast.dart';
import '../sim/dash.dart';
import '../sim/geo.dart';
import '../sim/village.dart';
import 'look.dart';
import 'mesh_builder.dart';
import 'world.dart';

/// Turns [hex] (sRGB) into a linear colour vector.
vm.Vector3 _lin(int hex) => rgb(hex);

double _ease(double from, double to, double rate, double dt) => from + (to - from) * math.min(1.0, dt * rate);

double _angleTo(double from, double to) => (to - from + math.pi) % (2 * math.pi) - math.pi;

/// One llama in the scene: the rigged model with its own tinted materials,
/// Idle and Gallop blended by speed, and simple activity poses.
class LlamaActor {
  LlamaActor._(this.name, this.root, this._idle, this._gallop, this._squint, this._wool, this._scarf)
    : _scarfColor = _scarf.baseColorFactor.clone(),
      _scarfSheen = _scarf.sheenColor.clone();

  final String name;
  final Node root;
  final AnimationClip? _idle, _gallop;
  final List<(Node, int)> _squint;
  final PhysicallyBasedMaterial _wool, _scarf;

  vm.Vector3 position = vm.Vector3.zero();
  double yaw = 0;
  double _gallopW = 0, _squintW = 0;
  bool _scarfShown = true;
  bool visible = true;

  /// Head height above [position], for bubbles and picking.
  static const double headHeight = 2.05;

  static Future<LlamaActor> load(String name) async {
    final model = await loadScene('assets/llama.glb');
    final (woolHex, accentHex) = llamaColors[name]!;
    late PhysicallyBasedMaterial wool, scarf;
    final made = <String, PhysicallyBasedMaterial>{};
    for (final node in model.meshNodes) {
      for (final prim in node.mesh!.primitives) {
        final src = prim.material;
        if (src is! PhysicallyBasedMaterial) continue;
        final m = made.putIfAbsent(src.name, () => _tuned(src, woolHex, accentHex));
        prim.material = m;
        if (src.name == 'Wool') wool = m;
        if (src.name == 'Scarf') scarf = m;
      }
    }
    for (final hidden in const ['Saddle', 'DashRider', 'Face_DashDetails']) {
      model.getChildByName(hidden)?.visible = false;
    }
    final squint = <(Node, int)>[];
    for (final n in [model, ...model.meshNodes]) {
      final i = n.morphTargetNames.indexOf('Squint');
      if (i >= 0) squint.add((n, i));
    }
    AnimationClip? clip(String clipName, double w) {
      final a = model.findAnimationByName(clipName);
      if (a == null) return null;
      return model.createAnimationClip(a)
        ..loop = true
        ..weight = w
        ..play();
    }

    final idle = clip('Idle', 1)?..playbackTimeScale = 0.8 + name.length * 0.05;
    final gallop = clip('Gallop', 0)?..playbackTimeScale = 1.4;
    final root = Node(name: name)..add(model);
    return LlamaActor._(name, root, idle, gallop, squint, wool, scarf);
  }

  static PhysicallyBasedMaterial _tuned(PhysicallyBasedMaterial src, int woolHex, int accentHex) {
    final m = PhysicallyBasedMaterial()
      ..name = src.name
      ..baseColorFactor = src.baseColorFactor.clone()
      ..roughnessFactor = 0.8
      ..metallicFactor = 0;
    void sheen(vm.Vector3 c) => m
      ..sheenColor = vm.Vector4(c.x, c.y, c.z, 1)
      ..sheenRoughness = 0.45;
    switch (src.name) {
      case 'Wool':
        final c = _lin(woolHex);
        m
          ..baseColorFactor = vm.Vector4(c.x, c.y, c.z, 1)
          ..roughnessFactor = 0.95;
        sheen(c * 1.05);
      case 'Scarf':
        final c = _lin(accentHex);
        m.baseColorFactor = vm.Vector4(c.x, c.y, c.z, 1);
        sheen(c * 1.2 + vm.Vector3.all(0.15));
      case 'Muzzle' || 'InnerEar':
        sheen(vm.Vector3(0.6, 0.55, 0.5));
      case 'EyeWhite' || 'EyeIris' || 'EyePupil':
        m
          ..roughnessFactor = 0.1
          ..clearcoat = 1
          ..clearcoatRoughness = 0.05;
      case 'EyeShine':
        final c = m.baseColorFactor;
        m
          ..roughnessFactor = 0.1
          ..emissiveFactor = vm.Vector4(c.x, c.y, c.z, 1)
          ..emissiveStrength = 2.5;
      case 'Hoof':
        m
          ..roughnessFactor = 0.45
          ..clearcoat = 0.4
          ..clearcoatRoughness = 0.1;
    }
    return m;
  }

  /// Shows or hides the scarf (Pip's goes missing on day 1). The scarf
  /// takes the wool's colour, since mounted primitives keep their material.
  set scarfShown(bool shown) {
    if (shown == _scarfShown) return;
    _scarfShown = shown;
    final from = shown ? _scarfColor : _wool.baseColorFactor;
    final sheen = shown ? _scarfSheen : _wool.sheenColor;
    _scarf
      ..baseColorFactor = from.clone()
      ..sheenColor = sheen.clone();
  }

  final vm.Vector4 _scarfColor;
  final vm.Vector4 _scarfSheen;

  void update(Village v, Llama l, double dt, double wall) {
    final (pos, heading, walking) = v.llamaPose(l);
    final ground = groundHeight(pos.$1, pos.$2);
    final target = vm.Vector3(pos.$1, ground, pos.$2);
    final before = position.clone();
    if (position.length2 == 0 || (target - position).length > 12) {
      position.setFrom(target);
    } else {
      position.setFrom(position + (target - position) * math.min(1.0, dt * 12));
    }
    final speed = dt > 0 ? (position - before).length / dt : 0.0;
    final kind = l.activity.kind;

    var face = heading;
    if (!walking) {
      final partner = l.activity.with_;
      if (kind == 'talk' && partner != null) {
        final (pp, _, _) = partner == 'Dash' ? (v.dash.pos, heading, false) : v.llamaPose(v.byName(partner));
        final dx = pp.$1 - pos.$1, dz = pp.$2 - pos.$2;
        if (dx * dx + dz * dz > 0.01) face = (dx, dz);
      }
    }
    final wantYaw = math.atan2(-face.$1, -face.$2);
    yaw += _angleTo(yaw, wantYaw) * math.min(1.0, dt * (walking ? 10 : 4));

    final moving = walking && speed > 0.2;
    _gallopW = _ease(_gallopW, moving ? 1 : 0, moving ? 10 : 5, dt);
    _gallop?.playbackTimeScale = (speed / 4.5).clamp(0.7, 2.6);
    _idle?.weight = 1 - _gallopW;
    _gallop?.weight = _gallopW;

    final atHome = l.place == l.home;
    visible = !(l.asleep && atHome && !walking);
    root.visible = visible;

    var pitch = 0.0, roll = 0.0, bob = 0.0, wobble = 0.0, sy = 1.0, squint = 0.0;
    final phase = wall + name.length * 0.7;
    final speaking = v.speech[name]?.kind == SpeechKind.say && v.speech[name]?.text != null;
    switch (kind) {
      case 'eat':
        pitch = 0.2;
        bob = 0.04 * math.sin(phase * 4);
        squint = 0.6;
      case 'work':
        bob = 0.05 * math.sin(phase * 7).abs();
        pitch = 0.06;
      case 'search':
        wobble = 0.55 * math.sin(phase * 1.6);
        pitch = 0.12;
      case 'practise':
        roll = 0.12 * math.sin(phase * 2.6);
        squint = 0.4;
      case 'nap' || 'sleep':
        sy = 0.8;
        pitch = 0.08;
        squint = 1;
      case 'flowers':
        pitch = 0.22;
      case 'watch':
        bob = 0.03 * math.sin(phase * 5).abs();
      case 'talk':
        if (speaking) pitch = 0.05 * math.sin(phase * 9);
    }
    if (v.storm && l.outdoors && !walking) roll += 0.03 * math.sin(phase * 31);
    if (l.mood >= 3 && !walking && kind != 'nap') bob += 0.03 * math.sin(phase * 3).abs();
    _squintW = _ease(_squintW, squint, 6, dt);
    for (final (n, i) in _squint) {
      n.setMorphWeight(i, _squintW);
    }
    root.localTransform = vm.Matrix4.translation(position + vm.Vector3(0, bob, 0))
      ..rotateY(yaw + wobble)
      ..rotateX(-pitch)
      ..rotateZ(roll)
      ..scaleByDouble(1, sy, 1, 1);
  }
}

/// Dash: a round blue bird, flying above the village.
class DashActor {
  DashActor() : root = Node(name: 'Dash');

  final Node root;
  final List<Node> _wings = [];
  vm.Vector3 position = vm.Vector3.zero();
  double yaw = 0;
  double _height = 2.6;

  void build(PhysicallyBasedMaterial gloss) {
    root.add(Node(mesh: Mesh(_dashBody(), gloss)));
    final wing = _dashWing();
    for (final s in [-1.0, 1.0]) {
      final pivot = Node(localTransform: vm.Matrix4.translation(vm.Vector3(s * 0.2, 0.02, 0.02)));
      pivot.add(Node(mesh: Mesh(wing, gloss), localTransform: s < 0 ? vm.Matrix4.rotationY(math.pi) : vm.Matrix4.identity()));
      _wings.add(pivot);
      root.add(pivot);
    }
  }

  void update(Village v, double dt, double wall) {
    final d = v.dash;
    final visit = d.visit;
    final talking = visit != null && visit.stage.index >= VisitStage.choosing.index;
    final ground = groundHeight(d.pos.$1, d.pos.$2);
    _height = _ease(_height, talking ? 1.9 : (d.moving ? 3.2 : 2.6), 3, dt);
    final target = vm.Vector3(d.pos.$1, ground + _height + 0.12 * math.sin(wall * 3.2), d.pos.$2);
    position = position.length2 == 0 ? target : position + (target - position) * math.min(1.0, dt * 14);
    var face = d.heading;
    if (talking) {
      final (lp, _, _) = v.llamaPose(visit.target);
      face = (lp.$1 - d.pos.$1, lp.$2 - d.pos.$2);
    }
    // The bird mesh faces -Z, like the llama.
    yaw += _angleTo(yaw, math.atan2(-face.$1, -face.$2)) * math.min(1.0, dt * 8);
    final flap = math.sin(wall * (d.moving ? 24 : 14)) * (d.moving ? 0.8 : 0.5);
    for (var i = 0; i < _wings.length; i++) {
      final s = i == 0 ? -1.0 : 1.0;
      final base = _wings[i].localTransform.getTranslation();
      _wings[i].localTransform = vm.Matrix4.translation(base)..rotateZ(s * flap);
    }
    root.localTransform = vm.Matrix4.translation(position)
      ..rotateY(yaw)
      ..rotateX(d.moving ? -0.25 : 0)
      ..scaleByDouble(1.6, 1.6, 1.6, 1);
  }
}

MeshGeometry _dashBody() {
  final blue = rgb(0x3E8EF0), white = rgb(0xF6F8FC), black = rgb(0x15171C);
  final b = MeshBuilder()
    ..sphere(vm.Vector3(0, 0, 0), vm.Vector3(0.26, 0.25, 0.26), blue, segments: 14, rings: 10)
    ..sphere(vm.Vector3(0, -0.06, -0.1), vm.Vector3(0.18, 0.16, 0.17), white)
    ..box(vm.Vector3(0, 0.27, 0.02), vm.Vector3(0.05, 0.12, 0.08), rgb(0x2F6FD0))
    ..box(vm.Vector3(0, -0.01, -0.27), vm.Vector3(0.08, 0.06, 0.1), rgb(0xF5A623));
  for (final s in [-1.0, 1.0]) {
    b
      ..sphere(vm.Vector3(s * 0.1, 0.07, -0.21), vm.Vector3(0.075, 0.085, 0.05), white)
      ..sphere(vm.Vector3(s * 0.1, 0.06, -0.255), vm.Vector3(0.04, 0.05, 0.02), black);
  }
  return b.build();
}

MeshGeometry _dashWing() => (MeshBuilder()..sphere(vm.Vector3(0.12, 0, 0), vm.Vector3(0.14, 0.04, 0.1), rgb(0x3580E0))).build();

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

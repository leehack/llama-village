import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../sim/dash.dart';
import '../sim/geo.dart';
import '../sim/village.dart';
import 'character_rig.dart';
import 'llama_rig.dart';
import 'mesh_builder.dart';

double _angleTo(double from, double to) => (to - from + math.pi) % (2 * math.pi) - math.pi;

/// Dash: a round blue bird that flaps when flying, hovers with a bob,
/// banks into turns, hops on landing, wiggles when a llama likes what he
/// said and droops when one is annoyed.
class DashActor {
  DashActor() : root = Node(name: 'Dash');

  final Node root;
  vm.Vector3 position = vm.Vector3.zero();
  double yaw = 0;
  double _height = 2.6;

  AnimationClip? _fly, _hover, _happy, _sad;
  List<ProceduralBone?> _lids = const [];
  Map<String, List<(Node, int)>> _morphs = const {};
  final Blinker _blink = Blinker(2.8, 11);

  double _flyW = 0, _happyW = 0, _sadW = 0, _bank = 0, _lid = 0;
  double _cheer = 0, _sulk = 0;
  double _hop = -1;
  bool _wasMoving = false;
  VisitStage? _lastStage;

  static const double scale = 1.15;

  Future<void> load() async {
    final model = await loadScene('assets/dash.glb');
    tuneCharacter(model, sheen: rgb(0x8CC4FF));
    AnimationClip? clip(String name, double w) {
      final a = model.findAnimationByName(name);
      if (a == null) return null;
      return model.createAnimationClip(a)
        ..loop = true
        ..weight = w
        ..play();
    }

    _fly = clip('Fly', 0);
    _hover = clip('Hover', 1);
    _happy = clip('Happy', 0);
    _sad = clip('Sad', 0);
    _lids = [ProceduralBone.find(model, 'lid_L'), ProceduralBone.find(model, 'lid_R')];
    _morphs = morphSlots(model, const ['Happy', 'Sad']);
    root.add(model);
  }

  /// How a llama took Dash's line: 0 offended .. 4 delighted.
  void react(int level) {
    if (level >= 3) {
      _cheer = 2.4;
      _sulk = 0;
    } else if (level <= 1) {
      _sulk = 2.8;
      _cheer = 0;
    }
  }

  void update(Village v, double dt, double wall) {
    final d = v.dash;
    final visit = d.visit;
    final talking = visit != null && visit.stage.index >= VisitStage.choosing.index;
    final ground = groundHeight(d.pos.$1, d.pos.$2);
    _height = approach(_height, talking ? 1.9 : (d.moving ? 3.2 : 2.6), 3, dt);
    final target = vm.Vector3(d.pos.$1, ground + _height + 0.12 * math.sin(wall * 3.2), d.pos.$2);
    position = position.length2 == 0 ? target : position + (target - position) * math.min(1.0, dt * 14);
    var face = d.heading;
    if (talking) {
      final (lp, _, _) = v.llamaPose(visit.target);
      face = (lp.$1 - d.pos.$1, lp.$2 - d.pos.$2);
    }
    // The bird faces -Z, like the llamas.
    final turn = _angleTo(yaw, math.atan2(-face.$1, -face.$2)) * math.min(1.0, dt * 8);
    yaw += turn;
    final yawRate = dt > 0 ? turn / dt : 0.0;
    _bank = approach(_bank, (yawRate * 0.18).clamp(-0.6, 0.6) * (d.moving ? 1 : 0.4), 6, dt);

    // A landing hop when Dash stops, or arrives at a llama.
    final stage = visit?.stage;
    final arrived = _lastStage == VisitStage.flying && stage != null && stage != VisitStage.flying;
    if ((_wasMoving && !d.moving) || arrived) _hop = 0;
    _wasMoving = d.moving;
    _lastStage = stage;

    _cheer = math.max(0, _cheer - dt);
    _sulk = math.max(0, _sulk - dt);
    _flyW = approach(_flyW, d.moving ? 1 : 0, 5, dt);
    _happyW = approach(_happyW, _cheer > 0 ? 1 : 0, 6, dt);
    _sadW = approach(_sadW, _sulk > 0 ? 1 : 0, 4, dt);
    final react = math.min(1.0, _happyW + _sadW);
    _fly?.weight = _flyW * (1 - react);
    _fly?.playbackTimeScale = 1 + 0.3 * _flyW;
    _hover?.weight = (1 - _flyW) * (1 - react);
    _happy?.weight = _happyW;
    _sad?.weight = _sadW;

    var lift = 0.0, sx = 1.0, sy = 1.0;
    if (_hop >= 0) {
      _hop += dt;
      final s = _hop;
      if (s < 0.16) {
        // Touch down: dip and squash.
        final k = math.sin(math.pi * s / 0.16);
        lift = -0.16 * k;
        sy = 1 - 0.2 * k;
        sx = 1 + 0.12 * k;
      } else if (s < 0.56) {
        // Then a little hop, stretched.
        final k = math.sin(math.pi * (s - 0.16) / 0.4);
        lift = 0.3 * k;
        sy = 1 + 0.08 * k;
        sx = 1 - 0.04 * k;
      } else {
        _hop = -1;
      }
    }
    final droop = _sadW * 0.25;
    root.localTransform = vm.Matrix4.translation(position + vm.Vector3(0, lift - _sadW * 0.15, 0))
      ..rotateY(yaw)
      ..rotateZ(_bank)
      ..rotateX(-0.25 * _flyW + droop)
      ..scaleByDouble(scale * sx, scale * sy, scale * sx, 1);

    for (final (name, w) in [('Happy', _happyW), ('Sad', _sadW)]) {
      for (final (node, slot) in _morphs[name] ?? const <(Node, int)>[]) {
        node.setMorphWeight(slot, w);
      }
    }
    final blink = _blink.update(dt);
    final want = _sadW * 0.35 + _happyW * 0.15;
    _lid = approach(_lid, want, 8, dt);
    final lid = _lid + (1 - _lid) * blink;
    for (final l in _lids) {
      l?.turnAboutOwnAxis(-lid * 120 * math.pi / 180);
    }
  }
}

import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../sim/cast.dart';
import '../sim/geo.dart';
import '../sim/village.dart';
import 'character_rig.dart';
import 'llama_rig.dart';
import 'mesh_builder.dart';
import 'world.dart';

double _angleTo(double from, double to) => (to - from + math.pi) % (2 * math.pi) - math.pi;

/// Where a character's head is, by name ('Dash' included), or null if it
/// is not in the scene.
typedef HeadOf = vm.Vector3? Function(String name);

/// One llama in the scene: its own rigged model, the clips blended by
/// speed, and the procedural life on top (look-at, blinks, expressions,
/// ears, tail, breathing).
class LlamaActor {
  LlamaActor._(this.name, this.spec, this.root, Node model, this._idle, this._walk, this._gallop)
    : _neck = ProceduralBone.find(model, 'neck_aim'),
      _head = ProceduralBone.find(model, 'head_aim'),
      _ears = [ProceduralBone.find(model, 'ear_L'), ProceduralBone.find(model, 'ear_R')],
      _lids = [ProceduralBone.find(model, 'lid_L'), ProceduralBone.find(model, 'lid_R')],
      _tail = ProceduralBone.find(model, 'tail'),
      _belly = ProceduralBone.find(model, 'belly'),
      _scarfBone = ProceduralBone.find(model, 'scarf'),
      _scarf = [?model.getChildByName('Scarf'), ?model.getChildByName('ScarfTail')],
      _morphs = morphSlots(model, llamaMorphs),
      _blink = Blinker(spec.blinkEvery, name.hashCode),
      _rng = math.Random(name.length * 31 + 7);

  final String name;
  final LlamaSpec spec;
  final Node root;
  final AnimationClip? _idle, _walk, _gallop;
  final ProceduralBone? _neck, _head, _tail, _belly, _scarfBone;
  final List<ProceduralBone?> _ears, _lids;
  final List<Node> _scarf;
  final Map<String, List<(Node, int)>> _morphs;
  final Blinker _blink;
  final math.Random _rng;

  vm.Vector3 position = vm.Vector3.zero();
  double yaw = 0;
  bool visible = true;

  /// A scripted spot for tours and captures: the llama stands (or walks,
  /// when the spot moves) here facing [yaw], looking at `look` if set,
  /// instead of following the sim.
  ({double x, double z, double yaw, vm.Vector3? look})? staged;

  /// A scripted face for captures, instead of the one its mood gives.
  FaceTargets? forcedFace;
  bool _scarfShown = true;

  double _speed = 0, _turnRate = 0, _runHeat = 0;
  double _lookYaw = 0, _lookPitch = 0, _glanceYaw = 0, _glanceUntil = 0, _nextGlance = 2;
  final List<double> _faceW = List.filled(llamaMorphs.length, 0);
  double _lid = 0;
  double _surprise = 0, _delight = 0, _annoyance = 0;
  final List<double> _earFlick = [0, 0], _earNext = [1.5, 3.2];

  /// Top of the head above [position], for bubbles and picking.
  double get headHeight => spec.headHeight;

  static Future<LlamaActor> load(String name) async {
    final spec = llamaSpecs[name]!;
    final model = await loadScene(spec.asset);
    tuneCharacter(model, sheen: rgb(llamaColors[name]!.$1));
    AnimationClip? clip(String clipName, double w) {
      final a = model.findAnimationByName(clipName);
      if (a == null) return null;
      return model.createAnimationClip(a)
        ..loop = true
        ..weight = w
        ..play();
    }

    final idle = clip('Idle', 1);
    final walk = clip('Walk', 0);
    final gallop = clip('Gallop', 0);
    final root = Node(name: name)..add(model);
    return LlamaActor._(name, spec, root, model, idle, walk, gallop);
  }

  /// Shows or hides Pip's scarf (it goes missing on day 1).
  set scarfShown(bool shown) {
    if (shown == _scarfShown) return;
    _scarfShown = shown;
    for (final n in _scarf) {
      n.visible = shown;
    }
  }

  /// A short reaction: 'surprise' (news, a storm), 'delight' or
  /// 'annoyance' (how Dash's line landed).
  void react(String kind) {
    switch (kind) {
      case 'surprise':
        _surprise = 1;
      case 'delight':
        _delight = 1;
        _annoyance = 0;
      case 'annoyance':
        _annoyance = 1;
        _delight = 0;
    }
  }

  /// World position of the head centre (for others to look at).
  vm.Vector3 get headWorld {
    final c = math.cos(yaw), s = math.sin(yaw);
    final h = spec.head;
    return position + vm.Vector3(c * h.x + s * h.z, h.y, -s * h.x + c * h.z);
  }

  void update(Village v, Llama l, double dt, double wall, HeadOf headOf) {
    final spot = staged;
    final (pos, heading, walking) = spot == null
        ? v.llamaPose(l)
        : ((spot.x, spot.z), (-math.sin(spot.yaw), -math.cos(spot.yaw)), (vm.Vector3(spot.x, 0, spot.z) - position).length > 0.002);
    final ground = groundHeight(pos.$1, pos.$2);
    final target = vm.Vector3(pos.$1, ground, pos.$2);
    final before = position.clone();
    if (position.length2 == 0 || (target - position).length > 12) {
      position.setFrom(target);
    } else {
      position.setFrom(position + (target - position) * math.min(1.0, dt * 12));
    }
    final rawSpeed = dt > 0 ? (position - before).length / dt : 0.0;
    _speed = approach(_speed, rawSpeed, 10, dt);
    final kind = spot == null ? l.activity.kind : 'idle';

    var face = heading;
    if (!walking && spot == null) {
      final partner = l.activity.with_;
      if (kind == 'talk' && partner != null) {
        final (pp, _, _) = partner == 'Dash' ? (v.dash.pos, heading, false) : v.llamaPose(v.byName(partner));
        final dx = pp.$1 - pos.$1, dz = pp.$2 - pos.$2;
        if (dx * dx + dz * dz > 0.01) face = (dx, dz);
      }
    }
    final wantYaw = math.atan2(-face.$1, -face.$2);
    final turn = _angleTo(yaw, wantYaw) * math.min(1.0, dt * (walking ? 10 : 4));
    yaw += turn;
    _turnRate = approach(_turnRate, dt > 0 ? turn / dt : 0, 6, dt);

    // Fast-forward (and the night boost) plays the gait faster instead of
    // turning a walk into a gallop.
    final pace = spot == null && v.minutesPerSecond > 0 ? v.timeScale * (v.fastNight ? Village.nightBoost : 1) : 1.0;
    final mix = gaitMix(spec, walking ? _speed / pace : 0);
    _idle?.weight = mix.idle;
    _walk
      ?..weight = mix.walk
      ..playbackTimeScale = mix.walkRate * pace;
    _gallop
      ?..weight = mix.gallop
      ..playbackTimeScale = mix.gallopRate * pace;
    _runHeat = approach(_runHeat, mix.gallop, mix.gallop > _runHeat ? 0.8 : 0.12, dt);

    final atHome = l.place == l.home;
    visible = spot != null || !(l.asleep && atHome && !walking);
    root.visible = visible;
    if (!visible) return;

    var pitch = 0.0, roll = 0.0, bob = 0.0, wobble = 0.0, sy = 1.0;
    final phase = wall + name.length * 0.7;
    final speech = v.speech[name];
    final speaking = speech?.kind == SpeechKind.say && speech?.text != null;
    switch (kind) {
      case 'eat':
        pitch = 0.2;
        bob = 0.04 * math.sin(phase * 4);
      case 'work':
        bob = 0.05 * math.sin(phase * 7).abs();
        pitch = 0.06;
      case 'search':
        wobble = 0.55 * math.sin(phase * 1.6);
        pitch = 0.12;
      case 'practise':
        roll = 0.12 * math.sin(phase * 2.6);
      case 'nap' || 'sleep':
        sy = 0.86;
        pitch = 0.08;
      case 'flowers':
        pitch = 0.22;
      case 'watch':
        bob = 0.03 * math.sin(phase * 5).abs();
    }
    if (v.storm && l.outdoors && !walking) roll += 0.03 * math.sin(phase * 31);
    if (l.mood >= 3 && !walking && kind != 'nap') bob += 0.03 * math.sin(phase * 3).abs();
    // Lean into turns while moving.
    if (walking) roll += (_turnRate * 0.04).clamp(-0.12, 0.12) * math.min(1.0, _speed / 3);
    root.localTransform = vm.Matrix4.translation(position + vm.Vector3(0, bob, 0))
      ..rotateY(yaw + wobble)
      ..rotateX(-pitch)
      ..rotateZ(roll)
      ..scaleByDouble(1, sy, 1, 1);

    _updateLook(v, l, dt, wall, headOf, walking, kind);
    _updateFace(l, dt, wall, kind, speaking);
    _updateEars(l, dt, kind);
    _updateTailAndBreath(dt, wall, kind);
    _updateScarf(dt, wall);
  }

  /// The character [l] should look at now, if any.
  vm.Vector3? _lookTarget(Village v, Llama l, HeadOf headOf, bool walking, String kind) {
    final spot = staged;
    if (spot != null) return spot.look;
    if (kind == 'sleep' || kind == 'nap' || kind == 'eat') return null;
    final me = headWorld;
    vm.Vector3? near(String who, double range) {
      final p = headOf(who);
      return p != null && (p - me).length < range ? p : null;
    }

    final partner = l.activity.with_;
    // Whoever is talking to me, or my partner when they speak.
    for (final s in v.speech.values) {
      if (s.who == name || s.kind != SpeechKind.say) continue;
      if (s.to == name || s.who == partner) {
        final p = near(s.who, 14);
        if (p != null) return p;
      }
    }
    if (partner != null) {
      final p = near(partner, 14);
      if (p != null) return p;
    }
    // Anyone speaking close by turns heads.
    if (!walking) {
      for (final s in v.speech.values) {
        if (s.who == name || s.kind != SpeechKind.say || s.text == null) continue;
        final p = near(s.who, 9);
        if (p != null) return p;
      }
    }
    return near('Dash', walking ? 5 : 7.5);
  }

  void _updateLook(Village v, Llama l, double dt, double wall, HeadOf headOf, bool walking, String kind) {
    final target = _lookTarget(v, l, headOf, walking, kind);
    var wantYaw = 0.0, wantPitch = 0.0;
    if (target != null) {
      (wantYaw, wantPitch) = lookAngles(head: headWorld, bodyYaw: yaw, target: target, maxYaw: walking ? 0.6 : 1.15);
    } else if (!walking && staged == null && kind != 'sleep' && kind != 'nap') {
      // Idle glances around.
      if (wall > _nextGlance) {
        _glanceYaw = (_rng.nextDouble() * 2 - 1) * 0.9;
        _glanceUntil = wall + 1.2 + _rng.nextDouble() * 1.8;
        _nextGlance = _glanceUntil + 2 + _rng.nextDouble() * 5;
      }
      if (wall < _glanceUntil) wantYaw = _glanceYaw;
    }
    _lookYaw = approach(_lookYaw, wantYaw, spec.lookRate, dt);
    _lookPitch = approach(_lookPitch, wantPitch, spec.lookRate, dt);
    _neck?.turn(yawPitch(_lookYaw * 0.45, _lookPitch * 0.35));
    _head?.turn(yawPitch(_lookYaw * 0.55, _lookPitch * 0.65));
  }

  void _updateFace(Llama l, double dt, double wall, String kind, bool speaking) {
    _surprise = math.max(0, _surprise - dt / 1.6);
    _delight = math.max(0, _delight - dt / 3.5);
    _annoyance = math.max(0, _annoyance - dt / 3.5);
    final t =
        forcedFace ??
        faceTargets(
          mood: l.mood,
          activity: kind,
          energy: l.energy,
          speaking: speaking,
          talkPhase: wall * 17 + name.length,
          surprise: math.min(1, _surprise * 1.6),
          delight: math.min(1, _delight * 1.5),
          annoyance: math.min(1, _annoyance * 1.5),
        );
    final mix = mixFace(t, forcedFace == null ? _blink.update(dt) : 0);
    for (var i = 0; i < llamaMorphs.length; i++) {
      // The mouth flaps fast; the rest of the face eases.
      _faceW[i] = llamaMorphs[i] == 'Talk' ? mix.morphs[i] : approach(_faceW[i], mix.morphs[i], 7, dt);
      for (final (node, slot) in _morphs[llamaMorphs[i]]!) {
        node.setMorphWeight(slot, _faceW[i]);
      }
    }
    // Blinks are quick; slow lid changes (dozing off) ease.
    _lid = mix.lid > _lid + 0.3 || mix.lid < _lid - 0.3 ? mix.lid : approach(_lid, mix.lid, 12, dt);
    final angle = -_lid * lidTravelDegrees * math.pi / 180;
    for (final lid in _lids) {
      lid?.turnAboutOwnAxis(angle);
    }
  }

  void _updateEars(Llama l, double dt, String kind) {
    for (var i = 0; i < 2; i++) {
      _earNext[i] -= dt;
      if (_earNext[i] <= 0) {
        _earFlick[i] = 1;
        _earNext[i] = 2.5 + _rng.nextDouble() * 6;
        // Sometimes both ears go together.
        if (_rng.nextDouble() < 0.25) _earFlick[1 - i] = 0.8;
      }
      _earFlick[i] = math.max(0, _earFlick[i] - dt / 0.28);
    }
    final mood = l.mood <= -2 ? 0.35 : (l.mood >= 3 ? -0.12 : 0.0);
    final sleepy = kind == 'sleep' || kind == 'nap' ? 0.3 : 0.0;
    final alert = _surprise * -0.25;
    for (var i = 0; i < 2; i++) {
      final f = math.sin(_earFlick[i] * math.pi);
      final side = i == 0 ? 1.0 : -1.0;
      _ears[i]?.turn(yawPitch(0, -(mood + sleepy + alert) - 0.45 * f, side * 0.3 * f));
    }
  }

  void _updateTailAndBreath(double dt, double wall, String kind) {
    final moving = math.min(1.0, _speed / 2);
    final swish = 0.28 * math.sin(wall * 1.4 + name.length) + moving * 0.22 * math.sin(wall * 7.5);
    _tail?.turn(yawPitch(swish, -0.55 * _runHeat - 0.1 * moving));
    final asleep = kind == 'sleep' || kind == 'nap';
    final rate = asleep ? 0.16 : 0.24 + 0.5 * _runHeat;
    final amp = asleep ? 0.035 : 0.022 + 0.02 * _runHeat;
    _belly?.turn(vm.Quaternion.identity(), scale: 1 + amp * (0.5 + 0.5 * math.sin(wall * rate * 2 * math.pi)));
  }

  void _updateScarf(double dt, double wall) {
    final bone = _scarfBone;
    if (bone == null || !_scarfShown) return;
    final trail = math.min(1.0, _speed / 6);
    bone.turn(yawPitch(-_turnRate * 0.05 + 0.08 * math.sin(wall * 1.1), -0.15 - 0.7 * trail + 0.06 * math.sin(wall * 9) * trail));
  }
}

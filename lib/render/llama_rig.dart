import 'dart:math' as math;

import 'package:vector_math/vector_math.dart' as vm;

/// Per-llama constants that the character assets were built with
/// (`tool/blender/llama.py`), plus the runtime gait tuning.
class LlamaSpec {
  const LlamaSpec({
    required this.id,
    required this.headHeight,
    required this.head,
    required this.walkSeconds,
    required this.strideMetres,
    required this.runFrom,
    required this.blinkEvery,
    required this.lookRate,
  });

  /// Asset id: `assets/llama_<id>.glb`, `assets/portraits/<id>.png`.
  final String id;

  /// Top of the head (or hat) above the ground, in metres.
  final double headHeight;

  /// Head centre in the model frame (llama faces -Z), for look-at.
  final vm.Vector3 head;

  /// Length of the baked Walk clip.
  final double walkSeconds;

  /// Ground covered per walk cycle at the clip's own speed.
  final double strideMetres;

  /// Speed (m/s) at which the walk hands over to the gallop.
  final double runFrom;

  /// Mean seconds between blinks.
  final double blinkEvery;

  /// How fast the head turns toward a new target (1/s).
  final double lookRate;

  String get asset => 'assets/llama_$id.glb';
}

final Map<String, LlamaSpec> llamaSpecs = {
  // Pip prances: a quick, high-stepping walk with her head held high.
  'Pip': LlamaSpec(
    id: 'pip',
    headHeight: 2.12,
    head: vm.Vector3(0, 1.76, -0.52),
    walkSeconds: 22 / 30,
    strideMetres: 0.93,
    runFrom: 2.6,
    blinkEvery: 3.2,
    lookRate: 6,
  ),
  // Mo plods: short heavy steps, a rolling waddle.
  'Mo': LlamaSpec(
    id: 'mo',
    headHeight: 1.98,
    head: vm.Vector3(0, 1.40, -0.56),
    walkSeconds: 32 / 30,
    strideMetres: 0.47,
    runFrom: 1.8,
    blinkEvery: 4.5,
    lookRate: 3.5,
  ),
  // June scurries: fast little steps.
  'June': LlamaSpec(
    id: 'june',
    headHeight: 1.62,
    head: vm.Vector3(0, 1.29, -0.43),
    walkSeconds: 14 / 30,
    strideMetres: 0.51,
    runFrom: 2.4,
    blinkEvery: 2.4,
    lookRate: 9,
  ),
  // Bramble slouches: long slow strides, head low.
  'Bramble': LlamaSpec(
    id: 'bramble',
    headHeight: 1.9,
    head: vm.Vector3(0, 1.56, -0.70),
    walkSeconds: 34 / 30,
    strideMetres: 0.91,
    runFrom: 2.2,
    blinkEvery: 5.0,
    lookRate: 3,
  ),
  // Clover marches: crisp, even steps, upright.
  'Clover': LlamaSpec(
    id: 'clover',
    headHeight: 1.9,
    head: vm.Vector3(0, 1.60, -0.43),
    walkSeconds: 24 / 30,
    strideMetres: 0.70,
    runFrom: 2.3,
    blinkEvery: 3.8,
    lookRate: 5,
  ),
};

/// The face morph targets of every llama, in the glb's order.
const List<String> llamaMorphs = ['Happy', 'Sulky', 'Surprised', 'Sleepy', 'Talk'];

/// Bones the game drives itself; the clips never key them.
const List<String> proceduralBones = ['neck_aim', 'head_aim', 'ear_L', 'ear_R', 'lid_L', 'lid_R', 'scarf', 'tail', 'belly'];

/// Degrees the lid bones turn from open to shut (`LID_OPEN - LID_SHUT` in
/// `tool/blender/llama.py`).
const double lidTravelDegrees = 110;

/// How far a sleepy or sulky face lowers the lids (0 open, 1 shut).
const double sleepyLid = 0.5, sulkyLid = 0.35, surprisedLid = -0.2;

/// Clip weights and playback rates for a llama moving at [speed] m/s.
class GaitMix {
  const GaitMix(this.idle, this.walk, this.gallop, this.walkRate, this.gallopRate);
  final double idle, walk, gallop, walkRate, gallopRate;
}

double _smooth(double e0, double e1, double x) {
  final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Idle below a crawl, the walk at walking speeds (its rate matched to the
/// ground so hooves do not slide), the gallop from [LlamaSpec.runFrom].
GaitMix gaitMix(LlamaSpec spec, double speed) {
  final moving = _smooth(0.08, 0.45, speed);
  final run = _smooth(spec.runFrom - 0.5, spec.runFrom + 0.5, speed);
  final walkRate = (speed / spec.strideMetres * spec.walkSeconds).clamp(0.45, 2.4);
  final gallopRate = (speed / 4.5).clamp(0.7, 2.6);
  return GaitMix(1 - moving, moving * (1 - run), moving * run, walkRate, gallopRate);
}

/// Yaw and pitch (radians) that turn a head at [head], on a body facing
/// [bodyYaw] (about +Y; 0 faces -Z), toward [target]. Targets far behind
/// are clamped to the shoulder rather than wrapping round.
(double, double) lookAngles({
  required vm.Vector3 head,
  required double bodyYaw,
  required vm.Vector3 target,
  double maxYaw = 1.15,
  double maxPitch = 0.5,
}) {
  final d = target - head;
  final c = math.cos(-bodyYaw), s = math.sin(-bodyYaw);
  // Into the body frame: rotate by -bodyYaw about +Y.
  final lx = c * d.x + s * d.z;
  final lz = -s * d.x + c * d.z;
  final flat = math.sqrt(lx * lx + lz * lz);
  if (flat < 1e-6 && d.y.abs() < 1e-6) return (0, 0);
  final yaw = math.atan2(-lx, -lz).clamp(-maxYaw, maxYaw);
  final pitch = math.atan2(d.y, math.max(flat, 0.3)).clamp(-maxPitch, maxPitch);
  return (yaw, pitch);
}

/// What a llama's face should show, before blinking.
class FaceTargets {
  const FaceTargets({this.happy = 0, this.sulky = 0, this.surprised = 0, this.sleepy = 0, this.talk = 0, this.shut = 0});
  final double happy, sulky, surprised, sleepy, talk;

  /// Eyes closed regardless (asleep).
  final double shut;
}

/// Morph weights (in the glb's order: Happy, Sulky, Surprised, Sleepy,
/// Talk) and the lid closure, -0.2 (wide) to 1 (shut).
class FaceMix {
  const FaceMix(this.morphs, this.lid);
  final List<double> morphs;
  final double lid;
}

/// The face for a mood (-5..5), activity, energy (0..1) and short-lived
/// reactions (each 0..1, decaying).
FaceTargets faceTargets({
  required int mood,
  required String activity,
  required double energy,
  bool speaking = false,
  double talkPhase = 0,
  double surprise = 0,
  double delight = 0,
  double annoyance = 0,
}) {
  if (activity == 'sleep' || activity == 'nap') return const FaceTargets(sleepy: 0.6, shut: 1);
  var happy = mood >= 3 ? 0.85 : (mood >= 1 ? 0.45 : 0.1);
  var sulky = mood <= -3 ? 0.9 : (mood <= -1 ? 0.5 : 0.0);
  var sleepy = _smooth(0.3, 0.1, energy) * 0.9;
  if (activity == 'eat') happy = math.max(happy, 0.6);
  if (activity == 'practise') happy = math.max(happy, 0.5);
  happy = math.max(happy, delight);
  sulky = math.max(sulky, annoyance);
  if (delight > 0) sulky *= 1 - delight;
  if (annoyance > 0) happy *= 1 - annoyance;
  if (surprise > 0) sleepy *= 1 - surprise;
  final talk = speaking ? 0.35 + 0.65 * (0.5 + 0.5 * math.sin(talkPhase)) : 0.0;
  return FaceTargets(happy: happy, sulky: sulky, surprised: surprise, sleepy: sleepy, talk: talk);
}

/// Blends [t] with a blink (0..1) so that the lids never travel past shut
/// however the expressions stack, and a wide-eyed look gives way to the
/// blink instead of fighting it.
FaceMix mixFace(FaceTargets t, double blink) {
  final b = blink.clamp(0.0, 1.0);
  final surprised = t.surprised.clamp(0.0, 1.0) * (1 - b);
  final base = (t.sleepy * sleepyLid + t.sulky * sulkyLid).clamp(0.0, 0.85);
  var lid = base + surprised * surprisedLid;
  lid += (1 - lid) * math.max(b, t.shut.clamp(0.0, 1.0));
  return FaceMix([
    t.happy.clamp(0.0, 1.0) * (1 - t.shut),
    t.sulky.clamp(0.0, 1.0),
    surprised,
    t.sleepy.clamp(0.0, 1.0),
    t.talk.clamp(0.0, 1.0) * (1 - t.shut),
  ], lid.clamp(surprisedLid, 1.0));
}

/// Blinks at random intervals around [every] seconds, sometimes twice.
class Blinker {
  Blinker(this.every, int seed) : _rng = math.Random(seed) {
    _next = _rng.nextDouble() * every;
  }

  final double every;
  final math.Random _rng;
  double _t = 0, _next = 0;
  double _blinkAt = -1;
  bool _double = false;

  static const double closeTime = 0.07, openTime = 0.13;

  /// Advances by [dt] and returns the lid closure of the blink, 0..1.
  double update(double dt) {
    _t += dt;
    if (_blinkAt < 0 && _t >= _next) {
      _blinkAt = _t;
      _double = _rng.nextDouble() < 0.18;
    }
    if (_blinkAt < 0) return 0;
    final s = _t - _blinkAt;
    const len = closeTime + openTime;
    if (s >= len) {
      if (_double) {
        _double = false;
        _blinkAt = _t + 0.08;
        return 0;
      }
      _blinkAt = -1;
      _next = _t + every * (0.5 + _rng.nextDouble());
      return 0;
    }
    if (s < 0) return 0;
    return s < closeTime ? s / closeTime : 1 - (s - closeTime) / openTime;
  }
}

/// Moves [from] toward [to] at [rate] per second, frame-rate independent.
double approach(double from, double to, double rate, double dt) => from + (to - from) * (1 - math.exp(-rate * dt));

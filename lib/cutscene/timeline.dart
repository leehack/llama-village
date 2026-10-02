import 'dart:async';
import 'dart:math' as math;

import 'package:vector_math/vector_math.dart' as vm;

enum Ease { linear, inOut, out }

double applyEase(Ease e, double t) {
  final x = t.clamp(0.0, 1.0);
  return switch (e) {
    Ease.linear => x,
    Ease.inOut => x * x * (3 - 2 * x),
    Ease.out => 1 - (1 - x) * (1 - x),
  };
}

const double defaultFov = 28 * math.pi / 180;

class CameraPose {
  CameraPose(this.eye, this.target, {this.fov = defaultFov});
  final vm.Vector3 eye;
  final vm.Vector3 target;

  /// Vertical field of view in radians.
  final double fov;

  CameraPose lerp(CameraPose b, double t) =>
      CameraPose(eye + (b.eye - eye) * t, target + (b.target - target) * t, fov: fov + (b.fov - fov) * t);
}

/// The camera reaches [pose] at [at], easing in from the previous key.
class CameraKey {
  CameraKey(this.at, CameraPose pose, {this.ease = Ease.inOut}) : _pose = (() => pose);

  /// A key whose pose is worked out when it is used, for subjects only
  /// known mid-scene (the festival winner).
  CameraKey.lazy(this.at, CameraPose Function() pose, {this.ease = Ease.inOut}) : _pose = pose;

  final double at;
  final CameraPose Function() _pose;
  final Ease ease;

  CameraPose get pose => _pose();
}

/// A value going from [from] to [to] over [duration] seconds from [at]; it
/// holds [to] afterwards until the next ramp starts.
class Ramp {
  const Ramp(this.at, this.duration, this.from, this.to);
  final double at;
  final double duration;
  final double from;
  final double to;

  double valueAt(double t) => duration <= 0 ? to : from + (to - from) * applyEase(Ease.inOut, (t - at) / duration);
}

double _rampValue(List<Ramp> ramps, double t) {
  Ramp? current;
  for (final r in ramps) {
    if (r.at <= t && (current == null || r.at >= current.at)) current = r;
  }
  return current?.valueAt(t) ?? 0;
}

enum TextKind { subtitle, dream, song, title }

/// A line on screen from [at] for [duration] seconds: a subtitle, a dream
/// bubble pinned to [anchor], or a title card. Its text is fixed, or comes
/// from [future] (a generated line); with [hold] the timeline waits at [at]
/// for it, up to [maxWait] seconds, then shows [fallback].
class TextCue {
  TextCue(
    this.at,
    this.duration, {
    this.text,
    this.future,
    this.kind = TextKind.subtitle,
    this.speaker,
    this.subtitle,
    this.anchor,
    this.hold = false,
    this.maxWait = 8,
    this.fallback = '…',
  });

  final double at;
  final double duration;
  final TextKind kind;
  final String? speaker;

  /// The small line under a title card.
  final String? subtitle;
  final vm.Vector3? anchor;
  final bool hold;
  final double maxWait;
  final String fallback;
  final Future<String>? future;

  /// Null while the line is still being written.
  String? text;
  bool get ready => text != null;
}

/// Runs [run] once when the timeline passes [at] (or on a skip).
class Cue {
  Cue(this.at, this.run, {this.label = ''});
  final double at;
  final void Function() run;
  final String label;
}

/// The timeline waits at [at] until [ready] or for [maxWait] seconds.
class Hold {
  Hold(this.at, this.ready, {this.maxWait = 10, this.label = ''});
  final double at;
  final bool Function() ready;
  final double maxWait;
  final String label;
}

/// Music notes rising from [anchor] (a singer's head) from [at] for
/// [duration] seconds: a new one every [every] seconds, each rising and
/// fading out over [life].
class NoteCue {
  NoteCue(this.at, this.duration, {required this.anchor, this.speaker});
  final double at;
  final double duration;
  final vm.Vector3 Function() anchor;
  final String? speaker;

  static const double every = 0.42, life = 1.9;

  /// The notes in the air at [time], as (index, seconds since it appeared).
  List<(int, double)> notesAt(double time) {
    final out = <(int, double)>[];
    final first = math.max(0, ((time - at - life) / every).floor() + 1);
    for (var k = first; at + k * every <= math.min(time, at + duration); k++) {
      out.add((k, time - at - k * every));
    }
    return out;
  }
}

class Shake {
  const Shake(this.at, this.duration, this.amplitude);
  final double at;
  final double duration;
  final double amplitude;
}

/// A scripted scene: camera keys, letterbox and fade ramps, text, cues,
/// holds and shakes on one clock of [duration] seconds.
class Cutscene {
  Cutscene({
    required this.name,
    required this.duration,
    List<CameraKey> camera = const [],
    this.letterbox = const [],
    this.fade = const [],
    this.texts = const [],
    List<Cue> cues = const [],
    List<Hold> holds = const [],
    this.shakes = const [],
    this.notes = const [],
    this.pausesSim = true,
    this.onFrame,
  }) : camera = [...camera]..sort((a, b) => a.at.compareTo(b.at)),
       cues = [...cues]..sort((a, b) => a.at.compareTo(b.at)),
       holds = [...holds]..sort((a, b) => a.at.compareTo(b.at));

  final String name;
  final double duration;
  final List<CameraKey> camera;
  final List<Ramp> letterbox;

  /// 0 clear, 1 black.
  final List<Ramp> fade;
  final List<TextCue> texts;
  final List<Cue> cues;
  final List<Hold> holds;
  final List<Shake> shakes;
  final List<NoteCue> notes;
  final bool pausesSim;

  /// Called with the scene time after every update, for continuous effects
  /// such as the sky's hour.
  final void Function(double time)? onFrame;
}

/// Something the timeline is waiting at: a [Hold] or a holding [TextCue].
class _Block {
  _Block(this.at, this.ready, this.maxWait, this.onTimeout);
  final double at;
  final bool Function() ready;
  final double maxWait;
  final void Function() onTimeout;
  double waited = 0;
  bool released = false;
}

/// Plays a [Cutscene]: advance it with [update], read the camera, bars,
/// fade and text off it each frame. [skip] runs every remaining cue at once.
class CutscenePlayer {
  CutscenePlayer(this.scene, {this.reducedMotion = false}) {
    for (final t in scene.texts) {
      final f = t.future;
      if (f == null) continue;
      unawaited(
        f.then(
          (s) => t.text ??= s.isEmpty ? t.fallback : s,
          onError: (Object _) {
            t.text ??= t.fallback;
            return t.text!;
          },
        ),
      );
    }
    _blocks = [
      for (final h in scene.holds) _Block(h.at, h.ready, h.maxWait, () {}),
      for (final t in scene.texts)
        if (t.hold && t.future != null) _Block(t.at, () => t.ready, t.maxWait, () => t.text ??= t.fallback),
    ]..sort((a, b) => a.at.compareTo(b.at));
  }

  final Cutscene scene;

  /// Cuts most of each camera move (the camera covers only the last 30% of
  /// the path) and turns off shake.
  final bool reducedMotion;

  late final List<_Block> _blocks;
  int _nextCue = 0;
  double time = 0;
  bool finished = false;
  bool skipped = false;

  /// Holds that gave up waiting, for logs and tests.
  int timeouts = 0;

  /// Called once when the scene ends, played out or skipped.
  void Function()? onEnd;

  /// Whether the timeline is stopped at a hold right now.
  bool get waiting {
    final b = _pending;
    return b != null && time >= b.at && !finished;
  }

  _Block? get _pending => _blocks.where((b) => !b.released).firstOrNull;

  void update(double dt) {
    _run(dt);
    scene.onFrame?.call(time);
  }

  void _run(double dt) {
    var remaining = dt;
    while (!finished) {
      final block = _pending;
      final stop = math.min(block?.at ?? scene.duration, scene.duration);
      final step = math.min(remaining, math.max(0.0, stop - time));
      if (step > 0) {
        _advanceTo(time + step);
        remaining -= step;
      }
      if (time >= scene.duration) {
        _finish();
        return;
      }
      if (block == null || time < block.at) return;
      _advanceTo(time);
      if (block.ready()) {
        block.released = true;
        continue;
      }
      block.waited += remaining;
      if (block.waited < block.maxWait) return;
      remaining = block.waited - block.maxWait;
      block
        ..released = true
        ..onTimeout();
      timeouts++;
    }
  }

  void _advanceTo(double t) {
    time = t;
    while (_nextCue < scene.cues.length && scene.cues[_nextCue].at <= time) {
      scene.cues[_nextCue++].run();
    }
  }

  /// Runs the remaining cues in order and ends the scene.
  void skip() {
    if (finished) return;
    skipped = true;
    for (final b in _blocks) {
      if (!b.released) {
        b.released = true;
        b.onTimeout();
      }
    }
    _advanceTo(scene.duration);
    scene.onFrame?.call(scene.duration);
    _finish();
  }

  void _finish() {
    if (finished) return;
    _advanceTo(scene.duration);
    time = scene.duration;
    finished = true;
    onEnd?.call();
  }

  /// The camera now, or null when the scene has no camera keys.
  CameraPose? get camera {
    final keys = scene.camera;
    if (keys.isEmpty) return null;
    var pose = keys.first.pose;
    if (time > keys.first.at) {
      pose = keys.last.pose;
      for (var i = 0; i + 1 < keys.length; i++) {
        final a = keys[i], b = keys[i + 1];
        if (time >= b.at) continue;
        var p = b.at <= a.at ? 1.0 : applyEase(b.ease, (time - a.at) / (b.at - a.at));
        if (reducedMotion) p = 0.7 + 0.3 * p;
        pose = a.pose.lerp(b.pose, p);
        break;
      }
    }
    final shake = shakeOffset;
    if (shake.length2 == 0) return pose;
    return CameraPose(pose.eye + shake, pose.target + shake * 0.5, fov: pose.fov);
  }

  vm.Vector3 get shakeOffset {
    final out = vm.Vector3.zero();
    if (reducedMotion) return out;
    for (final s in scene.shakes) {
      final u = (time - s.at) / s.duration;
      if (u < 0 || u >= 1) continue;
      final k = s.amplitude * (1 - u);
      out.add(vm.Vector3(math.sin(time * 41), math.sin(time * 33 + 1.3), math.sin(time * 37 + 2.1)) * k);
    }
    return out;
  }

  double get letterbox => _rampValue(scene.letterbox, time).clamp(0.0, 1.0);
  double get fade => _rampValue(scene.fade, time).clamp(0.0, 1.0);

  /// Note cues with notes in the air now.
  List<NoteCue> get notes => [
    for (final n in scene.notes)
      if (!finished && time >= n.at && time < n.at + n.duration + NoteCue.life) n,
  ];

  /// Texts on screen now, with their opacity (0.35 s in and out).
  List<(TextCue, double)> get texts {
    final held = waiting ? time : null;
    return [
      for (final t in scene.texts)
        if (time >= t.at && time < t.at + t.duration && !finished)
          (t, t.at == held ? 1.0 : math.min(1.0, math.min(time - t.at, t.at + t.duration - time) / 0.35)),
    ];
  }
}

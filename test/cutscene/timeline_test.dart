import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/cutscene/timeline.dart';
import 'package:vector_math/vector_math.dart' as vm;

CameraPose pose(double x, {double fov = defaultFov}) => CameraPose(vm.Vector3(x, 10, 0), vm.Vector3(x, 0, 0), fov: fov);

/// Steps [p] in 1/60 s frames for [seconds].
void run(CutscenePlayer p, double seconds) {
  for (var i = 0; i < (seconds * 60).round(); i++) {
    p.update(1 / 60);
  }
}

void main() {
  test('cues fire once, in order, when the clock passes them', () {
    final fired = <String>[];
    final p = CutscenePlayer(
      Cutscene(
        name: 't',
        duration: 3,
        cues: [Cue(2.0, () => fired.add('b')), Cue(0.5, () => fired.add('a')), Cue(2.0, () => fired.add('c'))],
      ),
    );
    var ended = 0;
    p.onEnd = () => ended++;
    p.update(0.49);
    expect(fired, isEmpty);
    p.update(0.02);
    expect(fired, ['a']);
    p.update(1.6);
    expect(fired, ['a', 'b', 'c']);
    expect(p.finished, isFalse);
    p.update(5);
    expect(p.finished, isTrue);
    expect(p.time, 3);
    expect(ended, 1);
    p.update(1);
    expect(ended, 1);
  });

  test('the camera eases between keys and holds the ends', () {
    final p = CutscenePlayer(
      Cutscene(
        name: 't',
        duration: 10,
        camera: [
          CameraKey(1, pose(0, fov: 0.5)),
          CameraKey(3, pose(10, fov: 1.0)),
          CameraKey(5, pose(10), ease: Ease.linear),
        ],
      ),
    );
    expect(p.camera!.eye.x, 0);
    p.update(1.5);
    expect(p.camera!.eye.x, closeTo(10 * applyEase(Ease.inOut, 0.25), 1e-9));
    p.update(0.5);
    expect(p.camera!.eye.x, closeTo(5, 1e-9));
    expect(p.camera!.fov, closeTo(0.75, 1e-9));
    p.update(5);
    expect(p.camera!.eye.x, 10);
    expect(p.camera!.fov, defaultFov);
  });

  test('reduced motion cuts most of a move and drops the shake', () {
    Cutscene scene() => Cutscene(
      name: 't',
      duration: 4,
      camera: [
        CameraKey(0, pose(0)),
        CameraKey(2, pose(10), ease: Ease.linear),
      ],
      shakes: const [Shake(0, 4, 0.5)],
    );
    final full = CutscenePlayer(scene())..update(0.5);
    final calm = CutscenePlayer(scene(), reducedMotion: true)..update(0.5);
    expect(full.shakeOffset.length, greaterThan(0));
    expect(calm.shakeOffset.length, 0);
    expect(calm.camera!.eye.x, closeTo(7 + 3 * 0.25, 1e-9));
    calm.update(1.5);
    expect(calm.camera!.eye.x, closeTo(10, 1e-9));
  });

  test('a hold stops the clock until it is ready, and gives up after maxWait', () {
    var ready = false;
    final fired = <double>[];
    final p = CutscenePlayer(
      Cutscene(
        name: 't',
        duration: 6,
        holds: [Hold(2, () => ready, maxWait: 3), Hold(4, () => false, maxWait: 1)],
        cues: [Cue(2, () => fired.add(2)), Cue(3, () => fired.add(3)), Cue(5, () => fired.add(5))],
      ),
    );
    run(p, 2.5);
    expect(p.time, 2);
    expect(p.waiting, isTrue);
    expect(fired, [2], reason: 'a cue at the hold time fires before the wait');
    ready = true;
    p.update(0.5);
    expect(p.time, closeTo(2.5, 1e-9), reason: 'the rest of the frame is spent past the hold');
    run(p, 1.5);
    expect(p.time, closeTo(4, 1e-9));
    run(p, 0.9);
    expect(p.time, 4);
    expect(p.timeouts, 0);
    run(p, 0.2);
    expect(p.timeouts, 1);
    expect(p.time, greaterThan(4));
    run(p, 3);
    expect(fired, [2, 3, 5]);
    expect(p.finished, isTrue);
  });

  test('total time is the scene length plus what holds waited', () {
    var frames = 0;
    final p = CutscenePlayer(Cutscene(name: 't', duration: 2, holds: [Hold(1, () => false, maxWait: 0.5)]));
    while (!p.finished) {
      p.update(1 / 60);
      frames++;
    }
    expect(frames / 60, closeTo(2.5, 2 / 60));
  });

  test('a generated line holds the scene until it lands, with a fallback on timeout', () async {
    final slow = Completer<String>();
    final fails = Completer<String>();
    final late = TextCue(1, 2, future: slow.future, hold: true, maxWait: 5, speaker: 'Clover');
    final broken = TextCue(4, 1, future: fails.future, hold: true, fallback: 'Hmm.');
    final never = TextCue(6, 1, future: Completer<String>().future, hold: true, maxWait: 1, fallback: 'Zzz.');
    final p = CutscenePlayer(Cutscene(name: 't', duration: 8, texts: [late, broken, never]));
    run(p, 2);
    expect(p.time, 1);
    expect(p.texts.single.$1, late);
    expect(p.texts.single.$2, 1, reason: 'a held line shows its "…" at full opacity');
    expect(late.text, isNull);
    slow.complete('The festival is on day five!');
    fails.completeError(StateError('model gone'));
    await Future<void>.delayed(Duration.zero);
    expect(late.text, 'The festival is on day five!');
    expect(broken.text, 'Hmm.');
    run(p, 1);
    expect(p.time, closeTo(2, 1e-6));
    run(p, 5.2);
    expect(never.text, 'Zzz.');
    expect(p.timeouts, 1);
  });

  test('skipping runs every remaining cue in order, releases holds and ends once', () {
    final fired = <String>[];
    final pending = TextCue(3, 1, future: Completer<String>().future, hold: true, fallback: 'later');
    final p = CutscenePlayer(
      Cutscene(
        name: 't',
        duration: 10,
        holds: [Hold(1, () => false, maxWait: 100)],
        texts: [pending],
        cues: [Cue(0, () => fired.add('start')), Cue(5, () => fired.add('middle')), Cue(9.9, () => fired.add('end'))],
      ),
    );
    var ended = 0;
    p.onEnd = () => ended++;
    run(p, 2);
    expect(fired, ['start']);
    p.skip();
    p.skip();
    expect(fired, ['start', 'middle', 'end']);
    expect(pending.text, 'later');
    expect(p.finished && p.skipped, isTrue);
    expect(ended, 1);
    expect(p.texts, isEmpty);
  });

  test('letterbox and fade follow their ramps', () {
    final p = CutscenePlayer(
      Cutscene(name: 't', duration: 10, letterbox: const [Ramp(0, 1, 0, 1), Ramp(8, 1, 1, 0)], fade: const [Ramp(0, 0.5, 1, 0)]),
    );
    expect(p.letterbox, 0);
    expect(p.fade, 1);
    p.update(0.5);
    expect(p.letterbox, closeTo(0.5, 1e-9));
    expect(p.fade, 0);
    p.update(3);
    expect(p.letterbox, 1);
    p.update(5);
    expect(p.letterbox, closeTo(0.5, 1e-9));
    p.update(1);
    expect(p.letterbox, 0);
  });
}

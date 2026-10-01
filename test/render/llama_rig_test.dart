import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/render/llama_rig.dart';
import 'package:vector_math/vector_math.dart' as vm;

void main() {
  group('lookAngles', () {
    // vector_math stores Float32s.
    final head = vm.Vector3(0, 1.5, 0);

    test('looks straight ahead at a target in front', () {
      final (yaw, pitch) = lookAngles(head: head, bodyYaw: 0, target: vm.Vector3(0, 1.5, -5));
      expect(yaw, closeTo(0, 1e-6));
      expect(pitch, closeTo(0, 1e-6));
    });

    test('turns the same way the body would to face the target', () {
      // A body turning by +yaw faces (-sin, 0, -cos): toward -X.
      final (yaw, _) = lookAngles(head: head, bodyYaw: 0, target: vm.Vector3(-3, 1.5, -3));
      expect(yaw, closeTo(math.pi / 4, 1e-6));
      final (right, _) = lookAngles(head: head, bodyYaw: 0, target: vm.Vector3(3, 1.5, -3));
      expect(right, closeTo(-math.pi / 4, 1e-6));
    });

    test('is relative to the body yaw', () {
      // Facing -X (yaw pi/2), a target at -X is straight ahead.
      final (yaw, _) = lookAngles(head: head, bodyYaw: math.pi / 2, target: vm.Vector3(-4, 1.5, 0));
      expect(yaw, closeTo(0, 1e-6));
    });

    test('pitches up toward a raised target and down toward a low one', () {
      final (_, up) = lookAngles(head: head, bodyYaw: 0, target: vm.Vector3(0, 1.9, -1));
      expect(up, closeTo(math.atan2(0.4, 1), 1e-6));
      final (_, down) = lookAngles(head: head, bodyYaw: 0, target: vm.Vector3(0, 0, -20));
      expect(down, lessThan(0));
    });

    test('clamps targets behind and far above to the limits', () {
      final (yaw, _) = lookAngles(head: head, bodyYaw: 0, target: vm.Vector3(-0.5, 1.5, 6), maxYaw: 1.1);
      expect(yaw, 1.1);
      final (_, pitch) = lookAngles(head: head, bodyYaw: 0, target: vm.Vector3(0, 30, -1), maxPitch: 0.5);
      expect(pitch, 0.5);
    });

    test('a target at the head itself gives no turn', () {
      expect(lookAngles(head: head, bodyYaw: 1, target: head.clone()), (0.0, 0.0));
    });
  });

  group('faceTargets', () {
    test('mood drives happy and sulky', () {
      expect(faceTargets(mood: 4, activity: 'idle', energy: 1).happy, greaterThan(0.8));
      expect(faceTargets(mood: 4, activity: 'idle', energy: 1).sulky, 0);
      expect(faceTargets(mood: -4, activity: 'idle', energy: 1).sulky, greaterThan(0.8));
      expect(faceTargets(mood: 0, activity: 'idle', energy: 1).sulky, 0);
    });

    test('low energy makes a llama sleepy and sleep shuts the eyes', () {
      expect(faceTargets(mood: 0, activity: 'idle', energy: 0.05).sleepy, greaterThan(0.8));
      expect(faceTargets(mood: 0, activity: 'idle', energy: 0.9).sleepy, 0);
      expect(faceTargets(mood: 0, activity: 'sleep', energy: 0.5).shut, 1);
    });

    test('a delighted reaction wins over a sulk, and the other way round', () {
      final pleased = faceTargets(mood: -4, activity: 'talk', energy: 1, delight: 1);
      expect(pleased.happy, 1);
      expect(pleased.sulky, 0);
      final annoyed = faceTargets(mood: 4, activity: 'talk', energy: 1, annoyance: 1);
      expect(annoyed.sulky, 1);
      expect(annoyed.happy, 0);
    });

    test('speaking opens the mouth, silence closes it', () {
      for (var p = 0.0; p < 7; p += 0.5) {
        expect(faceTargets(mood: 0, activity: 'talk', energy: 1, speaking: true, talkPhase: p).talk, inInclusiveRange(0.35, 1));
      }
      expect(faceTargets(mood: 0, activity: 'talk', energy: 1).talk, 0);
    });
  });

  group('mixFace', () {
    test('keeps the morph order of the glb', () {
      final m = mixFace(const FaceTargets(happy: 0.1, sulky: 0.2, surprised: 0.3, sleepy: 0.4, talk: 0.5), 0);
      expect(m.morphs, [0.1, 0.2, 0.3, 0.4, 0.5]);
      expect(llamaMorphs, ['Happy', 'Sulky', 'Surprised', 'Sleepy', 'Talk']);
    });

    test('a neutral face is open and a blink shuts it', () {
      expect(mixFace(const FaceTargets(), 0).lid, 0);
      expect(mixFace(const FaceTargets(), 1).lid, 1);
      expect(mixFace(const FaceTargets(), 0.5).lid, 0.5);
    });

    test('sleepy and sulky lower the lids part way', () {
      expect(mixFace(const FaceTargets(sleepy: 1), 0).lid, sleepyLid);
      expect(mixFace(const FaceTargets(sulky: 1), 0).lid, sulkyLid);
    });

    test('lids never pass shut however the expressions stack', () {
      for (final sleepy in [0.0, 0.5, 1.0]) {
        for (final sulky in [0.0, 0.5, 1.0]) {
          for (final surprised in [0.0, 1.0]) {
            for (final blink in [0.0, 0.3, 0.7, 1.0]) {
              final m = mixFace(FaceTargets(sleepy: sleepy, sulky: sulky, surprised: surprised), blink);
              expect(m.lid, inInclusiveRange(surprisedLid, 1.0));
              if (blink == 1) expect(m.lid, closeTo(1, 1e-9));
            }
          }
        }
      }
    });

    test('a blink stays a full blink on a sleepy, sulky face', () {
      final m = mixFace(const FaceTargets(sleepy: 1, sulky: 1), 1);
      expect(m.lid, closeTo(1, 1e-9));
    });

    test('surprise widens the eyes and gives way to a blink', () {
      expect(mixFace(const FaceTargets(surprised: 1), 0).lid, surprisedLid);
      final blinking = mixFace(const FaceTargets(surprised: 1), 1);
      expect(blinking.morphs[2], 0);
      expect(blinking.lid, closeTo(1, 1e-9));
    });

    test('asleep: eyes shut and no smile or talking', () {
      final m = mixFace(const FaceTargets(happy: 1, talk: 1, shut: 1), 0);
      expect(m.lid, 1);
      expect(m.morphs[0], 0);
      expect(m.morphs[4], 0);
    });
  });

  group('gaitMix', () {
    final spec = llamaSpecs['Mo']!;

    test('idles when still, walks at walking speed, gallops when running', () {
      final still = gaitMix(spec, 0);
      expect(still.idle, 1);
      final walking = gaitMix(spec, 1.0);
      expect(walking.walk, greaterThan(0.9));
      final running = gaitMix(spec, 6);
      expect(running.gallop, 1);
      for (final s in [0.0, 0.2, 0.5, 1.0, spec.runFrom, 3.0, 8.0]) {
        final m = gaitMix(spec, s);
        expect(m.idle + m.walk + m.gallop, closeTo(1, 1e-9));
      }
    });

    test('the walk plays at the speed its stride covers the ground', () {
      for (final s in llamaSpecs.values) {
        final natural = s.strideMetres / s.walkSeconds;
        expect(gaitMix(s, natural).walkRate, closeTo(1, 1e-9), reason: s.id);
      }
    });

    test('each llama has its own gait', () {
      final cadence = {for (final s in llamaSpecs.values) s.id: s.walkSeconds};
      expect(cadence['june']!, lessThan(cadence['pip']!));
      expect(cadence['pip']!, lessThan(cadence['mo']!));
      expect(cadence['bramble']!, greaterThan(cadence['clover']!));
      expect(cadence.values.toSet(), hasLength(5));
    });
  });

  test('Blinker blinks every few seconds and stays in range', () {
    final b = Blinker(3, 1);
    var blinks = 0;
    var wasShut = false;
    for (var i = 0; i < 60 * 60; i++) {
      final v = b.update(1 / 60);
      expect(v, inInclusiveRange(0, 1));
      final shut = v > 0.9;
      if (shut && !wasShut) blinks++;
      wasShut = shut;
    }
    expect(blinks, inInclusiveRange(12, 40));
  });

  test('approach is frame-rate independent', () {
    var a = 0.0, b = 0.0;
    for (var i = 0; i < 60; i++) {
      a = approach(a, 1, 3, 1 / 60);
    }
    for (var i = 0; i < 30; i++) {
      b = approach(b, 1, 3, 1 / 30);
    }
    expect(a, closeTo(b, 1e-9));
  });
}

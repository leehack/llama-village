import 'package:flutter_scene/scene.dart';
// The public library exports no way to build an Animation by hand.
// ignore: implementation_imports
import 'package:flutter_scene/src/animation.dart' show AnimationChannel, BindKey, PropertyResolver;
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/render/character_rig.dart';
import 'package:vector_math/vector_math.dart' as vm;

void main() {
  group('stepClips', () {
    late Node model;
    late Node bone;
    late AnimationClip clip;

    setUp(() {
      bone = Node(name: 'bone');
      model = Node(name: 'model')..add(bone);
      final slide = Animation(
        name: 'Slide',
        channels: [
          AnimationChannel(
            bindTarget: BindKey(nodeName: 'bone'),
            resolver: PropertyResolver.makeTranslationTimeline([0, 1], [vm.Vector3.zero(), vm.Vector3(1, 0, 0)]),
          ),
        ],
      );
      clip = model.createAnimationClip(slide)..loop = true;
    });

    test('advances a clip by game time at its playback rate', () {
      clip.playbackTimeScale = 2;
      for (var i = 0; i < 6; i++) {
        stepClips([clip], 1 / 60);
      }
      expect(clip.playbackTime, closeTo(0.2, 1e-9));
    });

    test('wraps a looping clip', () {
      stepClips([clip], 0.75);
      stepClips([clip], 0.5);
      expect(clip.playbackTime, closeTo(0.25, 1e-9));
    });

    test('is not moved by the scene tick, which carries wall time', () {
      stepClips([clip], 0.25);
      // An offline render spends ~0.3 s of wall time on each frame; the
      // scene's own tick must only pose the clip, not advance it.
      model.scenePrePass(0.3);
      expect(clip.playbackTime, closeTo(0.25, 1e-9));
      expect(bone.localTransform.getTranslation().x, closeTo(0.25, 1e-6));
    });

    test('skips missing clips', () {
      stepClips([null, clip], 0.1);
      expect(clip.playbackTime, closeTo(0.1, 1e-9));
    });
  });
}

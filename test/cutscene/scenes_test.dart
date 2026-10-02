import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/audio/soundscape.dart';
import 'package:llama_village/cutscene/festival_show.dart';
import 'package:llama_village/cutscene/scenes.dart';
import 'package:llama_village/cutscene/timeline.dart';

/// The music levels a scene scored with [music] asks for [seconds] in,
/// after the themes [before] it.
Map<String, double> levelsAt(Map<String, List<Ramp>> music, double seconds, {Map<String, double> before = const {}}) {
  final p = CutscenePlayer(Cutscene(name: 't', duration: 30, music: music))..update(seconds);
  return Soundscape.mix(16.2, storm: false, themes: {...before, ...p.music});
}

void main() {
  test('the festival loop takes over from the day loop while the title comes up', () {
    expect(levelsAt(festivalMusic, 0)['music_day'], 1);
    final title = festivalMusic['music_festival']!.single;
    expect(title.at, greaterThanOrEqualTo(0));
    expect(title.at + title.duration, lessThanOrEqualTo(FestivalShow.audienceIn), reason: 'done before the first singer');
    final mid = levelsAt(festivalMusic, title.at + title.duration / 2);
    expect(mid['music_festival'], closeTo(0.5, 1e-9));
    expect(mid['music_day'], closeTo(0.5, 1e-9));
    final on = levelsAt(festivalMusic, FestivalShow.audienceIn);
    expect(on['music_festival'], 1);
    expect(on['music_day'], 0);
  });

  test("the ending theme fades in step with the harmony ending's sky going to dusk", () {
    const after = {'music_festival': 1.0};
    expect(levelsAt(endingMusic, 0, before: after)['music_festival'], 1, reason: 'picks up where the festival left off');
    for (var t = 0.0; t <= 8; t += 0.25) {
      final sky = applyEase(Ease.inOut, t / 6);
      final levels = levelsAt(endingMusic, t, before: after);
      expect(levels['music_ending'], closeTo(sky, 1e-9), reason: 'at $t s');
      expect(levels['music_festival'], closeTo(1 - sky, 1e-9));
    }
    expect(levelsAt(endingMusic, 17, before: after)['music_ending'], 1, reason: 'and holds for the epilogue');
  });
}

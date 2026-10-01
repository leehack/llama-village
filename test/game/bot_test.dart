import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/game/bot.dart';
import 'package:llama_village/sim/canned.dart';
import 'package:llama_village/sim/endings.dart';
import 'package:llama_village/sim/influence.dart';
import 'package:llama_village/sim/village.dart';

import '../sim/harness.dart';

/// Plays the whole week headless at 1x pacing (one game minute per 500 ms
/// step, so Dash flies at its real speed) until the festival is judged.
Future<(Village, PlayerBot)> playWeek(BotPreset preset, int seed) async {
  final v = Village(chat: CannedChat(), embed: HashEmbed(), seed: seed, msPerMinute: 500, autoAck: true);
  final bot = PlayerBot(preset);
  await v.begin();
  for (var steps = 0; !v.weekOver && steps < 20000; steps++) {
    v.advance(500);
    await settle();
    bot.tick(v);
  }
  return (v, bot);
}

void main() {
  const expected = {BotPreset.harmony: Ending.harmonyFestival, BotPreset.drama: Ending.dramaLlama, BotPreset.quiet: Ending.quietValley};
  for (final preset in BotPreset.values) {
    for (final seed in [1, 2]) {
      test('the ${preset.name} bot reaches ${expected[preset]!.name} (seed $seed)', () async {
        final (v, bot) = await playWeek(preset, seed);
        expect(v.festival.state, 'judged');
        final verdict = decideEnding(measure(v));
        expect(verdict.ending, expected[preset], reason: '${measure(v).toJson()} ${verdict.reasons}');
        if (preset == BotPreset.quiet) {
          expect(bot.visits, 0);
        } else {
          expect(bot.picks, isNotEmpty);
        }
      }, timeout: const Timeout(Duration(minutes: 3)));
    }
  }

  test('presets parse from their names', () {
    expect(botPresetFrom('drama'), BotPreset.drama);
    expect(botPresetFrom('nope'), isNull);
    expect(botPresetFrom(null), isNull);
  });
}

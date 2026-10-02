import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/game/bot.dart';
import 'package:llama_village/sim/canned.dart';
import 'package:llama_village/sim/clock.dart';
import 'package:llama_village/sim/model.dart';
import 'package:llama_village/sim/rng.dart';
import 'package:llama_village/sim/session.dart';
import 'package:llama_village/sim/village.dart';

import 'harness.dart';

/// Canned answers that land a few steps after they are asked, like a real
/// model writing beside the game loop, streaming as they go.
class _SlowChat implements ChatModel {
  final CannedChat canned = CannedChat();
  final SimRandom rng = SimRandom(3);
  final List<(int, Completer<String>, String, void Function(String)?)> waiting = [];
  int step = 0;

  @override
  Future<String> complete(
    String system,
    String user, {
    required int maxTokens,
    required double temp,
    required int seed,
    List<String> stop = const [],
    Map<String, dynamic>? jsonSchema,
    void Function(String text)? onText,
  }) async {
    final out = await canned.complete(system, user, maxTokens: maxTokens, temp: temp, seed: seed, stop: stop, jsonSchema: jsonSchema);
    final c = Completer<String>();
    waiting.add((step + 1 + rng.nextInt(24), c, out, onText));
    return c.future;
  }

  Future<void> land() async {
    for (final w in waiting.where((w) => w.$1 <= step).toList()) {
      waiting.remove(w);
      w.$4?.call(w.$3.substring(0, w.$3.length ~/ 2));
      w.$2.complete(w.$3);
      await settle();
    }
    step++;
  }
}

/// Plays day 1 to midday on day 2 with the harmony bot on 60 Hz steps,
/// calling [between] after every step.
Future<Village> _play(ChatModel chat, EmbedModel embed, Future<void> Function() between, {SessionRecorder? rec, SessionReplay? rep}) async {
  final v = Village(chat: chat, embed: embed, seed: 5, msPerMinute: 50, autoAck: true);
  rec?.attach(v);
  rep?.attach(v);
  final bot = PlayerBot(BotPreset.harmony)..thinkMs = 1200;
  var begun = false;
  unawaited(v.begin().then((_) => begun = true));
  while (!begun) {
    await between();
  }
  while (v.now.compareTo(const GameTime(2, 12 * 60)) < 0) {
    v.advance(1000 / 60);
    bot.tick(v);
    rec?.checkpoint(v);
    rep?.verify(v);
    await between();
  }
  // Let follow-up calls of the last answers be asked on both sides.
  await settle();
  await settle();
  return v;
}

void main() {
  test('a recorded game replays step for step with no model', () async {
    final slow = _SlowChat();
    final rec = SessionRecorder(meta: {'seed': 5});
    final recorded = await _play(rec.chat(slow), rec.embed(HashEmbed()), slow.land, rec: rec);
    expect(recorded.dash.visit != null || recorded.done.isNotEmpty, isTrue);

    final file = jsonDecode(jsonEncode(rec.toJson())) as Map<String, Object?>;
    final replay = SessionReplay(file);
    expect(replay.meta['seed'], 5);
    final replayed = await _play(replay, replay, () async {
      await replay.pump();
      await settle();
    }, rep: replay);

    expect(replay.mismatches, 0);
    expect(replay.unrecorded, 0);
    expect(replay.skipped, 0);
    expect(replay.checkpointsSeen, greaterThan(20));
    expect(replay.checkpointMisses, 0);
    expect(replayed.rng.stateHex, recorded.rng.stateHex);
    expect([for (final e in replayed.log.entries) e.text], [for (final e in recorded.log.entries) e.text]);
    expect(replayed.lines.map((l) => l.text).toList(), recorded.lines.map((l) => l.text).toList());
    expect(recorded.lines, isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('a call asked late in a pause still gets its answer', () async {
    final rec = SessionRecorder(meta: {});
    final chat = rec.chat(CannedChat());
    await chat.complete('s', 'first', maxTokens: 8, temp: 0.5, seed: 1);
    await chat.complete('s', 'second', maxTokens: 8, temp: 0.5, seed: 2);
    final replay = SessionReplay(jsonDecode(jsonEncode(rec.toJson())) as Map<String, Object?>);
    final first = replay.complete('s', 'first', maxTokens: 8, temp: 0.5, seed: 1);
    for (var i = 0; i < 2000; i++) {
      await replay.pump();
    }
    expect(await first, isA<String>());
    final second = replay.complete('s', 'second', maxTokens: 8, temp: 0.5, seed: 2);
    await replay.pump();
    expect(await second, isA<String>());
    expect(replay.skipped, 0);
    expect(replay.mismatches, 0);
  });

  test('vectors keep every bit through the file', () {
    expect(decodeVector(encodeVector([0.5, -1.25, 3])), [0.5, -1.25, 3]);
    final odd = [0.1, 1 / 3];
    expect(encodeVector(odd), startsWith('d:'));
    expect(decodeVector(encodeVector(odd)), odd);
  });

  test('a replay counts a prompt it does not have', () async {
    final rec = SessionRecorder(meta: {});
    final chat = rec.chat(CannedChat());
    await chat.complete('s', 'hello', maxTokens: 8, temp: 0.5, seed: 1);
    final replay = SessionReplay(jsonDecode(jsonEncode(rec.toJson())) as Map<String, Object?>);
    final out = replay.complete('s', 'something else', maxTokens: 8, temp: 0.5, seed: 1);
    await replay.pump();
    expect(await out, isA<String>());
    expect(replay.mismatches, 1);
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/sim/canned.dart';
import 'package:llama_village/sim/clock.dart';
import 'package:llama_village/sim/snapshot.dart';
import 'package:llama_village/sim/village.dart';

import 'harness.dart';

final DateTime _at = DateTime.utc(2026, 10, 1, 12);

Village _fresh() => testVillage(seed: 999);

/// Saves [v], sends the save through JSON text as the store would, and
/// loads it into a fresh village.
Village _reload(Village v) {
  final text = jsonEncode(snapshotVillage(v, at: _at));
  final copy = _fresh();
  restoreVillage(copy, decodeSave(text));
  return copy;
}

String _save(Village v) => jsonEncode(snapshotVillage(v, at: _at));

void main() {
  test('a mid-week save loads back to the same state', () async {
    final v = testVillage(seed: 21);
    await v.begin();
    await runMinutes(v, 9 * 60);
    final june = v.byName('June');
    final options = await v.dash.talk(june);
    for (var i = 0; i < 400 && v.dash.visit?.stage.name != 'choosing'; i++) {
      v.advance(20);
      await settle();
    }
    v.dash.choose(options.indexWhere((o) => o.intent == 'gossip').clamp(0, options.length - 1));
    await settle();
    await runMinutes(v, 120);

    expect(v.embed.cache, isNotEmpty, reason: 'conversations embed what was said');
    expect(v.kb.transfers, isNotEmpty);
    expect(v.cast.any((l) => l.diary.isNotEmpty), isTrue);
    expect(v.cast.any((l) => l.topicsRaised.isNotEmpty), isTrue, reason: 'the topics raised are saved, so none repeats after a load');

    final copy = _reload(v);
    expect(_save(copy), _save(v));
    expect(copy.now, v.now);
    expect(copy.rng.state, v.rng.state);
    expect(copy.kb.facts.keys, v.kb.facts.keys);
    expect(copy.embed.cache.length, v.embed.cache.length);
    expect(copy.festival.contestants, v.festival.contestants);
    expect(copy.log.entries.length, v.log.entries.length.clamp(0, 300));
    expect(copy.dash.inventory, v.dash.inventory);
  });

  test('a loaded village plays on exactly like the original', () async {
    final v = testVillage(seed: 8);
    await v.begin();
    while (v.now.compareTo(const GameTime(1, 23 * 60)) < 0 || v.active.isNotEmpty || !v.chat.queue.idle) {
      await runMinutes(v, 1);
      // At 10 ms a game minute a chat can outlast the night; the night skip
      // ends it the same way.
      if (v.now.compareTo(const GameTime(1, 23 * 60)) >= 0) v.abandonConversations();
    }
    expect(v.active, isEmpty);
    final copy = _reload(v);
    await runMinutes(v, 300);
    await runMinutes(copy, 300);
    expect(copy.now.day, 2, reason: 'through the planning hold and into the morning');
    expect(copy.log.entries.any((e) => e.text.contains('Morning of day 2')), isTrue);
    expect(_save(copy), _save(v));
  });

  test('conversations in flight are not saved: their llamas come back idle', () async {
    final v = testVillage(seed: 3, autoAck: false);
    await v.begin();
    for (var i = 0; i < 600 && v.active.isEmpty; i++) {
      await runMinutes(v, 1);
    }
    final talking = v.active.first.a;
    expect(talking.activity.kind, 'talk');
    final copy = _reload(v);
    expect(copy.byName(talking.name).activity.kind, 'idle');
    expect(copy.active, isEmpty);
  });

  test('a damaged or foreign save fails with a SaveException, never a crash', () {
    expect(() => decodeSave('{"game": "llama_village", "vers'), throwsA(isA<SaveException>()));
    expect(() => decodeSave(''), throwsA(isA<SaveException>()));
    expect(() => decodeSave('[1, 2, 3]'), throwsA(isA<SaveException>()));
    expect(() => decodeSave('{"game": "other", "version": 1}'), throwsA(isA<SaveException>()));
    expect(
      () => decodeSave('{"game": "llama_village", "version": 99}'),
      throwsA(isA<SaveException>().having((e) => e.message, 'message', contains('version 99'))),
    );

    final good = snapshotVillage(_fresh(), at: _at);
    final text = jsonEncode(good);
    expect(() => decodeSave(text.substring(0, text.length ~/ 2)), throwsA(isA<SaveException>()));
    for (final key in ['cast', 'kb', 'threads', 'rng', 'core', 'embeddings']) {
      final broken = jsonDecode(text) as Map<String, Object?>;
      broken[key] = 'garbage';
      expect(() => restoreVillage(_fresh(), broken), throwsA(isA<SaveException>()), reason: key);
    }
    final noCast = jsonDecode(text) as Map<String, Object?>..remove('cast');
    expect(() => restoreVillage(_fresh(), noCast), throwsA(isA<SaveException>()));
  });

  test('embeddings round-trip exactly through the float32 encoding', () async {
    final v = Village(chat: CannedChat(), embed: HashEmbed(), seed: 1, msPerMinute: 10);
    await v.embed.embed(['Mo bakes bread at dawn.', 'The scarf is in the pond reeds.']);
    final copy = _reload(v);
    expect(copy.embed.cache, v.embed.cache);
  });
}

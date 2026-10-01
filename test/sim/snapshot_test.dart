import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/sim/canned.dart';
import 'package:llama_village/sim/cast.dart';
import 'package:llama_village/sim/clock.dart';
import 'package:llama_village/sim/log.dart';
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

  test('a conversation in progress is saved with what was said and finishes after a load', () async {
    final v = testVillage(seed: 3);
    await v.begin();
    for (var i = 0; i < 900 && !v.active.any((c) => c.shown >= 1 && c.shown < c.lines.length); i++) {
      await runMinutes(v, 1);
    }
    final c = v.active.firstWhere((c) => c.shown >= 1 && c.shown < c.lines.length);
    final said = [for (final l in c.lines) l.text];

    final copy = _reload(v);
    expect(_save(copy), _save(v));
    final resumed = copy.active.single;
    expect(resumed.id, c.id);
    expect([for (final l in resumed.lines) l.text], said);
    expect(copy.byName(c.a.name).activity.kind, 'talk');
    expect(copy.byName(c.b.name).activity.with_, c.a.name);

    for (var i = 0; i < 900 && copy.active.isNotEmpty; i++) {
      await runMinutes(copy, 1);
    }
    final ended = copy.done.firstWhere((d) => d.id == c.id);
    expect([for (final l in ended.lines) l.text], said);
    final logged = [for (final e in copy.log.entries.where((e) => e.kind == LogKind.line)) e.text];
    for (final l in ended.lines.skip(c.shown + 1)) {
      expect(logged, contains('${l.speaker}: "${l.text}"'), reason: 'the lines not yet shown are said after the load');
    }
    expect(copy.byName(c.a.name).diary.where((d) => d.$1 == c.start), hasLength(1), reason: 'the outcome is recorded once');
  });

  test('a conversation saved mid-generation writes its remaining turns and outcome after a load', () async {
    final v = testVillage(seed: 3);
    await v.begin();
    for (var i = 0; i < 900 && !v.active.any((c) => c.shown >= 1); i++) {
      await runMinutes(v, 1);
    }
    final save = jsonDecode(_save(v)) as Map<String, Object?>;
    final talk = (save['talks'] as List).first as Map<String, Object?>;
    final first = ((talk['lines'] as List).first as Map)['text'];
    // How a save taken while the second line was being written looks.
    talk
      ..['lines'] = (talk['lines'] as List).take(1).toList()
      ..['shown'] = 1
      ..['generationDone'] = false
      ..['outcomeDone'] = false
      ..['friendship'] = <String, int>{}
      ..['mood'] = <String, int>{};
    final copy = _fresh();
    restoreVillage(copy, decodeSave(jsonEncode(save)));
    final id = talk['id'] as int;
    final a = copy.byName(talk['a'] as String);
    final diary = a.diary.length;

    for (var i = 0; i < 900 && copy.active.isNotEmpty; i++) {
      await runMinutes(copy, 1);
    }
    final ended = copy.done.firstWhere((d) => d.id == id);
    expect(ended.lines, hasLength(ended.turns));
    expect(ended.lines.first.text, first);
    expect(ended.friendshipDelta.keys, containsAll([ended.a.name, ended.b.name]));
    expect(a.diary.length, greaterThan(diary));
  });

  test('a llama talking with Dash comes back idle: the visit is not saved', () async {
    final v = testVillage(seed: 21);
    await v.begin();
    bool free(Llama l) => !l.busyTalking && !l.asleep && l.activity.kind != 'walk';
    await runMinutes(v, 3 * 60);
    for (var i = 0; i < 600 && !v.cast.any(free); i++) {
      await runMinutes(v, 1);
    }
    final l = v.cast.firstWhere(free);
    await v.dash.talk(l);
    for (var i = 0; i < 400 && v.dash.visit?.stage.name != 'choosing'; i++) {
      v.advance(20);
      await settle();
    }
    expect(l.activity.with_, 'Dash');
    final copy = _reload(v);
    expect(copy.byName(l.name).activity.kind, 'idle');
    expect(copy.dash.visit, isNull);
  });

  test('playtime is saved, and a save from before playtime and saved conversations still loads', () async {
    final v = testVillage(seed: 3);
    await v.begin();
    v.playtime = 754.5;
    expect(_reload(v).playtime, 754.5);

    for (var i = 0; i < 900 && v.active.isEmpty; i++) {
      await runMinutes(v, 1);
    }
    final old = jsonDecode(_save(v)) as Map<String, Object?>
      ..remove('playtime')
      ..remove('talks');
    final copy = _fresh();
    restoreVillage(copy, decodeSave(jsonEncode(old)));
    expect(copy.playtime, 0);
    expect(copy.active, isEmpty);
    expect(copy.now, v.now);
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

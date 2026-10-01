import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/sim/canned.dart';
import 'package:llama_village/sim/cast.dart';
import 'package:llama_village/sim/clock.dart';
import 'package:llama_village/sim/dialogue.dart';
import 'package:llama_village/sim/village.dart';
import 'package:llama_village/sim/week.dart';

import 'harness.dart';

void main() {
  test('day labels count down to the festival', () {
    expect(dayLabel(1), '4 days to the festival');
    expect(dayLabel(4), 'the day before the festival');
    expect(dayLabel(festivalDay), 'Berry Festival day');
    expect(dayLabel(festivalDay + 1), 'after the festival');
  });

  test('the week plays out on its days and ends with the festival on day $festivalDay', () async {
    final v = testVillage(seed: 5);
    await v.begin();
    while (!v.weekOver) {
      await runMinutes(v, 30);
    }
    int dayOf(String id) => v.kb[id].created.day;
    expect(dayOf('festival'), 1);
    expect(dayOf('scarf_missing'), 1);
    expect(dayOf('anon_poem'), 2);
    expect(dayOf('honey_loaf'), 2);
    expect(dayOf('storm_hit'), stormDay);
    expect(dayOf('rehearsal'), 4);
    expect(dayOf('lanterns'), festivalDay);
    expect(v.storm_.state, 'passed');
    expect(v.festival.state, 'judged');
    expect(v.now.day, festivalDay);
    expect(v.now.minute, inInclusiveRange(festivalMinute + 25, festivalMinute + 55));
    expect(v.festival.performances.map((p) => p.$1), containsAll(v.festival.scores.keys));
    expect(v.week.state, 'day $festivalDay');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('the night skip runs the night at once and holds at 05:59 until the plans are written', () async {
    final v = testVillage();
    await v.begin();
    v.now = const GameTime(1, 21 * 60 + 30);
    final dawn = const GameTime(2, 6 * 60);
    expect(v.skipTo(dawn), isFalse);
    expect(v.now.hhmm, '05:59');
    expect(v.planning, isTrue);
    expect(v.cast.every((l) => l.reflections.isEmpty), isTrue, reason: 'reflections are still being written');
    await settle();
    expect(v.skipTo(dawn), isTrue);
    expect(v.now, dawn);
    expect(v.cast.every((l) => l.reflections.length == 1 && l.reflectedDay == 1), isTrue);
    expect(v.log.entries.any((e) => e.text.contains('Morning of day 2')), isTrue);
  });

  test('the debug jump reaches a later morning with rule-made plans', () async {
    final v = testVillage();
    await v.begin();
    await v.jumpTo(festivalDay);
    expect(v.now, const GameTime(festivalDay, 6 * 60));
    expect(v.offline, isFalse);
    expect(v.festival.state, isNot('unannounced'));
    expect(v.storm_.state, 'passed');
    expect(v.cast.every((l) => l.schedule.length == 8), isTrue);
    expect(v.done, isEmpty, reason: 'nobody talks during the jump');
  });

  test('a night skip cuts conversations short: nobody keeps talking and no more lines come', () async {
    final v = Village(
      chat: CannedChat(delay: const Duration(milliseconds: 20)),
      embed: HashEmbed(),
      seed: 3,
      msPerMinute: 10,
    );
    await v.begin();
    for (var i = 0; i < 2000 && v.active.isEmpty; i++) {
      v.advance(10);
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    final c = v.active.first;
    expect(c.generationDone, isFalse);
    final said = c.lines.length;
    v.abandonConversations();
    expect(v.active, isEmpty);
    expect(c.a.activity.kind, 'idle');
    expect(c.b.activity.kind, 'idle');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(c.lines.length, lessThanOrEqualTo(said + 1), reason: 'at most the line already being written lands');
    expect(c.generationDone, isFalse);
    expect(c.outcomeDone, isFalse);
  });

  test('before the festival, chats elsewhere break off and Dash cannot hold anyone back', () async {
    final v = Village(
      chat: CannedChat(delay: Duration.zero),
      embed: HashEmbed(),
      seed: 3,
      msPerMinute: 500,
      autoAck: true,
    );
    await v.begin();
    await v.jumpTo(festivalDay);
    // A chat away from the hilltop, caught as it starts: no line is written
    // yet, and none can be during the synchronous skip, so it cannot end by
    // itself before the call.
    const call = GameTime(festivalDay, festivalCall);
    var away = <Conversation>[];
    for (var i = 0; i < 4000 && away.isEmpty && v.now.compareTo(call) < 0; i++) {
      v.advance(500);
      away = v.active.where((c) => c.place != 'hilltop' && !c.generationDone).toList();
      if (away.isEmpty) await Future<void>.delayed(Duration.zero);
    }
    expect(away, isNotEmpty);
    final mo = v.byName('Mo');
    v.skipTo(call);
    for (final c in away) {
      expect(c.abandoned, isTrue);
      expect(v.active, isNot(contains(c)));
    }
    mo
      ..place = 'bakery'
      ..activity = Activity('idle', v.now);
    expect(await v.dash.talk(mo), isEmpty, reason: 'festival rush');
    expect(v.dash.notice!.english, contains('hurrying'));
  });
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/sim/cast.dart';
import 'package:llama_village/sim/clock.dart';
import 'package:llama_village/sim/canned.dart';
import 'package:llama_village/sim/dash.dart';
import 'package:llama_village/sim/dialogue.dart';
import 'package:llama_village/sim/log.dart';
import 'package:llama_village/sim/village.dart';

import 'harness.dart';

void main() {
  test('a full day runs: plans, conversations, story events, bedtime', () async {
    final v = testVillage();
    await v.begin();
    expect(v.cast.every((l) => l.schedule.length >= 5), isTrue);
    await runMinutes(v, 16 * 60);
    expect(v.now.label, 'D1 22:00');
    expect(v.done, isNotEmpty);
    expect(v.festival.state, isNot('unannounced'));
    expect(v.kb.maybe('scarf_missing'), isNotNull);
    expect(v.storm_.state, 'forecast', reason: 'the storm is due on day $stormDay');
    expect(v.log.entries.where((e) => e.kind == LogKind.line), isNotEmpty);
    await runMinutes(v, 30);
    expect(v.cast.where((l) => l.place == l.home && l.asleep).length, greaterThanOrEqualTo(4));
  });

  test('the night fast-forwards and the next morning starts with fresh plans', () async {
    final v = testVillage();
    await v.begin();
    v.now = v.now.plus(16 * 60 - 1);
    await runMinutes(v, 8 * 60 + 2);
    expect(v.now.day, 2);
    expect(v.now.minute, greaterThanOrEqualTo(6 * 60));
    expect(v.planning, isFalse);
    expect(v.log.entries.any((e) => e.text.contains('Morning of day 2')), isTrue);
  });

  test('pause stops the clock and time scale speeds it up', () async {
    final v = testVillage();
    await v.begin();
    v.paused = true;
    v.advance(1000);
    expect(v.now.minute, 6 * 60);
    v.paused = false;
    v.timeScale = 4;
    v.advance(10);
    await settle();
    expect(v.now.minute, 6 * 60 + 4);
  });

  test('a conversation waits for the bubble acknowledgement', () async {
    final v = testVillage(autoAck: false);
    await v.begin();
    for (var i = 0; i < 600 && v.speech.values.every((s) => s.text == null || s.kind != SpeechKind.say); i++) {
      await runMinutes(v, 1);
    }
    final shown = v.speech.values.firstWhere((s) => s.text != null && s.kind == SpeechKind.say);
    final c = v.active.firstWhere((c) => c.a.name == shown.who || c.b.name == shown.who);
    expect(c.awaitingAck, isNotNull);
    v.advance(100);
    expect(c.awaitingAck, isNotNull, reason: 'no ack yet and the timeout has not passed');
    v.ackBubble(shown.id);
    v.advance(1);
    expect(c.awaitingAck, isNull);
    expect(shown.shownAtMs, isNotNull);
    expect(c.freeAtMs, closeTo(shown.shownAtMs! + v.displayFor(shown.text!), 1e-6));
  });

  test('a bubble the UI never acknowledges is counted as shown after the timeout', () async {
    final v = Village(chat: CannedChat(), embed: HashEmbed(), seed: 3, msPerMinute: 1000000);
    await v.begin();
    final mo = v.byName('Mo');
    v.think(mo);
    await settle();
    final s = v.speech['Mo']!;
    expect(s.text, isNotNull);
    v.advance(ackTimeoutMs + 1);
    expect(s.shownAtMs, isNotNull);
  });

  test('Dash flies to a llama, gets prefetched options, chooses, and the reply applies effects', () async {
    final v = testVillage();
    await v.begin();
    final june = v.byName('June');
    final before = june.friendship['Dash'];
    final options = v.dash.talk(june);
    expect(v.dash.visit!.stage, VisitStage.flying);
    final list = await options;
    expect(list.length, inInclusiveRange(3, 4));
    for (var i = 0; i < 400 && v.dash.visit?.stage != VisitStage.choosing; i++) {
      v.advance(20);
      await settle();
    }
    expect(v.dash.visit!.stage, VisitStage.choosing);
    expect(june.activity.with_, 'Dash');
    v.dash.choose(0);
    expect(v.speech['Dash']?.text, list.first.text);
    await settle();
    v.advance(1);
    final visit = v.dash.visit!;
    expect(visit.stage, VisitStage.done);
    expect(visit.reply, isNotNull);
    expect(v.speech['June']?.text, visit.reply);
    expect(june.friendship['Dash'], isNot(before ?? -99));
    v.dash.leave();
    expect(june.activity.kind, 'idle');
  });

  test('Dash keeps flying beside a walking llama instead of stopping and hopping to catch up', () async {
    // Real time: a game minute is 500 ms, stepped at 60 Hz.
    final v = Village(chat: CannedChat(), embed: HashEmbed(), seed: 11, autoAck: true);
    await v.begin();
    v.offline = true;
    final june = v.byName('June')
      ..place = "June's hut"
      ..activity = Activity('walk', v.now.plus(60), dest: 'hilltop', start: v.now);
    unawaited(v.dash.talk(june));
    var frames = 0;
    for (var i = 0; i < 600 && v.dash.visit?.stage != VisitStage.waiting; i++) {
      v.advance(1000 / 60);
      await settle();
    }
    expect(v.dash.visit!.stage, VisitStage.waiting);
    // Hovering while June walks right past is fine; stopping for a few
    // frames, then catching up in one jump, is the stutter.
    var run = 0, shortest = 1 << 30, stops = 0;
    var was = v.dash.moving;
    for (; frames < 240 && june.activity.kind == 'walk'; frames++) {
      v.advance(1000 / 60);
      final moving = v.dash.moving;
      if (moving == was) {
        run++;
      } else {
        if (!was) shortest = math.min(shortest, run);
        if (!moving) stops++;
        run = 1;
      }
      was = moving;
    }
    expect(frames, 240);
    expect(stops, lessThanOrEqualTo(2), reason: 'Dash stopped $stops times in 4 s');
    expect(shortest, greaterThanOrEqualTo(20), reason: 'Dash stopped for only $shortest frames');
    expect(v.dash.moving, isTrue);
  });

  test('Dash moves to a place and is present there', () async {
    final v = testVillage();
    await v.begin();
    v.dash.moveTo('pond');
    for (var i = 0; i < 300 && v.dash.place != 'pond'; i++) {
      v.advance(20);
    }
    expect(v.dash.place, 'pond');
    expect(v.presentAt('pond'), contains('Dash'));
  });

  test('a sleeping llama does not take a visit', () async {
    final v = testVillage();
    await v.begin();
    final mo = v.byName('Mo')..activity = Activity('sleep', v.now.plus(600));
    expect(await v.dash.talk(mo), isEmpty);
    expect(v.dash.notice!.english, contains('asleep'));
  });

  test('the inspector shows persona, needs, knowledge with how it was learned, and decision utilities', () async {
    final v = testVillage();
    await v.begin();
    await runMinutes(v, 100);
    final pip = v.inspect('Pip');
    expect(pip.llama.traits, contains('vain'));
    expect(pip.knows.map((k) => k.how), contains('heard from June; maybe untrue'));
    expect(pip.knows.firstWhere((k) => k.text.contains('cannot hold a tune')).how, 'own secret');
    expect(pip.llama.lastDecision!.options, isNotEmpty);
    final u = pip.llama.lastDecision!.options.map((o) => o.utility).toList();
    expect(u, orderedEquals([...u]..sort((a, b) => b.compareTo(a))));
    expect(pip.goals, isNotEmpty);
  });

  test('a llama does not keep bringing up the same topic: not twice to one listener, and less often to everyone', () async {
    final v = testVillage()..now = const GameTime(2, 10 * 60);
    v.kb.learn('Bramble', 'bread_rumour', 'told', v.now, from: 'Pip', believes: false);
    final bramble = v.byName('Bramble');
    Future<String?> talk(String to) async {
      final c = Conversation(0, bramble, v.byName(to), bramble.place, v.now, 0);
      await v.pickTopic(c);
      v.now = v.now.plus(20);
      return c.topic;
    }

    final listeners = ['Pip', 'Pip', 'Clover', 'June', 'Mo', 'Clover'];
    final topics = [for (final to in listeners) await talk(to)];
    // Bramble's two strong goals (the storm warning, setting the bread
    // rumour straight) lead, but nothing is told twice to one listener
    // and the talk moves on to other things.
    expect(topics.take(4), containsAll(['storm_forecast', 'bread_truth']));
    final pairs = [for (var k = 0; k < topics.length; k++) (listeners[k], topics[k])];
    expect(pairs.toSet(), hasLength(pairs.length));
    expect(topics.toSet().length, greaterThanOrEqualTo(4));
    expect(bramble.topicsRaised, hasLength(topics.length));
  });
}

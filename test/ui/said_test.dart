import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/game/bot.dart';
import 'package:llama_village/l10n/app_localizations.dart';
import 'package:llama_village/sim/canned.dart';
import 'package:llama_village/sim/endings.dart';
import 'package:llama_village/sim/epilogue.dart';
import 'package:llama_village/sim/influence.dart';
import 'package:llama_village/sim/lang.dart';
import 'package:llama_village/sim/said.dart';
import 'package:llama_village/sim/storybook.dart';
import 'package:llama_village/sim/village.dart';
import 'package:llama_village/ui/strings.dart';

import '../sim/harness.dart';

final L10n en = lookupL10n(const Locale('en'));
final L10n ko = lookupL10n(const Locale('ko'));
final L10n fr = lookupL10n(const Locale('fr'));

/// Latin words left in Korean text once names and numbers are taken out.
List<String> _latinIn(String text) =>
    RegExp(r'[A-Za-z]{2,}')
        .allMatches(text.replaceAll(RegExp(r'\b(Pip|Mo|June|Bramble|Clover|Dash)\b'), ''))
        .map((m) => m.group(0)!)
        .toList();

/// English words that would give away an untranslated French sentence.
final RegExp _english = RegExp(r"\b(the|and|with|was|from|about|his|her|their|she|he|who|after|now|knows)\b");

Map<String, Object?> _sample(SaidKey key) => {
  'name': 'June',
  'a': 'Pip',
  'b': 'Mo',
  'place': 'pond',
  'names': ['Pip', 'Mo'],
  'seen': ['Clover'],
  'day': 3,
  'count': 2,
  'fact': 'pip_tune',
  'short': "Pip's secret singing",
  'title': const Said(SaidKey.stormTitle, 'Storm'),
  'text': const Said(SaidKey.storm, 'Thunder.'),
  'why': const Said(SaidKey.whySkyCleared, 'the sky cleared'),
  'how': key == SaidKey.storyTalk || key == SaidKey.storyTalkAbout ? 'warm' : const Said(SaidKey.howFair, 'judged'),
  'level': 3,
  'effects': [
    const Said(SaidKey.dashEffect, 'x', {'kind': 'work', 'name': 'Mo'}),
  ],
  'thread': 'scarf',
  'from': 'Mo',
  'to': 'poem found',
  'outcome': 'accepted',
  'pct': 40,
  'v': '0.50',
  'thought': '…',
  'scores': 'June 1.20',
  'reaction': 'pleased',
  'intent': 'gift',
  'about': 'Mo',
  'item': 'a red ribbon',
  'arc': 'rift',
  'ending': 'dramaLlama',
  'overheard': 'yes',
  'untrue': 'yes',
  'doubts': 'no',
  if (key == SaidKey.dashEffect) ...{'kind': 'trust', 'delta': 1, 'now': 2, 'mood': 1},
};

/// Every sentence the sim showed the player over a week: the log, the
/// storybook journal, the knowledge base, and the inspector's goals and
/// reasons sampled each game hour.
Future<List<Said>> _weekOfSaids(BotPreset preset, int seed) async {
  final v = Village(chat: CannedChat(), embed: HashEmbed(), seed: seed, msPerMinute: 500, autoAck: true);
  final bot = PlayerBot(preset);
  final out = <Said>[];
  await v.begin();
  for (var steps = 0; !v.weekOver && steps < 20000; steps++) {
    v.advance(500);
    await settle();
    bot.tick(v);
    if (v.now.minute % 60 == 0) {
      for (final l in v.cast) {
        final inspector = v.inspect(l.name);
        out
          ..addAll(inspector.goals)
          ..addAll([for (final o in l.lastDecision?.options ?? const []) o.why]);
      }
    }
  }
  final i = measure(v);
  out
    ..addAll([for (final e in v.log.entries) ?e.said])
    ..addAll([for (final b in v.journal.beats) b.said])
    ..addAll([for (final f in v.kb.facts.values) f.said])
    ..addAll(endingFacts(v, i, decideEnding(i)));
  return out;
}

void main() {
  test('every template says itself in English, Korean and French', () {
    for (final key in SaidKey.values.where((k) => k != SaidKey.raw)) {
      final s = Said(key, 'english', _sample(key));
      for (final (lang, l) in [('en', en), ('ko', ko), ('fr', fr)]) {
        final text = l.say(s);
        expect(text.trim(), isNotEmpty, reason: '$lang:${key.name}');
        expect(text, isNot(contains(RegExp(r'[{}]'))), reason: '$lang:${key.name} $text');
      }
      expect(_latinIn(ko.say(s)), isEmpty, reason: 'ko:${key.name} ${ko.say(s)}');
      expect(_english.hasMatch(fr.say(s)), isFalse, reason: 'fr:${key.name} ${fr.say(s)}');
    }
  });

  test('a week of log lines, goals, reasons, facts and story beats is fully templated', () async {
    for (final (preset, seed) in [(BotPreset.drama, 1), (BotPreset.harmony, 2)]) {
      final saids = await _weekOfSaids(preset, seed);
      expect(saids.length, greaterThan(300));
      for (final s in saids.where((s) => s.key != SaidKey.raw)) {
        final k = ko.say(s), f = fr.say(s);
        expect(k, isNot(contains(RegExp(r'[{}]'))), reason: k);
        expect(_latinIn(k).where((w) => !s.english.contains('"') && !RegExp(r'^\d').hasMatch(w)), isEmpty, reason: '${s.key.name}: $k');
        expect(_english.hasMatch(f) && !s.english.contains('"'), isFalse, reason: '${s.key.name}: $f');
        expect(en.say(s).trim(), isNotEmpty);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 4)));

  test('pages written by rules are wholly in the book\'s language', () async {
    final (v, _) = await () async {
      final v = Village(chat: CannedChat(), embed: HashEmbed(), seed: 1, msPerMinute: 500, autoAck: true);
      final bot = PlayerBot(BotPreset.drama);
      await v.begin();
      for (var steps = 0; !v.weekOver && steps < 20000; steps++) {
        v.advance(500);
        await settle();
        bot.tick(v);
      }
      return (v, bot);
    }();
    final i = measure(v);
    final verdict = decideEnding(i);
    for (final (lang, l) in [(Lang.ko, ko), (Lang.fr, fr)]) {
      v.lang = lang;
      final book = newStorybook(v, verdict, id: 'b');
      StoryWriter(v, book, verdict: verdict, influence: i, onChange: () {}, say: l.say).finishWithFallbacks();
      for (final p in book.pages.where((p) => p.kind != PageKind.cover)) {
        expect(p.fallback, isTrue);
        final text = p.text!;
        if (lang == Lang.ko) {
          expect(_latinIn(text), isEmpty, reason: text);
        } else {
          expect(_english.hasMatch(text), isFalse, reason: text);
        }
      }
      if (i.festivalWinner != null) expect(book.pages.last.text, contains(i.festivalWinner!));
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}

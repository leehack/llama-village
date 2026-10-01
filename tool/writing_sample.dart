// Samples what the llamas write, with the real models, to check the
// writing in one language: conversations (and which topic each opener
// picks), daytime thoughts, the night's reflections and the epilogue cards.
//
//   dart run tool/writing_sample.dart <en|ko|fr> <out.md> [seed]
//
// The week is skipped to its interesting moments by rules (no model calls),
// with a little knowledge seeded so the rumour, the storm warning and the
// festival are in play; only the lines sampled here go to the model.

import 'dart:io';

import 'package:llama_village/ai/models.dart';
import 'package:llama_village/sim/clock.dart';
import 'package:llama_village/sim/dialogue.dart';
import 'package:llama_village/sim/endings.dart';
import 'package:llama_village/sim/epilogue.dart';
import 'package:llama_village/sim/influence.dart';
import 'package:llama_village/sim/lang.dart';
import 'package:llama_village/sim/model.dart';
import 'package:llama_village/sim/village.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('usage: dart run tool/writing_sample.dart <en|ko|fr> <out.md> [seed]');
    exit(64);
  }
  final lang = Lang.fromCode(args[0]);
  final out = File(args[1]);
  final seed = args.length > 2 ? int.parse(args[2]) : 7;
  final config = ModelConfig.resolve();
  if (!config.hasRequired) {
    stderr.writeln('missing models: ${config.missing.join(', ')}');
    exit(1);
  }
  final models = await VillageModels.load(config);
  final md = StringBuffer('# Writing sample (${lang.name}, seed $seed)\n\n${models.description}\n');
  try {
    await _sample(models, lang, seed, md);
  } finally {
    await models.dispose();
  }
  out
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(md.toString());
  stdout.writeln('wrote ${out.path}');
}

Future<void> _sample(VillageModels models, Lang lang, int seed, StringBuffer md) async {
  final v = Village(chat: models, embed: models, laya: models.hasLaya ? models : null, seed: seed)..lang = lang;
  await v.begin();
  Future<void> skip(GameTime to) async {
    v.offline = true;
    while (!v.skipTo(to)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    v.offline = false;
  }

  await skip(const GameTime(2, 10 * 60 + 30));
  // Mid-week gossip: the bread rumour has reached Pip and Bramble, and
  // Bramble has warned Clover about the storm.
  v.kb
    ..learn('Pip', 'bread_rumour', 'told', v.now, from: 'June', believes: true)
    ..learn('Bramble', 'bread_rumour', 'told', v.now, from: 'Pip', believes: false)
    ..learn('Clover', 'storm_forecast', 'told', v.now, from: 'Bramble', believes: true);

  md.writeln('\n## Topics Bramble brings up, one conversation after another (${v.now.label})\n');
  for (final other in ['Pip', 'Clover', 'Mo', 'Pip', 'June', 'Clover']) {
    final c = Conversation(0, v.byName('Bramble'), v.byName(other), v.byName('Bramble').place, v.now, v.uiMs);
    await v.pickTopic(c);
    md.writeln('- with $other: ${c.topic == null ? '(none)' : v.kb[c.topic!].short} (${c.topicSource})');
    v.now = v.now.plus(25);
  }

  md.writeln('\n## Conversations\n');
  for (final (a, b) in [('Bramble', 'Pip'), ('June', 'Mo')]) {
    final c = Conversation(0, v.byName(a), v.byName(b), v.byName(a).place, v.now, v.uiMs);
    await v.pickTopic(c);
    md.writeln('### $a and $b, ${v.now.label}, topic: ${c.topic == null ? '(none)' : v.kb[c.topic!].short}\n');
    for (var i = 0; i < c.turns; i++) {
      final s = c.speakerAt(i), o = c.other(s);
      final text = await v.chat.text<String>(
        'dialogue',
        Priority.dialogue,
        turnPrompt(v, c, i),
        parse: (raw) => v.checkLine(parseLine(raw, [s.name, o.name], previous: [for (final l in c.lines) l.text])),
        fallback: () => '(fallback) ${fallbackLinesIn(lang).first}',
        maxTokens: tokensFor(lang, 48),
        seed: v.rng.nextInt(1 << 30),
        stop: const ['\n\n'],
        lang: lang,
      );
      c.lines.add(Line(c.id, i, s.name, o.name, text, v.now, const {}, 0));
      md.writeln('- **${s.name}**: $text');
    }
    md.writeln();
    v.now = v.now.plus(40);
  }

  await skip(const GameTime(2, 17 * 60 + 40));
  md.writeln('\n## Thoughts (${v.now.label})\n');
  for (final l in v.cast) {
    final text = await v.chat.text<String>(
      'thought',
      Priority.thought,
      v.thoughtPrompt(l),
      parse: (raw) => v.checkLine(parseLine(raw, [l.name])),
      fallback: () => '(none)',
      maxTokens: tokensFor(lang, 32),
      seed: v.rng.nextInt(1 << 30),
      lang: lang,
    );
    md.writeln('- **${l.name}**: $text');
  }

  await skip(const GameTime(2, 22 * 60 - 1));
  // The evening reflections are written as 22:00 strikes, with the models on.
  v.skipTo(const GameTime(2, 22 * 60));
  while (v.cast.any((l) => l.reflectedDay < 2)) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  md.writeln('\n## Reflections at bedtime (night of day 2, ${v.now.label}; the storm is due on day $stormDay)\n');
  for (final l in v.cast) {
    md.writeln('- **${l.name}**: ${l.reflections.last}');
  }

  await skip(const GameTime(festivalDay, festivalMinute + 30));
  final i = measure(v);
  final verdict = decideEnding(i);
  md.writeln('\n## Epilogue cards (${verdict.ending.name}; winner ${v.festival.winner ?? 'nobody'})\n');
  for (final l in v.cast) {
    md.writeln('- **${l.name}**: ${await epilogueLine(v, l, i, verdict: verdict)}');
  }
  v.close();
}

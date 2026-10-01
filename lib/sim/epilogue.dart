import 'dart:math' as math;

import 'cast.dart';
import 'dialogue.dart';
import 'endings.dart';
import 'influence.dart';
import 'lang.dart';
import 'model.dart';
import 'said.dart';
import 'story.dart';
import 'village.dart';

const Map<String, String> _pronoun = {'Pip': 'she', 'Mo': 'he', 'June': 'she', 'Bramble': 'he', 'Clover': 'she'};
const Map<String, String> _work = {
  'Pip': 'knitting scarves',
  'Mo': 'baking bread',
  'June': 'picking berries',
  'Bramble': 'watching the clouds',
  'Clover': "planning next year's festival",
};

String _festivalRole(Village v, Llama l) {
  final f = v.festival;
  if (f.winner == l.name) return 'won the Golden Bell at the Berry Festival';
  if (f.scores[l.name] == -1) return 'fainted on stage at the Berry Festival';
  if (f.scores.containsKey(l.name)) return 'sang at the Berry Festival but did not win';
  if (f.contestants.contains(l.name)) return 'signed up to sing but missed the festival';
  if (l.name == 'Clover') return 'ran the Berry Festival';
  return 'watched the Berry Festival';
}

(String, int)? _extreme(Llama l, {required bool warmest}) {
  final others = [
    for (final n in llamaNames)
      if (n != l.name) (n, l.friendship[n] ?? 0),
  ]..sort((a, b) => warmest ? b.$2.compareTo(a.$2) : a.$2.compareTo(b.$2));
  return others.firstOrNull;
}

/// The story arc [l] shares with another llama, as one clause; empty for
/// Clover.
String arcFor(Llama l, Influence i) => switch (l.name) {
  'Pip' || 'Mo' => switch (i.pipMo) {
    PipMoArc.reconciled => 'Pip and Mo made up',
    PipMoArc.rift => 'Pip and Mo fell out',
    PipMoArc.unresolved => 'things between Pip and Mo were left unsaid',
  },
  'Bramble' || 'June' => switch (i.bramble) {
    BrambleArc.accepted => 'June said yes to Bramble',
    BrambleArc.declined || BrambleArc.exposedDeclined => 'June let Bramble down gently',
    BrambleArc.revealed => "everyone knows Bramble writes June's poems",
    BrambleArc.secret => "nobody learned who writes June's poems",
  },
  _ => '',
};

String _arcId(Llama l, Influence i) => switch (l.name) {
  'Pip' || 'Mo' => i.pipMo.name,
  _ => switch (i.bramble) {
    BrambleArc.accepted => 'accepted',
    BrambleArc.declined || BrambleArc.exposedDeclined => 'declined',
    BrambleArc.revealed => 'revealed',
    BrambleArc.secret => 'secret',
  },
};

/// The settled facts of how the week ended, from the sim's state: the
/// decided ending, the festival winner and how the village stands. The
/// epilogue cards and the storybook's last page are both grounded in them.
List<Said> endingFacts(Village v, Influence i, EndingVerdict verdict) {
  final info = endingInfo[verdict.ending]!;
  final lies = i.falseBeliefs.length;
  final trusting = i.dashTrust.values.where((t) => t >= 3).length;
  final cross = i.dashTrust.values.where((t) => t <= -3).length;
  final happiest = [...v.cast]..sort((a, b) => b.mood.compareTo(a.mood));
  final winner = i.festivalWinner;
  return [
    Said(SaidKey.endWeek, 'The week ended as "${info.title}": ${info.blurb}', {'ending': verdict.ending.name}),
    winner == null
        ? const Said(SaidKey.endNoWinner, 'Nobody won the Golden Bell.')
        : Said(SaidKey.factFestivalWinner, '$winner won the Golden Bell at the Berry Festival.', {'name': winner}),
    lies == 0
        ? const Said(SaidKey.endRumoursNone, 'Every untrue rumour had been put right.')
        : lies < 4
        ? const Said(SaidKey.endRumoursFew, 'A few untrue rumours were still going round.')
        : const Said(SaidKey.endRumoursMany, 'Many untrue rumours were still going round.'),
    i.harmony >= 1.5
        ? const Said(SaidKey.endFond, 'The llamas were fond of one another.')
        : i.harmony < 0.5
        ? const Said(SaidKey.endSoured, 'Many friendships had soured.')
        : const Said(SaidKey.endMixed, 'Some friendships were warm and some were cool.'),
    for (final l in v.cast)
      if (arcFor(l, i).isNotEmpty && (l.name == 'Pip' || l.name == 'Bramble'))
        Said(SaidKey.endArc, '${arcFor(l, i)[0].toUpperCase()}${arcFor(l, i).substring(1)}.', {'arc': _arcId(l, i)}),
    Said(SaidKey.endHappiest, '${happiest.first.name} ended the week happiest, and ${happiest.last.name} the gloomiest.', {
      'a': happiest.first.name,
      'b': happiest.last.name,
    }),
    cross > trusting
        ? const Said(SaidKey.endDashCross, 'Most llamas were cross with Dash.')
        : trusting >= 3
        ? const Said(SaidKey.endDashFond, 'Most llamas had grown fond of Dash.')
        : const Said(SaidKey.endDashUnsure, 'The llamas were not sure what to make of Dash.'),
  ];
}

/// [l]'s weightiest moments of the week from the storybook's journal, in
/// the order they happened.
List<StoryBeat> weekMoments(Village v, Llama l, {int limit = 3}) {
  final mine = [
    for (final b in v.journal.beats)
      if (b.who.contains(l.name) || b.text.contains(l.name)) b,
  ]..sort((a, b) => a.weight != b.weight ? b.weight.compareTo(a.weight) : a.seq.compareTo(b.seq));
  return mine.take(limit).toList()..sort((a, b) => a.seq.compareTo(b.seq));
}

/// A model epilogue line to set the tone, about someone other than
/// [name], so it is not copied.
String _example(Lang lang, String name) {
  final mo = name != 'Mo';
  return switch (lang) {
    Lang.en =>
      mo
          ? 'Mo kept baking honey loaves after the festival, and every morning he left the warmest one on Pip\'s doorstep.'
          : 'June pinned the unsigned poems above her bed, and on quiet evenings she read them aloud to the berry bushes.',
    Lang.ko =>
      mo
          ? 'Mo는 축제가 끝난 뒤에도 매일 아침 꿀빵을 구워, 가장 따끈한 한 덩이를 Pip의 문 앞에 살며시 놓아두었답니다.'
          : 'June은 이름 없는 시들을 침대 머리맡에 붙여 두고, 조용한 저녁이면 베리 덤불에게 소리 내어 읽어 주었답니다.',
    Lang.fr =>
      mo
          ? 'Après la fête, Mo continua de cuire ses pains au miel, et chaque matin il déposait le plus chaud devant la porte de Pip.'
          : 'June épingla les poèmes sans signature au-dessus de son lit, et les soirs tranquilles, elle les lisait aux buissons de baies.',
  };
}

/// The model prompt for [l]'s epilogue card: its final state, what it knows,
/// its moments of the week and how the week ended, nothing else.
String epiloguePrompt(Village v, Llama l, Influence i, {EndingVerdict? verdict}) {
  final warm = _extreme(l, warmest: true), cold = _extreme(l, warmest: false);
  final facts = relevantFacts(v, l, limit: 4);
  final moments = weekMoments(v, l);
  final arc = arcFor(l, i);
  final he = _pronoun[l.name] ?? 'they';
  final winner = v.festival.winner;
  final prompt = [
    'How festival week really ended (true; never contradict it):',
    for (final f in endingFacts(v, i, verdict ?? decideEnding(i))) '- ${f.english}',
    '- ${winner == null ? 'Nobody won the Golden Bell; do not say anyone won it.' : 'Only $winner won the Golden Bell; nobody else won anything.'}',
    '',
    'Festival week in Llama Village is over. ${l.name} ($he), the ${l.job} (${l.traits}), ${_festivalRole(v, l)}.',
    'Mood at the end: ${l.moodWord}. Closest to ${warm?.$1}; coolest toward ${cold?.$1}. '
        'Of Dash, the little blue bird, ${l.name} would say: "I ${feelingWord(l.friendship['Dash'] ?? 0)} him."',
    if (arc.isNotEmpty) 'Also: $arc.',
    if (moments.isNotEmpty) ...['${l.name}\'s week:', for (final b in moments) '- (day ${b.day}, ${partOfDay(b.minute)}) ${b.text}'],
    'What ${l.name} knows: ${facts.map((f) => f.text).join(' ')}',
    '',
    'Write one warm, specific sentence, under 26 words, past tense, third person ("$he"), about what became of ${l.name} '
        'after the festival, like the tender last page of a storybook. It is about ${l.name}, not the week or the valley: '
        'build it on one concrete thing from ${l.name}\'s week or what ${l.name} knows (an object, a place, a friend by name), '
        'and end on a gentle, hopeful note. Begin with "${l.name}". No quotes.',
    'The kind of sentence wanted (do not copy it): ${_example(v.lang, l.name)}',
  ].join('\n');
  return inLang(prompt, v.lang, story: true);
}

enum _Role { won, fainted, sang, missed, ran, watched }

_Role _roleOf(Village v, Llama l) {
  final f = v.festival;
  if (f.winner == l.name) return _Role.won;
  if (f.scores[l.name] == -1) return _Role.fainted;
  if (f.scores.containsKey(l.name)) return _Role.sang;
  if (f.contestants.contains(l.name)) return _Role.missed;
  if (l.name == 'Clover') return _Role.ran;
  return _Role.watched;
}

/// The rule-made line used when the model fails: built only from state, in
/// the village's language.
String fallbackEpilogue(Village v, Llama l, Influence i) {
  final warm = _extreme(l, warmest: true);
  final friend = warm != null && warm.$2 >= 3 ? warm.$1 : null;
  final happy = l.mood >= 2, sour = l.mood <= -2;
  switch (v.lang) {
    case Lang.en:
      final he = _pronoun[l.name] ?? 'they';
      final with_ = friend != null ? '; $he spent the autumn mostly with $friend' : '';
      final mood = happy
          ? 'and was happier than $he had been in years'
          : sour
          ? 'and grumbled about it for weeks'
          : 'and was back to ${_work[l.name] ?? 'work'} the next morning';
      return '${l.name} ${_festivalRole(v, l)} $mood$with_.';
    case Lang.ko:
      final role = switch (_roleOf(v, l)) {
        _Role.won => '베리 축제에서 황금 종을 받았고',
        _Role.fainted => '베리 축제 무대에서 기절했고',
        _Role.sang => '베리 축제에서 노래했지만 우승하지 못했고',
        _Role.missed => '노래하기로 했지만 축제를 놓쳤고',
        _Role.ran => '베리 축제를 이끌었고',
        _Role.watched => '베리 축제를 구경했고',
      };
      const work = {'Pip': '목도리 뜨기', 'Mo': '빵 굽기', 'June': '베리 따기', 'Bramble': '구름 관찰', 'Clover': '내년 축제 준비'};
      final mood = happy
          ? '몇 년 만에 가장 행복했어요.'
          : sour
          ? '몇 주 동안이나 투덜거렸어요.'
          : '다음 날 아침이면 다시 ${work[l.name] ?? '일'}에 바빴어요.';
      final with_ = friend == null ? '' : ' 가을 내내 주로 $friend${const {'Pip', 'June', 'Bramble'}.contains(friend) ? '과' : '와'} 함께 지냈답니다.';
      return '${koTopic(l.name)} $role $mood$with_';
    case Lang.fr:
      final she = _pronoun[l.name] == 'she';
      final e = she ? 'e' : '';
      final role = switch (_roleOf(v, l)) {
        _Role.won => 'a remporté la Cloche d\'or à la fête des Baies',
        _Role.fainted => 's\'est évanoui$e sur la scène de la fête des Baies',
        _Role.sang => 'a chanté à la fête des Baies sans gagner',
        _Role.missed => 'devait chanter mais a manqué la fête des Baies',
        _Role.ran => 'a organisé la fête des Baies',
        _Role.watched => 'a regardé la fête des Baies',
      };
      const work = {
        'Pip': 'son tricot',
        'Mo': 'son pain',
        'June': 'sa cueillette',
        'Bramble': 'ses nuages',
        'Clover': 'la fête de l\'an prochain',
      };
      final mood = happy
          ? 'et n\'avait pas été aussi heureu${she ? 'se' : 'x'} depuis des années'
          : sour
          ? 'et en a ronchonné pendant des semaines'
          : 'et dès le lendemain matin, a retrouvé ${work[l.name] ?? 'le travail'}';
      final with_ = friend == null ? '' : ' ; ${she ? 'elle' : 'il'} a passé l\'automne surtout avec $friend';
      return '${l.name} $role $mood$with_.';
  }
}

final RegExp _winWord = RegExp(
  r"\b(won|wins?|winning|winners?|champion|victor(y|ious)?)\b|우승|이겼|1등|일등|gagn|remport|vainqu|victoire|laur[ée]at",
  caseSensitive: false,
);
final RegExp _bellWon = RegExp(r"golden bell|황금\s*종|cloche d.or", caseSensitive: false);
final RegExp _holding = RegExp(
  r"\b(got|gets|received?|took|earned|was given|clutch\w*|held|holds|holding|carried|kept|treasur\w*)\b|받|차지|거머|품|들고|안고|re[çc]u|obtenu|d[ée]croch|tenait|serr|brandi",
  caseSensitive: false,
);
final RegExp _faintWord = RegExp(r"\b(faint\w*|swoon\w*|collapsed?)\b|기절|쓰러|[ée]vanoui|tomb[ée]e? dans les pommes", caseSensitive: false);
final RegExp _negation = RegExp(
  r"\b(not|never|without|lost|missed)\b|n't|못|않|놓쳤|\bne\b|\bn'|\bpas\b|jamais|sans|perdu|manqu",
  caseSensitive: false,
);

/// Where [clause] claims a win, or null.
Match? _winClaim(String clause) {
  final win = _winWord.firstMatch(clause);
  if (win != null) return win;
  final bell = _bellWon.firstMatch(clause);
  return bell != null && _holding.hasMatch(clause) ? bell : null;
}

/// A negation just before the claim ("did not win", "n'a pas gagné") or
/// just after it ("받지 못했어요").
bool _negated(String clause, Match m) =>
    _negation.hasMatch(clause.substring(math.max(0, m.start - 25), math.min(clause.length, m.end + 8)));

/// Whether [line], written for [l]'s epilogue card, claims something the
/// sim contradicts: that someone other than the festival winner won (or
/// that the winner did not), or that a llama fainted who did not. A clause
/// that names no llama is about [l].
bool epilogueContradicts(String line, Village v, Llama l) {
  final winner = v.festival.winner;
  final fainted = {
    for (final e in v.festival.scores.entries)
      if (e.value == -1) e.key,
  };
  for (final clause in line.split(RegExp(r'[.!?;。]|,\s*(?=but\b|mais\b|while\b|tandis\b)'))) {
    final named = {
      for (final n in llamaNames)
        if (RegExp('\\b$n\\b').hasMatch(clause)) n,
    };
    final who = named.isEmpty ? {l.name} : named;
    final win = _winClaim(clause);
    if (win != null) {
      final negated = _negated(clause, win);
      if (!negated && (winner == null || !who.contains(winner))) return true;
      if (negated && winner != null && who.length == 1 && who.single == winner) return true;
    }
    final faint = _faintWord.firstMatch(clause);
    if (faint != null && !_negated(clause, faint) && who.intersection(fainted).isEmpty) return true;
  }
  return false;
}

/// Writes [l]'s epilogue line, grounded in [endingFacts]. A line that
/// contradicts them is written once more, then replaced by
/// [fallbackEpilogue].
Future<String> epilogueLine(Village v, Llama l, Influence i, {EndingVerdict? verdict}) => v.chat.text<String>(
  'epilogue',
  Priority.dashReply,
  epiloguePrompt(v, l, i, verdict: verdict),
  parse: (raw) {
    final line = parseLine(raw, [l.name]);
    // A line that never names its llama is about the week in general.
    return line == null || line.length > 220 || !line.contains(l.name) || epilogueContradicts(line, v, l) ? null : line;
  },
  fallback: () => fallbackEpilogue(v, l, i),
  maxTokens: tokensFor(v.lang, 60),
  seed: 4242 + l.slot,
  lang: v.lang,
);

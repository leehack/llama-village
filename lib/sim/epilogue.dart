import 'cast.dart';
import 'dialogue.dart';
import 'influence.dart';
import 'lang.dart';
import 'model.dart';
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

/// The model prompt for [l]'s epilogue card: its final state and what it
/// knows, nothing else.
String epiloguePrompt(Village v, Llama l, Influence i) {
  final warm = _extreme(l, warmest: true), cold = _extreme(l, warmest: false);
  final facts = relevantFacts(v, l, limit: 4);
  final arc = arcFor(l, i);
  final he = _pronoun[l.name] ?? 'they';
  final prompt = [
    'Festival week in Llama Village is over. ${l.name} ($he), the ${l.job} (${l.traits}), ${_festivalRole(v, l)}.',
    'Mood at the end: ${l.moodWord}. Closest to ${warm?.$1}; coolest toward ${cold?.$1}. '
        'Feels ${feelingWord(l.friendship['Dash'] ?? 0)} Dash, the little blue bird.',
    if (arc.isNotEmpty) 'Also: $arc.',
    'What ${l.name} knows: ${facts.map((f) => f.text).join(' ')}',
    '',
    'Write one sentence, under 22 words, past tense, third person ("$he"), about what became of ${l.name} after the festival, '
        'like the last page of a storybook. Use one concrete detail from above. No quotes, no name prefix.',
  ].join('\n');
  return inLang(prompt, v.lang);
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

/// Writes [l]'s epilogue line; falls back to [fallbackEpilogue].
Future<String> epilogueLine(Village v, Llama l, Influence i) => v.chat.text<String>(
  'epilogue',
  Priority.dashReply,
  epiloguePrompt(v, l, i),
  parse: (raw) {
    final line = parseLine(raw, [l.name]);
    return line == null || line.length > 180 ? null : line;
  },
  fallback: () => fallbackEpilogue(v, l, i),
  maxTokens: tokensFor(v.lang, 48),
  seed: 4242 + l.slot,
  lang: v.lang,
);

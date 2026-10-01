import 'cast.dart';
import 'dialogue.dart';
import 'influence.dart';
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

String _arcFor(Llama l, Influence i) => switch (l.name) {
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
  final arc = _arcFor(l, i);
  return [
    'Festival week in Llama Village is over. ${l.name}, the ${l.job} (${l.traits}), ${_festivalRole(v, l)}.',
    'Mood at the end: ${l.moodWord}. Closest to ${warm?.$1}; coolest toward ${cold?.$1}. '
        'Feels ${feelingWord(l.friendship['Dash'] ?? 0)} Dash, the little blue bird.',
    if (arc.isNotEmpty) 'Also: $arc.',
    'What ${l.name} knows: ${facts.map((f) => f.text).join(' ')}',
    '',
    'Write one sentence, under 22 words, past tense, third person, about what became of ${l.name} after the festival, '
        'like the last page of a storybook. No quotes, no name prefix.',
  ].join('\n');
}

/// The rule-made line used when the model fails: built only from state.
String fallbackEpilogue(Village v, Llama l, Influence i) {
  final he = _pronoun[l.name] ?? 'they';
  final warm = _extreme(l, warmest: true);
  final role = _festivalRole(v, l);
  final with_ = warm != null && warm.$2 >= 3 ? '; $he spent the autumn mostly with ${warm.$1}' : '';
  final mood = l.mood >= 2
      ? 'and was happier than $he had been in years'
      : l.mood <= -2
      ? 'and grumbled about it for weeks'
      : 'and was back to ${_work[l.name] ?? 'work'} the next morning';
  return '${l.name} $role $mood$with_.';
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
  maxTokens: 48,
  seed: 4242 + l.slot,
);

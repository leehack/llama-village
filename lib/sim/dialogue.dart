import 'dart:math' as math;

import 'cast.dart';
import 'clock.dart';
import 'facts.dart';
import 'places.dart';
import 'model.dart';
import 'village.dart';
import 'week.dart';

/// One spoken line, with what the speaker knew when it was generated.
class Line {
  Line(this.convId, this.index, this.speaker, this.listener, this.text, this.at, this.known, this.generatedMs);
  final int convId;
  final int index;
  final String speaker;
  final String listener;
  final String text;
  final GameTime at;
  final Set<String> known;
  final double generatedMs;
  double? shownMs;
  double stallMs = 0;
  bool fallback = false;

  Map<String, Object?> toJson() => {'conv': convId, 'i': index, 'speaker': speaker, 'listener': listener, 'text': text, 'at': at.label};
}

int displayMs(String text) => (1300 + 110 * text.split(' ').length).clamp(2200, 4800);

/// A conversation whose turns are generated one at a time on the model
/// queue while the world keeps ticking; lines are shown as they arrive.
class Conversation {
  Conversation(this.id, this.a, this.b, this.place, this.start, this.startMs, {this.turns = 4});
  final int id;
  final Llama a;
  final Llama b;
  final String place;
  final GameTime start;
  final double startMs;
  final int turns;
  String? topic;
  String topicSource = 'none';
  String? layaShadowTopic;
  final List<Line> lines = [];
  int shown = 0;
  double freeAtMs = 0;
  bool generationDone = false;
  bool outcomeDone = false;
  double? outcomeDoneMs;
  double? lastHideMs;
  final Map<String, int> friendshipDelta = {};
  final Map<String, int> moodDelta = {};

  /// Yes/no story questions a thread wants the outcome model to answer.
  final Map<String, String> questions = {};
  final Map<String, bool> answers = {};
  final List<String> notes = [];
  final List<String> bystanders = [];

  /// Cut short (the night skip): no more turns or outcome.
  bool abandoned = false;

  /// The line waiting for the UI to say its bubble is up.
  Line? awaitingAck;
  double ackDeadlineMs = 0;

  Llama speakerAt(int i) => i.isEven ? a : b;
  Llama other(Llama l) => l == a ? b : a;
  bool get complete => generationDone && outcomeDone && shown == lines.length;
}

String _whenLabel(GameTime t) => 'Day ${t.day} of festival week (${dayLabel(t.day)}), ${t.hhmm}, ${t.partOfDay}';

/// Up to [limit] facts for a prompt, most relevant first.
List<Fact> relevantFacts(Village v, Llama l, {Llama? listener, String? topic, int limit = 7}) {
  final goals = v.goalsFor(l);
  final goalTopics = {
    for (final g in goals)
      if (g.topic != null) g.topic!,
  };
  double score(Fact f) {
    final k = f.knownBy[l.name]!;
    var s = 0.2;
    if (f.id == topic) s += 3;
    if (goalTopics.contains(f.id)) s += 2;
    if (listener != null && f.text.contains(listener.name)) s += 1;
    if (f.secretOf.contains(l.name)) s += 0.8;
    if (v.now.minutesSince(k.at) < 180) s += 0.6;
    if (f.id == 'mo_voice') s -= 0.3;
    return s;
  }

  final facts = v.kb.known(l.name)..sort((x, y) => score(y).compareTo(score(x)));
  return facts.take(limit).toList();
}

String personaBlock(Village v, Llama l, Llama listener, {String? topic}) {
  final goals = v.goalsFor(l)..sort((x, y) => y.weight.compareTo(x.weight));
  final facts = relevantFacts(v, l, listener: listener, topic: topic);
  final memory = [for (final d in l.diary.reversed.where((d) => d.$2 == listener.name).take(1)) '${v.now.relative(d.$1)}: ${d.$3}'];
  return [
    'You are ${l.name}, the ${l.job}: ${l.traits}. Mood: ${l.moodWord}. You ${feelingWord(l.friendship[listener.name] ?? 0)} ${listener.name}.',
    if (l.items.contains("Pip's red scarf")) "You are carrying Pip's red scarf, which you found.",
    if (goals.isNotEmpty) 'What you want: ${goals.take(2).map((g) => g.text).join('; ')}.',
    'What you know (only these; you know nothing else about anyone\'s secrets):',
    for (final f in facts) '- ${f.text} (${v.kb.label(l.name, f, v.now)})',
    if (memory.isNotEmpty) 'Last time with ${listener.name}: ${memory.single}',
  ].join('\n');
}

String turnPrompt(Village v, Conversation c, int index) {
  final s = c.speakerAt(index);
  final o = c.other(s);
  final topicFact = c.topic == null ? null : v.kb.maybe(c.topic!);
  final nearby = [
    for (final x in v.cast)
      if (x != c.a && x != c.b && x.place == c.place) x.name,
  ];
  final instruction = index == 0
      ? (topicFact == null
            ? 'You walk up to ${o.name} and start talking.'
            : topicFact.secretOf.contains(s.name)
            ? 'You walk up to ${o.name}. You have decided to tell ${o.name} your secret: ${topicFact.text}'
            : 'You walk up to ${o.name} and bring up: ${topicFact.short} (${topicFact.text})')
      : index == c.turns - 1
      ? 'Reply to ${o.name} and close the conversation.'
      : 'Reply to what ${o.name} just said.';
  return [
    '${_whenLabel(v.now)}, at ${theP(c.place)}. Weather: ${v.storm ? 'a storm is raging' : 'clear'}.'
        '${nearby.isEmpty ? '' : ' Also here: ${nearby.join(', ')}.'}',
    personaBlock(v, s, o, topic: c.topic),
    '',
    if (c.lines.isNotEmpty) 'Conversation so far:',
    for (final l in c.lines) '${l.speaker}: "${l.text}"',
    if (c.lines.isNotEmpty) '',
    '$instruction Write only ${s.name}\'s next spoken line: one or two short sentences, under 25 words, no name prefix, no quotes.',
  ].join('\n');
}

String? parseLine(String raw, List<String> names, {List<String> previous = const []}) {
  final candidates = raw.split('\n').map((l) => cleanLine(l, names: names)).where((l) => l.isNotEmpty).toList();
  if (candidates.isEmpty) return null;
  var line = candidates.first;
  if (line.split(' ').length < 2) return null;
  final sentences = RegExp(r'[^.!?]+[.!?]*').allMatches(line).map((m) => m.group(0)!.trim()).where((x) => x.isNotEmpty).toList();
  if (sentences.length > 2) line = sentences.take(2).join(' ');
  if (line.length > 200) line = '${line.substring(0, 197).trimRight()}...';
  String norm(String x) => x.toLowerCase().replaceAll(RegExp(r'[^a-z ]'), '').trim();
  if (previous.any((p) => norm(p) == norm(line))) return null;
  return line;
}

const List<String> fallbackLines = [
  'Hmm. Well, I suppose so.',
  'I have a lot on my mind today.',
  'Let us talk about it later.',
  'Oh! Is that so?',
];

/// A possible transfer: [teller] knew [fact], the other did not.
class Candidate {
  Candidate(this.fact, this.teller, this.sim, this.keyword);
  final Fact fact;
  final Llama teller;
  final double sim;
  final bool keyword;
  String id = '';
}

/// Facts one participant knew and the other did not, scored against what
/// the teller actually said; the best few go to the outcome model.
/// Keyword groups may be satisfied across all of the teller's lines.
bool _saidKeywords(Fact f, List<String> said) => f.keywordHit(said.join(' '));

Future<List<Candidate>> transferCandidates(Village v, Conversation c, {int limit = 6}) async {
  final out = <Candidate>[];
  for (final teller in [c.a, c.b]) {
    final hearer = c.other(teller);
    final said = [
      for (final l in c.lines)
        if (l.speaker == teller.name) l.text,
    ];
    if (said.isEmpty) continue;
    final unknown = [
      for (final f in v.kb.known(teller.name))
        if (!v.kb.knows(hearer.name, f.id)) f,
    ];
    if (unknown.isEmpty) continue;
    final lineVecs = await v.embed.embed(said, type: 'embed_check');
    final factVecs = await v.embed.embed([for (final f in unknown) f.text], type: 'embed_check');
    for (var i = 0; i < unknown.length; i++) {
      final sim = lineVecs.map((l) => cosine(l, factVecs[i])).reduce(math.max);
      out.add(Candidate(unknown[i], teller, sim, _saidKeywords(unknown[i], said)));
    }
  }
  out.sort((x, y) => ((y.keyword ? 0.3 : 0) + y.sim).compareTo((x.keyword ? 0.3 : 0) + x.sim));
  final kept = out.take(limit).toList();
  for (var i = 0; i < kept.length; i++) {
    kept[i].id = 'f${i + 1}';
  }
  return kept;
}

/// The model proposes which facts were told; code accepts a claim only when
/// the teller's words support it, and adds strong unclaimed matches.
const double claimedSim = 0.6;
const double unclaimedSim = 0.5;

bool acceptTransfer(Candidate c, bool claimed) {
  if (c.fact.kind == FactKind.secret) return c.keyword && (claimed || c.sim >= unclaimedSim);
  return claimed ? (c.keyword || c.sim >= claimedSim) : (c.keyword && c.sim >= unclaimedSim);
}

Future<void> runOutcome(Village v, Conversation c) async {
  final candidates = await transferCandidates(v, c);
  const moods = [-2, -1, 0, 1, 2];
  const friends = [-3, -2, -1, 0, 1, 2, 3];
  Map<String, Object?> side() => {
    'type': 'object',
    'properties': {
      'mood': {'enum': moods},
      'friendship': {'enum': friends},
    },
    'required': ['mood', 'friendship'],
    'additionalProperties': false,
  };
  final schema = {
    'type': 'object',
    'properties': {
      if (candidates.isNotEmpty)
        'revealed': {
          'type': 'array',
          'items': {
            'enum': [for (final c in candidates) c.id],
          },
          'maxItems': 4,
        },
      c.a.name: side(),
      c.b.name: side(),
      for (final k in c.questions.keys) k: {'type': 'boolean'},
    },
    'required': [if (candidates.isNotEmpty) 'revealed', c.a.name, c.b.name, ...c.questions.keys],
    'additionalProperties': false,
  };
  final prompt = [
    'Conversation at ${theP(c.place)}:',
    for (final l in c.lines) '${l.speaker}: "${l.text}"',
    '',
    if (candidates.isNotEmpty) ...[
      'Facts that only one of them knew before talking:',
      for (final x in candidates) '${x.id} (${x.teller.name} knew): ${x.fact.text}',
      'revealed: the ids whose content was clearly said out loud in the conversation (often none).',
    ],
    'For each llama: mood change (-2..2) and friendship change toward the other (-3..3; negative if hurt, annoyed or jealous).',
    for (final e in c.questions.entries) '${e.key}: ${e.value} (true or false)',
  ].join('\n');
  final out = await v.chat.json(
    'outcome',
    Priority.outcome,
    prompt,
    schema,
    fallback: () => {
      if (candidates.isNotEmpty) 'revealed': <String>[],
      c.a.name: {'mood': 0, 'friendship': 0},
      c.b.name: {'mood': 0, 'friendship': 0},
    },
    validate: (out) {
      bool sideOk(Object? x) => x is Map && moods.contains(x['mood']) && friends.contains(x['friendship']);
      if (!sideOk(out[c.a.name]) || !sideOk(out[c.b.name])) return false;
      final r = out['revealed'];
      return r == null || r is List;
    },
    maxTokens: 70,
    seed: v.rng.nextInt(1 << 30),
  );
  final revealed = {for (final r in (out['revealed'] as List?) ?? const []) '$r'};
  for (final k in c.questions.keys) {
    c.answers[k] = out[k] == true;
  }
  for (final l in [c.a, c.b]) {
    final side = out[l.name] as Map;
    final md = side['mood'] as int;
    final fd = side['friendship'] as int;
    c.moodDelta[l.name] = md;
    c.friendshipDelta[l.name] = fd;
    l.addMood(md);
    l.addFriendship(c.other(l).name, fd);
  }
  for (final x in candidates) {
    final claimed = revealed.contains(x.id);
    final accepted = acceptTransfer(x, claimed);
    if (!accepted) continue;
    final f = x.fact;
    final teller = x.teller;
    final hearer = c.other(teller);
    final tellerBelieves = v.kb.believes(teller.name, f.id) || f.knownBy[teller.name]!.how == 'own';
    final trust = (hearer.friendship[teller.name] ?? 0) >= 0 || hearer.traits.contains('nosy');
    final believes = tellerBelieves && trust;
    if (v.kb.learn(hearer.name, f.id, 'told', v.now, from: teller.name, believes: believes)) {
      c.notes.add('(${hearer.name} now knows: ${f.short}${believes ? '' : ', but doubts it'})');
    }
    for (final by in v.presentAt(c.place, exclude: {c.a.name, c.b.name})) {
      if (v.rng.nextDouble() < 0.5 && v.kb.learn(by, f.id, 'overheard', v.now, from: teller.name, believes: believes)) {
        c.notes.add('($by overheard: ${f.short})');
      }
    }
  }
  final worst = math.min(c.friendshipDelta[c.a.name]!, c.friendshipDelta[c.b.name]!);
  final best = math.max(c.friendshipDelta[c.a.name]!, c.friendshipDelta[c.b.name]!);
  if (worst <= -3 || best <= -2) {
    final f = v.newFact(
      v.kb.newId('argument'),
      '${c.a.name} and ${c.b.name} had a heated argument at ${theP(c.place)} (day ${v.now.day}).',
      '${c.a.name} and ${c.b.name} arguing',
      kind: FactKind.deed,
    );
    v.kb.learn(c.a.name, f.id, 'own', v.now);
    v.kb.learn(c.b.name, f.id, 'own', v.now);
    final seen = v.witness(f.id, c.place);
    if (seen.isNotEmpty) c.notes.add('(${seen.join(', ')} saw them argue)');
  }
  for (final l in [c.a, c.b]) {
    final o = c.other(l);
    l.diary.add((
      c.start,
      o.name,
      'at ${theP(c.place)}${c.topic == null ? '' : ', about ${v.kb[c.topic!].short}'}; ${o.name} said: '
          '"${c.lines.where((x) => x.speaker == o.name).lastOrNull?.text ?? '...'}"',
    ));
  }
}

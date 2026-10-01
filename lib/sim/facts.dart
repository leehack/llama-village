import 'clock.dart';

enum FactKind { secret, event, rumour, deed, news }

/// How one llama came to know a fact.
class Knowing {
  Knowing(this.how, this.from, this.at, {required this.believes});

  /// 'own', 'saw', 'told', 'overheard' or 'announced'.
  final String how;
  final String? from;
  final GameTime at;
  bool believes;

  Map<String, Object?> toJson() => {'how': how, 'from': from, 'at': at.label, 'believes': believes};
}

class Fact {
  Fact({
    required this.id,
    required this.text,
    required this.truth,
    required this.origin,
    required this.kind,
    required this.created,
    required this.short,
    this.keywords = const [],
    this.contradicts,
    this.secretOf = const {},
    this.interested,
  });

  final String id;

  /// Third-person statement, as a narrator would write it.
  final String text;
  final bool truth;
  final String origin;
  final FactKind kind;
  final GameTime created;

  /// A topic label, for topic choice.
  final String short;

  /// Leakage keywords: a line matches when every group has a hit.
  final List<List<String>> keywords;

  /// A fact id this one disproves: believing this one drops belief in it.
  final String? contradicts;

  /// Llamas who would rather this stayed hidden.
  final Set<String> secretOf;

  /// Whoever this fact clears: from their own mouth it does not convince
  /// someone who believes the fact it contradicts.
  final String? interested;

  final Map<String, Knowing> knownBy = {};

  bool keywordHit(String line) {
    if (keywords.isEmpty) return false;
    final l = line.toLowerCase();
    return keywords.every((group) => group.any(l.contains));
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    'truth': truth,
    'origin': origin,
    'kind': kind.name,
    'created': created.label,
    'knownBy': {for (final e in knownBy.entries) e.key: e.value.toJson()},
  };
}

/// One knowledge transfer, for the transcript and the inspector.
class Transfer {
  Transfer(this.llama, this.fact, this.knowing);
  final String llama;
  final Fact fact;
  final Knowing knowing;
}

/// The single source of truth for who knows what.
class KnowledgeBase {
  final Map<String, Fact> facts = {};
  final List<Transfer> transfers = [];
  void Function(Transfer)? onLearn;
  int _next = 0;

  String newId(String prefix) => '$prefix${++_next}';

  Fact add(Fact fact) => facts[fact.id] = fact;
  Fact operator [](String id) => facts[id]!;
  Fact? maybe(String id) => facts[id];

  bool knows(String llama, String factId) => facts[factId]?.knownBy.containsKey(llama) ?? false;
  bool believes(String llama, String factId) => facts[factId]?.knownBy[llama]?.believes ?? false;

  List<Fact> known(String llama) => [
    for (final f in facts.values)
      if (f.knownBy.containsKey(llama)) f,
  ];
  Set<String> snapshot(String llama) => {for (final f in known(llama)) f.id};

  /// Records that [llama] learned [factId]; returns false when already known.
  bool learn(String llama, String factId, String how, GameTime at, {String? from, bool? believes}) {
    final fact = facts[factId]!;
    final existing = fact.knownBy[llama];
    if (existing != null) {
      // Seeing something for yourself settles a doubt.
      if (how == 'saw' && !existing.believes && fact.truth) existing.believes = true;
      return false;
    }
    final knowing = Knowing(how, from, at, believes: believes ?? true);
    if (fact.contradicts != null &&
        from != null &&
        from == fact.interested &&
        (facts[fact.contradicts!]?.knownBy[llama]?.believes ?? false)) {
      knowing.believes = false;
    }
    fact.knownBy[llama] = knowing;
    if (knowing.believes && fact.contradicts != null) {
      final old = facts[fact.contradicts!]?.knownBy[llama];
      if (old != null) old.believes = false;
    }
    // A llama who already believes the disproof shrugs the rumour off.
    for (final other in facts.values) {
      if (other.contradicts == factId && (other.knownBy[llama]?.believes ?? false)) knowing.believes = false;
    }
    final transfer = Transfer(llama, fact, knowing);
    transfers.add(transfer);
    onLearn?.call(transfer);
    return true;
  }

  /// Prompt label for what [llama] knows about [fact].
  String label(String llama, Fact fact, GameTime now) {
    final k = fact.knownBy[llama]!;
    final when = now.relative(k.at);
    return switch (k.how) {
      'own' when fact.secretOf.contains(llama) => 'your secret: keep it hidden unless you choose to confess',
      'own' => 'you know',
      'saw' => 'you saw it, $when',
      'announced' => 'announced to everyone, $when',
      _ when !k.believes => 'heard from ${k.from}, $when; you do not believe it',
      _ => 'heard from ${k.from}, $when; maybe untrue',
    };
  }
}

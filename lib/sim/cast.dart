import 'clock.dart';
import 'facts.dart';
import 'places.dart';

/// What a llama is doing right now; the 3D scene animates from this.
class Activity {
  Activity(this.kind, this.until, {this.dest, this.with_, this.label, GameTime? start}) : start = start ?? until;

  /// idle, walk, work, eat, nap, sleep, talk, search, watch, wait, practise.
  final String kind;
  final GameTime start;
  final GameTime until;
  final String? dest;
  final String? with_;
  final String? label;

  Map<String, Object?> toJson() => {
    'kind': kind,
    'until': until.label,
    if (dest != null) 'dest': dest,
    if (with_ != null) 'with': with_,
    if (label != null) 'label': label,
  };
}

class Llama {
  Llama({
    required this.name,
    required this.traits,
    required this.job,
    required this.workplace,
    required this.workVerb,
    required this.likes,
    required this.lifeGoal,
    required this.friendship,
    required this.singing,
    this.courage = 0.5,
    required this.slot,
  }) : place = hutOf(name);

  /// Standing spot index at every place, so llamas never overlap.
  final int slot;

  final String name;
  final String traits;
  final String job;
  final String workplace;
  final String workVerb;
  final String likes;
  final String lifeGoal;
  final Map<String, int> friendship;

  /// Singing skill, 0-1, for the festival.
  final double singing;
  double courage;

  String get home => hutOf(name);
  String place;
  double hunger = 0.35;
  double energy = 0.9;
  double social = 0.4;
  int mood = 0;
  final Set<String> items = {};
  Activity activity = Activity('idle', backstory);
  String? lastActionKind;

  /// Hour -> (place, activity) from the morning plan.
  final Map<int, (String, String)> schedule = {};
  final Map<String, GameTime> lastTalk = {};
  GameTime lastConversationEnd = backstory;

  /// (when, with whom, summary) of past conversations.
  final List<(GameTime, String, String)> diary = [];
  final Set<String> searched = {};
  final List<String> reflections = [];

  /// The day whose evening reflection is the last of [reflections].
  int reflectedDay = 0;

  /// Recent one-line thoughts, newest last.
  final List<String> thoughts = [];

  /// The options weighed at the last decision, best first.
  Decision? lastDecision;

  (String, String)? planAt(int minute) {
    final hour = minute ~/ 60;
    final starts = schedule.keys.where((h) => h <= hour).toList()..sort();
    return starts.isEmpty ? null : schedule[starts.last];
  }

  String resolve(String place) => place == 'home' ? home : place;

  bool get outdoors => outdoorPlaces.contains(place);
  bool get busyTalking => activity.kind == 'talk';
  bool get asleep => activity.kind == 'sleep';

  String get moodWord => switch (mood) {
    <= -3 => 'miserable',
    <= -1 => 'grumpy',
    0 => 'calm',
    <= 2 => 'cheerful',
    _ => 'elated',
  };

  void addFriendship(String other, int delta) => friendship[other] = ((friendship[other] ?? 0) + delta).clamp(-10, 10);
  void addMood(int delta) => mood = (mood + delta).clamp(-5, 5);

  Map<String, Object?> inspector(GameTime now) => {
    'name': name,
    'place': place,
    'activity': activity.toJson(),
    'needs': {'hunger': _r(hunger), 'energy': _r(energy), 'social': _r(social)},
    'mood': mood,
    'courage': _r(courage),
    'friendship': friendship,
    'items': items.toList(),
    'plan_now': planAt(now.minute)?.$2,
  };
}

/// One utility choice, as the inspector shows it.
class DecisionOption {
  const DecisionOption(this.kind, this.utility, this.why, {this.dest});
  final String kind;
  final double utility;
  final String why;
  final String? dest;

  String get label => dest == null ? kind : '$kind to ${theP(dest!)}';
}

class Decision {
  const Decision(this.at, this.options);
  final GameTime at;
  final List<DecisionOption> options;
}

double _r(double v) => (v * 100).round() / 100;

String feelingWord(int f) => switch (f) {
  <= -6 => 'despise',
  <= -3 => 'dislike',
  <= -1 => 'are wary of',
  <= 2 => 'feel neutral about',
  <= 5 => 'like',
  _ => 'adore',
};

List<Llama> buildCast() => [
  Llama(
    name: 'Pip',
    slot: 0,
    traits: 'vain, dramatic, fashionable, secretly insecure',
    job: 'scarf knitter',
    workplace: "Pip's hut",
    workVerb: 'knits scarves',
    likes: 'her red scarf, ribbons, compliments',
    lifeGoal: 'win the Golden Bell for best singer at the Berry Festival',
    friendship: {'Mo': 1, 'June': 5, 'Bramble': -1, 'Clover': 3, 'Dash': 0},
    singing: 0.3,
    courage: 0.9,
  ),
  Llama(
    name: 'Mo',
    slot: 1,
    traits: 'shy, kind, anxious, has a golden singing voice',
    job: 'baker',
    workplace: 'bakery',
    workVerb: 'bakes bread',
    likes: 'warm bread, quiet mornings, honest praise',
    lifeGoal: 'find the courage to sing at the festival without fainting',
    friendship: {'Pip': 6, 'June': -1, 'Bramble': 4, 'Clover': 3, 'Dash': 0},
    singing: 0.9,
    courage: 0.25,
  ),
  Llama(
    name: 'June',
    slot: 2,
    traits: 'nosy, chatty, cheerful, loves a scandal',
    job: 'berry farmer',
    workplace: 'berry bushes',
    workVerb: 'picks berries',
    likes: 'gossip, sweet berries, being asked for news',
    lifeGoal: 'be the first llama to know every secret in the village',
    friendship: {'Pip': 5, 'Mo': -2, 'Bramble': 1, 'Clover': 4, 'Dash': 0},
    singing: 0.5,
    courage: 0.6,
  ),
  Llama(
    name: 'Bramble',
    slot: 3,
    traits: 'grumpy, old, proud, secretly romantic',
    job: 'weather watcher',
    workplace: 'hilltop',
    workVerb: 'watches the clouds',
    likes: 'clouds, poetry, being right',
    lifeGoal: 'be taken seriously when he predicts a storm',
    friendship: {'Pip': -2, 'Mo': 5, 'June': 7, 'Clover': -4, 'Dash': 0},
    singing: 0.2,
    courage: 0.3,
  ),
  Llama(
    name: 'Clover',
    slot: 4,
    traits: 'bossy, ambitious, playful, impatient',
    job: 'festival organiser',
    workplace: 'hilltop',
    workVerb: 'builds the festival stage',
    likes: 'clipboards, applause, things going to plan',
    lifeGoal: 'run a perfect Berry Festival and be elected village mayor',
    friendship: {'Pip': 4, 'Mo': 3, 'June': 4, 'Bramble': -3, 'Dash': 0},
    singing: 0.4,
    courage: 0.8,
  ),
];

/// Backstory facts. Each llama starts knowing only its own.
void seedFacts(KnowledgeBase kb) {
  void add(
    String id,
    String text,
    String short, {
    required String origin,
    bool truth = true,
    FactKind kind = FactKind.secret,
    Map<String, ({String how, String? from, bool believes})> known = const {},
    List<List<String>> keywords = const [],
    String? contradicts,
    Set<String> secretOf = const {},
    String? interested,
  }) {
    kb.add(
      Fact(
        id: id,
        text: text,
        truth: truth,
        origin: origin,
        kind: kind,
        created: backstory,
        short: short,
        keywords: keywords,
        contradicts: contradicts,
        secretOf: secretOf,
        interested: interested,
      ),
    );
    for (final e in known.entries) {
      kb.learn(e.key, id, e.value.how, backstory, from: e.value.from, believes: e.value.believes);
    }
  }

  const own = (how: 'own', from: null, believes: true);
  add(
    'pip_tune',
    'Pip cannot hold a tune and practises singing in secret at the pond at dawn.',
    "Pip's secret singing",
    origin: 'Pip',
    known: {'Pip': own},
    secretOf: {'Pip'},
    keywords: [
      ['tune', 'off-key', 'off key', 'croak', 'screech', 'squawk', 'flat', 'sing badly', "can't sing", 'cannot sing', 'secret practi'],
    ],
  );
  add(
    'mo_scarf',
    "Mo knocked Pip's red scarf into the pond reeds by accident and never told her.",
    "Mo's scarf accident",
    origin: 'Mo',
    known: {'Mo': own},
    secretOf: {'Mo'},
    keywords: [
      ['scarf'],
      ['knock', 'accident', 'my fault', 'his fault', 'your fault', 'mo did', 'pushed', 'i did it', 'clumsy'],
    ],
  );
  add(
    'scarf_where',
    "Pip's red scarf is lying in the pond reeds.",
    'where the scarf is',
    origin: 'Mo',
    known: {'Mo': own},
    secretOf: {'Mo'},
    keywords: [
      ['scarf'],
      ['reed', 'pond', 'water'],
    ],
  );
  add(
    'june_rumour',
    "June made up the rumour that Mo's bread made Bramble sick.",
    'who started the bread rumour',
    origin: 'June',
    known: {'June': own},
    secretOf: {'June'},
    keywords: [
      ['rumou', 'story', 'tale', 'lie'],
      ['june', 'made up', 'started', 'invent', 'spread it', 'your doing'],
    ],
  );
  add(
    'bread_rumour',
    "Mo's bread made Bramble sick.",
    "Mo's bread rumour",
    origin: 'June',
    truth: false,
    kind: FactKind.rumour,
    known: {
      'June': (how: 'own', from: null, believes: false),
      'Clover': (how: 'told', from: 'June', believes: true),
      'Pip': (how: 'told', from: 'June', believes: true),
      'Mo': (how: 'told', from: 'someone', believes: false),
    },
    keywords: [
      ['bread', 'loaf', 'loaves'],
      ['sick', 'ill', 'poison', 'stomach', 'tummy'],
    ],
  );
  add(
    'bread_truth',
    "Bramble was never sick from Mo's bread; the bread rumour is false.",
    'the bread rumour is false',
    origin: 'Bramble',
    contradicts: 'bread_rumour',
    kind: FactKind.news,
    interested: 'Mo',
    known: {'Bramble': own, 'Mo': own},
    keywords: [
      ['bread', 'loaf', 'loaves', 'rumou'],
      ['never', 'not sick', 'false', 'untrue', 'nonsense', 'lie', 'wasn'],
    ],
  );
  add(
    'bramble_poems',
    'Bramble writes anonymous love poems to June.',
    "Bramble's poems for June",
    origin: 'Bramble',
    known: {'Bramble': own},
    secretOf: {'Bramble'},
    keywords: [
      ['poem', 'poet', 'verse', 'love', 'crush', 'sweet on', 'admire', 'wildflower'],
    ],
  );
  add(
    'wildflowers',
    'Someone keeps leaving wildflowers at the berry bushes for June.',
    'the mystery wildflowers',
    origin: 'world',
    kind: FactKind.event,
    known: {'June': (how: 'saw', from: null, believes: true)},
    keywords: [
      ['wildflower', 'flowers'],
    ],
  );
  add(
    'clover_deal',
    'Clover secretly promised Pip the Golden Bell in exchange for a free scarf.',
    "Clover's Golden Bell deal",
    origin: 'Clover',
    known: {'Clover': own, 'Pip': own},
    secretOf: {'Clover', 'Pip'},
    keywords: [
      ['bell', 'prize', 'win'],
      ['promis', 'deal', 'rig', 'fix', 'bribe', 'free scarf', 'in exchange', 'bought'],
    ],
  );
  add(
    'storm_forecast',
    'Bramble predicts a big storm will hit the village on the afternoon of day $stormDay.',
    "Bramble's storm warning",
    origin: 'Bramble',
    kind: FactKind.news,
    known: {'Bramble': own},
    keywords: [
      ['storm', 'thunder', 'rain', 'weather'],
      ['predict', 'warn', 'coming', 'will hit', 'brewing', 'on its way', 'this afternoon'],
    ],
  );
  add(
    'mo_voice',
    "Mo sang beautifully at last year's festival and got the loudest applause.",
    "Mo's singing voice",
    origin: 'world',
    kind: FactKind.news,
    known: {
      for (final n in ['Pip', 'Mo', 'June', 'Bramble', 'Clover']) n: (how: 'saw', from: null, believes: true),
    },
  );
}

import 'dart:async';
import 'dart:math' as math;

import 'brain.dart';
import 'cast.dart';
import 'clock.dart';
import 'dash.dart';
import 'dialogue.dart';
import 'facts.dart';
import 'geo.dart';
import 'laya_roles.dart';
import 'log.dart';
import 'model.dart';
import 'places.dart';
import 'rng.dart';
import 'story.dart';
import 'threads.dart';
import 'week.dart';

const Set<String> _chatty = {'idle', 'work', 'eat', 'linger', 'wait', 'search', 'watch'};

enum SpeechKind { say, thought }

/// A bubble above a speaker. [text] is null while the model is still
/// writing it (the UI shows "…").
class Speech {
  Speech(this.id, this.who, this.text, this.kind, this.bornMs, {this.to});
  final int id;
  final String who;
  final String? text;
  final SpeechKind kind;
  final double bornMs;
  final String? to;

  /// When the UI acknowledged the bubble, in [Village.uiMs].
  double? shownAtMs;
  double untilMs = double.infinity;
  bool get pending => text == null;
}

/// What a llama knows, as the inspector lists it.
class KnownFact {
  const KnownFact(this.text, this.how, {required this.believes, required this.secret});
  final String text;
  final String how;
  final bool believes;
  final bool secret;
}

/// Everything the inspector panel shows for one llama.
class LlamaInspector {
  const LlamaInspector({required this.llama, required this.activity, required this.goals, required this.knows, required this.thought});
  final Llama llama;
  final String activity;
  final List<String> goals;
  final List<KnownFact> knows;
  final String? thought;
}

/// How long the UI waits for a bubble acknowledgement before the sim
/// counts the bubble as shown anyway.
const double ackTimeoutMs = 1500;

/// The live village: a game clock that advances with [advance], llamas
/// deciding by utility rules, and model work running beside it on queues.
/// Nothing here waits on the model: lines, outcomes, thoughts and Dash's
/// options land whenever they are ready.
class Village {
  Village({
    required ChatModel chat,
    required EmbedModel embed,
    this.laya,
    required int seed,
    this.msPerMinute = 500,
    this.maxConversations = 3,
    this.autoAck = false,
  }) : metrics = RunMetrics(),
       rng = SimRandom(seed) {
    this.chat = ChatRuntime(chat, metrics);
    this.embed = Embedder(embed, metrics);
    seedFacts(kb);
    threads = [scarf, festival, crush, rumour, storm_, week];
    kb.onLearn = (t) {
      for (final th in threads) {
        th.onLearn(t, this);
      }
      events.emit('learn', {
        'who': t.llama,
        'fact': t.fact.id,
        'how': t.knowing.how,
        'from': t.knowing.from,
        'believes': t.knowing.believes,
      });
    };
    journal.attach(this);
  }

  late final ChatRuntime chat;
  late final Embedder embed;
  final TopicChooser? laya;
  final RunMetrics metrics;
  final SimRandom rng;

  /// Real milliseconds per game minute at 1x speed.
  final int msPerMinute;
  final int maxConversations;

  /// Acknowledge bubbles without a UI, for tests and headless runs.
  final bool autoAck;
  final List<Llama> cast = buildCast();
  final KnowledgeBase kb = KnowledgeBase();
  late final EventLog events = EventLog(() => now);
  late final Transcript log = Transcript(() => now);
  late final Dash dash = Dash(this);
  final ScarfThread scarf = ScarfThread();
  final FestivalThread festival = FestivalThread();
  final CrushThread crush = CrushThread();
  final RumourThread rumour = RumourThread();
  final StormThread storm_ = StormThread();
  final WeekThread week = WeekThread();
  late final List<StoryThread> threads;

  /// The week's notable moments and pictures, for the storybook.
  final StoryJournal journal = StoryJournal();
  final StoryAlbum album = StoryAlbum();

  GameTime now = const GameTime(1, 6 * 60);
  bool storm = false;
  final List<Conversation> active = [];
  final List<Conversation> done = [];
  final List<Line> lines = [];
  int _convId = 0;

  /// Pause-aware real milliseconds; bubbles are timed on it.
  double uiMs = 0;

  /// Fraction of the current game minute, for smooth walking.
  double minuteFrac = 0;
  double _acc = 0;
  bool paused = false;

  /// 1, 2 or 4 (up to 32 in debug runs): game minutes per [msPerMinute].
  double timeScale = 1;

  /// Scales how long bubbles stay up: above 1 reads slower (text speed).
  double textPace = 1;

  /// Debug fast-forward: plans and reflections come from the rules and no
  /// conversations or thoughts start, so whole days can be skipped instantly.
  bool offline = false;
  bool started = false;

  /// True while tomorrow's plans are being written; the clock holds at
  /// 05:59 until they are ready.
  bool planning = false;
  bool _plannedTomorrow = false;
  bool _reflected = false;
  int deferred = 0;
  bool _closed = false;

  final Map<String, Speech> speech = {};
  int _speechId = 0;
  final Map<String, GameTime> _lastThought = {};

  static const double nightBoost = 6;

  /// The deep night runs [nightBoost] times faster.
  bool get fastNight => now.minute >= 22 * 60 + 30 || now.minute < 5 * 60 + 30;
  bool get isNight => now.minute >= 21 * 60 + 10 || now.minute < 6 * 60;

  /// Game minutes advanced per real second right now, for the HUD.
  double get minutesPerSecond => paused ? 0 : 1000 / msPerMinute * timeScale * (fastNight ? nightBoost : 1);

  Llama byName(String name) => cast.firstWhere((l) => l.name == name);
  Llama? maybeByName(String name) => cast.where((l) => l.name == name).firstOrNull;
  List<Goal> goalsFor(Llama l) => [for (final t in threads) ...t.goalsFor(l, this)];

  Fact newFact(
    String id,
    String text,
    String short, {
    FactKind kind = FactKind.event,
    List<List<String>> keywords = const [],
    bool truth = true,
    String origin = 'world',
  }) => kb.add(Fact(id: id, text: text, truth: truth, origin: origin, kind: kind, created: now, short: short, keywords: keywords));

  List<String> presentAt(String place, {Set<String> exclude = const {}}) => [
    for (final l in cast)
      if (l.place == place && !l.asleep && l.activity.kind != 'walk' && !exclude.contains(l.name)) l.name,
    if (dash.place == place && !exclude.contains('Dash')) 'Dash',
  ];

  /// Everyone at [place] sees [factId]; returns who newly learned it.
  List<String> witness(String factId, String place, {Set<String> extra = const {}, Set<String> exclude = const {}}) {
    final learned = <String>[];
    for (final n in {...presentAt(place, exclude: exclude), ...extra}) {
      if (kb.learn(n, factId, 'saw', now) && !extra.contains(n)) learned.add(n);
    }
    return learned;
  }

  void worldEvent(String title, String text, {required String at, String? fact, Set<String> also = const {}}) {
    final seen = fact == null ? <String>[] : witness(fact, at, extra: also);
    log.event(title, '$text${seen.isEmpty ? '' : ' (seen by ${seen.join(', ')})'}');
    events.emit('world_event', {'title': title, 'text': text, 'place': at, 'fact': fact});
  }

  void announce(String title, String text, String factId, {bool quiet = false, String how = 'announced'}) {
    for (final n in [...cast.map((l) => l.name), 'Dash']) {
      kb.learn(n, factId, how, now);
    }
    if (quiet) {
      log.note(text, kind: LogKind.event);
    } else {
      log.event(title, text);
    }
    events.emit('world_event', {'title': title, 'text': text, 'place': 'everywhere', 'fact': factId});
  }

  // ------------------------------------------------------------ clock

  /// Writes the day-1 plans; call once before the first [advance].
  Future<void> begin() async {
    log.heading('## Day 1');
    await makeSchedules();
    started = true;
    events.emit('begin', {});
  }

  /// Ends conversations at once, without outcomes: all of them, so nobody
  /// is left talking through a night skip, or those [where] says.
  void abandonConversations({bool Function(Conversation c)? where, String why = 'say goodnight'}) {
    for (final c in active.where(where ?? (_) => true).toList()) {
      c.abandoned = true;
      active.remove(c);
      for (final l in [c.a, c.b]) {
        l.activity = Activity('idle', now, start: now);
        l.lastConversationEnd = now;
        speech.remove(l.name);
      }
      log.note('${c.a.name} and ${c.b.name} $why.');
    }
  }

  /// Twenty-five minutes before the festival, everyone still chatting
  /// elsewhere breaks off and heads for the hilltop.
  void _callToFestival() {
    abandonConversations(where: (c) => c.place != 'hilltop', why: 'break off to hurry to the festival');
    final visit = dash.visit;
    if (visit != null && visit.target.place != 'hilltop') {
      dash.leave();
      dash.say('${visit.target.name} hurries off to the festival.');
    }
  }

  /// The festival has been judged: the week is over.
  bool get weekOver => festival.state == 'judged' || now.day > festivalDay;

  /// Runs the minute logic up to [target] without real time passing, for
  /// the night skip. Stops early (returning false) while tomorrow's plans
  /// are still being written at 05:59.
  bool skipTo(GameTime target) {
    while (now.compareTo(target) < 0) {
      if (_holdForPlans()) return false;
      now = now.plus(1);
      _minute();
    }
    return true;
  }

  /// Debug: skips straight to 06:00 on [day] with rule-made plans.
  Future<void> jumpTo(int day) async {
    final was = offline;
    offline = true;
    final target = GameTime(day, 6 * 60);
    while (!skipTo(target)) {
      await Future<void>.delayed(Duration.zero);
    }
    offline = was;
  }

  /// Advances the world by [dtMs] real milliseconds.
  void advance(double dtMs) {
    if (!started || paused || _closed) return;
    uiMs += dtMs;
    final boost = fastNight ? nightBoost : 1.0;
    _acc += dtMs * timeScale * boost / msPerMinute;
    var steps = 0;
    while (_acc >= 1 && steps < 30) {
      if (_holdForPlans()) {
        _acc = math.min(_acc, 0.999);
        break;
      }
      _acc -= 1;
      steps++;
      now = now.plus(1);
      _minute();
    }
    if (_acc >= 1) _acc = 0.999;
    minuteFrac = _acc;
    dash.update(dtMs);
    _advanceConversations();
    _expireSpeech();
  }

  bool _holdForPlans() => now.minute == 5 * 60 + 59 && planning;

  /// The private clock and bookkeeping a save needs.
  Map<String, Object?> saveCore() => {
    'now': now.absolute,
    'storm': storm,
    'uiMs': uiMs,
    'acc': _acc,
    'timeScale': timeScale,
    'plannedTomorrow': _plannedTomorrow,
    'reflected': _reflected,
    'deferred': deferred,
    'convId': _convId,
    'speechId': _speechId,
    'lastThought': {for (final e in _lastThought.entries) e.key: e.value.absolute},
  };

  void loadCore(Map<String, Object?> j) {
    now = GameTime.fromAbsolute(j['now'] as int);
    storm = j['storm'] as bool;
    uiMs = (j['uiMs'] as num).toDouble();
    _acc = (j['acc'] as num).toDouble();
    minuteFrac = _acc;
    timeScale = (j['timeScale'] as num).toDouble();
    _plannedTomorrow = j['plannedTomorrow'] as bool;
    _reflected = j['reflected'] as bool;
    deferred = j['deferred'] as int;
    _convId = j['convId'] as int;
    _speechId = j['speechId'] as int;
    _lastThought
      ..clear()
      ..addAll({for (final e in (j['lastThought'] as Map).entries) e.key as String: GameTime.fromAbsolute(e.value as int)});
    planning = false;
    started = true;
  }

  void _minute() {
    if (now.minute == 6 * 60 && now.day > 1) _morning();
    if (now.minute == 22 * 60) _evening();
    if (now.day == festivalDay && now.minute == festivalMinute - 25) _callToFestival();
    if (now.minute == 4 * 60 + 30 && !_plannedTomorrow) {
      _plannedTomorrow = true;
      planning = true;
      unawaited(makeSchedules().whenComplete(() => planning = false));
    }
    for (final t in threads) {
      t.onMinute(this);
    }
    for (final l in cast) {
      driftNeeds(l);
    }
    _finishActivities();
    _decideIdle();
    _maybeStartConversations();
    _witnessOngoing();
    _maybeThink();
  }

  void _morning() {
    log.heading('## Day ${now.day}');
    for (final l in cast) {
      l.hunger = 0.4;
      l.energy = 0.95;
      l.social = 0.3;
      l.mood = (l.mood / 2).round();
      if (l.asleep) l.activity = Activity('idle', now, start: now);
    }
    _plannedTomorrow = false;
    _reflected = false;
    log.note('Morning of day ${now.day}. The village wakes up.', kind: LogKind.event);
    events.emit('morning', {'day': now.day});
  }

  void _evening() {
    if (_reflected) return;
    _reflected = true;
    final day = now.day;
    log.heading('### Threads after day $day');
    for (final t in threads) {
      log.raw('- **${t.title}**: ${t.state}');
    }
    for (final l in cast) {
      if (offline) {
        l
          ..reflections.add('What a day.')
          ..reflectedDay = day;
        continue;
      }
      final facts = relevantFacts(this, l, limit: 6);
      final today = l.diary.where((d) => d.$1.day == day).toList().reversed.take(3).toList();
      final prompt = [
        'You are ${l.name}, the ${l.job} (${l.traits}). Mood: ${l.moodWord}. It is the night of day $day; you lie down in your hut.',
        'What you know:',
        for (final f in facts) '- ${f.text} (${kb.label(l.name, f, now)})',
        if (today.isNotEmpty) 'Today you talked with: ${today.map((d) => '${d.$2} (${d.$3})').join('; ')}',
        '',
        'In first person and in character, write one sentence about one specific thing that happened today (name who or what) '
            'and how you feel about it. Only mention what you know.',
      ].join('\n');
      chat
          .text<String>(
            'reflection',
            Priority.dashOptions,
            prompt,
            parse: (raw) => parseLine(raw, [l.name]),
            fallback: () => 'What a day.',
            maxTokens: 50,
            seed: rng.nextInt(1 << 30),
          )
          .then((r) {
            l
              ..reflections.add(r)
              ..reflectedDay = day;
            l.thoughts.add(r);
            log.note('${l.name} lies awake thinking: "$r"');
          });
    }
  }

  void _finishActivities() {
    final lateNight = isNight;
    for (final l in cast) {
      final a = l.activity;
      if (a.kind == 'talk' || a.kind == 'idle') continue;
      final interrupt = (storm && l.outdoors && a.kind != 'walk') || (lateNight && a.kind != 'walk' && a.kind != 'sleep');
      if (now.compareTo(a.until) < 0 && !interrupt) continue;
      switch (a.kind) {
        case 'walk':
          l.place = a.dest!;
          events.emit('arrive', {'who': l.name, 'place': l.place});
        case 'eat':
          if (!interrupt) l.hunger = math.max(0, l.hunger - 0.6);
        case 'search':
          if (!interrupt) scarf.search(this, l);
        case 'flowers':
          if (!interrupt) crush.leaveFlowers(this, l);
        case 'sleep':
          continue;
      }
      l.activity = Activity('idle', now, start: now);
    }
  }

  void _decideIdle() {
    for (final l in cast) {
      if (l.activity.kind != 'idle') continue;
      final c = decide(this, l);
      if (c.kind == 'walk') {
        l.activity = Activity('walk', now.plus(math.max(1, c.minutes)), dest: c.dest, label: c.why, start: now);
        events.emit('move', {'who': l.name, 'from': l.place, 'to': c.dest, 'eta': l.activity.until.label, 'why': c.why});
      } else {
        l.activity = Activity(c.kind, now.plus(c.minutes), label: c.why, start: now);
        if (c.kind == 'sleep') speech.remove(l.name);
        events.emit('activity', {'who': l.name, 'kind': c.kind, 'place': l.place, 'until': l.activity.until.label, 'why': c.why});
      }
    }
  }

  void _witnessOngoing() {
    final pip = byName('Pip');
    if (pip.activity.kind == 'practise') {
      final seen = witness('pip_tune', pip.place, exclude: {'Pip'});
      if (seen.isNotEmpty) log.note('${seen.join(' and ')} hear${seen.length == 1 ? 's' : ''} Pip croaking scales at ${theP(pip.place)}.');
    }
  }

  /// On festival day nobody starts a chat on the way to the hilltop.
  bool festivalRush(Llama l) =>
      now.day == festivalDay && now.minute >= 14 * 60 + 30 && now.minute < festivalMinute + 40 && l.place != 'hilltop';

  bool _available(Llama l) =>
      !offline &&
      !l.asleep &&
      !festivalRush(l) &&
      _chatty.contains(l.activity.kind) &&
      !(storm && l.outdoors) &&
      !isNight &&
      now.minutesSince(l.lastConversationEnd) >= 20 &&
      dash.visit?.target != l;

  void _maybeStartConversations() {
    final byPlace = <String, List<Llama>>{};
    for (final l in cast.where(_available)) {
      byPlace.putIfAbsent(l.place, () => []).add(l);
    }
    for (final group in byPlace.values) {
      if (group.length < 2) continue;
      group.shuffle(rng);
      for (var i = 0; i < group.length; i++) {
        for (var j = i + 1; j < group.length; j++) {
          final a = group[i], b = group[j];
          if (a.busyTalking || b.busyTalking) continue;
          final seekAB = goalsFor(a).where((g) => g.seek == b.name).fold<double>(0, (m, g) => math.max(m, g.weight));
          final seekBA = goalsFor(b).where((g) => g.seek == a.name).fold<double>(0, (m, g) => math.max(m, g.weight));
          final seek = math.max(seekAB, seekBA);
          final last = a.lastTalk[b.name];
          final cooldown = seek > 0 ? 45 : 120;
          if (last != null && now.minutesSince(last) < cooldown) continue;
          final p =
              0.025 +
              0.05 * (a.social + b.social) +
              (seek > 0 ? 0.3 + seek * 0.5 : 0) +
              ((a.friendship[b.name] ?? 0) + (b.friendship[a.name] ?? 0)) / 600;
          if (rng.nextDouble() >= p) continue;
          if (active.length >= maxConversations) {
            deferred++;
            continue;
          }
          final opener = seekBA > seekAB || (seekAB == seekBA && b.social > a.social) ? b : a;
          _startConversation(opener, opener == a ? b : a);
        }
      }
    }
  }

  // ------------------------------------------------------------ conversations

  void _startConversation(Llama a, Llama b) {
    final c = Conversation(++_convId, a, b, a.place, now, uiMs);
    active.add(c);
    for (final l in [a, b]) {
      final o = c.other(l);
      l.activity = Activity('talk', now.plus(999), with_: o.name, start: now);
      l.social = math.max(0, l.social - 0.45);
      l.lastTalk[o.name] = now;
      if (speech[l.name]?.kind == SpeechKind.thought) speech.remove(l.name);
    }
    c.bystanders.addAll(presentAt(c.place, exclude: {a.name, b.name}));
    if ({a.name, b.name}.containsAll({'Mo', 'Clover'}) && !festival.contestants.contains('Mo') && kb.knows('Mo', 'festival')) {
      c.questions['mo_agreed_to_sing'] = 'Did Mo clearly agree to sing at the festival?';
    }
    events.emit('conversation_start', {'conv': c.id, 'a': a.name, 'b': b.name, 'place': c.place});
    unawaited(_openConversation(c));
  }

  /// Whether [a] can tell that [b] already knows [f]: b told a, a told b,
  /// it was announced, b shares the secret, or b took part in it.
  bool listenerKnows(Llama a, Llama b, Fact f) {
    final k = f.knownBy[a.name]!;
    if (k.from == b.name || k.how == 'announced') return true;
    if (f.knownBy[b.name]?.from == a.name) return true;
    if (f.secretOf.contains(b.name) && k.how == 'own') return true;
    return f.kind == FactKind.deed && f.text.startsWith('${b.name} ') || (f.id.startsWith('argument') && f.text.contains(b.name));
  }

  TopicCase topicCase(Llama a, Llama b) {
    final goals = goalsFor(a);
    final options = <TopicOption>[];
    for (final f in relevantFacts(this, a, listener: b, limit: 8)) {
      final k = f.knownBy[a.name]!;
      final goalW = goals.where((g) => g.topic == f.id).fold<double>(0, (m, g) => math.max(m, g.weight));
      final own = f.secretOf.contains(a.name) && k.how == 'own';
      options.add(
        TopicOption(
          f.id,
          f.short,
          f.text,
          goal: goalW,
          ownSecret: own,
          confessing: own && goalW > 0,
          fromListener: listenerKnows(a, b, f),
          aboutListener: f.text.contains(b.name),
          recent: now.minutesSince(k.at) < 180,
          juicy:
              f.kind == FactKind.rumour || (f.kind == FactKind.secret && !own) || (f.kind == FactKind.deed && !f.id.startsWith('argument')),
          public: k.how == 'announced' || f.knownBy.length >= 5,
        ),
      );
    }
    return TopicCase(a.name, a.traits, b.name, feelingWord(a.friendship[b.name] ?? 0), a.place, now.hhmm, [
      for (final g in goals) g.text,
    ], options);
  }

  Future<void> _openConversation(Conversation c) async {
    final tc = topicCase(c.a, c.b);
    if (tc.options.isNotEmpty) {
      final watch = Stopwatch()..start();
      final (topic, source) = await gatedTopic(laya, tc);
      if (source == 'laya') metrics.add(CallRecord('topic_laya', watch.elapsedMicroseconds / 1000));
      c.topic = topic;
      c.topicSource = source;
    }
    log.talkStarted(c, kb);
    _generateTurn(c, 0);
  }

  void _generateTurn(Conversation c, int index) {
    if (_closed || c.abandoned) return;
    final s = c.speakerAt(index);
    final o = c.other(s);
    final prompt = turnPrompt(this, c, index);
    final known = kb.snapshot(s.name);
    final at = now;
    chat
        .text<String>(
          'dialogue',
          Priority.dialogue,
          prompt,
          parse: (raw) => parseLine(raw, [s.name, o.name], previous: [for (final l in c.lines) l.text]),
          fallback: () => '\u0000${fallbackLines[rng.nextInt(fallbackLines.length)]}',
          maxTokens: 48,
          seed: rng.nextInt(1 << 30),
          stop: const ['\n\n'],
        )
        .then((text) {
          final fallback = text.startsWith('\u0000');
          final line = Line(c.id, index, s.name, o.name, fallback ? text.substring(1) : text, at, known, uiMs)..fallback = fallback;
          if (c.abandoned) return;
          c.lines.add(line);
          lines.add(line);
          if (lines.length > 400) lines.removeAt(0);
          if (index + 1 < c.turns) {
            _generateTurn(c, index + 1);
          } else {
            c.generationDone = true;
            runOutcome(this, c).then((_) {
              c.outcomeDone = true;
              c.outcomeDoneMs = uiMs;
            });
          }
        });
  }

  /// Display time shrinks a little at higher speeds.
  double displayFor(String text) => displayMs(text) * textPace / math.sqrt(timeScale);

  Speech _say(String who, String? text, SpeechKind kind, {String? to}) {
    final s = Speech(++_speechId, who, text, kind, uiMs, to: to);
    speech[who] = s;
    if (text != null) {
      events.emit(kind == SpeechKind.say ? 'say' : 'think', {'speech': s.id, 'speaker': who, 'listener': to, 'text': text});
      if (autoAck) ackBubble(s.id);
    }
    return s;
  }

  /// Shows [text] as [who]'s bubble now; Dash's chosen line and replies.
  Speech sayNow(String who, String text, {String? to}) => _say(who, text, SpeechKind.say, to: to);

  /// Marks [who] as working on a reply ("…").
  Speech pendingSay(String who, {String? to}) => _say(who, null, SpeechKind.say, to: to);

  /// The UI calls this once a bubble is on screen; its display time starts
  /// then, so dialogue pacing follows what the player actually sees.
  void ackBubble(int id) {
    for (final s in speech.values) {
      if (s.id == id && s.shownAtMs == null && s.text != null) {
        s.shownAtMs = uiMs;
        s.untilMs = uiMs + displayFor(s.text!);
      }
    }
  }

  void _expireSpeech() {
    for (final s in speech.values) {
      if (s.text != null && s.shownAtMs == null && uiMs - s.bornMs > ackTimeoutMs) ackBubble(s.id);
    }
    speech.removeWhere((who, s) => s.text != null && uiMs >= s.untilMs);
  }

  void _advanceConversations() {
    for (final c in active.toList()) {
      final waiting = c.awaitingAck;
      if (waiting != null) {
        final s = speech[waiting.speaker];
        final mine = s != null && s.text == waiting.text;
        if (mine && s.shownAtMs == null) {
          if (uiMs < c.ackDeadlineMs) continue;
          ackBubble(s.id);
        }
        c.freeAtMs = (mine ? s.shownAtMs! : uiMs) + displayFor(waiting.text);
        c.awaitingAck = null;
        c.shown++;
      }
      if (c.shown < c.lines.length && uiMs >= c.freeAtMs) {
        final line = c.lines[c.shown];
        line.shownMs = uiMs;
        c.awaitingAck = line;
        c.ackDeadlineMs = uiMs + ackTimeoutMs;
        _say(line.speaker, line.text, SpeechKind.say, to: line.listener);
        log.line(line.speaker, line.text);
        continue;
      }
      if (!c.generationDone && c.shown == c.lines.length && uiMs >= c.freeAtMs) {
        final next = c.speakerAt(c.lines.length);
        if (speech[next.name]?.pending != true) pendingSay(next.name, to: c.other(next).name);
      }
      if (c.generationDone && c.shown == c.lines.length && uiMs >= c.freeAtMs && c.outcomeDone) {
        _endConversation(c);
      }
    }
  }

  void _endConversation(Conversation c) {
    active.remove(c);
    done.add(c);
    if (done.length > 200) done.removeAt(0);
    for (final l in [c.a, c.b]) {
      l.activity = Activity('idle', now, start: now);
      l.lastConversationEnd = now;
      if (speech[l.name]?.pending == true) speech.remove(l.name);
    }
    for (final t in threads) {
      t.onConversationEnd(c, this);
    }
    log.conversation(c, kb);
    events.emit('conversation_end', {'conv': c.id, 'mood': c.moodDelta, 'friendship': c.friendshipDelta, 'notes': c.notes});
  }

  // ------------------------------------------------------------ thoughts

  /// Now and then an idle llama thinks something out loud, in a thought
  /// bubble; the inspector shows the latest one.
  void _maybeThink() {
    if (offline || now.minute % 12 != 0 || isNight || chat.queue.depth > 1) return;
    final candidates = cast.where((l) {
      if (l.asleep || l.busyTalking || speech.containsKey(l.name)) return false;
      final last = _lastThought[l.name];
      return last == null || now.minutesSince(last) >= 70;
    }).toList();
    if (candidates.isEmpty || rng.nextDouble() > 0.6) return;
    think(candidates[rng.nextInt(candidates.length)]);
  }

  /// Asks the model for one private thought of [l] and shows it.
  void think(Llama l) {
    _lastThought[l.name] = now;
    final goals = goalsFor(l)..sort((x, y) => y.weight.compareTo(x.weight));
    final facts = relevantFacts(this, l, limit: 3);
    final need = l.hunger > 0.6
        ? 'You are hungry.'
        : l.energy < 0.3
        ? 'You are tired.'
        : '';
    final prompt = [
      'You are ${l.name}, the ${l.job} (${l.traits}). Mood: ${l.moodWord}. ${_doing(l)} $need',
      if (goals.isNotEmpty) 'What you want: ${goals.take(2).map((g) => g.text).join('; ')}.',
      'On your mind: ${facts.map((f) => f.text).join(' ')}',
      '',
      'Write one short private thought, first person, in character, under 14 words. No quotes, no name prefix.',
    ].join('\n');
    final pending = _say(l.name, null, SpeechKind.thought);
    chat
        .text<String>(
          'thought',
          Priority.thought,
          prompt,
          parse: (raw) => parseLine(raw, [l.name]),
          fallback: () => '',
          maxTokens: 32,
          seed: rng.nextInt(1 << 30),
        )
        .then((text) {
          final stillMine = speech[l.name]?.id == pending.id;
          if (text.isNotEmpty) {
            l.thoughts.add(text);
            if (l.thoughts.length > 12) l.thoughts.removeAt(0);
          }
          if (!stillMine) return;
          if (text.isEmpty || l.busyTalking || l.asleep) {
            speech.remove(l.name);
          } else {
            _say(l.name, text, SpeechKind.thought);
          }
        });
  }

  String _doing(Llama l) {
    final a = l.activity;
    return switch (a.kind) {
      'walk' => 'You are walking to ${theP(a.dest!)}.',
      'talk' => 'You are talking with ${a.with_}.',
      _ => 'You are at ${theP(l.place)} (${a.kind}).',
    };
  }

  // ------------------------------------------------------------ plans

  Future<void> makeSchedules() async {
    final hours = [6, 8, 10, 12, 14, 16, 18, 20];
    final futures = <Future<void>>[];
    for (final l in cast) {
      final facts = relevantFacts(this, l, limit: 6);
      final goals = goalsFor(l)..sort((x, y) => y.weight.compareTo(x.weight));
      final day = now.minute >= 22 * 60 ? now.day + 1 : now.day;
      final festivalNote = !kb.knows(l.name, 'festival') || day > festivalDay
          ? ''
          : day == festivalDay
          ? ', Berry Festival day (16:00, hilltop)'
          : ' (${dayLabel(day)})';
      final prompt = [
        'You are ${l.name}, the ${l.job} (${l.traits}). You work at ${l.workplace == l.home ? 'home' : 'the ${l.workplace}'}. Life goal: ${l.lifeGoal}.',
        'Today is day $day$festivalNote.',
        'What you know:',
        for (final f in facts) '- ${f.text} (${kb.label(l.name, f, now)})',
        if (goals.isNotEmpty) 'What you want: ${goals.take(3).map((g) => g.text).join('; ')}.',
        if (l.reflections.isNotEmpty) 'Last night you thought: ${l.reflections.last}',
        '',
        'Write your plan for today, one line per block, exactly in this format:',
        '06 bakery | short activity',
        'Use the hours ${hours.map((h) => h.toString().padLeft(2, '0')).join(', ')}. Place is one of: pond, berry bushes, bakery, hilltop, home. '
            'Activities under 10 words. Include work, meals and seeing specific llamas. End at home.',
      ].join('\n');
      Map<int, (String, String)> rulePlan() => {
        for (final h in hours) h: h >= 20 ? ('home', 'rest at home') : (l.workplace == l.home ? 'home' : l.workplace, l.workVerb),
      };
      if (offline) {
        l.schedule
          ..clear()
          ..addAll(rulePlan());
        continue;
      }
      futures.add(
        chat
            .text<Map<int, (String, String)>>(
              'schedule',
              Priority.background,
              prompt,
              parse: (raw) => parseSchedule(raw, hours),
              fallback: rulePlan,
              maxTokens: 160,
              temp: 0.7,
              seed: rng.nextInt(1 << 30),
            )
            .then((plan) {
              l.schedule
                ..clear()
                ..addAll(plan);
            }),
      );
    }
    await Future.wait(futures);
    for (final l in cast) {
      final e = l.schedule.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
      log.raw('- **${l.name}**: ${e.map((x) => '${x.key.toString().padLeft(2, '0')} ${x.value.$2} (${x.value.$1})').join(' · ')}');
    }
    log.note('The llamas have planned their day.', kind: LogKind.event);
  }

  // ------------------------------------------------------------ views

  /// Where [l] stands or walks right now, its heading, and whether it is
  /// on the move. Walks follow the path graph smoothly between minutes.
  (P2, P2, bool) llamaPose(Llama l) {
    final a = l.activity;
    if (a.kind == 'walk' && a.dest != null) {
      final total = math.max(1, a.until.minutesSince(a.start));
      final t = ((now.minutesSince(a.start) + minuteFrac) / total).clamp(0.0, 1.0);
      final path = walkPath(l.place, a.dest!, l.slot);
      final (p, dir) = along(path, t);
      // Keep right, so llamas passing each other do not merge.
      final right = (-dir.$2, dir.$1);
      final side = 0.6 * math.sin(math.pi * t);
      return ((p.$1 + right.$1 * side, p.$2 + right.$2 * side), dir, true);
    }
    return (slotPoint(l.place, l.slot), placeFacing(l.place), false);
  }

  LlamaInspector inspect(String name) {
    final l = byName(name);
    final goals = goalsFor(l)..sort((x, y) => y.weight.compareTo(x.weight));
    final known = kb.known(l.name)..sort((x, y) => y.knownBy[l.name]!.at.compareTo(x.knownBy[l.name]!.at));
    return LlamaInspector(
      llama: l,
      activity: activityLabel(l),
      goals: [for (final g in goals) g.text],
      knows: [
        for (final f in known)
          KnownFact(
            f.text,
            howLearned(f.knownBy[l.name]!, own: f.secretOf.contains(l.name)),
            believes: f.knownBy[l.name]!.believes,
            secret: f.secretOf.contains(l.name) && f.knownBy[l.name]!.how == 'own',
          ),
      ],
      thought: l.thoughts.lastOrNull,
    );
  }

  String activityLabel(Llama l) {
    final a = l.activity;
    final why = a.label == null || a.label!.isEmpty ? '' : ' (${a.label})';
    return switch (a.kind) {
      'walk' => 'walking to ${theP(a.dest!)}$why',
      'talk' => 'talking with ${a.with_} at ${theP(l.place)}',
      'sleep' => 'asleep in ${theP(l.place)}',
      'idle' => 'standing at ${theP(l.place)}',
      _ => '${a.kind} at ${theP(l.place)}$why',
    };
  }

  /// Drops queued model work so nothing new starts during shutdown.
  void close() {
    _closed = true;
    chat.queue.close();
    embed.queue.close();
  }
}

/// The inspector's "how learned" tag for one llama's knowing [k].
String howLearned(Knowing k, {required bool own}) => switch (k.how) {
  'own' when own => 'own secret',
  'own' => 'knows it',
  'saw' => 'saw it',
  'announced' => 'announced',
  'overheard' when !k.believes => 'overheard from ${k.from}; does not believe it',
  'overheard' => 'overheard from ${k.from}; maybe untrue',
  _ when !k.believes => 'heard from ${k.from}; does not believe it',
  _ => 'heard from ${k.from}; maybe untrue',
};

/// Reads a morning plan: one "HH place | activity" line per block.
Map<int, (String, String)>? parseSchedule(String raw, List<int> hours) {
  final out = <int, (String, String)>{};
  final re = RegExp(r'^\W*(\d{1,2})(?::\d\d)?\W+(pond|berry bushes|bakery|hilltop|home)\s*[|:\-–—]+\s*(.+)$', caseSensitive: false);
  for (final line in raw.split('\n')) {
    final m = re.firstMatch(line.trim());
    final h = m == null ? null : int.tryParse(m.group(1)!);
    if (m != null && h != null && hours.contains(h)) out[h] = (m.group(2)!.toLowerCase(), cleanLine(m.group(3)!));
  }
  return out.length >= 5 ? out : null;
}

import 'dart:convert';
import 'dart:typed_data';

import 'clock.dart';
import 'dialogue.dart';
import 'facts.dart';
import 'places.dart';
import 'village.dart';

/// One thing worth telling in the storybook, as a plain English sentence
/// built from the sim's state; [weight] ranks it within its day.
class StoryBeat {
  const StoryBeat(this.seq, this.day, this.minute, this.kind, this.text, this.weight, {this.who = const []});
  final int seq;
  final int day;
  final int minute;
  final String kind;
  final String text;
  final int weight;
  final List<String> who;

  String get hhmm => '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

  List<Object?> toJson() => [seq, day, minute, kind, text, weight, who];

  static StoryBeat fromJson(List<Object?> j) =>
      StoryBeat(j[0] as int, j[1] as int, j[2] as int, j[3] as String, j[4] as String, j[5] as int, who: (j[6] as List).cast<String>());
}

/// The day a moment belongs to: the small hours count as the night before.
int storyDay(GameTime t) => t.minute < 6 * 60 && t.day > 1 ? t.day - 1 : t.day;

/// Records the week's notable moments from the event stream: world events,
/// story-thread turns, conversations, secrets and rumours passed on, and
/// Dash's visits. Saves carry it, so a loaded game's storybook still knows
/// what happened before the save.
class StoryJournal {
  final List<StoryBeat> beats = [];
  int _seq = 0;

  static const int perDayCap = 60;

  void attach(Village v) => v.events.listeners.add((e) => record(v, e));

  void _add(Village v, String kind, String text, int weight, {List<String> who = const []}) {
    final day = storyDay(v.now);
    if (beats.where((b) => b.day == day).length >= perDayCap) {
      final weakest = beats.where((b) => b.day == day).reduce((a, b) => b.weight < a.weight ? b : a);
      if (weakest.weight >= weight) return;
      beats.remove(weakest);
    }
    beats.add(StoryBeat(_seq++, day, v.now.minute, kind, text, weight, who: who));
  }

  void record(Village v, Map<String, Object?> e) {
    switch (e['type']) {
      case 'world_event':
        final title = e['title'] as String;
        final text = plainStory(e['text'] as String);
        if (title == 'Lanterns') return _add(v, 'world', text, 2);
        final weight = switch (title) {
          'The Golden Bell' => 8,
          'Storm' => 7,
          'Scarf found' || 'Mo faints' => 6,
          _ when title.startsWith('The Berry Festival') || title.endsWith(' sings') => 5,
          _ => 4,
        };
        _add(v, 'world', text, weight);
      case 'thread':
        final thread = e['thread'] as String;
        if (thread == 'week') return;
        final to = e['to'] as String;
        final title = v.threads.firstWhere((t) => t.id == thread).title;
        final weight = switch (to) {
          'accepted' || 'let down gently' || 'confessed' || 'exposed' || 'judged' => 7,
          'debunked' || 'june exposed' || 'returned' || 'found' => 6,
          _ => 5,
        };
        _add(v, 'thread', '$title: ${plainStory(e['why'] as String)}', weight);
      case 'conversation_end':
        final c = v.done.where((c) => c.id == e['conv']).firstOrNull;
        if (c != null) _talk(v, c);
      case 'learn':
        _learn(v, e);
      case 'dash_reply':
        _dash(v, e);
    }
  }

  void _talk(Village v, Conversation c) {
    final topic = c.topic == null ? null : v.kb.maybe(c.topic!);
    final worst = [c.friendshipDelta[c.a.name] ?? 0, c.friendshipDelta[c.b.name] ?? 0].reduce((a, b) => a < b ? a : b);
    final best = [c.friendshipDelta[c.a.name] ?? 0, c.friendshipDelta[c.b.name] ?? 0].reduce((a, b) => a > b ? a : b);
    final how = worst <= -2
        ? ', and it ended in a quarrel'
        : worst >= 1 && best >= 2
        ? ', and they parted warmly'
        : '';
    final juicy = topic != null && (topic.kind == FactKind.secret || topic.kind == FactKind.rumour || topic.secretOf.isNotEmpty);
    _add(
      v,
      'talk',
      '${c.a.name} and ${c.b.name} talked at ${theP(c.place)}${topic == null ? '' : ' about ${topic.short}'}$how.',
      2 + (juicy ? 1 : 0) + (how.isEmpty ? 0 : 2),
      who: [c.a.name, c.b.name],
    );
  }

  void _learn(Village v, Map<String, Object?> e) {
    final how = e['how'] as String;
    final from = e['from'] as String?;
    // What Dash says is told by its own beat.
    if ((how != 'told' && how != 'overheard') || from == null || from == 'Dash') return;
    final f = v.kb.maybe(e['fact'] as String);
    final who = e['who'] as String;
    if (f == null) return;
    final believes = e['believes'] == true;
    final said = _unstop(f.text);
    if (who == 'Dash') {
      _add(v, 'learn', '$from confided in Dash: $said.', 3, who: [from]);
      return;
    }
    final secret = f.secretOf.isNotEmpty && !f.secretOf.contains(who);
    final rumour = f.kind == FactKind.rumour || !f.truth;
    final correction = f.contradicts != null;
    if (!secret && !rumour && !correction) return;
    final verb = how == 'overheard' ? 'overheard $from say' : 'heard from $from';
    final tag = !f.truth ? ' (it was not true)' : '';
    final doubt = believes ? '' : ', but did not believe it';
    _add(v, 'learn', '$who $verb: $said$tag$doubt.', secret ? 5 : (correction ? 4 : 3), who: [who, from]);
  }

  void _dash(Village v, Map<String, Object?> e) {
    final target = e['target'] as String;
    final about = e['about'] as String?;
    final reaction = e['reaction'] as String;
    final strong = reaction == 'delighted' || reaction == 'offended';
    if (e['intent'] == 'gossip' && about != null) {
      // One beat per listener and day, naming everyone Dash told tales about.
      final day = storyDay(v.now);
      final i = beats.indexWhere((b) => b.kind == 'gossip' && b.day == day && b.who.first == target);
      final abouts = [if (i >= 0) ...beats[i].who.skip(1), if (i < 0 || !beats[i].who.skip(1).contains(about)) about];
      final text =
          'Dash whispered made-up ${abouts.length == 1 ? 'rumour' : 'rumours'} about ${_and(abouts)} to $target, and $target was $reaction.';
      if (i >= 0) {
        final old = beats[i];
        beats[i] = StoryBeat(
          old.seq,
          old.day,
          old.minute,
          old.kind,
          text,
          (old.weight + (strong ? 1 : 0)).clamp(0, 6),
          who: [target, ...abouts],
        );
      } else {
        _add(v, 'gossip', text, 4 + (strong ? 1 : 0), who: [target, about]);
      }
      return;
    }
    final did = switch (e['intent']) {
      'praise' => 'told $target something kind about $about',
      'tell' => 'passed on some news to $target',
      'gift' => 'gave $target ${e['item'] ?? 'a present'}',
      'help' => 'offered to help $target',
      'compliment' => 'paid $target a compliment',
      'tease' => 'teased $target',
      final other => 'spoke with $target ($other)',
    };
    _add(v, 'dash', 'Dash $did, and $target was $reaction.', 3 + (strong ? 1 : 0), who: [target]);
  }

  Map<String, Object?> save() => {
    'seq': _seq,
    'beats': [for (final b in beats) b.toJson()],
  };

  void load(Map<String, Object?>? j) {
    beats.clear();
    _seq = 0;
    if (j == null) return;
    _seq = j['seq'] as int;
    beats.addAll([for (final b in j['beats'] as List) StoryBeat.fromJson(b as List<Object?>)]);
  }
}

String _unstop(String s) => s.trim().replaceFirst(RegExp(r'[.!]+$'), '');

String _and(List<String> names) => names.length < 2 ? names.join() : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';

const List<String> _small = ['no', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine'];

/// A sim sentence made fit for a children's story: no scores, no
/// bracketed numbers, small counts in words, one full stop.
String plainStory(String s) {
  var out = s
      .replaceAll(RegExp(r'\s*Scores?:.*$'), '')
      .replaceAll(RegExp(r'\s*\([^)]*\d[^)]*\)'), '')
      .replaceAllMapped(RegExp(r'\b(\d)\b(?= llamas?\b)'), (m) => _small[int.parse(m.group(1)!)])
      .replaceAll('no llamas had been warned', 'nobody had believed him')
      .replaceAll('one llamas', 'one llama')
      .trim();
  out = _unstop(out);
  return out.isEmpty ? out : '$out.';
}

/// The few facts a storybook page about [day] may use: the [limit] weightiest
/// beats of the day (earlier first on ties, and no more than three of one
/// kind, so one busy habit does not crowd out the rest), told in the order
/// they happened. A pure function of the beats, so the same week always
/// yields the same digest.
List<StoryBeat> dayDigest(Iterable<StoryBeat> beats, int day, {int limit = 7}) {
  final seen = <String>{};
  final ranked = [
    for (final b in beats)
      if (b.day == day && seen.add(b.text)) b,
  ]..sort((a, b) => a.weight != b.weight ? b.weight.compareTo(a.weight) : a.seq.compareTo(b.seq));
  final perKind = <String, int>{};
  final kept = [
    for (final b in ranked)
      if ((perKind[b.kind] = (perKind[b.kind] ?? 0) + 1) <= 3) b,
  ];
  return kept.take(limit).toList()..sort((a, b) => a.seq.compareTo(b.seq));
}

/// When in the day a beat happened, in storybook words rather than clock
/// times.
String partOfDay(int minute) => switch (minute ~/ 60) {
  < 6 => 'in the night',
  < 9 => 'early in the morning',
  < 12 => 'in the morning',
  < 14 => 'around midday',
  < 18 => 'in the afternoon',
  < 21 => 'in the evening',
  _ => 'at night',
};

/// The digest as prompt lines, in order: "- (early in the morning) Pip noticed …".
List<String> digestLines(List<StoryBeat> digest) => [for (final b in digest) '- (${partOfDay(b.minute)}) ${b.text}'];

/// One in-engine picture of a story moment, a small PNG.
class StoryShot {
  StoryShot(this.id, this.day, this.minute, this.kind, this.weight, this.png, {this.who = const []});
  final String id;
  final int day;
  final int minute;
  final String kind;
  final int weight;
  final Uint8List png;
  final List<String> who;

  Map<String, Object?> toJson() => {
    'id': id,
    'day': day,
    'minute': minute,
    'kind': kind,
    'weight': weight,
    'who': who,
    'png': base64Encode(png),
  };

  static StoryShot fromJson(Map<String, Object?> j) => StoryShot(
    j['id'] as String,
    j['day'] as int,
    j['minute'] as int,
    j['kind'] as String,
    j['weight'] as int,
    base64Decode(j['png'] as String),
    who: (j['who'] as List).cast<String>(),
  );
}

/// The week's illustrations: the best few per day and for the ending, kept
/// small enough to travel inside a save.
class StoryAlbum {
  final List<StoryShot> shots = [];
  int _next = 0;

  static const int perDay = 2;

  String newId() => 'shot${++_next}';

  List<StoryShot> _rivals(int day, String kind) =>
      shots.where((s) => s.day == day && (s.kind == 'ending') == (kind == 'ending')).toList()
        ..sort((a, b) => a.weight != b.weight ? a.weight.compareTo(b.weight) : b.minute.compareTo(a.minute));

  int _cap(String kind) => kind == 'ending' ? 1 : perDay;

  /// Whether a shot of [weight] would be kept, so a picture is only taken
  /// when it is.
  bool wouldKeep(int day, String kind, int weight) {
    final rivals = _rivals(day, kind);
    return rivals.length < _cap(kind) || rivals.first.weight < weight;
  }

  /// Keeps [shot] when it beats the weakest of its day (or its day has room).
  bool add(StoryShot shot) {
    if (!wouldKeep(shot.day, shot.kind, shot.weight)) return false;
    final rivals = _rivals(shot.day, shot.kind);
    if (rivals.length >= _cap(shot.kind)) shots.remove(rivals.first);
    shots.add(shot);
    return true;
  }

  bool hasDay(int day) => shots.any((s) => s.day == day && s.kind != 'ending');

  StoryShot? byId(String? id) => id == null ? null : shots.where((s) => s.id == id).firstOrNull;

  /// The best shot for [day] that is not in [used]; the heaviest, earliest first.
  StoryShot? bestFor(int day, {Set<String> used = const {}}) {
    final c = shots.where((s) => s.day == day && s.kind != 'ending' && !used.contains(s.id)).toList()
      ..sort((a, b) => a.weight != b.weight ? b.weight.compareTo(a.weight) : a.minute.compareTo(b.minute));
    return c.firstOrNull;
  }

  StoryShot? get ending => shots.where((s) => s.kind == 'ending').firstOrNull;

  Map<String, Object?> save() => {
    'next': _next,
    'shots': [for (final s in shots) s.toJson()],
  };

  void load(Map<String, Object?>? j) {
    shots.clear();
    _next = 0;
    if (j == null) return;
    _next = j['next'] as int;
    shots.addAll([for (final s in j['shots'] as List) StoryShot.fromJson((s as Map).cast<String, Object?>())]);
  }
}

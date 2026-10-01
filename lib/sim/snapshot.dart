import 'dart:convert';
import 'dart:typed_data';

import 'cast.dart';
import 'clock.dart';
import 'facts.dart';
import 'log.dart';
import 'rng.dart';
import 'village.dart';

/// Bumped whenever the save layout changes; older saves are refused.
const int saveVersion = 1;

/// A save that cannot be read: damaged, from another version, or not a save.
class SaveException implements Exception {
  const SaveException(this.message);
  final String message;

  @override
  String toString() => 'SaveException: $message';
}

/// The whole sim as JSON-able data. Conversations, bubbles and a visit in
/// flight are not saved: their llamas come back idle and pick up from
/// there.
Map<String, Object?> snapshotVillage(Village v, {DateTime? at}) => {
  'game': 'llama_village',
  'version': saveVersion,
  'savedAt': (at ?? DateTime.now()).toUtc().toIso8601String(),
  'day': v.now.day,
  'time': v.now.hhmm,
  'rng': v.rng.stateHex,
  'core': v.saveCore(),
  'cast': [for (final l in v.cast) _llama(l, v.now)],
  'kb': _kb(v.kb),
  'threads': {for (final t in v.threads) t.id: t.save()},
  'dash': v.dash.save(),
  'embeddings': {for (final e in v.embed.cache.entries) e.key: _vector(e.value)},
  'log': [
    for (final e in v.log.entries.skip(v.log.entries.length > 300 ? v.log.entries.length - 300 : 0))
      {'at': e.at.absolute, 'kind': e.kind.name, 'text': e.text, 'who': e.who},
  ],
};

/// Checks the header of a decoded save; throws [SaveException].
Map<String, Object?> checkSave(Object? json) {
  if (json is! Map<String, Object?> || json['game'] != 'llama_village') throw const SaveException('not a Llama Village save');
  final version = json['version'];
  if (version != saveVersion) throw SaveException('save version $version, expected $saveVersion');
  return json;
}

/// Decodes and checks a save file's text.
Map<String, Object?> decodeSave(String text) {
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException catch (e) {
    throw SaveException('damaged save file (${e.message})');
  }
  return checkSave(json);
}

/// Loads [j] into a freshly built [v] (same cast, no plans yet).
void restoreVillage(Village v, Map<String, Object?> j) {
  checkSave(j);
  try {
    v.rng.state = SimRandom.parseState(j['rng'] as String);
    v.loadCore((j['core'] as Map).cast<String, Object?>());
    _loadKb(v.kb, (j['kb'] as Map).cast<String, Object?>());
    for (final raw in j['cast'] as List) {
      final m = (raw as Map).cast<String, Object?>();
      _loadLlama(v.byName(m['name'] as String), m);
    }
    final threads = (j['threads'] as Map).cast<String, Object?>();
    for (final t in v.threads) {
      t.load((threads[t.id] as Map).cast<String, Object?>());
    }
    v.dash.load((j['dash'] as Map).cast<String, Object?>());
    v.embed.cache
      ..clear()
      ..addAll({for (final e in (j['embeddings'] as Map).entries) e.key as String: _unvector(e.value as String)});
    v.log.entries
      ..clear()
      ..addAll([
        for (final raw in j['log'] as List)
          LogEntry(
            GameTime.fromAbsolute((raw as Map)['at'] as int),
            LogKind.values.byName(raw['kind'] as String),
            raw['text'] as String,
            who: (raw['who'] as List).cast<String>(),
          ),
      ]);
    v.speech.clear();
    v.active.clear();
  } on SaveException {
    rethrow;
  } catch (e) {
    throw SaveException('damaged save data (${e.runtimeType})');
  }
}

String _vector(List<double> v) => base64Encode(Float32List.fromList(v).buffer.asUint8List());

List<double> _unvector(String s) => Float32List.view(Uint8List.fromList(base64Decode(s)).buffer).map((x) => x.toDouble()).toList();

Map<String, Object?> _activity(Activity a) => {
  'kind': a.kind,
  'start': a.start.absolute,
  'until': a.until.absolute,
  'dest': a.dest,
  'with': a.with_,
  'label': a.label,
};

Activity _unactivity(Map<String, Object?> m) => Activity(
  m['kind'] as String,
  GameTime.fromAbsolute(m['until'] as int),
  start: GameTime.fromAbsolute(m['start'] as int),
  dest: m['dest'] as String?,
  with_: m['with'] as String?,
  label: m['label'] as String?,
);

Map<String, Object?> _llama(Llama l, GameTime now) {
  final a = l.activity;
  final settled = a.kind == 'talk' ? Activity('idle', now, start: now) : a;
  return {
    'name': l.name,
    'place': l.place,
    'hunger': l.hunger,
    'energy': l.energy,
    'social': l.social,
    'mood': l.mood,
    'courage': l.courage,
    'friendship': {...l.friendship},
    'items': [...l.items],
    'activity': _activity(settled),
    'schedule': {
      for (final e in l.schedule.entries) '${e.key}': [e.value.$1, e.value.$2],
    },
    'lastTalk': {for (final e in l.lastTalk.entries) e.key: e.value.absolute},
    'lastConversationEnd': l.lastConversationEnd.absolute,
    'diary': [
      for (final (at, who, text) in l.diary) [at.absolute, who, text],
    ],
    'searched': [...l.searched],
    'reflections': [...l.reflections],
    'reflectedDay': l.reflectedDay,
    'thoughts': [...l.thoughts],
  };
}

void _loadLlama(Llama l, Map<String, Object?> m) {
  l
    ..place = m['place'] as String
    ..hunger = (m['hunger'] as num).toDouble()
    ..energy = (m['energy'] as num).toDouble()
    ..social = (m['social'] as num).toDouble()
    ..mood = m['mood'] as int
    ..courage = (m['courage'] as num).toDouble()
    ..activity = _unactivity((m['activity'] as Map).cast<String, Object?>())
    ..lastConversationEnd = GameTime.fromAbsolute(m['lastConversationEnd'] as int)
    ..reflectedDay = m['reflectedDay'] as int
    ..lastDecision = null;
  l.friendship
    ..clear()
    ..addAll((m['friendship'] as Map).cast<String, int>());
  l.items
    ..clear()
    ..addAll((m['items'] as List).cast<String>());
  l.schedule
    ..clear()
    ..addAll({
      for (final e in (m['schedule'] as Map).entries) int.parse(e.key as String): ((e.value as List)[0] as String, e.value[1] as String),
    });
  l.lastTalk
    ..clear()
    ..addAll({for (final e in (m['lastTalk'] as Map).entries) e.key as String: GameTime.fromAbsolute(e.value as int)});
  l.diary
    ..clear()
    ..addAll([for (final d in m['diary'] as List) (GameTime.fromAbsolute((d as List)[0] as int), d[1] as String, d[2] as String)]);
  l.searched
    ..clear()
    ..addAll((m['searched'] as List).cast<String>());
  l.reflections
    ..clear()
    ..addAll((m['reflections'] as List).cast<String>());
  l.thoughts
    ..clear()
    ..addAll((m['thoughts'] as List).cast<String>());
}

Map<String, Object?> _kb(KnowledgeBase kb) => {
  'idCounter': kb.idCounter,
  'facts': [
    for (final f in kb.facts.values)
      {
        'id': f.id,
        'text': f.text,
        'truth': f.truth,
        'origin': f.origin,
        'kind': f.kind.name,
        'created': f.created.absolute,
        'short': f.short,
        'keywords': f.keywords,
        'contradicts': f.contradicts,
        'secretOf': [...f.secretOf],
        'interested': f.interested,
        'knownBy': {
          for (final e in f.knownBy.entries)
            e.key: {'how': e.value.how, 'from': e.value.from, 'at': e.value.at.absolute, 'believes': e.value.believes},
        },
      },
  ],
  'transfers': [
    for (final t in kb.transfers) [t.llama, t.fact.id],
  ],
};

void _loadKb(KnowledgeBase kb, Map<String, Object?> j) {
  kb.facts.clear();
  kb.transfers.clear();
  kb.idCounter = j['idCounter'] as int;
  for (final raw in j['facts'] as List) {
    final m = (raw as Map).cast<String, Object?>();
    final f = Fact(
      id: m['id'] as String,
      text: m['text'] as String,
      truth: m['truth'] as bool,
      origin: m['origin'] as String,
      kind: FactKind.values.byName(m['kind'] as String),
      created: GameTime.fromAbsolute(m['created'] as int),
      short: m['short'] as String,
      keywords: [for (final g in m['keywords'] as List) (g as List).cast<String>()],
      contradicts: m['contradicts'] as String?,
      secretOf: (m['secretOf'] as List).cast<String>().toSet(),
      interested: m['interested'] as String?,
    );
    for (final e in (m['knownBy'] as Map).entries) {
      final k = (e.value as Map).cast<String, Object?>();
      f.knownBy[e.key as String] = Knowing(
        k['how'] as String,
        k['from'] as String?,
        GameTime.fromAbsolute(k['at'] as int),
        believes: k['believes'] as bool,
      );
    }
    kb.add(f);
  }
  for (final t in j['transfers'] as List) {
    final llama = (t as List)[0] as String;
    final f = kb[t[1] as String];
    kb.transfers.add(Transfer(llama, f, f.knownBy[llama]!));
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'laya_roles.dart';
import 'model.dart';
import 'village.dart';

/// A played game kept for deterministic replay: every model call with its
/// full output (and the text it streamed), when it was asked for and when
/// it landed on the village's pause-aware clock ([Village.uiMs]), the seed
/// and settings the game started from, the sim's events and hourly
/// checkpoints of its state.
///
/// The sim is deterministic given its seed, a fixed step and the model
/// outputs landing at the same points between steps, so [SessionReplay]
/// plays the same week again with no model loaded. Calls are keyed on
/// [Village.uiMs] rather than frame counts because a cutscene (which pauses
/// the sim) can take a different number of frames from run to run.
class SessionRecorder {
  SessionRecorder({required this.meta});

  /// The seed, settings and model description the game ran with.
  final Map<String, Object?> meta;
  final List<Map<String, Object?>> _calls = [];
  final List<String> _systems = [];
  final List<Map<String, Object?>> _events = [];
  final List<Map<String, Object?>> _checkpoints = [];
  int _landed = 0;
  int _chats = 0, _embeds = 0, _topics = 0;
  int? _lastHour;
  double Function() _clock = () => 0;

  int get calls => _calls.length;

  ChatModel chat(ChatModel inner) => _RecordingChat(this, inner);
  EmbedModel embed(EmbedModel inner) => _RecordingEmbed(this, inner);
  TopicChooser topics(TopicChooser inner) => _RecordingTopics(this, inner);

  /// Times calls on [v]'s clock and keeps its events.
  void attach(Village v) {
    _clock = () => v.uiMs;
    v.events.listeners.add((e) => _events.add({'ui': v.uiMs, ...e}));
  }

  /// Notes the sim's state once per game hour; call after every step.
  void checkpoint(Village v) {
    final hour = v.now.absolute ~/ 60;
    if (hour == _lastHour) return;
    _lastHour = hour;
    _checkpoints.add(sessionCheckpoint(v));
  }

  Map<String, Object?> _start(String kind, int n) {
    final call = <String, Object?>{'kind': kind, 'n': n, 'asked': _clock()};
    _calls.add(call);
    return call;
  }

  void _land(Map<String, Object?> call) {
    call['landed'] = _clock();
    call['order'] = _landed++;
  }

  int _system(String s) {
    final i = _systems.indexOf(s);
    if (i >= 0) return i;
    _systems.add(s);
    return _systems.length - 1;
  }

  Map<String, Object?> toJson() => {
    'version': sessionVersion,
    'meta': meta,
    'systems': _systems,
    'calls': _calls,
    'checkpoints': _checkpoints,
    'events': _events,
  };
}

/// Bumped when the file's layout changes.
const int sessionVersion = 1;

/// The state a checkpoint compares: the clock, the generator's position,
/// lines said, facts known and conversations held.
Map<String, Object?> sessionCheckpoint(Village v) => {
  'ui': v.uiMs,
  'now': v.now.absolute,
  'rng': v.rng.stateHex,
  'lines': v.lines.length,
  'known': v.cast.fold<int>(0, (n, l) => n + v.kb.known(l.name).length),
  'done': v.done.length,
};

class _RecordingChat implements ChatModel {
  _RecordingChat(this.r, this.inner);
  final SessionRecorder r;
  final ChatModel inner;

  @override
  Future<String> complete(
    String system,
    String user, {
    required int maxTokens,
    required double temp,
    required int seed,
    List<String> stop = const [],
    Map<String, dynamic>? jsonSchema,
    void Function(String text)? onText,
  }) async {
    final call = r._start('chat', r._chats++)
      ..addAll({
        'hash': chatHash(system, user, maxTokens, temp, seed, stop, jsonSchema),
        'system': r._system(system),
        'user': user,
        'maxTokens': maxTokens,
        'temp': temp,
        'seed': seed,
        if (stop.isNotEmpty) 'stop': stop,
        if (jsonSchema != null) 'json': true,
      });
    final stream = <List<Object>>[];
    try {
      final out = await inner.complete(
        system,
        user,
        maxTokens: maxTokens,
        temp: temp,
        seed: seed,
        stop: stop,
        jsonSchema: jsonSchema,
        onText: onText == null
            ? null
            : (t) {
                stream.add([r._clock(), t]);
                onText(t);
              },
      );
      call['out'] = out;
      return out;
    } catch (e) {
      call['error'] = '$e';
      rethrow;
    } finally {
      if (stream.isNotEmpty) call['stream'] = stream;
      r._land(call);
    }
  }
}

class _RecordingEmbed implements EmbedModel {
  _RecordingEmbed(this.r, this.inner);
  final SessionRecorder r;
  final EmbedModel inner;

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async {
    final call = r._start('embed', r._embeds++)..addAll({'hash': textHash(texts.join('\u0001')), 'texts': texts});
    try {
      final out = await inner.embedBatch(texts);
      call['vectors'] = [for (final v in out) encodeVector(v)];
      return out;
    } catch (e) {
      call['error'] = '$e';
      rethrow;
    } finally {
      r._land(call);
    }
  }
}

class _RecordingTopics implements TopicChooser {
  _RecordingTopics(this.r, this.inner);
  final SessionRecorder r;
  final TopicChooser inner;

  @override
  Future<String> choose(TopicCase c) async {
    final call = r._start('topic', r._topics++)..addAll({'hash': topicHash(c)});
    try {
      final out = await inner.choose(c);
      call['out'] = out;
      return out;
    } catch (e) {
      call['error'] = '$e';
      rethrow;
    } finally {
      r._land(call);
    }
  }
}

/// Plays a recorded session's model calls back in place of the models:
/// each call gets the output recorded for it, landing once the village's
/// clock reaches the time it landed in the recording, in the recorded
/// order. [pump] delivers whatever is due; call it between steps.
class SessionReplay implements ChatModel, EmbedModel, TopicChooser {
  SessionReplay(Map<String, Object?> json)
    : meta = (json['meta'] as Map).cast<String, Object?>(),
      _systems = (json['systems'] as List).cast<String>(),
      checkpoints = [for (final c in json['checkpoints'] as List) (c as Map).cast<String, Object?>()],
      events = [for (final e in json['events'] as List) (e as Map).cast<String, Object?>()] {
    if (json['version'] != sessionVersion) throw FormatException('session version ${json['version']}, expected $sessionVersion');
    final calls = [for (final c in json['calls'] as List) (c as Map).cast<String, Object?>()];
    for (final (i, c) in calls.indexed) {
      final rec = _Recorded(i, c);
      _byKind.putIfAbsent(rec.kind, () => []).add(rec);
      if (rec.landed != null) _landing.add(rec);
    }
    _landing.sort((a, b) => a.order.compareTo(b.order));
  }

  final Map<String, Object?> meta;
  final List<String> _systems;
  final List<Map<String, Object?>> checkpoints;

  /// The recorded sim events, each with the clock it happened at ('ui').
  final List<Map<String, Object?>> events;

  final Map<String, List<_Recorded>> _byKind = {};
  final Map<String, int> _nextOf = {};
  final List<_Recorded> _landing = [];
  final Map<int, _Pending> _pending = {};
  int _nextLanding = 0;
  int _stuckPumps = 0;

  /// How far past a recorded call's landing the replay runs before the
  /// call counts as never asked for.
  static const double giveUpMs = 5000;
  int _checked = 0;
  bool _pumping = false;
  double Function() clock = () => 0;

  /// Calls asked for with a different prompt than the one recorded at
  /// that point (the replay drifted), calls the recording does not have,
  /// recorded calls the replay never asked for, and checkpoints that did
  /// not match.
  int mismatches = 0, unrecorded = 0, skipped = 0, checkpointMisses = 0;

  /// Checkpoints compared so far.
  int checkpointsSeen = 0;
  void Function(String message)? log;

  bool get hasTopics => _byKind.containsKey('topic') || meta['laya'] == true;

  /// Every recorded call has been delivered.
  bool get drained => _nextLanding >= _landing.length;

  /// Times the replay on [v]'s clock.
  void attach(Village v) => clock = () => v.uiMs;

  _Recorded? _take(String kind, String hash) {
    final list = _byKind[kind] ?? const <_Recorded>[];
    var i = _nextOf[kind] ?? 0;
    if (i >= list.length) {
      unrecorded++;
      log?.call('REPLAY no recorded $kind call left (hash $hash)');
      return null;
    }
    if (list[i].hash != hash) {
      // Look a little ahead in case the replay skipped a call.
      final ahead = list.indexWhere((r) => r.hash == hash && !r.used, i);
      mismatches++;
      log?.call('REPLAY $kind #$i asked with another prompt${ahead >= 0 ? ', matched #$ahead' : ''}');
      if (ahead >= 0 && ahead - i < 64) i = ahead;
    }
    final rec = list[i]..used = true;
    _nextOf[kind] = i + 1;
    return rec;
  }

  Future<T> _ask<T>(String kind, String hash, T Function(_Recorded r) value, {void Function(String)? onText}) {
    final rec = _take(kind, hash);
    if (rec == null) return Completer<T>().future;
    final p = _Pending<T>(rec, value, onText);
    _pending[rec.index] = p;
    return p.completer.future;
  }

  @override
  Future<String> complete(
    String system,
    String user, {
    required int maxTokens,
    required double temp,
    required int seed,
    List<String> stop = const [],
    Map<String, dynamic>? jsonSchema,
    void Function(String text)? onText,
  }) => _ask('chat', chatHash(system, user, maxTokens, temp, seed, stop, jsonSchema), (r) => r.json['out'] as String, onText: onText);

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) => _ask('embed', textHash(texts.join('\u0001')), (r) {
    return [for (final v in r.json['vectors'] as List) decodeVector(v as String)];
  });

  @override
  Future<String> choose(TopicCase c) => _ask('topic', topicHash(c), (r) => r.json['out'] as String);

  /// The system prompt of recorded chat call [i] (for tools reading a file).
  String systemOf(Map<String, Object?> call) => _systems[call['system'] as int];

  /// Delivers every call that has landed by now, one per event-loop turn
  /// so each one's follow-up work runs before the next lands, as it did
  /// when the models wrote them. Streams partial text that is due too.
  Future<void> pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      final now = clock();
      for (final p in _pending.values) {
        p.streamUntil(now);
      }
      var progressed = false;
      while (_nextLanding < _landing.length) {
        final rec = _landing[_nextLanding];
        if (rec.landed! > clock() + 1e-6) break;
        final p = _pending.remove(rec.index);
        if (p == null) {
          // A call that landed during a pause may only be asked later in
          // the same pause (the clock stands still while the night skip
          // runs), so a call is given up on only once the replay has run
          // well past it, or after a very long wait with the clock stopped.
          if (!rec.used && (clock() - rec.landed! > giveUpMs || _stuckPumps++ > 20000)) {
            skipped++;
            log?.call('REPLAY skipped ${rec.kind} #${rec.n}: never asked for');
            _nextLanding++;
            _stuckPumps = 0;
            continue;
          }
          break;
        }
        _stuckPumps = 0;
        _nextLanding++;
        progressed = true;
        p.land();
        await settle();
      }
      if (progressed) _stuckPumps = 0;
    } finally {
      _pumping = false;
    }
  }

  /// Compares [v] with the recording's checkpoint for this hour; call
  /// after every step. Logs and counts a mismatch.
  void verify(Village v) {
    final hour = v.now.absolute ~/ 60;
    while (_checked < checkpoints.length && (checkpoints[_checked]['now'] as int) ~/ 60 < hour) {
      _checked++;
    }
    if (_checked >= checkpoints.length) return;
    final want = checkpoints[_checked];
    if ((want['now'] as int) ~/ 60 != hour) return;
    _checked++;
    checkpointsSeen++;
    final got = sessionCheckpoint(v);
    final same = want.keys.every((k) => k == 'ui' ? ((want[k] as num) - (got[k] as num)).abs() < 1e-3 : want[k] == got[k]);
    if (!same) {
      checkpointMisses++;
      log?.call('REPLAY checkpoint differs at ${v.now.label}: recorded $want, replayed $got');
    } else {
      log?.call('REPLAY checkpoint ${v.now.label} matches');
    }
  }

  /// How faithful the replay has been so far, for the log.
  String get summary =>
      'checkpoints ${checkpointsSeen - checkpointMisses}/$checkpointsSeen matched, prompt mismatches $mismatches, '
      'unrecorded $unrecorded, skipped $skipped, delivered $_nextLanding/${_landing.length}';

  /// Lets queued futures and their follow-ups run.
  static Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

class _Recorded {
  _Recorded(this.index, this.json)
    : kind = json['kind'] as String,
      n = json['n'] as int,
      hash = json['hash'] as String,
      landed = (json['landed'] as num?)?.toDouble(),
      order = (json['order'] as int?) ?? -1;
  final int index;
  final Map<String, Object?> json;
  final String kind;
  final int n;
  final String hash;
  final double? landed;
  final int order;
  bool used = false;
}

class _Pending<T> {
  _Pending(this.rec, this.value, this.onText);
  final _Recorded rec;
  final T Function(_Recorded r) value;
  final void Function(String)? onText;
  final Completer<T> completer = Completer<T>();
  int _streamed = 0;

  List<Object?> get _stream => (rec.json['stream'] as List?) ?? const [];

  void streamUntil(double now) {
    final s = _stream, on = onText;
    if (on == null) return;
    while (_streamed < s.length && ((s[_streamed] as List)[0] as num) <= now + 1e-6) {
      on((s[_streamed++] as List)[1] as String);
    }
  }

  void land() {
    streamUntil(double.infinity);
    final error = rec.json['error'];
    if (error != null) {
      completer.completeError(StateError('recorded model error: $error'));
    } else {
      completer.complete(value(rec));
    }
  }
}

/// FNV-1a over [s], as 16 hex digits.
String textHash(String s) {
  var h = 0xcbf29ce484222325;
  for (final c in utf8.encode(s)) {
    h ^= c;
    h *= 0x100000001b3;
  }
  return (h >>> 32).toRadixString(16).padLeft(8, '0') + (h & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
}

String chatHash(String system, String user, int maxTokens, double temp, int seed, List<String> stop, Map<String, dynamic>? schema) =>
    textHash([system, user, maxTokens, temp, seed, stop.join('\u0002'), schema == null ? '' : jsonEncode(schema)].join('\u0001'));

String topicHash(TopicCase c) => textHash(
  [
    c.speaker,
    c.listener,
    c.feeling,
    c.place,
    c.time,
    ...c.goals,
    for (final o in c.options) '${o.id}:${o.goal}:${o.raisedLately}',
  ].join('\u0001'),
);

/// A vector as base64 float32 when that is exact, else float64 ("d:").
String encodeVector(List<double> v) {
  final f32 = Float32List.fromList(v);
  var exact = true;
  for (var i = 0; i < v.length && exact; i++) {
    exact = f32[i] == v[i];
  }
  return exact ? base64.encode(f32.buffer.asUint8List()) : 'd:${base64.encode(Float64List.fromList(v).buffer.asUint8List())}';
}

List<double> decodeVector(String s) {
  if (s.startsWith('d:')) return Float64List.view(base64.decode(s.substring(2)).buffer).toList();
  return Float32List.view(base64.decode(s).buffer).toList();
}

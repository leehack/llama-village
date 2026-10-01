import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'lang.dart';

/// A text generator. The app backs it with llamadart; tests with a script.
abstract interface class ChatModel {
  /// Completes [user] under [system]. When [jsonSchema] is set the output is
  /// grammar-constrained to it. [onText], when set, gets the text written so
  /// far as it streams in.
  Future<String> complete(
    String system,
    String user, {
    required int maxTokens,
    required double temp,
    required int seed,
    List<String> stop,
    Map<String, dynamic>? jsonSchema,
    void Function(String text)? onText,
  });
}

/// Sentence embeddings for the knowledge-transfer check.
abstract interface class EmbedModel {
  Future<List<List<double>>> embedBatch(List<String> texts);
}

/// One timed model call, for the performance readout.
class CallRecord {
  CallRecord(this.type, this.ms, {this.queueMs});
  final String type;
  final double ms;
  final double? queueMs;
}

class RunMetrics {
  final List<CallRecord> calls = [];
  final Map<String, Map<String, int>> json = {};

  void count(String type, String outcome) {
    final m = json.putIfAbsent(type, () => {'calls': 0, 'first_try': 0, 'after_retry': 0, 'fallback': 0});
    m[outcome] = (m[outcome] ?? 0) + 1;
    m['calls'] = m['calls']! + 1;
  }

  void add(CallRecord r) {
    calls.add(r);
    if (calls.length > 2000) calls.removeRange(0, 500);
  }
}

double round1(num v) => (v * 10).round() / 10;
double mean(Iterable<num> v) => v.isEmpty ? 0 : v.fold<double>(0, (a, b) => a + b) / v.length;

class _Job {
  _Job(this.type, this.priority, this.seq, this.run, this.enqueued);
  final String type;
  final int priority;
  final int seq;
  final Stopwatch enqueued;
  final Future<void> Function(double queueMs) run;
}

/// Serialises jobs for one engine: llama.cpp runs one generation at a time
/// per context, so callers queue by priority (lower runs first), FIFO within
/// a priority.
class ModelQueue {
  ModelQueue(this.name);
  final String name;
  final List<_Job> _pending = [];
  bool _busy = false;
  bool _closed = false;
  int _seq = 0;
  String? runningType;

  int get depth => _pending.length + (_busy ? 1 : 0);
  bool get idle => depth == 0;
  bool get busy => _busy;

  Future<T> submit<T>(String type, int priority, Future<T> Function(double queueMs) run) {
    final completer = Completer<T>();
    if (_closed) return completer.future;
    _pending.add(
      _Job(type, priority, _seq++, (q) async {
        try {
          completer.complete(await run(q));
        } catch (e, s) {
          completer.completeError(e, s);
        }
      }, Stopwatch()..start()),
    );
    scheduleMicrotask(_pump);
    return completer.future;
  }

  /// Drops queued jobs; their futures never complete. Used at shutdown.
  void close() {
    _closed = true;
    _pending.clear();
  }

  Future<void> _pump() async {
    if (_busy || _pending.isEmpty || _closed) return;
    _pending.sort((a, b) => a.priority != b.priority ? a.priority.compareTo(b.priority) : a.seq.compareTo(b.seq));
    final job = _pending.removeAt(0);
    _busy = true;
    runningType = job.type;
    try {
      await job.run(job.enqueued.elapsedMicroseconds / 1000);
    } finally {
      _busy = false;
      runningType = null;
      scheduleMicrotask(_pump);
    }
  }

  /// Resolves once every queued job has finished.
  Future<void> drain() async {
    while (!idle) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }
}

/// Priorities on the dialogue engine.
abstract final class Priority {
  static const int dashReply = 0;
  static const int dialogue = 1;
  static const int outcome = 2;
  static const int dashOptions = 3;
  static const int thought = 4;
  static const int background = 5;
}

/// The dialogue model behind a priority queue.
class ChatRuntime {
  ChatRuntime(this.model, this.metrics) : queue = ModelQueue('chat');
  final ChatModel model;
  final RunMetrics metrics;
  final ModelQueue queue;

  static const String system =
      'You write a lively, slightly dramatic village soap opera about talking llamas. '
      'Keep every line short, concrete and in character. Characters only mention things listed '
      'as known to them; they never invent other secrets. Never use emojis. Never mention being an AI. $castGenders';

  /// [system], plus the language the player reads for calls in [lang].
  static String systemIn(Lang lang) => lang == Lang.en ? system : '$system ${writeIn(lang)}';

  Future<String> _generate(
    String type,
    String user,
    double queueMs, {
    Lang lang = Lang.en,
    required int maxTokens,
    required double temp,
    required int seed,
    List<String> stop = const [],
    Map<String, dynamic>? jsonSchema,
    void Function(String text)? onText,
  }) async {
    final watch = Stopwatch()..start();
    final out = await model.complete(
      systemIn(lang),
      user,
      maxTokens: maxTokens,
      temp: temp,
      seed: seed,
      stop: stop,
      jsonSchema: jsonSchema,
      onText: onText == null ? null : (t) => onText(polish(t, lang)),
    );
    metrics.add(CallRecord(type, watch.elapsedMicroseconds / 1000, queueMs: queueMs));
    return polish(out, lang);
  }

  /// Free text, parsed by [parse]; one retry with another seed, then
  /// [fallback]. A model error goes straight to the fallback. [onText]
  /// streams each attempt's text as it is written.
  Future<T> text<T>(
    String type,
    int priority,
    String user, {
    required T? Function(String) parse,
    required T Function() fallback,
    int maxTokens = 60,
    double temp = 0.85,
    required int seed,
    List<String> stop = const [],
    void Function(String text)? onText,
    Lang lang = Lang.en,
  }) {
    return queue.submit(type, priority, (queueMs) async {
      for (var attempt = 0; attempt < 2; attempt++) {
        final String raw;
        try {
          raw = await _generate(
            type,
            user,
            attempt == 0 ? queueMs : 0,
            maxTokens: maxTokens,
            temp: temp,
            seed: seed + attempt * 7919,
            stop: stop,
            onText: onText,
            lang: lang,
          );
        } catch (_) {
          break;
        }
        var value = parse(raw);
        // An answer in the wrong language is retried like one that does not parse.
        if (value is String && !speaksIn(value, lang)) value = null;
        if (value != null) {
          metrics.count(type, attempt == 0 ? 'first_try' : 'after_retry');
          return value;
        }
      }
      metrics.count(type, 'fallback');
      return fallback();
    });
  }

  /// Grammar-constrained JSON for small outcome objects; [validate] rejects
  /// a decoded object that does not fit.
  Future<Map<String, dynamic>> json(
    String type,
    int priority,
    String user,
    Map<String, dynamic> schema, {
    required Map<String, dynamic> Function() fallback,
    required bool Function(Map<String, dynamic>) validate,
    int maxTokens = 120,
    double temp = 0.4,
    required int seed,
    Lang lang = Lang.en,
  }) {
    return queue.submit(type, priority, (queueMs) async {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final raw = await _generate(
            type,
            '$user\n\nAnswer with compact JSON on one line.',
            attempt == 0 ? queueMs : 0,
            maxTokens: maxTokens,
            temp: temp,
            seed: seed + attempt * 7919,
            jsonSchema: schema,
            lang: lang,
          );
          final value = jsonDecode(raw.trim());
          if (value is Map<String, dynamic> && validate(value)) {
            metrics.count(type, attempt == 0 ? 'first_try' : 'after_retry');
            return value;
          }
        } on FormatException {
          continue;
        } catch (_) {
          break;
        }
      }
      metrics.count(type, 'fallback');
      return fallback();
    });
  }
}

double cosine(List<double> a, List<double> b) {
  var dot = 0.0, na = 0.0, nb = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  return dot / (math.sqrt(na) * math.sqrt(nb) + 1e-9);
}

/// Strips quotes, name prefixes, markdown and stray tags from one line.
String cleanLine(String s, {List<String> names = const []}) {
  var out = s.trim();
  final cut = out.indexOf('<');
  if (cut >= 0) out = out.substring(0, cut);
  out = out.replaceAll(RegExp(r'\*+'), '');
  for (final n in names) {
    out = out.replaceFirst(RegExp('^\\s*$n\\s*(\\(.*?\\))?\\s*:\\s*', caseSensitive: false), '');
  }
  out = out.replaceAll(RegExp(r'[“”"«»]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  return out;
}

/// EmbeddingGemma behind its own queue, with a cache for repeated texts.
class Embedder {
  Embedder(this.model, this.metrics) : queue = ModelQueue('embed');
  final EmbedModel model;
  final RunMetrics metrics;
  final ModelQueue queue;
  final Map<String, List<double>> _cache = {};

  /// Text -> vector for everything embedded so far; saves carry it.
  Map<String, List<double>> get cache => _cache;

  Future<List<List<double>>> embed(List<String> texts, {String type = 'embed'}) async {
    final missing = texts.where((t) => !_cache.containsKey(t)).toSet().toList();
    for (var i = 0; i < missing.length; i += 32) {
      final chunk = missing.sublist(i, math.min(missing.length, i + 32));
      final vectors = await queue.submit(type, 1, (queueMs) async {
        final watch = Stopwatch()..start();
        final v = await model.embedBatch([for (final t in chunk) 'title: none | text: $t']);
        metrics.add(CallRecord(type, watch.elapsedMicroseconds / 1000, queueMs: queueMs));
        return v;
      });
      for (var j = 0; j < chunk.length; j++) {
        _cache[chunk[j]] = vectors[j];
      }
    }
    return [for (final t in texts) _cache[t]!];
  }
}

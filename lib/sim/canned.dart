import 'dart:math' as math;

import 'model.dart';

/// A model-free stand-in: canned lines, schedules, options and outcomes.
/// Used by the tests and by "play without AI" when the models are missing.
class CannedChat implements ChatModel {
  CannedChat({this.delay = Duration.zero});

  /// Simulated generation time.
  final Duration delay;
  int calls = 0;

  static const List<String> _scripted = [
    'last page of a storybook',
    'Ring your bell and announce',
    'Write one line of the song',
    'fairy-tale picture book',
  ];

  static const List<String> _lines = [
    'Lovely weather for it, is it not?',
    'I have been meaning to ask you about that.',
    'You will never guess what I heard today.',
    'Hmm, I am not sure I believe a word of it.',
    'Well, I suppose we shall see soon enough.',
    'Oh, do not get me started on that again.',
    'That is the most exciting news all week!',
    'Let us keep this between the two of us.',
  ];

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
    calls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final r = math.Random(seed);
    if (jsonSchema != null) return _json(jsonSchema, r);
    if (user.contains('Write your plan for today')) {
      const places = ['bakery', 'pond', 'berry bushes', 'hilltop', 'home'];
      return [
        for (final h in [6, 8, 10, 12, 14, 16, 18, 20])
          '${h.toString().padLeft(2, '0')} ${h >= 20 ? 'home' : places[r.nextInt(places.length)]} | potter about',
      ].join('\n');
    }
    if (user.contains('Write four things Dash could say')) {
      final intents = RegExp(
        r'^(compliment|gossip|praise|tell|gift|help|tease): <',
        multiLine: true,
      ).allMatches(user).map((m) => m.group(1)!);
      return [for (final i in intents) '$i: ${_option(i)}'].join('\n');
    }
    if (user.contains('private thought')) return 'I wonder what everyone is up to today.';
    // Cutscene and epilogue lines fall back to their written defaults.
    if (_scripted.any(user.contains)) return '';
    return _lines[r.nextInt(_lines.length)];
  }

  static String _option(String intent) => switch (intent) {
    'compliment' => 'Your wool looks extra fluffy today, truly.',
    'gossip' => 'Someone told me they saw a fox near the bakery.',
    'praise' => 'Everyone says your neighbour has a heart of gold.',
    'tell' => 'Did you hear the latest news from the hilltop?',
    'gift' => 'I brought you a little present from my travels.',
    'help' => 'Can I lend you a wing with your work today?',
    _ => 'Is that hay in your fringe or a new hairstyle?',
  };

  Object? _value(Map<String, dynamic> schema, math.Random r) {
    final e = schema['enum'];
    if (e is List) return e[r.nextInt(e.length)];
    return switch (schema['type']) {
      'object' => {
        for (final MapEntry(:key, :value) in (schema['properties'] as Map<String, dynamic>).entries)
          key: _value(value as Map<String, dynamic>, r),
      },
      'array' => <Object?>[],
      'boolean' => r.nextBool(),
      'integer' || 'number' => 0,
      _ => '',
    };
  }

  String _json(Map<String, dynamic> schema, math.Random r) {
    final v = _value(schema, r);
    return _encode(v);
  }

  static String _encode(Object? v) => switch (v) {
    Map() => '{${v.entries.map((e) => '"${e.key}":${_encode(e.value)}').join(',')}}',
    List() => '[${v.map(_encode).join(',')}]',
    String() => '"$v"',
    _ => '$v',
  };
}

/// Bag-of-words hashing vectors; similar texts score as similar.
class HashEmbed implements EmbedModel {
  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async => [for (final t in texts) _vector(t)];

  static List<double> _vector(String text) {
    final v = List<double>.filled(64, 0);
    for (final w in text.toLowerCase().split(RegExp(r'[^a-z]+'))) {
      if (w.length < 3) continue;
      v[w.hashCode % 64] += 1;
    }
    return v;
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/sim/canned.dart';
import 'package:llama_village/sim/epilogue.dart';
import 'package:llama_village/sim/influence.dart';
import 'package:llama_village/sim/model.dart';
import 'package:llama_village/sim/village.dart';

class _Fixed implements ChatModel {
  _Fixed(this.line);
  final String line;

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
  }) async => line;
}

class _Broken implements ChatModel {
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
  }) async => throw StateError('model gone');
}

void main() {
  test('the epilogue prompt is built from the llama\'s final state', () {
    final v = Village(chat: CannedChat(), embed: HashEmbed(), seed: 1);
    v.festival
      ..state = 'judged'
      ..winner = 'Pip'
      ..scores.addAll({'Pip': 1.2, 'Mo': -1});
    final i = measure(v);
    final pip = epiloguePrompt(v, v.byName('Pip'), i);
    expect(pip, contains('won the Golden Bell'));
    expect(pip, contains('Closest to June'));
    expect(pip, contains('Pip and Mo'));
    expect(epiloguePrompt(v, v.byName('Mo'), i), contains('fainted on stage'));
    expect(epiloguePrompt(v, v.byName('Clover'), i), contains('ran the Berry Festival'));
  });

  test('a failed generation falls back to a deterministic line', () async {
    final v = Village(chat: _Broken(), embed: HashEmbed(), seed: 1);
    v.festival
      ..state = 'judged'
      ..winner = 'Mo';
    v.byName('Mo').mood = 3;
    final i = measure(v);
    final line = await epilogueLine(v, v.byName('Mo'), i);
    expect(line, fallbackEpilogue(v, v.byName('Mo'), i));
    expect(line, startsWith('Mo won the Golden Bell'));
    expect(line, contains('happier'));
    expect(
      fallbackEpilogue(v, v.byName('June'), i),
      'June watched the Berry Festival and was back to picking berries the next morning; she spent the autumn mostly with Pip.',
    );
  });

  test('a working model writes the line, cleaned of quotes and name prefixes', () async {
    final v = Village(chat: _Fixed('Bramble: "Bramble took up reading his poems aloud on the hilltop."'), embed: HashEmbed(), seed: 1);
    expect(await epilogueLine(v, v.byName('Bramble'), measure(v)), 'Bramble took up reading his poems aloud on the hilltop.');
  });

  test('canned play uses the rule-made line', () async {
    final v = Village(chat: CannedChat(), embed: HashEmbed(), seed: 1);
    expect(await epilogueLine(v, v.byName('Clover'), measure(v)), fallbackEpilogue(v, v.byName('Clover'), measure(v)));
  });
}

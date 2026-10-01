import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/sim/canned.dart';
import 'package:llama_village/sim/cast.dart';
import 'package:llama_village/sim/endings.dart';
import 'package:llama_village/sim/epilogue.dart';
import 'package:llama_village/sim/influence.dart';
import 'package:llama_village/sim/lang.dart';
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

/// Answers with [lines] in turn, counting the calls.
class _Scripted implements ChatModel {
  _Scripted(this.lines);
  final List<String> lines;
  int calls = 0;

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
  }) async => lines[calls++ % lines.length];
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

  Village judged(ChatModel chat, {Lang lang = Lang.en}) => Village(chat: chat, embed: HashEmbed(), seed: 1)
    ..lang = lang
    ..festival.state = 'judged'
    ..festival.winner = 'Pip'
    ..festival.scores.addAll({'Pip': 1.2, 'Clover': 0.9, 'Mo': -1});

  test('the epilogue prompt states the decided ending and the festival winner', () {
    final v = judged(CannedChat());
    final i = measure(v);
    final verdict = decideEnding(i);
    final prompt = epiloguePrompt(v, v.byName('Clover'), i, verdict: verdict);
    expect(prompt, contains('The week ended as "${endingInfo[verdict.ending]!.title}"'));
    expect(prompt, contains('Pip won the Golden Bell at the Berry Festival.'));
    expect(prompt, contains('Only Pip won the Golden Bell'));
    final facts = endingFacts(v, i, verdict).map((f) => f.english).toList();
    expect(facts, contains('Pip won the Golden Bell at the Berry Festival.'));
  });

  test('a line naming the wrong winner is written again, then replaced by the rules', () async {
    final wrong = _Scripted([
      "Clover a remporté la Cloche d'or et l'a gardée sur sa cheminée tout l'hiver.",
      'Clover rayonnait : elle avait gagné la Cloche d\'or devant tout le village.',
    ]);
    final v = judged(wrong, lang: Lang.fr);
    final i = measure(v);
    final line = await epilogueLine(v, v.byName('Clover'), i);
    expect(wrong.calls, 2, reason: 'one retry');
    expect(line, fallbackEpilogue(v, v.byName('Clover'), i));
    expect(line, startsWith('Clover a chanté à la fête des Baies sans gagner'));
    expect(v.metrics.json['epilogue']!['fallback'], 1);
  });

  test('a retry that gets the winner right is kept', () async {
    final chat = _Scripted(['클로버는 황금 종을 받고 가을 내내 자랑했어요.', 'Clover는 Pip이 황금 종을 받는 모습을 보며 내년 축제를 꿈꿨어요.']);
    final v = judged(chat, lang: Lang.ko);
    final line = await epilogueLine(v, v.byName('Clover'), measure(v));
    expect(chat.calls, 2);
    expect(line, contains('Pip이 황금 종을 받는'));
  });

  test('the winner check reads English, Korean and French claims', () {
    final v = judged(CannedChat());
    final pip = v.byName('Pip'), clover = v.byName('Clover'), june = v.byName('June');
    bool wrong(Llama l, String line) => epilogueContradicts(line, v, l);
    expect(wrong(clover, 'Clover won the Golden Bell and never let anyone forget it.'), isTrue);
    expect(wrong(clover, 'She held the Golden Bell up for the whole valley to see.'), isTrue);
    expect(wrong(clover, 'Clover cheered as Pip won the Golden Bell.'), isFalse);
    expect(wrong(clover, 'Clover handed Pip the Golden Bell and planned next year.'), isFalse);
    expect(wrong(pip, 'She won the Golden Bell and wore it with her red scarf.'), isFalse);
    expect(wrong(pip, 'Pip did not win the Golden Bell, but she smiled anyway.'), isTrue);
    expect(wrong(june, 'June sang her heart out but did not win.'), isFalse);
    expect(wrong(june, 'June는 우승해서 황금 종을 받았어요.'), isTrue);
    expect(wrong(june, 'June은 Pip이 황금 종을 받자 박수를 쳤어요.'), isFalse);
    expect(wrong(pip, 'Pip은 황금 종을 받지 못했어요.'), isTrue);
    expect(wrong(june, "June n'a pas gagné, mais elle a ri tout l'automne."), isFalse);
    expect(wrong(june, "June a gagné la Cloche d'or."), isTrue);
    expect(wrong(june, 'June fainted on stage.'), isTrue, reason: 'only Mo fainted');
    expect(wrong(june, 'June laughed when Mo fainted into the tarts.'), isFalse);
  });
}

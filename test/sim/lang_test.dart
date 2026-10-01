import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/sim/canned.dart';
import 'package:llama_village/sim/clock.dart';
import 'package:llama_village/sim/dash.dart';
import 'package:llama_village/sim/dialogue.dart';
import 'package:llama_village/sim/epilogue.dart';
import 'package:llama_village/sim/influence.dart';
import 'package:llama_village/sim/lang.dart';
import 'package:llama_village/sim/model.dart';
import 'package:llama_village/sim/storybook.dart';
import 'package:llama_village/sim/village.dart';
import 'package:llama_village/sim/week.dart';

import 'harness.dart';

/// Canned answers, with every prompt kept.
class _Recorder implements ChatModel {
  final CannedChat _canned = CannedChat();
  final List<(String system, String user, bool json)> calls = [];

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
  }) {
    calls.add((system, user, jsonSchema != null));
    return _canned.complete(system, user, maxTokens: maxTokens, temp: temp, seed: seed, stop: stop, jsonSchema: jsonSchema);
  }

  Iterable<(String, String, bool)> where(String marker) => calls.where((c) => c.$2.contains(marker));
}

/// Answers with [answers] in turn.
class _Script implements ChatModel {
  _Script(this.answers);
  final List<String> answers;
  int _next = 0;

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
  }) async => answers[_next++ % answers.length];
}

/// A day on [lang]: plans, talk, thoughts, a visit from Dash and the evening.
Future<_Recorder> _day(Lang lang) async {
  final r = _Recorder();
  final v = Village(chat: r, embed: HashEmbed(), seed: 6, msPerMinute: 10, autoAck: true)..lang = lang;
  await v.begin();
  await runMinutes(v, 6 * 60);
  final mo = v.byName('Mo');
  final options = v.dash.talk(mo);
  await settle();
  await options;
  v.dash.visit!.stage = VisitStage.choosing;
  v.dash.choose(0);
  await runMinutes(v, 10 * 60 + 10);
  return r;
}

void main() {
  test('every line the player reads is asked for in the chosen language; plans and outcomes stay English', () async {
    final ko = await _day(Lang.ko);
    final asks = {
      'dialogue': ko.where('next spoken line'),
      'thought': ko.where('private thought'),
      'reflection': ko.where('It is the night of day'),
      'Dash\'s options': ko.where('Write four things Dash could say'),
      'reply to Dash': ko.where('spoken reply to Dash'),
    };
    for (final MapEntry(key: what, value: calls) in asks.entries) {
      expect(calls, isNotEmpty, reason: what);
      for (final (system, user, _) in calls) {
        expect(system, contains('natural Korean'), reason: what);
        expect(user, contains('한국어'), reason: what);
        expect(user, contains('Pip, Mo, June, Bramble, Clover, Dash'), reason: what);
      }
    }
    expect(asks['Dash\'s options']!.first.$2, contains('Keep the JSON keys in English'));
    expect(asks['Dash\'s options']!.first.$3, isTrue, reason: 'the options are grammar-constrained JSON');
    final internal = [...ko.where('Write your plan for today'), ...ko.where('For each llama: mood change')];
    expect(internal, isNotEmpty);
    for (final (system, user, _) in internal) {
      expect(system, ChatRuntime.system);
      expect(user, isNot(contains('한국어')));
    }

    final en = await _day(Lang.en);
    expect(en.calls, isNotEmpty);
    for (final (system, user, _) in en.calls) {
      expect(system, ChatRuntime.system);
      expect(user, isNot(contains('한국어')));
      expect(user, isNot(contains('français')));
    }
  });

  test('the epilogue, the cutscene lines and the storybook carry the language too', () {
    final v = testVillage()..lang = Lang.fr;
    final i = measure(v);
    expect(epiloguePrompt(v, v.byName('Pip'), i), endsWith(speakIn(Lang.fr, story: true)));
    expect(announcementPrompt(Lang.fr), contains('français'));
    expect(songPrompt('Mo', Lang.ko), contains('한국어'));
    expect(announcementPrompt(Lang.en), isNot(contains('français')));
    final page = StoryPage(PageKind.day, day: 1);
    final prompt = storyPagePrompt(v, page, pageFacts(v, page));
    expect(prompt, contains('Begin with "Il était une fois"'));
    expect(prompt, endsWith(speakIn(Lang.fr, story: true)));
    expect(fallbackPageText(v.lang, page, const []), startsWith('Il était une fois'));
    v.lang = Lang.ko;
    expect(fallbackEpilogue(v, v.byName('Mo'), i), startsWith('Mo는 '));
    expect(fallbackEpilogue(v, v.byName('Pip'), i), startsWith('Pip은 '));
  });

  test('Korean output keeps the names in English letters with the right particles', () {
    expect(polish('모의 빵이 브램블을 아프게 했다고 소문냈지.', Lang.ko), 'Mo의 빵이 Bramble을 아프게 했다고 소문냈지.');
    expect(polish('준, 준비됐어? 모두 모였어.', Lang.ko), 'June, 준비됐어? 모두 모였어.');
    expect(polish('피프는 웃었다. Pip가 노래했다. Mo이 왔다.', Lang.ko), 'Pip은 웃었다. Pip이 노래했다. Mo가 왔다.');
    expect(polish('Clover는 모에게서 들은 이야기를 전했어요.', Lang.ko), 'Clover는 Mo에게서 들은 이야기를 전했어요.');
    expect(polish('Berry Festival 노래 경연에서 the Golden Bell을 받았어요.', Lang.ko), '베리 축제 노래 경연에서 황금 종을 받았어요.');
    expect(polish('Les llamas dansent à la Berry Festival.', Lang.fr), 'Les lamas dansent à la fête des Baies.');
    expect(polish('Pip가', Lang.en), 'Pip가');
  });

  test('a fact told in Korean or French is still recognised by its keywords', () {
    final v = testVillage();
    final rumour = v.kb['bread_rumour'];
    expect(rumour.keywordHit('Mo의 빵 때문에 Bramble이 배탈이 났대.'), isTrue);
    expect(rumour.keywordHit('Le pain de Mo a rendu Bramble malade.'), isTrue);
    expect(rumour.keywordHit('Mo의 빵은 정말 맛있어.'), isFalse);
    expect(v.kb['bramble_poems'].keywordHit('June에게 시를 쓰는 건 바로 나야.'), isTrue);
    expect(v.kb['storm_forecast'].keywordHit("Un orage va éclater cet après-midi, je vous préviens."), isTrue);
  });

  test('an answer in the wrong language does not count', () async {
    expect(speaksIn('June이 웃었어요.', Lang.ko), isTrue);
    expect(speaksIn('Bramble watched the lanterns fade.', Lang.ko), isFalse);
    expect(speaksIn("Bramble regarda les lanternes s'éteindre.", Lang.fr), isTrue);
    expect(speaksIn('Bramble watched the lanterns fade.', Lang.fr), isFalse);
    final v = Village(chat: CannedChat(), embed: HashEmbed(), seed: 1, msPerMinute: 10)..lang = Lang.ko;
    final english = await v.chat.text<String>(
      'thought',
      0,
      'x',
      parse: (raw) => 'An English thought here.',
      fallback: () => '',
      seed: 1,
      lang: Lang.ko,
    );
    expect(english, '', reason: 'retried, then the fallback');
    expect(v.metrics.json['thought']!['fallback'], 1);
    expect(
      dashOptionsFrom({'gossip': 'June hides berries under her bed.', 'help': '내가 반죽 좀 도와줄까?'}, ['gossip', 'help'], lang: Lang.ko),
      isNull,
    );
  });

  test('Korean lines are not mistaken for repeats', () {
    expect(parseLine('안녕 Mo, 오늘 빵 냄새 좋다.', ['June'], previous: ['어제 비가 많이 왔어.']), '안녕 Mo, 오늘 빵 냄새 좋다.');
    expect(parseLine('어제 비가 많이 왔어.', ['June'], previous: ['어제 비가 많이 왔어!']), isNull);
    expect(cleanLine('«Bonjour, Mo.»'), 'Bonjour, Mo.');
  });

  test('Dash\'s options parse from Korean values, and fall back to Korean canned lines', () {
    final picked = ['gossip', 'praise', 'help', 'tease'];
    final o = dashOptionsFrom(
      {'gossip': 'June이 몰래 베리를 숨겨 둔대.', 'praise': 'Mo는 마음씨가 정말 고와요.', 'help': '내가 반죽 좀 도와줄까?', 'tease': '그 모자 진짜 웃기다, 진짜로.'},
      picked,
      about: 'June',
      praiseAbout: 'Mo',
    )!;
    expect(o.map((x) => x.intent), picked);
    expect(cannedOptionIn(Lang.ko, 'praise', name: 'June', praiseAbout: 'Pip'), '어제 Pip이 네 칭찬을 엄청 하더라.');
    expect(cannedOptionIn(Lang.fr, 'gift', name: 'June', item: 'a jar of honey'), "Je t'ai apporté un pot de miel.");
  });

  test('the time of day: a part of today that is over is not still to come, and greetings fit the hour', () {
    const bedtime = GameTime(2, 22 * 60), noon = GameTime(3, 12 * 60 + 30), dawn = GameTime(3, 7 * 60);
    expect(timeSlip('The storm will hit this afternoon, mark my words.', bedtime, Lang.en), isTrue);
    expect(timeSlip('The storm will hit tomorrow afternoon.', bedtime, Lang.en), isFalse);
    expect(timeSlip('I baked bread this afternoon and it was lovely.', bedtime, Lang.en), isFalse);
    expect(timeSlip("It'll rain this afternoon, I'm sure.", noon, Lang.en), isFalse);
    expect(timeSlip("I'll finish the scarf this morning.", noon, Lang.en), isTrue);
    expect(timeSlip("L'orage va éclater cet après-midi !", bedtime, Lang.fr), isTrue);
    expect(timeSlip("L'orage éclatera cet après-midi.", bedtime, Lang.fr), isTrue);
    expect(timeSlip("Cet après-midi, j'ai cueilli des baies.", bedtime, Lang.fr), isFalse);
    expect(timeSlip('오늘 오후에 폭풍이 몰아칠 거야.', bedtime, Lang.ko), isTrue);
    expect(timeSlip('내일 오후에 폭풍이 올 거야.', bedtime, Lang.ko), isFalse);
    expect(timeSlip('오늘 오후에 빵을 구웠어.', bedtime, Lang.ko), isFalse);
    expect(timeSlip('Good night, Pip!', dawn, Lang.en), isTrue);
    expect(timeSlip('Good night, Pip!', bedtime, Lang.en), isFalse);
    expect(timeSlip('Good morning, Mo!', dawn, Lang.en), isFalse);
    expect(timeSlip('Good morning, Mo!', bedtime, Lang.en), isTrue);
    expect(timeSlip('Bonne nuit, June.', noon, Lang.fr), isTrue);
    expect(timeSlip('좋은 아침이야, Clover!', bedtime, Lang.ko), isTrue);
  });

  test('a slip of the clock is written once more, then the line falls back', () async {
    Future<List<String>> thoughts(List<String> answers) async {
      final v = Village(chat: _Script(answers), embed: HashEmbed(), seed: 1, msPerMinute: 10, autoAck: true)
        ..now = const GameTime(2, 21 * 60);
      final bramble = v.byName('Bramble');
      expect(v.thoughtPrompt(bramble), contains('Now: Day 2'));
      expect(v.reflectionPrompt(bramble, 2), contains('tomorrow is day 3'));
      v.think(bramble);
      await settle();
      return bramble.thoughts;
    }

    expect(await thoughts(['The storm will hit this afternoon, I know it.', 'The storm comes tomorrow afternoon, I know it.']), [
      'The storm comes tomorrow afternoon, I know it.',
    ]);
    expect(await thoughts(['The storm will hit this afternoon.', 'Good morning, clouds, the storm will come this afternoon.']), isEmpty);
  });

  test('every call knows who is female and who is male; French and Korean say it in their own words', () {
    expect(ChatRuntime.systemIn(Lang.fr), contains('Mo and Bramble are male'));
    expect(speakIn(Lang.fr), contains('Mo, Bramble et Dash sont des mâles'));
    expect(speakIn(Lang.fr), contains('Mo est content'));
    expect(speakIn(Lang.ko), contains('Mo, Bramble은 남자'));
    final v = testVillage()..lang = Lang.fr;
    final c = Conversation(1, v.byName('June'), v.byName('Mo'), 'bakery', v.now, 0);
    expect(turnPrompt(v, c, 0), contains('Mo (he)'));
  });
}

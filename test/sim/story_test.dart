import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/game/bot.dart';
import 'package:llama_village/sim/canned.dart';
import 'package:llama_village/sim/clock.dart';
import 'package:llama_village/sim/endings.dart';
import 'package:llama_village/sim/influence.dart';
import 'package:llama_village/sim/model.dart';
import 'package:llama_village/sim/snapshot.dart';
import 'package:llama_village/sim/story.dart';
import 'package:llama_village/sim/storybook.dart';
import 'package:llama_village/sim/village.dart';

import 'harness.dart';

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

/// Plays the week with the drama bot on canned models until the festival
/// is judged.
Future<Village> _week(int seed) async {
  final v = Village(chat: CannedChat(), embed: HashEmbed(), seed: seed, msPerMinute: 500, autoAck: true);
  final bot = PlayerBot(BotPreset.drama);
  await v.begin();
  for (var steps = 0; !v.weekOver && steps < 20000; steps++) {
    v.advance(500);
    await settle();
    bot.tick(v);
  }
  return v;
}

StoryBeat _beat(int seq, int day, int minute, int weight, String text) => StoryBeat(seq, day, minute, 'world', text, weight);

void main() {
  test('the same week always yields the same day digests, from what really happened', () async {
    final a = await _week(3);
    final b = await _week(3);
    expect(a.weekOver, isTrue);
    for (var day = 1; day <= festivalDay; day++) {
      final da = [for (final x in dayDigest(a.journal.beats, day)) '${x.hhmm} ${x.text}'];
      final db = [for (final x in dayDigest(b.journal.beats, day)) '${x.hhmm} ${x.text}'];
      expect(da, db, reason: 'day $day');
      expect(da, isNotEmpty, reason: 'day $day');
      expect(da.length, lessThanOrEqualTo(8));
    }
    final all = a.journal.beats.map((x) => x.text).join('\n');
    expect(all, contains('The lost red scarf: Pip noticed it was gone.'));
    expect(all, contains('Dash whispered made-up rumours about'));
    expect(dayDigest(a.journal.beats, 3).map((x) => x.text).join(' '), contains('Thunder cracks over the hilltop'));
    expect(dayDigest(a.journal.beats, festivalDay).map((x) => x.text).join(' '), contains('Golden Bell'));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('a digest keeps the weightiest beats of the day, in the order they happened', () {
    final beats = [
      _beat(0, 2, 400, 2, 'a small chat'),
      _beat(1, 2, 420, 7, 'the storm'),
      _beat(2, 1, 430, 9, 'yesterday'),
      _beat(3, 2, 500, 5, 'a rumour'),
      _beat(4, 2, 510, 5, 'a rumour'),
      _beat(5, 2, 520, 2, 'another chat'),
    ];
    expect(dayDigest(beats, 2, limit: 3).map((b) => b.text), ['a small chat', 'the storm', 'a rumour']);
    expect(digestLines(dayDigest(beats, 1)), ['- (early in the morning) yesterday']);
    expect(dayDigest(beats, 4), isEmpty);
  });

  test('story beats are plain words: no scores, no bracketed numbers', () {
    expect(plainStory('Clover hands the Golden Bell to June. Scores: June 0.48, Pip 0.30.'), 'Clover hands the Golden Bell to June.');
    expect(plainStory('it arrived on time; 0 llamas had been warned'), 'it arrived on time; nobody had believed him.');
    expect(plainStory('June let him down gently (June toward Bramble -4/10).'), 'June let him down gently.');
    expect(
      plainStory('Lanterns and a wobbly stage. 5 llamas gather on the hilltop.'),
      'Lanterns and a wobbly stage. five llamas gather on the hilltop.',
    );
  });

  test('the journal and the pictures survive a save', () async {
    final v = testVillage(seed: 8);
    await v.begin();
    await runMinutes(v, 6 * 60);
    v.album.add(StoryShot(v.album.newId(), 1, 600, 'talk', 3, Uint8List.fromList([1, 2, 3])));
    final copy = testVillage(seed: 1);
    restoreVillage(copy, decodeSave(jsonEncode(snapshotVillage(v))));
    expect(copy.journal.save(), v.journal.save());
    expect(copy.album.shots.single.png, [1, 2, 3]);
    expect(copy.journal.beats, isNotEmpty);
  });

  test('a save from before the storybook loads with an empty journal', () {
    final v = testVillage(seed: 8);
    final save = snapshotVillage(v)
      ..remove('journal')
      ..remove('album');
    final copy = testVillage(seed: 1);
    restoreVillage(copy, decodeSave(jsonEncode(save)));
    expect(copy.journal.beats, isEmpty);
    expect(copy.album.shots, isEmpty);
  });

  test('the album keeps the best pictures of each day', () {
    final album = StoryAlbum();
    Uint8List png() => Uint8List(1);
    for (final w in [1, 4, 2, 6]) {
      album.add(StoryShot(album.newId(), 2, 600 + w, 'talk', w, png()));
    }
    expect([for (final s in album.shots) s.weight]..sort(), [4, 6]);
    expect(album.wouldKeep(2, 'talk', 2), isFalse);
    expect(album.bestFor(2)!.weight, 6);
    expect(album.add(StoryShot(album.newId(), 5, 900, 'ending', 10, png())), isTrue);
    expect(album.ending!.weight, 10);
    expect(album.bestFor(5), isNull);
  });

  test('a failed model writes every page from the rules', () async {
    final v = Village(chat: _Broken(), embed: HashEmbed(), seed: 4, msPerMinute: 10, autoAck: true);
    v.festival
      ..state = 'judged'
      ..winner = 'Mo';
    v.journal.beats.add(_beat(0, 1, 7 * 60 + 30, 5, 'Pip reaches for her red scarf on its hook. The hook is empty.'));
    final i = measure(v);
    final verdict = decideEnding(i);
    final book = newStorybook(v, verdict, id: 'b1');
    var changes = 0;
    await StoryWriter(v, book, verdict: verdict, influence: i, onChange: () => changes++).start();
    expect(book.complete, isTrue);
    expect(changes, greaterThan(0));
    final day1 = book.pages[1];
    expect(day1.fallback, isTrue);
    expect(day1.text, fallbackPageText(v, day1, pageFacts(v, day1, verdict: verdict, influence: i)));
    expect(day1.text, startsWith('Once upon a time'));
    expect(day1.text, contains('The hook is empty.'));
    expect(book.pages.last.text, contains('Mo won the Golden Bell'));
    expect(v.metrics.json['storybook']!['fallback'], 6);
  });

  test('a page prompt carries only the day digest', () {
    final v = testVillage();
    v.journal.beats.add(_beat(0, 2, 8 * 60, 4, 'Mo pulls a honey loaf as big as a hay bale out of the bakery oven.'));
    final page = StoryPage(PageKind.day, day: 2);
    final prompt = storyPagePrompt(v, page, pageFacts(v, page), previous: 'Dash slept.');
    expect(prompt, contains('- (early in the morning) Mo pulls a honey loaf'));
    expect(prompt, contains('second day'));
    expect(prompt, contains('The previous page ended: "Dash slept."'));
    expect(prompt, contains('Do not begin with "Once upon a time"'));
    expect(pageFacts(v, StoryPage(PageKind.day, day: 3)).single, contains('quiet day'));
  });

  test('page text is cleaned, cut back to a whole sentence and rejected when too short', () {
    const long =
        'Once upon a time, Pip lost her red scarf. She looked everywhere for it, high and low, by the pond, the hilltop and the bakery. '
        'Mo said nothing at all, and baked bread instead';
    expect(
      parseStoryPage('**Page 1**\n$long'),
      'Once upon a time, Pip lost her red scarf. She looked everywhere for it, high and low, by the pond, the hilltop and the bakery.',
    );
    expect(parseStoryPage('Too short.'), isNull);
    expect(parseStoryPage('no ending punctuation at all'), isNull);
  });

  test('a storybook goes through JSON unchanged', () {
    final book = Storybook(
      id: 'w1',
      title: storyTitle,
      ending: Ending.quietValley,
      finishedAt: DateTime.utc(2026, 10, 1),
      language: 'ko',
      pages: [
        StoryPage(PageKind.cover, shot: Uint8List.fromList([9, 8])),
        StoryPage(PageKind.day, day: 1, text: '옛날 옛적에…', fallback: true),
      ],
    );
    final back = Storybook.fromJson((jsonDecode(jsonEncode(book.toJson())) as Map).cast<String, Object?>());
    expect(back.toJson(), book.toJson());
    expect(back.pages.first.shot, [9, 8]);
    expect(() => Storybook.fromJson({'game': 'x'}), throwsFormatException);
  });
}

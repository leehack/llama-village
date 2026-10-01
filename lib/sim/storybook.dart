import 'dart:convert';
import 'dart:typed_data';

import 'clock.dart';
import 'endings.dart';
import 'epilogue.dart';
import 'influence.dart';
import 'model.dart';
import 'story.dart';
import 'village.dart';
import 'week.dart';

enum PageKind { cover, day, ending }

/// One page of the storybook. [text] is set once the page is written (by
/// the model or, failing that, by [fallbackPageText]); [draft] holds the
/// text streaming in meanwhile.
class StoryPage {
  StoryPage(this.kind, {this.day, this.text, this.fallback = false, this.shot});
  final PageKind kind;
  final int? day;
  String? text;
  String draft = '';
  bool fallback;

  /// The illustration's PNG, if any.
  Uint8List? shot;

  bool get written => kind == PageKind.cover || text != null;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'day': day,
    'text': text,
    'fallback': fallback,
    if (shot != null) 'shot': base64Encode(shot!),
  };

  static StoryPage fromJson(Map<String, Object?> j) => StoryPage(
    PageKind.values.byName(j['kind'] as String),
    day: j['day'] as int?,
    text: j['text'] as String?,
    fallback: j['fallback'] as bool? ?? false,
    shot: j['shot'] == null ? null : base64Decode(j['shot'] as String),
  );
}

/// A finished week told as a fairy tale: a cover, a page per day and the
/// ending. Kept in the endings gallery, one per completed playthrough.
class Storybook {
  Storybook({
    required this.id,
    required this.title,
    required this.ending,
    required this.finishedAt,
    required this.pages,
    this.language = 'en',
  });

  final String id;
  final String title;
  final Ending ending;
  final DateTime finishedAt;

  /// The language code the pages were written in.
  final String language;
  final List<StoryPage> pages;

  bool get complete => pages.every((p) => p.written);
  int get writtenCount => pages.where((p) => p.kind != PageKind.cover && p.text != null).length;
  int get textPages => pages.where((p) => p.kind != PageKind.cover).length;

  Map<String, Object?> toJson() => {
    'game': 'llama_village_storybook',
    'version': 1,
    'id': id,
    'title': title,
    'ending': ending.name,
    'finishedAt': finishedAt.toUtc().toIso8601String(),
    'language': language,
    'pages': [for (final p in pages) p.toJson()],
  };

  static Storybook fromJson(Map<String, Object?> j) {
    if (j['game'] != 'llama_village_storybook' || j['version'] != 1) throw const FormatException('not a storybook');
    return Storybook(
      id: j['id'] as String,
      title: j['title'] as String,
      ending: Ending.values.byName(j['ending'] as String),
      finishedAt: DateTime.parse(j['finishedAt'] as String),
      language: j['language'] as String? ?? 'en',
      pages: [for (final p in j['pages'] as List) StoryPage.fromJson((p as Map).cast<String, Object?>())],
    );
  }
}

const String storyTitle = 'The Week Dash Came to Berry Valley';

const String _cast =
    'Dash is a little blue bird who flew into Berry Valley for festival week. The llamas: Pip the scarf knitter (she, vain and dramatic), '
    'Mo the shy baker (he, a golden voice), June the nosy berry farmer (she), Bramble the grumpy old weather watcher (he, secretly romantic) '
    'and Clover the bossy festival organiser (she).';

const List<String> _ordinal = ['first', 'second', 'third', 'fourth', 'fifth'];

/// The facts a page may use: the day's digest, or the ending's state.
List<String> pageFacts(Village v, StoryPage page, {EndingVerdict? verdict, Influence? influence}) {
  if (page.kind == PageKind.day) {
    final lines = digestLines(dayDigest(v.journal.beats, page.day!));
    return lines.isEmpty ? ['- A quiet day: the llamas went about their work.'] : lines;
  }
  final i = influence ?? measure(v);
  final verdictNow = verdict ?? decideEnding(i);
  final info = endingInfo[verdictNow.ending]!;
  final lies = i.falseBeliefs.length;
  final trusting = i.dashTrust.values.where((t) => t >= 3).length;
  final cross = i.dashTrust.values.where((t) => t <= -3).length;
  final happiest = [...v.cast]..sort((a, b) => b.mood.compareTo(a.mood));
  return [
    '- The week ended as "${info.title}": ${info.blurb}',
    '- ${i.festivalWinner == null ? 'Nobody won the Golden Bell.' : '${i.festivalWinner} won the Golden Bell at the Berry Festival.'}',
    '- ${lies == 0
        ? 'Every untrue rumour had been put right.'
        : lies < 4
        ? 'A few untrue rumours were still going round.'
        : 'Many untrue rumours were still going round.'}',
    '- ${i.harmony >= 1.5
        ? 'The llamas were fond of one another.'
        : i.harmony < 0.5
        ? 'Many friendships had soured.'
        : 'Some friendships were warm and some were cool.'}',
    for (final l in v.cast)
      if (arcFor(l, i).isNotEmpty && (l.name == 'Pip' || l.name == 'Bramble'))
        '- ${arcFor(l, i)[0].toUpperCase()}${arcFor(l, i).substring(1)}.',
    '- ${happiest.first.name} ended the week happiest, and ${happiest.last.name} the gloomiest.',
    '- ${cross > trusting
        ? 'Most llamas were cross with Dash.'
        : trusting >= 3
        ? 'Most llamas had grown fond of Dash.'
        : 'The llamas were not sure what to make of Dash.'}',
  ];
}

/// The model prompt for one page, grounded only in [pageFacts].
String storyPagePrompt(Village v, StoryPage page, List<String> facts, {String? previous}) {
  final day = page.day;
  final where = page.kind == PageKind.day
      ? 'This page tells the ${_ordinal[day! - 1]} day of festival week (${dayLabel(day)}).'
      : 'This is the last page: how the week ended.';
  final opening = day == 1
      ? 'Begin with "Once upon a time".'
      : page.kind == PageKind.ending
      ? 'End with a gentle closing line, like "And so…".'
      : 'Do not begin with "Once upon a time".';
  return [
    'You are writing a gentle fairy-tale picture book for children called "$storyTitle", one short page at a time.',
    _cast,
    where,
    'What really happened, in order (use only these facts; do not invent other events, secrets or outcomes):',
    ...facts,
    if (previous != null && previous.isNotEmpty) 'The previous page ended: "$previous"',
    '',
    'Write this page: one paragraph of 80 to 120 words, past tense, in a warm, simple fairy-tale voice. '
        'Retell the facts as a flowing little story, linking them with feelings and small details; you may leave out minor ones. '
        'Never mention clock times or counts; say "that morning" or "by evening" instead. $opening '
        'No title, no lists, no quotes around the text, no emojis.',
  ].join('\n');
}

/// A page of plain prose, or null when the model's text is unusable. A text
/// cut off by the token limit is trimmed back to its last full sentence.
String? parseStoryPage(String raw) {
  var text = raw
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'[*#_`]+'), '')
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !RegExp(r'^(page|day|title)\b.{0,40}:?$', caseSensitive: false).hasMatch(l))
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  text = text.replaceAll(RegExp(r'^["“”]+|["“”]+$'), '').trim();
  final end = text.lastIndexOf(RegExp(r'[.!?…。」”"]'));
  if (end < 0) return null;
  text = text.substring(0, end + 1).trim();
  final sentences = RegExp(r'[.!?…。]').allMatches(text).length;
  if (text.length < 120 || sentences < 2) return null;
  return text.length > 1400 ? null : text;
}

/// A page written by rules from the same facts, for when the model fails.
String fallbackPageText(Village v, StoryPage page, List<String> facts) {
  final told = [for (final f in facts) f.replaceFirst(RegExp(r'^- (\([^)]*\) )?'), '')];
  if (page.kind == PageKind.day) {
    final day = page.day!;
    final start = day == 1
        ? 'Once upon a time, in Berry Valley, a little blue bird called Dash arrived for festival week.'
        : 'On the ${_ordinal[day - 1]} day of festival week, the valley woke early.';
    return [start, ...told.take(5), if (day == festivalDay) 'And that evening the lanterns glowed all the way up the hill.'].join(' ');
  }
  return ['And so festival week came to an end.', ...told.take(4), 'Dash tucked his head under his wing, and the valley slept.'].join(' ');
}

/// Writes a storybook's pages in the background, one model call per page,
/// in order, each continuing from the last. [onChange] fires as text streams
/// in and when a page is done.
class StoryWriter {
  StoryWriter(this.v, this.book, {this.verdict, this.influence, required this.onChange});

  final Village v;
  final Storybook book;
  final EndingVerdict? verdict;
  final Influence? influence;
  final void Function() onChange;
  bool _stopped = false;
  Future<void>? _run;

  /// Starts writing; safe to call twice.
  Future<void> start() => _run ??= _writeAll();

  Future<void> _writeAll() async {
    String? previous;
    for (final page in book.pages.where((p) => p.kind != PageKind.cover)) {
      if (_stopped) return;
      await _write(page, previous);
      previous = _lastSentence(page.text ?? '');
    }
  }

  Future<void> _write(StoryPage page, String? previous) async {
    final facts = pageFacts(v, page, verdict: verdict, influence: influence);
    final text = await v.chat.text<String?>(
      'storybook',
      Priority.background,
      storyPagePrompt(v, page, facts, previous: previous),
      parse: parseStoryPage,
      fallback: () => null,
      maxTokens: 260,
      temp: 0.8,
      seed: 777 + (page.day ?? 9),
      onText: (t) {
        if (_stopped) return;
        page.draft = t;
        onChange();
      },
    );
    if (_stopped) return;
    page
      ..text = text ?? fallbackPageText(v, page, facts)
      ..fallback = text == null
      ..draft = '';
    onChange();
  }

  /// Finishes every unwritten page from the rules at once, for a game being
  /// left before the model is done.
  void finishWithFallbacks() {
    _stopped = true;
    for (final page in book.pages.where((p) => !p.written)) {
      page
        ..text = fallbackPageText(v, page, pageFacts(v, page, verdict: verdict, influence: influence))
        ..fallback = true
        ..draft = '';
    }
    onChange();
  }
}

String _lastSentence(String text) {
  final parts = RegExp(r'[^.!?…。]+[.!?…。]+').allMatches(text).map((m) => m.group(0)!.trim()).toList();
  return parts.isEmpty ? '' : parts.last;
}

/// Gives each page the best picture of its day (each picture used once), the
/// ending page the ending's picture and the cover the festival's. Called
/// again as pictures arrive during the ending scene.
void illustrate(Storybook book, StoryAlbum album) {
  final ending = album.ending ?? album.bestFor(festivalDay);
  final used = <String>{if (ending != null) ending.id};
  final cover = album.bestFor(festivalDay, used: used) ?? ending ?? album.bestFor(1);
  if (cover != null) used.add(cover.id);
  for (final p in book.pages) {
    final shot = switch (p.kind) {
      PageKind.cover => cover,
      PageKind.ending => ending,
      PageKind.day => album.bestFor(p.day!, used: used) ?? album.bestFor(p.day!),
    };
    if (shot != null && p.kind == PageKind.day) used.add(shot.id);
    p.shot = shot?.png ?? p.shot;
  }
}

/// A new book for the week [v] just finished, its pages unwritten.
Storybook newStorybook(Village v, EndingVerdict verdict, {required String id, DateTime? at}) {
  final book = Storybook(
    id: id,
    title: storyTitle,
    ending: verdict.ending,
    finishedAt: at ?? DateTime.now(),
    pages: [
      StoryPage(PageKind.cover),
      for (var d = 1; d <= festivalDay; d++) StoryPage(PageKind.day, day: d),
      StoryPage(PageKind.ending),
    ],
  );
  illustrate(book, v.album);
  return book;
}

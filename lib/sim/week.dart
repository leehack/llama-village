import 'cast.dart';
import 'clock.dart';
import 'facts.dart';
import 'lang.dart';
import 'said.dart';
import 'threads.dart';
import 'village.dart';

/// "Berry Festival day", "the day before the festival", "3 days to the festival".
String dayLabel(int day) => switch (festivalDay - day) {
  0 => 'Berry Festival day',
  1 => 'the day before the festival',
  < 0 => 'after the festival',
  final n => '$n days to the festival',
};

/// Clover's festival announcement, for the day-1 cutscene.
String announcementPrompt(Lang lang) => inLang(
  [
    'You are Clover, the festival organiser (bossy, ambitious, playful). It is the morning of day 1 of festival week.',
    'Ring your bell and announce to the whole village: the Berry Festival is on day $festivalDay at 16:00 on the hilltop, '
        'and the best singer wins the Golden Bell.',
    'Write only what Clover shouts: one or two short sentences, under 30 words. No quotes, no name prefix.',
  ].join('\n'),
  lang,
);

/// One line of [name]'s festival song.
String songPrompt(String name, Lang lang) => inLang(
  'Write one line of the song ${name == 'Pip' ? 'Pip sings (very off-key)' : '$name sings'} at the Berry Festival, '
  'about berries or the valley. Write the lyric itself, not a description of it. Under 12 words, no quotes.',
  lang,
);

/// The small set pieces that make each day of the week different. The big
/// threads (scarf, festival, crush, rumour, storm) are spread over the week
/// in their own classes.
class WeekThread extends StoryThread {
  WeekThread() : super('week', 'Festival week', 'day 1');

  /// Contestants who turned up to Clover's rehearsal.
  final List<String> rehearsed = [];

  @override
  void onMinute(Village v) {
    final t = v.now;
    if (t.minute == 6 * 60 && state != 'day ${t.day}') advance(v, 'day ${t.day}', Said(SaidKey.whyDay, dayLabel(t.day), {'day': t.day}));
    if (t.day == 2 && t.minute == 8 * 60 && v.kb.maybe('honey_loaf') == null) {
      final f = v.newFact(
        'honey_loaf',
        'Mo baked a giant honey loaf for the Berry Festival on day 2.',
        "Mo's honey loaf",
        kind: FactKind.news,
        saidKey: SaidKey.factHoneyLoaf,
        keywords: [
          ['honey', 'loaf'],
        ],
      );
      v.kb.learn('Mo', f.id, 'own', t);
      v.worldEvent(
        const Said(SaidKey.honeyLoafTitle, 'Honey loaf'),
        const Said(SaidKey.honeyLoaf, 'Mo pulls a honey loaf as big as a hay bale out of the bakery oven.'),
        at: 'bakery',
        fact: f.id,
      );
      v.byName('Mo').addMood(1);
    }
    if (t.day == 4 && t.minute == 11 * 60 && v.kb.maybe('rehearsal') == null) {
      final singers = v.festival.contestants.where((n) => v.byName(n).place == 'hilltop').toList();
      rehearsed.addAll(singers);
      final f = v.newFact(
        'rehearsal',
        'Clover held a festival rehearsal on the hilltop on day 4; ${singers.isEmpty ? 'no singer came' : '${singers.join(' and ')} practised'}.',
        'the rehearsal',
        kind: FactKind.event,
        saidKey: singers.isEmpty ? SaidKey.factRehearsalEmpty : SaidKey.factRehearsal,
        said: {'names': singers},
        keywords: [
          ['rehears'],
        ],
      );
      v.worldEvent(
        const Said(SaidKey.rehearsalTitle, 'Rehearsal'),
        singers.isEmpty
            ? const Said(SaidKey.rehearsalEmpty, 'Clover blows her whistle at an empty stage and writes something stern on her clipboard.')
            : const Said(SaidKey.rehearsal, 'Clover runs the singers through their songs; the stage wobbles but holds.'),
        at: 'hilltop',
        fact: f.id,
        also: {'Clover'},
      );
      for (final n in singers) {
        v.byName(n).courage = (v.byName(n).courage + 0.1).clamp(0, 1);
      }
    }
    if (t.day == festivalDay && t.minute == 6 * 60 + 30 && v.kb.maybe('lanterns') == null) {
      final f = v.newFact(
        'lanterns',
        'Clover strung lanterns all the way up the hilltop path for the festival.',
        'the lanterns',
        saidKey: SaidKey.factLanterns,
      );
      v.announce(
        const Said(SaidKey.lanternsTitle, 'Lanterns'),
        const Said(SaidKey.lanterns, 'Overnight, Clover has strung lanterns all the way up the hilltop path.'),
        f.id,
        quiet: true,
        how: 'saw',
      );
    }
  }

  @override
  List<Goal> goalsFor(Llama l, Village v) {
    final t = v.now;
    final rehearsal = t.day == 4 && t.minute >= 9 * 60 && t.minute < 11 * 60 + 10;
    if (!rehearsal || !v.kb.knows(l.name, 'festival')) return const [];
    if (l.name == 'Clover') {
      return [
        Goal(
          id,
          const Said(SaidKey.goalRunRehearsal, 'run the festival rehearsal on the hilltop at 11:00'),
          place: 'hilltop',
          weight: 0.8,
          by: 11 * 60,
        ),
      ];
    }
    if (v.festival.contestants.contains(l.name)) {
      return [
        Goal(
          id,
          const Said(SaidKey.goalGoRehearsal, "go to Clover's rehearsal on the hilltop at 11:00"),
          place: 'hilltop',
          weight: 0.7,
          by: 11 * 60,
        ),
      ];
    }
    return const [];
  }

  @override
  void finish(Village v) {
    resolution = 'Rehearsal: ${rehearsed.isEmpty ? 'nobody came' : rehearsed.join(', ')}.';
  }

  @override
  Map<String, Object?> save() => {...super.save(), 'rehearsed': rehearsed};

  @override
  void load(Map<String, Object?> j) {
    super.load(j);
    rehearsed
      ..clear()
      ..addAll((j['rehearsed'] as List).cast<String>());
  }
}

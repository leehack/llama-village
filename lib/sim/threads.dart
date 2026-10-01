import 'cast.dart';
import 'clock.dart';
import 'dialogue.dart';
import 'log.dart';
import 'facts.dart';
import 'places.dart';
import 'said.dart';
import 'village.dart';

/// A want that a thread hands to one llama: it steers the utility choice
/// (place, seek, action) and the dialogue prompt (text, topic).
class Goal {
  Goal(this.thread, this.said, {this.place, this.seek, this.action, this.weight = 0.5, this.topic});
  final String thread;

  /// What the llama wants, in the player's language; [text] is its English.
  final Said said;
  String get text => said.english;
  final String? place;
  final String? seek;
  final String? action;
  final double weight;
  final String? topic;
}

abstract class StoryThread {
  StoryThread(this.id, this.title, this.state);
  final String id;
  final String title;
  String state;
  String? resolution;
  final List<String> history = [];

  void advance(Village v, String to, Said why) {
    history.add('${v.now.label} $state → $to: $why');
    v.events.emit('thread', {'thread': id, 'from': state, 'to': to, 'why': why.english, 'said': why.toJson()});
    v.log.note(
      Said(SaidKey.threadTurn, 'Thread $title: $state → $to ($why)', {'thread': id, 'from': state, 'to': to, 'why': why}),
      kind: LogKind.thread,
    );
    state = to;
  }

  List<Goal> goalsFor(Llama l, Village v);
  void onMinute(Village v) {}
  void onLearn(Transfer t, Village v) {}
  void onConversationEnd(Conversation c, Village v) {}
  void finish(Village v);

  Map<String, Object?> toJson() => {'id': id, 'title': title, 'state': state, 'resolution': resolution, 'history': history};

  /// Everything a save needs to resume this thread; subclasses add their own fields.
  Map<String, Object?> save() => {
    'state': state,
    'resolution': resolution,
    'history': [...history],
  };

  void load(Map<String, Object?> j) {
    state = j['state'] as String;
    resolution = j['resolution'] as String?;
    history
      ..clear()
      ..addAll((j['history'] as List).cast<String>());
  }
}

List<String> _strings(Object? list) => (list as List).cast<String>();

class ScarfThread extends StoryThread {
  ScarfThread() : super('scarf', 'The lost red scarf', 'unnoticed');
  String? holder;
  String? finder;
  String? confession;
  GameTime? missingAt;

  @override
  void onMinute(Village v) {
    if (state != 'unnoticed' || v.now.day != 1 || v.now.minute < 7 * 60 + 30) return;
    final pip = v.byName('Pip');
    final atHome = pip.place == pip.home && pip.activity.kind != 'walk';
    if (!atHome && v.now.minute < 10 * 60) return;
    final f = v.newFact(
      'scarf_missing',
      "Pip's red scarf has gone missing from her hut.",
      'the missing scarf',
      kind: FactKind.event,
      saidKey: SaidKey.factScarfMissing,
      keywords: [
        ['scarf'],
        ['missing', 'gone', 'lost', 'vanish', 'stolen', 'took', 'find', 'where', 'seen', 'see '],
      ],
    );
    v.worldEvent(
      const Said(SaidKey.scarfMissingTitle, 'Pip notices her red scarf is missing'),
      atHome
          ? const Said(
              SaidKey.scarfMissingHome,
              'Pip reaches for her red scarf on its hook. The hook is empty. She turns her hut upside down: the scarf is gone.',
            )
          : const Said(
              SaidKey.scarfMissingAway,
              'Pip realises she has not seen her red scarf since yesterday. It is not on its hook: the scarf is gone.',
            ),
      at: pip.place,
      fact: f.id,
      also: {'Pip'},
    );
    pip.addMood(-3);
    missingAt = v.now;
    advance(v, 'missing', const Said(SaidKey.whyPipNoticed, 'Pip noticed it was gone'));
  }

  static const List<String> searchOrder = ['berry bushes', 'bakery', 'hilltop', 'pond'];

  void search(Village v, Llama l) {
    if (state != 'missing' || l.place != 'pond') {
      l.searched.add(l.place);
      v.log.note(
        Said(SaidKey.searchNothing, '${l.name} searches ${theP(l.place)} for the scarf and finds nothing.', {
          'name': l.name,
          'place': l.place,
        }),
      );
      return;
    }
    final knowsWhere = v.kb.knows(l.name, 'scarf_where');
    if (!knowsWhere && v.rng.nextDouble() > 0.3) {
      v.log.note(Said(SaidKey.pondNothing, '${l.name} pokes around the pond reeds but finds nothing.', {'name': l.name}));
      return;
    }
    finder = l.name;
    final f = v.newFact(
      'scarf_found',
      "${l.name} found Pip's red scarf in the pond reeds.",
      'the scarf was found',
      kind: FactKind.deed,
      saidKey: SaidKey.factScarfFound,
      said: {'name': l.name},
      keywords: [
        ['scarf'],
        ['found', 'reeds', 'fished'],
      ],
    );
    v.worldEvent(
      const Said(SaidKey.scarfFoundTitle, 'Scarf found'),
      Said(SaidKey.scarfFound, "${l.name} pulls ${l.name == 'Pip' ? 'her' : "Pip's"} red scarf, soggy, out of the pond reeds.", {
        'name': l.name,
      }),
      at: 'pond',
      fact: f.id,
    );
    v.witness('scarf_where', 'pond');
    if (l.name == 'Pip') {
      l.addMood(3);
      advance(v, 'returned', const Said(SaidKey.whyPipFoundHerself, 'Pip found it herself in the pond reeds'));
    } else {
      holder = l.name;
      l.items.add("Pip's red scarf");
      advance(v, 'found', Said(SaidKey.whyFoundIt, '${l.name} found it in the pond reeds', {'name': l.name}));
    }
  }

  @override
  void onConversationEnd(Conversation c, Village v) {
    if (state != 'found' || holder == null) return;
    final pair = {c.a.name, c.b.name};
    if (!pair.contains('Pip') || !pair.contains(holder)) return;
    final giver = v.byName(holder!);
    final pip = v.byName('Pip');
    giver.items.remove("Pip's red scarf");
    pip.addMood(3);
    pip.addFriendship(giver.name, 2);
    final f = v.newFact(
      'scarf_returned',
      "${giver.name} gave Pip back her red scarf.",
      'the scarf came back',
      kind: FactKind.deed,
      saidKey: SaidKey.factScarfReturned,
      said: {'name': giver.name},
      keywords: [
        ['scarf'],
        ['gave', 'back', 'returned'],
      ],
    );
    v.worldEvent(
      const Said(SaidKey.scarfReturnedTitle, 'Scarf returned'),
      Said(SaidKey.scarfReturned, '${giver.name} hands Pip her red scarf.', {'name': giver.name}),
      at: c.place,
      fact: f.id,
    );
    holder = null;
    advance(v, 'returned', Said(SaidKey.whyGaveBack, '${giver.name} gave it back', {'name': giver.name}));
  }

  @override
  void onLearn(Transfer t, Village v) {
    if (t.fact.id == 'mo_scarf' && t.llama == 'Pip' && confession == null) {
      final said = switch ((t.knowing.from, t.knowing.how)) {
        ('Mo', 'told') => const Said(SaidKey.confMoTold, 'Mo confessed to Pip'),
        ('Mo', 'overheard') => const Said(SaidKey.confPipOverheard, 'Pip overheard Mo confessing to someone else'),
        (final from, final how) => Said(SaidKey.confPipLearned, 'Pip learned it ($how) from $from', {'from': from ?? how}),
      };
      confession = said.english;
      v.log.note(Said(SaidKey.threadNote, 'Thread $title: $confession', {'thread': id, 'text': said}), kind: LogKind.thread);
      history.add('${v.now.label} $confession');
    }
  }

  @override
  List<Goal> goalsFor(Llama l, Village v) {
    final goals = <Goal>[];
    if (state == 'unnoticed' && l.name == 'Pip' && v.now.day == 1 && v.now.minute >= 7 * 60 + 30) {
      goals.add(
        Goal(id, const Said(SaidKey.goalFetchScarf, 'fetch your red scarf from your hut to look your best'), place: l.home, weight: 0.8),
      );
    }
    if (state == 'missing') {
      final unsearched = searchOrder.where((p) => !l.searched.contains(p)).toList();
      if (l.name == 'Pip') {
        bool asked(Llama o) => l.lastTalk[o.name] != null && l.lastTalk[o.name]!.compareTo(missingAt!) >= 0;
        final unasked = (v.cast.where((o) => o != l && !asked(o)).toList()
          ..sort((a, b) => (l.friendship[b.name] ?? 0).compareTo(l.friendship[a.name] ?? 0)));
        if (unasked.isNotEmpty) {
          goals.add(
            Goal(
              id,
              Said(SaidKey.goalAskSeen, 'ask ${unasked.first.name} whether they have seen your red scarf', {'name': unasked.first.name}),
              seek: unasked.first.name,
              weight: 0.5,
              topic: 'scarf_missing',
            ),
          );
        } else {
          goals.add(
            Goal(
              id,
              const Said(SaidKey.goalFindScarf, 'find your red scarf and find out who took it'),
              topic: 'scarf_missing',
              weight: 0.2,
            ),
          );
        }
        goals.add(
          Goal(
            id,
            const Said(SaidKey.goalSearchScarf, 'search for your red scarf'),
            action: 'search',
            place: unsearched.isEmpty ? 'pond' : unsearched.first,
            weight: 0.3,
          ),
        );
      } else if (l.name == 'Mo' && v.kb.knows('Mo', 'scarf_missing')) {
        goals.add(
          Goal(
            id,
            const Said(SaidKey.goalMoFish, 'quietly fish Pip\'s scarf out of the pond reeds before anyone learns what you did'),
            place: 'pond',
            action: 'search',
            weight: 0.75,
          ),
        );
      } else if (v.kb.knows(l.name, 'scarf_missing') && (l.friendship['Pip'] ?? 0) >= 3 && unsearched.isNotEmpty) {
        goals.add(
          Goal(
            id,
            const Said(SaidKey.goalHelpPip, 'help Pip look for her red scarf'),
            place: unsearched.first,
            action: 'search',
            weight: 0.25,
          ),
        );
      }
    }
    if (state == 'found' && holder == l.name) {
      goals.add(
        Goal(
          id,
          l.name == 'Mo'
              ? const Said(
                  SaidKey.goalGiveBackMo,
                  'give Pip back her red scarf, and decide whether to confess you knocked it into the pond',
                )
              : const Said(SaidKey.goalGiveBack, 'give Pip back her red scarf (you found it in the pond reeds)'),
          seek: 'Pip',
          weight: 0.9,
          topic: 'scarf_found',
        ),
      );
    }
    if (l.name == 'Mo' && state == 'returned' && confession == null && v.kb.knows('Pip', 'scarf_returned')) {
      goals.add(
        Goal(
          id,
          const Said(SaidKey.goalMoGuilty, 'you still feel guilty: maybe confess to Pip that you knocked her scarf into the pond'),
          seek: 'Pip',
          weight: 0.3,
          topic: 'mo_scarf',
        ),
      );
    }
    return goals;
  }

  @override
  Map<String, Object?> save() => {
    ...super.save(),
    'holder': holder,
    'finder': finder,
    'confession': confession,
    'missingAt': missingAt?.absolute,
  };

  @override
  void load(Map<String, Object?> j) {
    super.load(j);
    holder = j['holder'] as String?;
    finder = j['finder'] as String?;
    confession = j['confession'] as String?;
    final at = j['missingAt'] as int?;
    missingAt = at == null ? null : GameTime.fromAbsolute(at);
  }

  @override
  void finish(Village v) {
    resolution = switch (state) {
      'returned' =>
        'Scarf back with Pip${finder == null ? '' : ' (found by $finder)'}; ${confession ?? 'the truth stayed secret: Pip never learned Mo knocked it in'}.',
      'found' => 'Found by $finder, but still not returned to Pip.',
      'missing' => 'Still missing at the end.',
      _ => 'Never noticed.',
    };
  }
}

class FestivalThread extends StoryThread {
  FestivalThread() : super('festival', 'Berry Festival singing contest', 'unannounced');
  final List<String> contestants = [];
  String? winner;
  final Map<String, double> scores = {};

  /// (singer, what happened) in stage order, for the festival cutscene.
  final List<(String, String)> performances = [];

  @override
  void onMinute(Village v) {
    final t = v.now;
    if (t.day == 1 && t.minute == 7 * 60 && state == 'unannounced') {
      final f = v.newFact(
        'festival',
        'Clover announced the Berry Festival for day $festivalDay at 16:00 on the hilltop; the best singer wins the Golden Bell.',
        'the Berry Festival',
        kind: FactKind.news,
        saidKey: SaidKey.factFestival,
        said: {'day': festivalDay},
        keywords: [
          ['festival', 'golden bell', 'contest'],
        ],
      );
      v.announce(
        const Said(SaidKey.festivalAnnouncedTitle, 'Berry Festival announced'),
        Said(
          SaidKey.festivalAnnounced,
          'Clover rings her bell: the Berry Festival is on day $festivalDay at 16:00 on the hilltop, and the best singer wins the Golden Bell.',
          {'day': festivalDay},
        ),
        f.id,
      );
      contestants.add('Pip');
      final s = v.newFact(
        'pip_signed',
        'Pip signed up to sing at the Berry Festival.',
        'Pip entering the contest',
        kind: FactKind.deed,
        saidKey: SaidKey.factSigned,
        said: {'name': 'Pip'},
      );
      v.announce(
        const Said(SaidKey.pipSignsUpTitle, 'Pip signs up'),
        const Said(SaidKey.pipSignsUp, 'Pip shouts her name before Clover finishes the sentence.'),
        s.id,
        quiet: true,
      );
      advance(v, 'announced', const Said(SaidKey.whyAnnounced, 'Clover announced it; Pip signed up at once'));
    }
    if (t.day == festivalDay && t.minute == festivalMinute && state != 'judged') _perform(v);
    if (t.day == festivalDay && t.minute == festivalMinute + 25 && state == 'performed') _judge(v);
  }

  void signUp(Village v, Llama l, Said how) {
    if (contestants.contains(l.name) || state == 'performed' || state == 'judged') return;
    contestants.add(l.name);
    final f = v.newFact(
      '${l.name.toLowerCase()}_signed',
      '${l.name} signed up to sing at the Berry Festival.',
      '${l.name} entering the contest',
      kind: FactKind.deed,
      saidKey: SaidKey.factSigned,
      said: {'name': l.name},
    );
    v.witness(f.id, l.place, extra: {l.name, if (how.english.contains('Clover')) 'Clover'});
    v.log.note(Said(SaidKey.signsUp, '${l.name} signs up for the singing contest ($how).', {'name': l.name, 'how': how}));
    if (state == 'announced') advance(v, 'contest', Said(SaidKey.whyJoinedPip, '${l.name} joined Pip in the contest', {'name': l.name}));
  }

  @override
  void onConversationEnd(Conversation c, Village v) {
    if (state == 'unannounced' || state == 'performed' || state == 'judged') return;
    final pair = [c.a, c.b];
    final mo = pair.where((l) => l.name == 'Mo').firstOrNull;
    if (mo != null && !contestants.contains('Mo')) {
      final other = pair.firstWhere((l) => l != mo);
      final delta = c.friendshipDelta[other.name] ?? 0;
      if (delta > 0) {
        mo.courage = (mo.courage + 0.06 * delta).clamp(0, 1);
        final pct = (mo.courage * 100).round();
        v.log.note(
          Said(SaidKey.moBraver, 'Mo feels braver after talking with ${other.name} (courage $pct%).', {'name': other.name, 'pct': pct}),
        );
      }
      if (other.name == 'Clover' && c.answers['mo_agreed_to_sing'] == true) {
        if (mo.courage >= 0.3) {
          signUp(v, mo, const Said(SaidKey.howToldClover, 'he told Clover yes'));
        } else {
          final pct = (mo.courage * 100).round();
          v.log.note(Said(SaidKey.moTookBack, 'Mo said yes, then went pale and took it back (courage $pct%).', {'pct': pct}));
        }
      }
    }
    final june = pair.where((l) => l.name == 'June').firstOrNull;
    if (june != null && !contestants.contains('June') && pair.any((l) => l.name == 'Clover') && june.mood >= 1) {
      signUp(v, june, const Said(SaidKey.howCloverTalked, 'Clover talked her into it'));
    }
  }

  void _perform(Village v) {
    final present = v.cast.where((l) => l.place == 'hilltop').toList();
    final singers = contestants.where((n) => v.byName(n).place == 'hilltop').toList();
    v.worldEvent(
      const Said(SaidKey.festivalTitle, 'The Berry Festival'),
      Said(
        singers.isEmpty ? SaidKey.festivalNoSingers : SaidKey.festivalGathers,
        'Lanterns, berry tarts and a wobbly stage. ${present.length} llamas gather on the hilltop. '
        'Singers: ${singers.isEmpty ? 'nobody turned up' : singers.join(', ')}.',
        {'count': present.length, 'names': singers},
      ),
      at: 'hilltop',
    );
    for (final n in singers) {
      final l = v.byName(n);
      if (n == 'Pip') {
        const text = 'Pip sings with enormous feeling and almost no tune.';
        performances.add((n, text));
        v.worldEvent(const Said(SaidKey.pipSingsTitle, 'Pip sings'), const Said(SaidKey.pipSings, text), at: 'hilltop');
        v.witness('pip_tune', 'hilltop');
      } else if (n == 'Mo' && l.courage < 0.45) {
        final f = v.newFact(
          'mo_fainted',
          'Mo fainted on stage at the Berry Festival before singing a note.',
          'Mo fainting',
          kind: FactKind.deed,
          saidKey: SaidKey.factMoFainted,
        );
        const text = 'Mo opens his mouth, sways, and faints into the berry tarts.';
        performances.add((n, text));
        v.worldEvent(const Said(SaidKey.moFaintsTitle, 'Mo faints'), const Said(SaidKey.moFaints, text), at: 'hilltop', fact: f.id);
        scores[n] = -1;
      } else {
        final text = n == 'Mo'
            ? 'Mo sings, and the hilltop goes completely silent, then roars.'
            : '$n sings a cheerful berry-picking song.';
        performances.add((n, text));
        v.worldEvent(
          Said(SaidKey.singsTitle, '$n sings', {'name': n}),
          Said(n == 'Mo' ? SaidKey.moSings : SaidKey.llamaSings, text, {'name': n}),
          at: 'hilltop',
        );
      }
    }
    advance(
      v,
      'performed',
      singers.isEmpty
          ? const Said(SaidKey.whyNoSingers, 'no singers')
          : Said(SaidKey.whySang, '${singers.join(', ')} sang', {'names': singers}),
    );
  }

  void _judge(Village v) {
    final clover = v.byName('Clover');
    final audience = v.cast.where((l) => l.place == 'hilltop').toList();
    final dealKnownBy = v.kb['clover_deal'].knownBy.keys.where((n) => n != 'Clover' && n != 'Pip').toList();
    final rigged = dealKnownBy.isEmpty && (clover.friendship['Pip'] ?? 0) >= 2;
    for (final n in contestants.where((n) => v.byName(n).place == 'hilltop')) {
      if (scores[n] == -1) continue;
      final l = v.byName(n);
      final support =
          audience.where((a) => a != l).map((a) => a.friendship[n] ?? 0).fold<int>(0, (s, f) => s + f) /
          (audience.length <= 1 ? 1 : audience.length - 1);
      scores[n] = l.singing + 0.04 * support + 0.03 * l.mood + 0.03 * (clover.friendship[n] ?? 0) + (rigged && n == 'Pip' ? 0.6 : 0);
    }
    final ranked = scores.entries.where((e) => e.value >= 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    winner = ranked.isEmpty ? null : ranked.first.key;
    final how = winner == null
        ? const Said(SaidKey.howNobodySang, 'nobody sang')
        : rigged && winner == 'Pip'
        ? const Said(SaidKey.howDeal, 'Clover quietly honoured her secret deal with Pip')
        : dealKnownBy.isNotEmpty
        ? Said(SaidKey.howDealKnown, 'the deal was known to ${dealKnownBy.join(', ')}, so Clover judged fairly', {'names': dealKnownBy})
        : const Said(SaidKey.howFair, 'judged on voice and the crowd');
    if (winner != null) {
      final f = v.newFact(
        'festival_winner',
        '$winner won the Golden Bell at the Berry Festival.',
        'the festival winner',
        kind: FactKind.event,
        saidKey: SaidKey.factFestivalWinner,
        said: {'name': winner},
      );
      final scores = [for (final e in ranked) '${e.key} ${e.value.toStringAsFixed(2)}'].join(', ');
      v.announce(
        const Said(SaidKey.goldenBellTitle, 'The Golden Bell'),
        Said(SaidKey.goldenBell, 'Clover hands the Golden Bell to $winner. Scores: $scores.', {'name': winner, 'scores': scores}),
        f.id,
        story: Said(SaidKey.goldenBellStory, 'Clover hands the Golden Bell to $winner.', {'name': winner}),
      );
      v.byName(winner!).addMood(4);
      for (final n in contestants.where((n) => n != winner)) {
        v.byName(n).addMood(-2);
      }
    }
    final why = winner == null
        ? Said(SaidKey.whyNoWinner, 'No winner: $how.', {'how': how})
        : Said(SaidKey.whyWon, '$winner won the Golden Bell; $how.', {'name': winner, 'how': how});
    resolution = why.english;
    advance(v, 'judged', why);
  }

  @override
  List<Goal> goalsFor(Llama l, Village v) {
    final goals = <Goal>[];
    if (!v.kb.knows(l.name, 'festival') || state == 'judged') return goals;
    final t = v.now;
    if (t.day == festivalDay && t.minute >= 15 * 60 + 20 && t.minute < 16 * 60 + 40) {
      goals.add(
        Goal(
          id,
          const Said(SaidKey.goalBeAtFestival, 'be at the hilltop for the Berry Festival at 16:00'),
          place: 'hilltop',
          action: 'festival',
          weight: 1.4,
        ),
      );
    }
    if (l.name == 'Clover' && state != 'performed') {
      if (t.day == festivalDay && t.minute >= 14 * 60) {
        goals.add(Goal(id, const Said(SaidKey.goalSetUpStage, 'set up the festival stage on the hilltop'), place: 'hilltop', weight: 0.9));
      }
      final lastAsked = l.lastTalk['Mo'];
      if (!contestants.contains('Mo') && (lastAsked == null || t.minutesSince(lastAsked) > 180)) {
        goals.add(
          Goal(
            id,
            const Said(SaidKey.goalRecruitMo, 'recruit Mo to sing at the festival (he has the best voice)'),
            seek: 'Mo',
            weight: 0.45,
            topic: 'festival',
          ),
        );
      }
    }
    if (l.name == 'Mo' && !contestants.contains('Mo') && l.courage >= 0.5) {
      goals.add(
        Goal(
          id,
          const Said(SaidKey.goalTellClover, 'tell Clover you will sing at the festival after all'),
          seek: 'Clover',
          weight: 0.55,
          topic: 'festival',
        ),
      );
    }
    if (l.name == 'Mo' && !contestants.contains('Mo')) {
      final feeling = l.courage < 0.3
          ? const Said(SaidKey.goalMoScared, 'you are far too scared to sing at the festival; you would faint')
          : l.courage < 0.5
          ? const Said(SaidKey.goalMoTempted, 'you are tempted to sing at the festival but scared of fainting')
          : const Said(SaidKey.goalMoAlmost, 'you are almost brave enough to say yes to singing at the festival');
      goals.add(Goal(id, feeling, weight: 0.1, topic: 'festival'));
    }
    if (l.name == 'Pip' && t.minute < 8 * 60 + 30) {
      goals.add(
        Goal(
          id,
          const Said(SaidKey.goalPractise, 'practise singing at the pond at dawn, where nobody can hear'),
          place: 'pond',
          action: 'practise',
          weight: 0.7,
        ),
      );
    }
    if (l.name == 'Pip') {
      goals.add(Goal(id, const Said(SaidKey.goalWinBell, 'win the Golden Bell; outshine Mo'), weight: 0.1, topic: 'festival'));
    }
    return goals;
  }

  @override
  void finish(Village v) {
    resolution ??= 'Not held (state $state).';
  }

  @override
  Map<String, Object?> save() => {
    ...super.save(),
    'contestants': [...contestants],
    'winner': winner,
    'scores': {...scores},
    'performances': [
      for (final (n, t) in performances) [n, t],
    ],
  };

  @override
  void load(Map<String, Object?> j) {
    super.load(j);
    contestants
      ..clear()
      ..addAll(_strings(j['contestants']));
    winner = j['winner'] as String?;
    scores
      ..clear()
      ..addAll({for (final e in (j['scores'] as Map).entries) e.key as String: (e.value as num).toDouble()});
    performances
      ..clear()
      ..addAll([for (final p in j['performances'] as List) ((p as List)[0] as String, p[1] as String)]);
  }
}

class CrushThread extends StoryThread {
  CrushThread() : super('crush', "Bramble's crush on June", 'secret');
  bool flowersToday = false;
  String? revealedBy;
  String? pendingReaction;

  @override
  void onMinute(Village v) {
    if (v.now.minute == 6 * 60) flowersToday = false;
    if (v.now.day == 2 && v.now.minute == 6 * 60 + 1) {
      v.newFact(
        'anon_poem',
        'June found an unsigned love poem tucked into the wildflowers at the berry bushes.',
        'the anonymous love poem',
        kind: FactKind.event,
        saidKey: SaidKey.factAnonPoem,
        keywords: [
          ['poem', 'verse'],
          ['unsigned', 'anonymous', 'love', 'flowers', 'someone'],
        ],
      );
    }
    // June finds the poem the first time she is at the berry bushes from day 2 on.
    if (v.now.day >= 2 && !v.kb.knows('June', 'anon_poem') && v.byName('June').place == 'berry bushes' && v.kb.maybe('anon_poem') != null) {
      v.kb.learn('June', 'anon_poem', 'saw', v.now);
      v.log.note(const Said(SaidKey.juneFindsPoem, 'June finds an unsigned love poem tucked into the wildflowers. She reads it twice.'));
      v.byName('June').addMood(1);
      if (state == 'secret') advance(v, 'poem found', const Said(SaidKey.whyJuneFoundPoem, 'June found an anonymous love poem'));
    }
  }

  void leaveFlowers(Village v, Llama bramble) {
    flowersToday = true;
    final f =
        v.kb.maybe('bramble_flowers') ??
        v.newFact(
          'bramble_flowers',
          'Bramble was seen leaving wildflowers at the berry bushes at dawn.',
          'Bramble and the wildflowers',
          kind: FactKind.deed,
          saidKey: SaidKey.factBrambleFlowers,
          keywords: [
            ['bramble', 'he ', 'him', 'old'],
            ['flower'],
          ],
        );
    final seen = v.witness(f.id, 'berry bushes', exclude: {'Bramble'});
    v.kb.learn('Bramble', f.id, 'own', v.now);
    final english = 'Bramble tucks wildflowers into the berry bushes${seen.isEmpty ? ' unseen' : ', but ${seen.join(' and ')} sees him'}.';
    v.log.note(seen.isEmpty ? Said(SaidKey.flowersUnseen, english) : Said(SaidKey.flowersSeen, english, {'names': seen}));
    if (seen.contains('June') && state == 'secret') {
      advance(v, 'suspected', const Said(SaidKey.whyJuneSawFlowers, 'June saw Bramble leave the flowers'));
    }
  }

  @override
  void onLearn(Transfer t, Village v) {
    if (t.llama == 'June' && t.fact.id == 'bramble_poems' && revealedBy == null) {
      final overheard = t.knowing.how == 'overheard';
      final from = t.knowing.from ?? t.knowing.how;
      revealedBy = overheard ? '$from (overheard)' : from;
      advance(
        v,
        revealedBy == 'Bramble' ? 'confessed' : 'exposed',
        revealedBy == 'Bramble'
            ? const Said(SaidKey.whyBrambleTold, 'Bramble told June himself')
            : Said(overheard ? SaidKey.whyJuneOverheard : SaidKey.whyJuneHeard, 'June heard it from $revealedBy', {'name': from}),
      );
      pendingReaction = revealedBy;
    }
    if (t.llama == 'June' && t.fact.id == 'bramble_flowers' && state == 'secret') {
      advance(v, 'suspected', const Said(SaidKey.whyJuneHeardFlowers, 'June heard Bramble leaves the flowers'));
    }
  }

  @override
  void onConversationEnd(Conversation c, Village v) {
    if (pendingReaction == null) return;
    final names = {c.a.name, c.b.name};
    if (!names.containsAll({'June', 'Bramble'})) return;
    final june = v.byName('June');
    final feeling = june.friendship['Bramble'] ?? 0;
    final outcome = feeling >= 5 ? 'accepted' : 'let down gently';
    v.byName('Bramble').addMood(outcome == 'accepted' ? 3 : -2);
    pendingReaction = null;
    resolution =
        'Bramble ${revealedBy == 'Bramble' ? 'confessed' : 'was exposed by $revealedBy'}; June ${outcome == 'accepted' ? 'accepted him' : 'let him down gently'} '
        '(June toward Bramble $feeling/10).';
    final by = revealedBy!.replaceFirst(' (overheard)', '');
    advance(
      v,
      outcome,
      Said(by == 'Bramble' ? SaidKey.whyCrushConfessed : SaidKey.whyCrushExposed, resolution!, {
        'name': by,
        'outcome': outcome == 'accepted' ? 'accepted' : 'declined',
      }),
    );
  }

  @override
  List<Goal> goalsFor(Llama l, Village v) {
    final goals = <Goal>[];
    final t = v.now;
    if (l.name == 'Bramble' && !flowersToday && t.minute < 6 * 60 + 50) {
      goals.add(
        Goal(
          id,
          const Said(SaidKey.goalLeaveFlowers, 'leave wildflowers for June at the berry bushes before anyone sees'),
          place: 'berry bushes',
          action: 'flowers',
          weight: 1.0,
        ),
      );
    }
    if (l.name == 'Bramble' && revealedBy == null && (t.day >= festivalDay - 1 || l.mood >= 3)) {
      goals.add(
        Goal(
          id,
          const Said(SaidKey.goalTellJune, 'work up the courage to tell June that you are the one writing her love poems'),
          seek: 'June',
          weight: t.day >= festivalDay - 1 ? 0.55 : 0.3,
          topic: 'bramble_poems',
        ),
      );
    }
    if (l.name == 'June' && revealedBy == null && (v.kb.knows('June', 'anon_poem') || v.kb.knows('June', 'wildflowers'))) {
      final topic = v.kb.knows('June', 'bramble_flowers')
          ? 'bramble_flowers'
          : (v.kb.knows('June', 'anon_poem') ? 'anon_poem' : 'wildflowers');
      goals.add(
        Goal(id, const Said(SaidKey.goalFindWhoFlowers, 'find out who leaves you wildflowers and love poems'), weight: 0.3, topic: topic),
      );
    }
    if (l.name == 'June' && pendingReaction != null) {
      goals.add(
        Goal(
          id,
          const Said(SaidKey.goalTalkBramble, 'talk to Bramble about the love poems'),
          seek: 'Bramble',
          weight: 0.7,
          topic: 'bramble_poems',
        ),
      );
    }
    if (l.name == 'Bramble' && pendingReaction != null) {
      goals.add(Goal(id, const Said(SaidKey.goalFaceJune, 'face June about the poems'), seek: 'June', weight: 0.5, topic: 'bramble_poems'));
    }
    return goals;
  }

  @override
  Map<String, Object?> save() => {
    ...super.save(),
    'flowersToday': flowersToday,
    'revealedBy': revealedBy,
    'pendingReaction': pendingReaction,
  };

  @override
  void load(Map<String, Object?> j) {
    super.load(j);
    flowersToday = j['flowersToday'] as bool;
    revealedBy = j['revealedBy'] as String?;
    pendingReaction = j['pendingReaction'] as String?;
  }

  @override
  void finish(Village v) {
    resolution ??= switch (state) {
      'secret' => 'Still secret: June never learned who writes the poems.',
      'poem found' => 'June found the poem but never learned it was Bramble.',
      'suspected' => 'June suspects Bramble but nobody said it out loud.',
      _ => 'Revealed ($state) but June and Bramble never talked it through.',
    };
  }
}

class RumourThread extends StoryThread {
  RumourThread() : super('rumour', "The bread rumour", 'spreading');
  final List<String> hops = [];
  final List<String> debunks = [];

  List<String> believers(Village v) => [
    for (final e in v.kb['bread_rumour'].knownBy.entries)
      if (e.value.believes) e.key,
  ];

  @override
  void onLearn(Transfer t, Village v) {
    if (t.fact.id == 'bread_rumour') {
      hops.add('${t.knowing.from} → ${t.llama}${t.knowing.believes ? '' : ' (not believed)'}');
      if (t.knowing.believes) v.maybeByName(t.llama)?.addFriendship('Mo', -1);
    }
    if (t.fact.id == 'bread_truth' && t.knowing.believes) {
      debunks.add('${t.knowing.from ?? t.knowing.how} → ${t.llama}');
      if (believers(v).isEmpty && state == 'spreading') {
        advance(v, 'debunked', const Said(SaidKey.whyNobodyBelieves, 'nobody believes it any more'));
      }
    }
    if (t.fact.id == 'june_rumour' && (t.llama == 'Mo' || t.llama == 'Bramble') && state != 'june exposed') {
      v.byName(t.llama).addFriendship('June', -2);
      advance(
        v,
        'june exposed',
        Said(SaidKey.whyJuneExposed, '${t.llama} learned June made it up (from ${t.knowing.from})', {
          'name': t.llama,
          'from': t.knowing.from ?? t.knowing.how,
        }),
      );
    }
  }

  @override
  List<Goal> goalsFor(Llama l, Village v) {
    final goals = <Goal>[];
    if (l.name == 'June' && v.now.day <= 2) {
      goals.add(
        Goal(id, const Said(SaidKey.goalSpreadRumour, "spread the juicy story about Mo's bread"), weight: 0.15, topic: 'bread_rumour'),
      );
    }
    if (l.name == 'Mo') {
      goals.add(
        Goal(
          id,
          const Said(SaidKey.goalClearName, 'clear your name: your bread never made anyone sick'),
          weight: 0.15,
          topic: 'bread_truth',
        ),
      );
    }
    if (l.name == 'Bramble' && v.kb.knows('Bramble', 'bread_rumour')) {
      goals.add(
        Goal(
          id,
          const Said(SaidKey.goalSetRecord, "set the record straight: Mo's bread never made you sick"),
          weight: 0.35,
          topic: 'bread_truth',
        ),
      );
    }
    return goals;
  }

  @override
  Map<String, Object?> save() => {
    ...super.save(),
    'hops': [...hops],
    'debunks': [...debunks],
  };

  @override
  void load(Map<String, Object?> j) {
    super.load(j);
    hops
      ..clear()
      ..addAll(_strings(j['hops']));
    debunks
      ..clear()
      ..addAll(_strings(j['debunks']));
  }

  @override
  void finish(Village v) {
    final b = believers(v);
    resolution =
        '${state == 'spreading' ? 'Still spreading' : state}: ${hops.length} hops (${hops.join(', ')}); '
        '${debunks.length} debunks; believers at the end: ${b.isEmpty ? 'none' : b.join(', ')}.';
  }
}

class StormThread extends StoryThread {
  StormThread() : super('storm', "Bramble's storm warning", 'forecast');
  final List<String> warnedBeforeStorm = [];
  final List<String> soaked = [];

  @override
  void onMinute(Village v) {
    final t = v.now;
    if (t.day == stormDay && t.minute == 15 * 60 && state == 'forecast') {
      v.storm = true;
      for (final e in v.kb['storm_forecast'].knownBy.entries) {
        if (e.key != 'Bramble' && e.key != 'Dash' && e.value.believes) warnedBeforeStorm.add(e.key);
      }
      final f = v.newFact(
        'storm_hit',
        'A storm hit the village on day $stormDay at 15:00: thunder, sideways rain, the festival bunting blew away.',
        'the storm',
        kind: FactKind.event,
        saidKey: SaidKey.factStormHit,
        said: {'day': stormDay},
      );
      v.announce(
        const Said(SaidKey.stormTitle, 'Storm'),
        const Said(SaidKey.storm, 'Thunder cracks over the hilltop and sideways rain sweeps the village.'),
        f.id,
        how: 'saw',
      );
      final right = v.newFact(
        'bramble_right',
        "Bramble's storm prediction came true.",
        'Bramble being right',
        kind: FactKind.deed,
        saidKey: SaidKey.factBrambleRight,
        keywords: [
          ['bramble', 'he '],
          ['right', 'predict', 'warned', 'told us', 'said it'],
        ],
      );
      for (final n in v.kb['storm_forecast'].knownBy.keys) {
        v.kb.learn(n, right.id, 'saw', t);
      }
      for (final l in v.cast.where((l) => l.outdoors)) {
        soaked.add('${l.name} (${l.place})');
        l.addMood(-1);
      }
      v.byName('Bramble').addMood(1 + warnedBeforeStorm.length.clamp(0, 3));
      v.byName('Clover').addMood(-2);
      advance(
        v,
        'storm',
        Said(SaidKey.whyStormArrived, 'it arrived on time; ${warnedBeforeStorm.length} llamas had been warned', {
          'count': warnedBeforeStorm.length,
        }),
      );
    }
    if (t.day == stormDay && t.minute == 17 * 60 + 30 && state == 'storm') {
      v.storm = false;
      final f = v.newFact(
        'storm_passed',
        'The storm passed in the evening of day $stormDay, leaving puddles and a rainbow over the pond.',
        'the rainbow',
        kind: FactKind.event,
        saidKey: SaidKey.factStormPassed,
        said: {'day': stormDay},
      );
      v.announce(
        const Said(SaidKey.stormClearsTitle, 'The storm clears'),
        const Said(SaidKey.stormClears, 'The storm passes. Puddles everywhere, a rainbow over the pond.'),
        f.id,
        how: 'saw',
      );
      advance(v, 'passed', const Said(SaidKey.whySkyCleared, 'the sky cleared'));
    }
  }

  @override
  List<Goal> goalsFor(Llama l, Village v) {
    if (l.name == 'Bramble' && state == 'forecast') {
      final today = v.now.day == stormDay;
      final when = today ? 'this afternoon' : 'on the afternoon of day $stormDay';
      final text = 'warn everyone that a storm will hit $when; be taken seriously';
      return [
        Goal(
          id,
          today ? Said(SaidKey.goalWarnToday, text) : Said(SaidKey.goalWarnDay, text, {'day': stormDay}),
          weight: 0.5,
          topic: 'storm_forecast',
        ),
      ];
    }
    return const [];
  }

  @override
  Map<String, Object?> save() => {
    ...super.save(),
    'warned': [...warnedBeforeStorm],
    'soaked': [...soaked],
  };

  @override
  void load(Map<String, Object?> j) {
    super.load(j);
    warnedBeforeStorm
      ..clear()
      ..addAll(_strings(j['warned']));
    soaked
      ..clear()
      ..addAll(_strings(j['soaked']));
  }

  @override
  void finish(Village v) {
    resolution = state == 'forecast'
        ? 'The storm never came.'
        : 'Storm hit on day $stormDay at 15:00 as Bramble predicted. Warned beforehand: ${warnedBeforeStorm.isEmpty ? 'nobody' : warnedBeforeStorm.join(', ')}. '
              'Caught outdoors: ${soaked.isEmpty ? 'nobody' : soaked.join(', ')}.';
  }
}

import 'cast.dart';
import 'clock.dart';
import 'dialogue.dart';
import 'log.dart';
import 'facts.dart';
import 'places.dart';
import 'village.dart';

/// A want that a thread hands to one llama: it steers the utility choice
/// (place, seek, action) and the dialogue prompt (text, topic).
class Goal {
  Goal(this.thread, this.text, {this.place, this.seek, this.action, this.weight = 0.5, this.topic});
  final String thread;
  final String text;
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

  void advance(Village v, String to, String why) {
    history.add('${v.now.label} $state → $to: $why');
    v.events.emit('thread', {'thread': id, 'from': state, 'to': to, 'why': why});
    v.log.note('_Thread **$title**: $state → **$to** ($why)_', kind: LogKind.thread);
    state = to;
  }

  List<Goal> goalsFor(Llama l, Village v);
  void onMinute(Village v) {}
  void onLearn(Transfer t, Village v) {}
  void onConversationEnd(Conversation c, Village v) {}
  void finish(Village v);

  Map<String, Object?> toJson() => {'id': id, 'title': title, 'state': state, 'resolution': resolution, 'history': history};
}

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
      keywords: [
        ['scarf'],
        ['missing', 'gone', 'lost', 'vanish', 'stolen', 'took', 'find', 'where', 'seen', 'see '],
      ],
    );
    v.worldEvent(
      'Pip notices her red scarf is missing',
      atHome
          ? 'Pip reaches for her red scarf on its hook. The hook is empty. She turns her hut upside down: the scarf is gone.'
          : 'Pip realises she has not seen her red scarf since yesterday. It is not on its hook: the scarf is gone.',
      at: pip.place,
      fact: f.id,
      also: {'Pip'},
    );
    pip.addMood(-3);
    missingAt = v.now;
    advance(v, 'missing', 'Pip noticed it was gone');
  }

  static const List<String> searchOrder = ['berry bushes', 'bakery', 'hilltop', 'pond'];

  void search(Village v, Llama l) {
    if (state != 'missing' || l.place != 'pond') {
      l.searched.add(l.place);
      v.log.note('${l.name} searches ${theP(l.place)} for the scarf and finds nothing.');
      return;
    }
    final knowsWhere = v.kb.knows(l.name, 'scarf_where');
    if (!knowsWhere && v.rng.nextDouble() > 0.3) {
      v.log.note('${l.name} pokes around the pond reeds but finds nothing.');
      return;
    }
    finder = l.name;
    final f = v.newFact(
      'scarf_found',
      "${l.name} found Pip's red scarf in the pond reeds.",
      'the scarf was found',
      kind: FactKind.deed,
      keywords: [
        ['scarf'],
        ['found', 'reeds', 'fished'],
      ],
    );
    v.worldEvent(
      'Scarf found',
      "${l.name} pulls ${l.name == 'Pip' ? 'her' : "Pip's"} red scarf, soggy, out of the pond reeds.",
      at: 'pond',
      fact: f.id,
    );
    v.witness('scarf_where', 'pond');
    if (l.name == 'Pip') {
      l.addMood(3);
      advance(v, 'returned', 'Pip found it herself in the pond reeds');
    } else {
      holder = l.name;
      l.items.add("Pip's red scarf");
      advance(v, 'found', '${l.name} found it in the pond reeds');
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
      keywords: [
        ['scarf'],
        ['gave', 'back', 'returned'],
      ],
    );
    v.worldEvent('Scarf returned', '${giver.name} hands Pip her red scarf.', at: c.place, fact: f.id);
    holder = null;
    advance(v, 'returned', '${giver.name} gave it back');
  }

  @override
  void onLearn(Transfer t, Village v) {
    if (t.fact.id == 'mo_scarf' && t.llama == 'Pip' && confession == null) {
      confession = switch ((t.knowing.from, t.knowing.how)) {
        ('Mo', 'told') => 'Mo confessed to Pip',
        ('Mo', 'overheard') => 'Pip overheard Mo confessing to someone else',
        (final from, final how) => 'Pip learned it ($how) from $from',
      };
      v.log.note('_Thread **$title**: ${confession}_');
      history.add('${v.now.label} $confession');
    }
  }

  @override
  List<Goal> goalsFor(Llama l, Village v) {
    final goals = <Goal>[];
    if (state == 'unnoticed' && l.name == 'Pip' && v.now.day == 1 && v.now.minute >= 7 * 60 + 30) {
      goals.add(Goal(id, 'fetch your red scarf from your hut to look your best', place: l.home, weight: 0.8));
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
              'ask ${unasked.first.name} whether they have seen your red scarf',
              seek: unasked.first.name,
              weight: 0.5,
              topic: 'scarf_missing',
            ),
          );
        } else {
          goals.add(Goal(id, 'find your red scarf and find out who took it', topic: 'scarf_missing', weight: 0.2));
        }
        goals.add(
          Goal(id, 'search for your red scarf', action: 'search', place: unsearched.isEmpty ? 'pond' : unsearched.first, weight: 0.3),
        );
      } else if (l.name == 'Mo' && v.kb.knows('Mo', 'scarf_missing')) {
        goals.add(
          Goal(
            id,
            'quietly fish Pip\'s scarf out of the pond reeds before anyone learns what you did',
            place: 'pond',
            action: 'search',
            weight: 0.75,
          ),
        );
      } else if (v.kb.knows(l.name, 'scarf_missing') && (l.friendship['Pip'] ?? 0) >= 3 && unsearched.isNotEmpty) {
        goals.add(Goal(id, 'help Pip look for her red scarf', place: unsearched.first, action: 'search', weight: 0.25));
      }
    }
    if (state == 'found' && holder == l.name) {
      goals.add(
        Goal(
          id,
          l.name == 'Mo'
              ? 'give Pip back her red scarf, and decide whether to confess you knocked it into the pond'
              : 'give Pip back her red scarf (you found it in the pond reeds)',
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
          'you still feel guilty: maybe confess to Pip that you knocked her scarf into the pond',
          seek: 'Pip',
          weight: 0.3,
          topic: 'mo_scarf',
        ),
      );
    }
    return goals;
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

  @override
  void onMinute(Village v) {
    final t = v.now;
    if (t.day == 1 && t.minute == 7 * 60 && state == 'unannounced') {
      final f = v.newFact(
        'festival',
        'Clover announced the Berry Festival for day 2 at 16:00 on the hilltop; the best singer wins the Golden Bell.',
        'the Berry Festival',
        kind: FactKind.news,
        keywords: [
          ['festival', 'golden bell', 'contest'],
        ],
      );
      v.announce(
        'Berry Festival announced',
        'Clover rings her bell from the hilltop: the Berry Festival is tomorrow (day 2) at 16:00, and the best singer wins the Golden Bell.',
        f.id,
      );
      contestants.add('Pip');
      final s = v.newFact('pip_signed', 'Pip signed up to sing at the Berry Festival.', 'Pip entering the contest', kind: FactKind.deed);
      v.announce('Pip signs up', 'Pip shouts her name before Clover finishes the sentence.', s.id, quiet: true);
      advance(v, 'announced', 'Clover announced it; Pip signed up at once');
    }
    if (t.day == 2 && t.minute == 16 * 60 && state != 'judged') _perform(v);
    if (t.day == 2 && t.minute == 16 * 60 + 25 && state == 'performed') _judge(v);
  }

  void signUp(Village v, Llama l, String how) {
    if (contestants.contains(l.name) || state == 'performed' || state == 'judged') return;
    contestants.add(l.name);
    final f = v.newFact(
      '${l.name.toLowerCase()}_signed',
      '${l.name} signed up to sing at the Berry Festival.',
      '${l.name} entering the contest',
      kind: FactKind.deed,
    );
    v.witness(f.id, l.place, extra: {l.name, if (how.contains('Clover')) 'Clover'});
    v.log.note('_${l.name} signs up for the singing contest ($how)._');
    if (state == 'announced') advance(v, 'contest', '${l.name} joined Pip in the contest');
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
        v.log.note('_Mo feels braver after talking with ${other.name} (courage ${(mo.courage * 100).round()}%)._');
      }
      if (other.name == 'Clover' && c.answers['mo_agreed_to_sing'] == true) {
        if (mo.courage >= 0.3) {
          signUp(v, mo, 'he told Clover yes');
        } else {
          v.log.note('_Mo said yes, then went pale and took it back (courage ${(mo.courage * 100).round()}%)._');
        }
      }
    }
    final june = pair.where((l) => l.name == 'June').firstOrNull;
    if (june != null && !contestants.contains('June') && pair.any((l) => l.name == 'Clover') && june.mood >= 1) {
      signUp(v, june, 'Clover talked her into it');
    }
  }

  void _perform(Village v) {
    final present = v.cast.where((l) => l.place == 'hilltop').toList();
    final singers = contestants.where((n) => v.byName(n).place == 'hilltop').toList();
    v.worldEvent(
      'The Berry Festival',
      'Lanterns, berry tarts and a wobbly stage. ${present.length} llamas gather on the hilltop. '
          'Singers: ${singers.isEmpty ? 'nobody turned up' : singers.join(', ')}.',
      at: 'hilltop',
    );
    for (final n in singers) {
      final l = v.byName(n);
      if (n == 'Pip') {
        v.worldEvent('Pip sings', 'Pip sings with enormous feeling and almost no tune.', at: 'hilltop');
        v.witness('pip_tune', 'hilltop');
      } else if (n == 'Mo' && l.courage < 0.45) {
        final f = v.newFact(
          'mo_fainted',
          'Mo fainted on stage at the Berry Festival before singing a note.',
          'Mo fainting',
          kind: FactKind.deed,
        );
        v.worldEvent('Mo faints', 'Mo opens his mouth, sways, and faints into the berry tarts.', at: 'hilltop', fact: f.id);
        scores[n] = -1;
      } else {
        v.worldEvent(
          '$n sings',
          n == 'Mo' ? 'Mo sings, and the hilltop goes completely silent, then roars.' : '$n sings a cheerful berry-picking song.',
          at: 'hilltop',
        );
      }
    }
    advance(v, 'performed', singers.isEmpty ? 'no singers' : '${singers.join(', ')} sang');
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
        ? 'nobody sang'
        : rigged && winner == 'Pip'
        ? 'Clover quietly honoured her secret deal with Pip'
        : dealKnownBy.isNotEmpty
        ? 'the deal was known to ${dealKnownBy.join(', ')}, so Clover judged fairly'
        : 'judged on voice and the crowd';
    if (winner != null) {
      final f = v.newFact(
        'festival_winner',
        '$winner won the Golden Bell at the Berry Festival.',
        'the festival winner',
        kind: FactKind.event,
      );
      v.announce(
        'The Golden Bell',
        'Clover hands the Golden Bell to $winner. Scores: ${[for (final e in ranked) '${e.key} ${e.value.toStringAsFixed(2)}'].join(', ')}.',
        f.id,
      );
      v.byName(winner!).addMood(4);
      for (final n in contestants.where((n) => n != winner)) {
        v.byName(n).addMood(-2);
      }
    }
    resolution = winner == null ? 'No winner: $how.' : '$winner won the Golden Bell; $how.';
    advance(v, 'judged', resolution!);
  }

  @override
  List<Goal> goalsFor(Llama l, Village v) {
    final goals = <Goal>[];
    if (!v.kb.knows(l.name, 'festival') || state == 'judged') return goals;
    final t = v.now;
    if (t.day == 2 && t.minute >= 15 * 60 + 20 && t.minute < 16 * 60 + 40) {
      goals.add(Goal(id, 'be at the hilltop for the Berry Festival at 16:00', place: 'hilltop', action: 'festival', weight: 1.4));
    }
    if (l.name == 'Clover' && state != 'performed') {
      if (t.day == 2 && t.minute >= 14 * 60) {
        goals.add(Goal(id, 'set up the festival stage on the hilltop', place: 'hilltop', weight: 0.9));
      }
      final lastAsked = l.lastTalk['Mo'];
      if (!contestants.contains('Mo') && (lastAsked == null || t.minutesSince(lastAsked) > 180)) {
        goals.add(Goal(id, 'recruit Mo to sing at the festival (he has the best voice)', seek: 'Mo', weight: 0.45, topic: 'festival'));
      }
    }
    if (l.name == 'Mo' && !contestants.contains('Mo') && l.courage >= 0.5) {
      goals.add(Goal(id, 'tell Clover you will sing at the festival after all', seek: 'Clover', weight: 0.55, topic: 'festival'));
    }
    if (l.name == 'Mo' && !contestants.contains('Mo')) {
      final feeling = l.courage < 0.3
          ? 'you are far too scared to sing at the festival; you would faint'
          : l.courage < 0.5
          ? 'you are tempted to sing at the festival but scared of fainting'
          : 'you are almost brave enough to say yes to singing at the festival';
      goals.add(Goal(id, feeling, weight: 0.1, topic: 'festival'));
    }
    if (l.name == 'Pip' && t.minute < 8 * 60 + 30) {
      goals.add(Goal(id, 'practise singing at the pond at dawn, where nobody can hear', place: 'pond', action: 'practise', weight: 0.7));
    }
    if (l.name == 'Pip') {
      goals.add(Goal(id, 'win the Golden Bell; outshine Mo', weight: 0.1, topic: 'festival'));
    }
    return goals;
  }

  @override
  void finish(Village v) {
    resolution ??= 'Not held (state $state).';
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
        keywords: [
          ['poem', 'verse'],
          ['unsigned', 'anonymous', 'love', 'flowers', 'someone'],
        ],
      );
    }
    // June finds the poem the first time she is at the berry bushes on day 2.
    if (v.now.day == 2 && !v.kb.knows('June', 'anon_poem') && v.byName('June').place == 'berry bushes' && v.kb.maybe('anon_poem') != null) {
      v.kb.learn('June', 'anon_poem', 'saw', v.now);
      v.log.note('June finds an unsigned love poem tucked into the wildflowers. She reads it twice.');
      v.byName('June').addMood(1);
      if (state == 'secret') advance(v, 'poem found', 'June found an anonymous love poem');
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
          keywords: [
            ['bramble', 'he ', 'him', 'old'],
            ['flower'],
          ],
        );
    final seen = v.witness(f.id, 'berry bushes', exclude: {'Bramble'});
    v.kb.learn('Bramble', f.id, 'own', v.now);
    v.log.note('Bramble tucks wildflowers into the berry bushes${seen.isEmpty ? ' unseen' : ', but ${seen.join(' and ')} sees him'}.');
    if (seen.contains('June') && state == 'secret') advance(v, 'suspected', 'June saw Bramble leave the flowers');
  }

  @override
  void onLearn(Transfer t, Village v) {
    if (t.llama == 'June' && t.fact.id == 'bramble_poems' && revealedBy == null) {
      revealedBy = t.knowing.how == 'overheard' ? '${t.knowing.from} (overheard)' : (t.knowing.from ?? t.knowing.how);
      advance(
        v,
        revealedBy == 'Bramble' ? 'confessed' : 'exposed',
        revealedBy == 'Bramble' ? 'Bramble told June himself' : 'June heard it from $revealedBy',
      );
      pendingReaction = revealedBy;
    }
    if (t.llama == 'June' && t.fact.id == 'bramble_flowers' && state == 'secret') {
      advance(v, 'suspected', 'June heard Bramble leaves the flowers');
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
    advance(v, outcome, resolution!);
  }

  @override
  List<Goal> goalsFor(Llama l, Village v) {
    final goals = <Goal>[];
    final t = v.now;
    if (l.name == 'Bramble' && !flowersToday && t.minute < 6 * 60 + 50) {
      goals.add(
        Goal(
          id,
          'leave wildflowers for June at the berry bushes before anyone sees',
          place: 'berry bushes',
          action: 'flowers',
          weight: 1.0,
        ),
      );
    }
    if (l.name == 'Bramble' && revealedBy == null && (t.day == 2 || l.mood >= 3)) {
      goals.add(
        Goal(
          id,
          'work up the courage to tell June that you are the one writing her love poems',
          seek: 'June',
          weight: t.day == 2 ? 0.55 : 0.3,
          topic: 'bramble_poems',
        ),
      );
    }
    if (l.name == 'June' && revealedBy == null && (v.kb.knows('June', 'anon_poem') || v.kb.knows('June', 'wildflowers'))) {
      final topic = v.kb.knows('June', 'bramble_flowers')
          ? 'bramble_flowers'
          : (v.kb.knows('June', 'anon_poem') ? 'anon_poem' : 'wildflowers');
      goals.add(Goal(id, 'find out who leaves you wildflowers and love poems', weight: 0.3, topic: topic));
    }
    if (l.name == 'June' && pendingReaction != null) {
      goals.add(Goal(id, 'talk to Bramble about the love poems', seek: 'Bramble', weight: 0.7, topic: 'bramble_poems'));
    }
    if (l.name == 'Bramble' && pendingReaction != null) {
      goals.add(Goal(id, 'face June about the poems', seek: 'June', weight: 0.5, topic: 'bramble_poems'));
    }
    return goals;
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
      if (t.knowing.believes) v.byName(t.llama).addFriendship('Mo', -1);
    }
    if (t.fact.id == 'bread_truth' && t.knowing.believes) {
      debunks.add('${t.knowing.from ?? t.knowing.how} → ${t.llama}');
      if (believers(v).isEmpty && state == 'spreading') advance(v, 'debunked', 'nobody believes it any more');
    }
    if (t.fact.id == 'june_rumour' && (t.llama == 'Mo' || t.llama == 'Bramble') && state != 'june exposed') {
      v.byName(t.llama).addFriendship('June', -2);
      advance(v, 'june exposed', '${t.llama} learned June made it up (from ${t.knowing.from})');
    }
  }

  @override
  List<Goal> goalsFor(Llama l, Village v) {
    final goals = <Goal>[];
    if (l.name == 'June' && v.now.day == 1) {
      goals.add(Goal(id, "spread the juicy story about Mo's bread", weight: 0.15, topic: 'bread_rumour'));
    }
    if (l.name == 'Mo') {
      goals.add(Goal(id, 'clear your name: your bread never made anyone sick', weight: 0.15, topic: 'bread_truth'));
    }
    if (l.name == 'Bramble' && v.kb.knows('Bramble', 'bread_rumour')) {
      goals.add(Goal(id, "set the record straight: Mo's bread never made you sick", weight: 0.35, topic: 'bread_truth'));
    }
    return goals;
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
    if (t.day == 1 && t.minute == 15 * 60 && state == 'forecast') {
      v.storm = true;
      for (final e in v.kb['storm_forecast'].knownBy.entries) {
        if (e.key != 'Bramble' && e.key != 'Dash' && e.value.believes) warnedBeforeStorm.add(e.key);
      }
      final f = v.newFact(
        'storm_hit',
        'A storm hit the village on day 1 at 15:00: thunder, sideways rain, the festival bunting blew away.',
        'the storm',
        kind: FactKind.event,
      );
      v.announce('Storm', 'Thunder cracks over the hilltop and sideways rain sweeps the village.', f.id, how: 'saw');
      final right = v.newFact(
        'bramble_right',
        "Bramble's storm prediction came true.",
        'Bramble being right',
        kind: FactKind.deed,
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
      advance(v, 'storm', 'it arrived on time; ${warnedBeforeStorm.length} llamas had been warned');
    }
    if (t.day == 1 && t.minute == 17 * 60 + 30 && state == 'storm') {
      v.storm = false;
      final f = v.newFact(
        'storm_passed',
        'The storm passed in the evening of day 1, leaving puddles and a rainbow over the pond.',
        'the rainbow',
        kind: FactKind.event,
      );
      v.announce('The storm clears', 'The storm passes. Puddles everywhere, a rainbow over the pond.', f.id, how: 'saw');
      advance(v, 'passed', 'the sky cleared');
    }
  }

  @override
  List<Goal> goalsFor(Llama l, Village v) {
    if (l.name == 'Bramble' && state == 'forecast') {
      return [Goal(id, 'warn everyone that a storm will hit this afternoon; be taken seriously', weight: 0.5, topic: 'storm_forecast')];
    }
    return const [];
  }

  @override
  void finish(Village v) {
    resolution = state == 'forecast'
        ? 'The storm never came.'
        : 'Storm hit at 15:00 as Bramble predicted. Warned beforehand: ${warnedBeforeStorm.isEmpty ? 'nobody' : warnedBeforeStorm.join(', ')}. '
              'Caught outdoors: ${soaked.isEmpty ? 'nobody' : soaked.join(', ')}.';
  }
}

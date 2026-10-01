import 'dart:async';
import 'dart:math' as math;

import 'cast.dart';
import 'dialogue.dart';
import 'facts.dart';
import 'geo.dart';
import 'laya_roles.dart';
import 'model.dart';
import 'places.dart';
import 'village.dart';

class DashOption {
  DashOption(this.intent, this.text, {this.about, this.fact, this.item});
  final String intent;
  final String text;
  final String? about;
  final String? fact;
  final String? item;
  bool canned = false;

  Map<String, Object?> toJson() => {'intent': intent, 'text': text, if (about != null) 'about': about, if (canned) 'canned': true};
}

/// Where a visit to one llama stands.
enum VisitStage {
  /// Dash is flying over (options are being written meanwhile).
  flying,

  /// Dash is there but the llama is busy talking or walking.
  waiting,

  /// The options are up (or still being written: [DashVisit.options] null).
  choosing,

  /// Dash said something; the llama is answering.
  replying,

  /// The reply is out; Dash can say more or leave.
  done,
}

class DashVisit {
  DashVisit(this.target, this.startMs);
  final Llama target;
  final double startMs;
  VisitStage stage = VisitStage.flying;
  List<DashOption>? options;
  double? optionsReadyMs;
  double? arrivedMs;
  double? doneMs;
  int round = 0;
  DashOption? picked;
  String? reply;
  int? reaction;
  List<String> effects = const [];
  Completer<List<DashOption>> ready = Completer<List<DashOption>>();
}

/// The player: a little blue bird. Flies to places or llamas, sees four
/// prefetched options per visit, picks one and gets a reply.
class Dash {
  Dash(this.v);
  final Village v;

  /// Ground-plane position in metres; the renderer adds the altitude.
  P2 pos = slotPoint('bakery', 5);
  P2 heading = (0, 1);

  /// Where Dash is flying to, if anywhere.
  P2? goal;
  String? goalPlace;

  /// WASD steering, a unit-ish vector on the ground plane; zero when idle.
  P2 steer = (0, 0);
  bool moving = false;

  /// The place Dash is at, or null in between.
  String? place = 'bakery';
  final List<String> inventory = ['a red ribbon', 'a jar of honey', 'a shiny pebble', 'a bundle of mint'];
  DashVisit? visit;

  /// A short note for the player ("Mo is asleep"), cleared after a while.
  String? notice;
  double _noticeUntil = 0;
  final List<Map<String, Object?>> history = [];
  String? _told;

  /// Real-time flying speed in metres per second at 1x.
  static const double speed = 13;
  static const double talkRange = 3.2;

  void say(String text) {
    notice = text;
    _noticeUntil = v.uiMs + 3500;
  }

  // ------------------------------------------------------------ commands

  void moveTo(String place) {
    leave();
    goalPlace = place;
    goal = slotPoint(place, 5);
  }

  /// Flies to a free spot on the ground.
  void flyTo(P2 p) {
    leave();
    goalPlace = placeNear(p);
    goal = p;
  }

  void steerBy(double x, double z) {
    steer = (x, z);
    if (x != 0 || z != 0) {
      if (visit != null) leave();
      goal = null;
      goalPlace = null;
    }
  }

  /// Starts a visit: Dash flies over while the options are written. The
  /// future completes with the options once they are ready.
  Future<List<DashOption>> talk(Llama l) {
    final current = visit;
    if (current != null && current.target == l) return current.ready.future;
    leave();
    if (l.asleep) {
      say('${l.name} is asleep. Try again in the morning.');
      return Future.value(const []);
    }
    goal = null;
    goalPlace = null;
    final dv = DashVisit(l, v.uiMs);
    visit = dv;
    v.events.emit('dash_walk', {'target': l.name});
    _prefetch(dv);
    return dv.ready.future;
  }

  void choose(int index) {
    final dv = visit;
    if (dv == null || dv.stage != VisitStage.choosing || dv.options == null) return;
    if (index < 0 || index >= dv.options!.length) return;
    unawaited(_converse(dv, dv.options![index]));
  }

  /// Asks for a fresh set of options at the same llama.
  void sayMore() {
    final dv = visit;
    if (dv == null || dv.stage != VisitStage.done) return;
    dv
      ..stage = VisitStage.choosing
      ..options = null
      ..picked = null
      ..reply = null
      ..round += 1
      ..ready = Completer<List<DashOption>>();
    dv.target.activity = Activity('talk', v.now.plus(60), with_: 'Dash', start: v.now);
    _prefetch(dv);
  }

  void leave() {
    final dv = visit;
    if (dv == null) return;
    visit = null;
    if (dv.target.activity.kind == 'talk' && dv.target.activity.with_ == 'Dash') {
      dv.target.activity = Activity('idle', v.now, start: v.now);
      dv.target.lastConversationEnd = v.now;
    }
    if (v.speech[dv.target.name]?.pending == true) v.speech.remove(dv.target.name);
    if (!dv.ready.isCompleted) dv.ready.complete(const []);
  }

  // ------------------------------------------------------------ motion

  void update(double dtMs) {
    if (notice != null && v.uiMs > _noticeUntil) notice = null;
    final dt = dtMs / 1000;
    final dv = visit;
    P2? target = goal;
    if (dv != null) {
      final (lp, _, _) = v.llamaPose(dv.target);
      final toDash = _sub(pos, lp);
      final d = dist(pos, lp);
      final dir = d < 0.01 ? placeFacing(dv.target.place) : (toDash.$1 / d, toDash.$2 / d);
      target = (lp.$1 + dir.$1 * 2.2, lp.$2 + dir.$2 * 2.2);
    }
    final pace = speed * math.max(1.0, math.sqrt(v.timeScale));
    moving = false;
    if (steer.$1 != 0 || steer.$2 != 0) {
      final l = math.sqrt(steer.$1 * steer.$1 + steer.$2 * steer.$2);
      final d = (steer.$1 / l, steer.$2 / l);
      pos = _clampWorld((pos.$1 + d.$1 * pace * dt, pos.$2 + d.$2 * pace * dt));
      heading = d;
      moving = true;
    } else if (target != null) {
      final d = dist(pos, target);
      if (d > 0.05) {
        final step = math.min(d, pace * dt);
        final dir = ((target.$1 - pos.$1) / d, (target.$2 - pos.$2) / d);
        pos = (pos.$1 + dir.$1 * step, pos.$2 + dir.$2 * step);
        heading = dir;
        moving = step > 0.01;
      } else if (dv == null) {
        goal = null;
        goalPlace = null;
      }
    }
    final near = placeNear(pos);
    if (near != place) {
      place = near;
      if (near != null) v.events.emit('dash_arrive', {'place': near});
    }
    if (dv != null) _updateVisit(dv);
  }

  P2 _clampWorld(P2 p) => (p.$1.clamp(-48.0, 48.0), p.$2.clamp(-52.0, 40.0));

  void _updateVisit(DashVisit dv) {
    final l = dv.target;
    final (lp, _, _) = v.llamaPose(l);
    final close = dist(pos, lp) <= talkRange;
    switch (dv.stage) {
      case VisitStage.flying || VisitStage.waiting:
        if (!close) return;
        if (l.asleep) {
          say('${l.name} has fallen asleep.');
          leave();
          return;
        }
        final busy = l.busyTalking && l.activity.with_ != 'Dash' || l.activity.kind == 'walk';
        if (busy) {
          if (dv.stage != VisitStage.waiting) {
            dv.stage = VisitStage.waiting;
            say(l.activity.kind == 'walk' ? 'Catching up with ${l.name}…' : 'Waiting for ${l.name} to finish talking…');
          }
          return;
        }
        dv.stage = VisitStage.choosing;
        dv.arrivedMs = v.uiMs;
        l.activity = Activity('talk', v.now.plus(60), with_: 'Dash', start: v.now);
        if (v.speech[l.name]?.kind == SpeechKind.thought) v.speech.remove(l.name);
        v.events.emit('dash_arrive', {'target': l.name, 'place': l.place});
      case VisitStage.done:
        if (v.uiMs - (dv.doneMs ?? v.uiMs) > 25000) leave();
      case VisitStage.choosing || VisitStage.replying:
        break;
    }
  }

  // ------------------------------------------------------------ talking

  /// Options are generated while Dash flies over, so they are ready on
  /// arrival.
  void _prefetch(DashVisit dv) {
    final l = dv.target;
    final others = [
      for (final o in v.cast)
        if (o != l) o.name,
    ];
    final about = others[v.rng.nextInt(others.length)];
    final tellable = v.kb.known('Dash').where((f) => !v.kb.knows(l.name, f.id) && f.origin != 'Dash' && f.truth).toList();
    final tell = tellable.isEmpty ? null : tellable[v.rng.nextInt(tellable.length)];
    final item = inventory.isEmpty ? null : inventory[v.rng.nextInt(inventory.length)];
    final intents = <String>['compliment', 'gossip', if (tell != null) 'tell', if (item != null) 'gift', 'help', 'tease'];
    final first = intents.take(2).toList();
    final rest = intents.skip(2).toList()..shuffle(v.rng);
    final picked = [...first, ...rest.take(2)]..shuffle(v.rng);
    final goals = v.goalsFor(l);
    final facts = relevantFacts(v, l, limit: 4);
    final spec = {
      'compliment': 'a flattering remark',
      'gossip': 'a juicy made-up claim about $about, in the third person (it is untrue)',
      'tell': 'Dash tells ${l.name} this true news: ${tell?.text}',
      'gift': 'Dash offers ${l.name} $item',
      'help': "Dash offers to help with ${l.name}'s job or current want",
      'tease': 'a playful jab',
    };
    final prompt = [
      'Dash, a curious little bird new to the village (the player), flies up to ${l.name} at ${theP(l.place)}. '
          'Day ${v.now.day}, ${v.now.hhmm}, ${v.now.partOfDay}.',
      '${l.name}, the ${l.job}: ${l.traits}. Likes: ${l.likes}. Mood: ${l.moodWord}.',
      if (goals.isNotEmpty) '${l.name} wants: ${goals.take(2).map((g) => g.text).join('; ')}.',
      'What ${l.name} knows lately: ${facts.map((f) => f.text).join(' ')}',
      if (dv.reply != null) '${l.name} just said to Dash: "${dv.reply}"',
      '',
      'Write four things Dash could say to ${l.name} (Dash speaking, addressing ${l.name}), one per line, each under 20 words, exactly in this format:',
      for (final i in picked) '$i: <${spec[i]}>',
      'No other text.',
    ].join('\n');
    v.chat
        .text<List<DashOption>>(
          'dash_options',
          Priority.dashOptions,
          prompt,
          parse: (raw) => parseDashOptions(raw, picked, about: about, tell: tell?.id, item: item),
          fallback: () => [
            for (final i in picked)
              DashOption(
                i,
                switch (i) {
                  'compliment' => 'You look wonderful today, ${l.name}.',
                  'gossip' => 'I heard $about has been acting very strange lately.',
                  'tell' => 'Did you hear? ${tell!.text}',
                  'gift' => 'I brought you $item.',
                  'help' => 'Can I help you with anything?',
                  _ => 'Is that a frown or your normal face?',
                },
                about: i == 'gossip' ? about : null,
                fact: i == 'tell' ? tell!.id : null,
                item: i == 'gift' ? item : null,
              )..canned = true,
          ],
          maxTokens: 140,
          seed: v.rng.nextInt(1 << 30),
        )
        .then((options) {
          if (visit != dv) return;
          dv.options = options;
          dv.optionsReadyMs = v.uiMs;
          if (!dv.ready.isCompleted) dv.ready.complete(options);
          v.events.emit('dash_options', {
            'target': l.name,
            'options': [for (final o in options) o.toJson()],
          });
        });
  }

  Future<void> _converse(DashVisit dv, DashOption pick) async {
    final l = dv.target;
    dv
      ..stage = VisitStage.replying
      ..picked = pick;
    v.sayNow('Dash', pick.text, to: l.name);
    v.log.line('Dash', pick.text);
    final pending = v.pendingSay(l.name, to: 'Dash');
    final rc = ReactionCase(
      l.name,
      l.traits,
      l.likes,
      pick.intent,
      pick.text,
      feelingToDash: l.friendship['Dash'] ?? 0,
      mood: l.mood,
      giftLiked: pick.item != null && l.likes.split(', ').any((x) => pick.item!.contains(x.split(' ').last)),
      subjectFriendship: pick.about == null ? null : l.friendship[pick.about!],
    );
    final level = ruleReaction(rc);
    if (pick.intent == 'tell' && pick.fact != null) {
      final believes = (l.friendship['Dash'] ?? 0) >= 0;
      if (v.kb.learn(l.name, pick.fact!, 'told', v.now, from: 'Dash', believes: believes)) {
        _told = '${l.name} now knows: ${v.kb[pick.fact!].short}';
      }
    }
    final facts = relevantFacts(v, l, limit: 4);
    final reply = await v.chat.text<String>(
      'dash_reply',
      Priority.dashReply,
      [
        '${l.name}, the ${l.job} (${l.traits}; mood ${l.moodWord}), is at ${theP(l.place)}. Day ${v.now.day}, ${v.now.hhmm}.',
        'What ${l.name} knows (only these):',
        for (final f in facts) '- ${f.text} (${v.kb.label(l.name, f, v.now)})',
        'Dash, a little bird new to the village, says: "${pick.text}"',
        '${l.name} feels ${reactionLevels[level]} about it.',
        "Write only ${l.name}'s spoken reply to Dash: one or two sentences, under 30 words, in character. No quotes, no name prefix.",
      ].join('\n'),
      parse: (raw) => parseLine(raw, [l.name]),
      fallback: () => level >= 3 ? 'Oh! Well, thank you, Dash.' : 'Hmph. If you say so, Dash.',
      maxTokens: 60,
      seed: v.rng.nextInt(1 << 30),
    );
    if (visit != dv) {
      if (v.speech[l.name]?.id == pending.id) v.speech.remove(l.name);
      return;
    }
    v.sayNow(l.name, reply, to: 'Dash');
    v.log.line(l.name, reply);
    final effects = _effects(l, pick, level);
    dv
      ..reply = reply
      ..reaction = level
      ..effects = effects
      ..stage = VisitStage.done
      ..doneMs = v.uiMs;
    v.log.dash(v.now, l, dv.options!, pick, level, reply, effects);
    v.events.emit('dash_reply', {
      'target': l.name,
      'intent': pick.intent,
      'reaction': reactionLevels[level],
      'reply': reply,
      'effects': effects,
    });
    history.add({
      'time': v.now.label,
      'llama': l.name,
      'picked': pick.intent,
      'reaction': reactionLevels[level],
      'reply': reply,
      'effects': effects,
    });
  }

  List<String> _effects(Llama l, DashOption pick, int level) {
    final effects = <String>[];
    final fd = level - 2 + (pick.intent == 'gift' ? 1 : 0);
    final md = level >= 3 ? 1 : (level <= 1 ? -1 : 0);
    l.addFriendship('Dash', fd);
    l.addMood(md);
    effects.add('${l.name} toward Dash ${fd >= 0 ? '+' : ''}$fd (now ${l.friendship['Dash']}), mood ${md >= 0 ? '+' : ''}$md');
    if (pick.intent == 'gift' && pick.item != null) {
      inventory.remove(pick.item);
      l.items.add(pick.item!);
      final f = v.newFact(v.kb.newId('gift'), 'Dash gave ${l.name} ${pick.item}.', 'Dash\'s gift to ${l.name}', kind: FactKind.deed);
      v.kb.learn('Dash', f.id, 'own', v.now);
      v.witness(f.id, l.place, extra: {l.name});
    }
    if (pick.intent == 'gossip' && pick.about != null) {
      final f = v.newFact(
        v.kb.newId('dash_rumour'),
        pick.text,
        'what Dash said about ${pick.about}',
        kind: FactKind.rumour,
        truth: false,
        origin: 'Dash',
      );
      v.kb.learn('Dash', f.id, 'own', v.now, believes: false);
      final believes = (l.friendship['Dash'] ?? 0) >= 1 || l.traits.contains('nosy');
      v.kb.learn(l.name, f.id, 'told', v.now, from: 'Dash', believes: believes);
      if (believes) l.addFriendship(pick.about!, -1);
      effects.add('${l.name} ${believes ? 'believes' : 'doubts'} the made-up rumour about ${pick.about}');
    }
    if (_told != null) {
      effects.add(_told!);
      _told = null;
    }
    if (pick.intent == 'help' && l.place == l.workplace) effects.add('${l.name} gets work done faster');
    if (l.name == 'Mo' && level >= 3) {
      l.courage = (l.courage + 0.08).clamp(0, 1);
      effects.add('Mo courage ${(l.courage * 100).round()}%');
    }
    return effects;
  }
}

P2 _sub(P2 a, P2 b) => (a.$1 - b.$1, a.$2 - b.$2);

/// Reads the option lines ("intent: text") for the [picked] intents; null
/// when fewer than three usable lines came back.
List<DashOption>? parseDashOptions(String raw, List<String> picked, {String? about, String? tell, String? item}) {
  final found = <String, String>{};
  for (final line in raw.split('\n')) {
    final m = RegExp(r'^\W*(compliment|gossip|tell|gift|help|tease)\W*[:\-]\s*(.+)$', caseSensitive: false).firstMatch(line.trim());
    if (m == null) continue;
    final text = cleanLine(m.group(2)!.replaceAll(RegExp(r'^<|>$'), ''));
    if (text.split(' ').length >= 3) found[m.group(1)!.toLowerCase()] = text;
  }
  if (picked.where(found.containsKey).length < 3) return null;
  return [
    for (final i in picked)
      if (found[i] != null)
        DashOption(i, found[i]!, about: i == 'gossip' ? about : null, fact: i == 'tell' ? tell : null, item: i == 'gift' ? item : null),
  ];
}

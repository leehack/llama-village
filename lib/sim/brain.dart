import 'dart:math' as math;

import 'cast.dart';
import 'geo.dart';
import 'places.dart';
import 'said.dart';
import 'threads.dart';
import 'village.dart';

class Choice {
  Choice(this.kind, this.utility, this.why, {this.dest, this.minutes = 10, this.goal, this.hurry = false});
  final String kind;
  double utility;
  final Said why;
  final String? dest;
  final int minutes;
  final Goal? goal;
  final bool hurry;
}

/// Utility-based action selection: needs, storm safety, plan adherence and
/// thread goals, plus a little noise so llamas are not clockwork.
Choice decide(Village v, Llama l) {
  final options = <Choice>[];
  final minute = v.now.minute;
  final goals = v.goalsFor(l);
  final plan = l.planAt(minute);
  final planPlace = plan == null ? null : l.resolve(plan.$1);
  final night = v.isNight;
  final stormOut = v.storm && l.outdoors;

  void add(Choice c) => options.add(c);

  // Staying put.
  if (hasFood(l.place, l.home)) {
    final hunger = l.hunger.toStringAsFixed(2);
    add(
      Choice('eat', l.hunger > 0.45 ? 0.25 + l.hunger * 1.1 : 0.02, Said(SaidKey.whyHunger, 'hunger $hunger', {'v': hunger}), minutes: 20),
    );
  }
  if (l.place == l.workplace) {
    var u = 0.38 + (planPlace == l.workplace ? 0.25 : 0);
    if (l.hunger > 0.8) u -= 0.4;
    if (l.energy < 0.2) u -= 0.4;
    add(
      Choice(
        'work',
        u,
        planPlace == l.workplace ? const Said(SaidKey.whyPlanWork, 'plan says work') : const Said(SaidKey.whyAtWorkplace, 'at workplace'),
        minutes: 30,
      ),
    );
  }
  if (l.place == l.home) {
    final energy = l.energy.toStringAsFixed(2);
    add(
      Choice('nap', l.energy < 0.45 ? (1 - l.energy) * 1.15 : 0.02, Said(SaidKey.whyEnergy, 'energy $energy', {'v': energy}), minutes: 40),
    );
    if (night) add(Choice('sleep', 3, const Said(SaidKey.whyNight, 'night'), minutes: 600));
  }
  Said planWhy() => Said(SaidKey.whyPlan, 'plan: ${plan!.$2}', {'place': planPlace});
  if (planPlace == l.place) add(Choice('linger', 0.3, planWhy(), minutes: 15));
  for (final g in goals) {
    if (g.action != null && g.action != 'festival' && (g.place == null || g.place == l.place)) {
      add(Choice(g.action!, g.weight + 0.25, g.said, minutes: g.action == 'flowers' ? 8 : 20, goal: g));
    }
    if (g.action == 'festival' && l.place == 'hilltop') add(Choice('watch', g.weight + 0.3, g.said, minutes: 15, goal: g));
    // Early for an appointment: wait there rather than wander off again.
    final by = g.by;
    if (by != null && g.action == null && g.place == l.place && minute < by) {
      add(Choice('linger', g.weight + 0.2, g.said, minutes: math.min(15, by - minute), goal: g));
    }
    if (g.seek != null) {
      final target = v.byName(g.seek!);
      if (target.place == l.place && target.busyTalking) {
        add(
          Choice(
            'wait',
            g.weight + 0.1,
            Said(SaidKey.whyWaiting, 'waiting for ${target.name}', {'name': target.name}),
            minutes: 5,
            goal: g,
          ),
        );
      }
    }
  }
  if (stormOut) {
    for (final o in options) {
      o.utility -= 1.2;
    }
  }
  if (night) {
    for (final o in options) {
      if (o.kind != 'sleep') o.utility -= 1.5;
    }
  }

  // Moving.
  for (final dest in [...publicPlaces, l.home]) {
    if (dest == l.place) continue;
    final metres = walkMetres(l.place, dest, l.slot);
    final walking = travelMinutes(metres, l.walkPace);
    var u = 0.0;
    var why = const Said.raw('');
    int? by;
    void consider(double value, Said reason, {int? deadline}) {
      if (value > u) {
        u = value;
        why = reason;
        by = deadline;
      }
    }

    if (planPlace == dest) consider(0.5, planWhy());
    if (l.hunger > 0.55 && hasFood(dest, l.home)) consider(l.hunger, const Said(SaidKey.whyFood, 'food'));
    if (l.energy < 0.3 && dest == l.home) consider(1 - l.energy, const Said(SaidKey.whyRest, 'rest'));
    if (dest == l.workplace && !night) consider(0.3, const Said(SaidKey.whyWork, 'work'));
    for (final g in goals) {
      if (g.place == dest) consider(g.weight + 0.15, g.said, deadline: g.by);
      if (g.seek != null) {
        final t = v.byName(g.seek!);
        final where = t.activity.kind == 'walk' ? t.activity.dest : t.place;
        if (where == dest && !t.asleep) consider(g.weight + 0.1, g.said);
      }
    }
    for (final o in v.cast) {
      if (o != l && o.place == dest && !o.asleep) {
        consider(l.social * 0.45 + (l.friendship[o.name] ?? 0) / 40, Said(SaidKey.whyCompany, 'company: ${o.name}', {'name': o.name}));
      }
    }
    if (night && dest == l.home) consider(2.5, const Said(SaidKey.whyBedtime, 'bedtime'));
    if (v.storm) {
      if (outdoorPlaces.contains(dest)) {
        u -= 1.0;
      } else if (l.outdoors) {
        consider(1.6, const Said(SaidKey.whyShelter, 'shelter from the storm'));
      }
    }
    final deadline = by;
    final hurry = v.storm || (deadline != null && minute + walking > deadline);
    // Walks take up to ~100 game minutes, so a long one needs a real reason.
    u -= metres * 0.007;
    if (u > 0.05) add(Choice('walk', u, why, dest: dest, minutes: hurry ? travelMinutes(metres, hurryPace) : walking, hurry: hurry));
  }

  add(Choice('linger', 0.06, const Said(SaidKey.whyNothing, 'nothing better'), minutes: 10));
  for (final o in options) {
    o.utility += v.rng.nextDouble() * 0.12;
  }
  options.sort((a, b) => b.utility.compareTo(a.utility));
  l.lastDecision = Decision(v.now, [for (final o in options.take(6)) DecisionOption(o.kind, o.utility, o.why, dest: o.dest)]);
  return options.first;
}

/// Per-minute need drift by activity.
void driftNeeds(Llama l) {
  final kind = l.activity.kind;
  l.hunger = math.min(1, l.hunger + (kind == 'sleep' ? 0.0004 : 0.0013));
  l.energy -= switch (kind) {
    'sleep' => -0.0015,
    'nap' => -0.006,
    'work' || 'search' => 0.0014,
    'walk' => 0.0011,
    _ => 0.0008,
  };
  l.energy = l.energy.clamp(0, 1);
  if (kind != 'talk' && kind != 'sleep') l.social = math.min(1, l.social + 0.0018);
}

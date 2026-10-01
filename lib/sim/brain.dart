import 'dart:math' as math;

import 'cast.dart';
import 'places.dart';
import 'threads.dart';
import 'village.dart';

class Choice {
  Choice(this.kind, this.utility, this.why, {this.dest, this.minutes = 10, this.goal});
  final String kind;
  double utility;
  final String why;
  final String? dest;
  final int minutes;
  final Goal? goal;
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
    add(Choice('eat', l.hunger > 0.45 ? 0.25 + l.hunger * 1.1 : 0.02, 'hunger ${l.hunger.toStringAsFixed(2)}', minutes: 20));
  }
  if (l.place == l.workplace) {
    var u = 0.38 + (planPlace == l.workplace ? 0.25 : 0);
    if (l.hunger > 0.8) u -= 0.4;
    if (l.energy < 0.2) u -= 0.4;
    add(Choice('work', u, planPlace == l.workplace ? 'plan says work' : 'at workplace', minutes: 30));
  }
  if (l.place == l.home) {
    add(Choice('nap', l.energy < 0.45 ? (1 - l.energy) * 1.15 : 0.02, 'energy ${l.energy.toStringAsFixed(2)}', minutes: 40));
    if (night) add(Choice('sleep', 3, 'night', minutes: 600));
  }
  if (planPlace == l.place) add(Choice('linger', 0.3, 'plan: ${plan!.$2}', minutes: 15));
  for (final g in goals) {
    if (g.action != null && g.action != 'festival' && (g.place == null || g.place == l.place)) {
      add(Choice(g.action!, g.weight + 0.25, g.text, minutes: g.action == 'flowers' ? 8 : 20, goal: g));
    }
    if (g.action == 'festival' && l.place == 'hilltop') add(Choice('watch', g.weight + 0.3, g.text, minutes: 15, goal: g));
    if (g.seek != null) {
      final target = v.byName(g.seek!);
      if (target.place == l.place && target.busyTalking) {
        add(Choice('wait', g.weight + 0.1, 'waiting for ${target.name}', minutes: 5, goal: g));
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
    var u = 0.0;
    var why = '';
    void consider(double value, String reason) {
      if (value > u) {
        u = value;
        why = reason;
      }
    }

    if (planPlace == dest) consider(0.5, 'plan: ${plan!.$2}');
    if (l.hunger > 0.55 && hasFood(dest, l.home)) consider(l.hunger, 'food');
    if (l.energy < 0.3 && dest == l.home) consider(1 - l.energy, 'rest');
    if (dest == l.workplace && !night) consider(0.3, 'work');
    for (final g in goals) {
      if (g.place == dest) consider(g.weight + 0.15, g.text);
      if (g.seek != null) {
        final t = v.byName(g.seek!);
        final where = t.activity.kind == 'walk' ? t.activity.dest : t.place;
        if (where == dest && !t.asleep) consider(g.weight + 0.1, g.text);
      }
    }
    for (final o in v.cast) {
      if (o != l && o.place == dest && !o.asleep) {
        consider(l.social * 0.45 + (l.friendship[o.name] ?? 0) / 40, 'company: ${o.name}');
      }
    }
    if (night && dest == l.home) consider(2.5, 'bedtime');
    if (v.storm) {
      if (outdoorPlaces.contains(dest)) {
        u -= 1.0;
      } else if (l.outdoors) {
        consider(1.6, 'shelter from the storm');
      }
    }
    u -= travelMinutes(l.place, dest) * 0.008;
    if (u > 0.05) add(Choice('walk', u, why, dest: dest, minutes: travelMinutes(l.place, dest)));
  }

  add(Choice('linger', 0.06, 'nothing better', minutes: 10));
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

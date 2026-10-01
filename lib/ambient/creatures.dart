import 'dart:math' as math;

import '../sim/geo.dart';
import 'layout.dart';

/// What the creatures notice of the village each frame.
class AmbientView {
  const AmbientView({
    required this.hour,
    required this.storm,
    this.llamas = const [],
    this.dash = (0, 5.5),
    this.dashHeight = 2.6,
    this.dashMoving = false,
  });

  /// Time of day, 0-24 and fractional.
  final double hour;
  final bool storm;

  /// Ground positions of the llamas that are out, and whether each walks.
  final List<(P2, bool)> llamas;
  final P2 dash;

  /// Dash's height above the ground.
  final double dashHeight;
  final bool dashMoving;

  bool get night => hour >= 21.4 || hour < 5.8;

  /// From dusk to after sunrise, when the chickens stay in.
  bool get coopTime => hour >= 19.7 || hour < 6.4;

  /// When butterflies are out.
  bool get butterflyHours => hour >= 7.5 && hour < 19.2 && !storm;
}

enum Species { cat, chicken, duck, dog }

/// The behaviours, as shown in the scene and the tests.
enum Act {
  idle,
  walk,
  run,
  sit,
  groom,
  nap,
  sleep,
  hide,
  climb,
  perch,
  hop,
  chase,
  flee,
  peck,
  flutter,
  inside,
  float,
  paddle,
  dabble,
  sniff,
  follow,
  lie,
}

double _angleTo(double from, double to) => (to - from + math.pi) % (2 * math.pi) - math.pi;

/// One ambient animal: a small state machine with a position, a heading and
/// pose hints the scene animates from.
class Creature {
  Creature(this.species, this.index, this.pos, this.rng, {required this.home});

  final Species species;
  final int index;
  final math.Random rng;

  /// Where it rests: a sleep spot, a coop or a roost.
  final P2 home;

  P2 pos;

  /// Facing, as atan2(dx, dz) of the direction it looks.
  double heading = 0;

  /// Height above the ground under it (roofs, hops, jumps).
  double lift = 0;

  /// Whether it draws at all (false inside the coop or the doghouse).
  bool visible = true;

  Act act = Act.idle;

  /// Seconds in the current [act], and how long it lasts.
  double time = 0;
  double until = 3;

  /// Current ground speed, for the walk cycle.
  double speed = 0;

  /// Walk-cycle phase, advanced by distance travelled.
  double stride = 0;

  P2? target;

  /// For a roof visit: the eave spot and its height, and the ground spot
  /// below it to jump from.
  P2? perchAt;
  double perchHeight = 0;
  P2? perchFrom;

  /// Whether it sits up on a roof.
  bool perched = false;

  /// What to do after the current walk or jump.
  Act? next;
  P2? _jumpFrom;
  double _jumpFromLift = 0;

  /// Index of the butterfly a cat is after.
  int? prey;
  double _calm = 0;
  double _bored = 0;
  double _delay = 0;

  /// Shows [a] while heading for [to], without restarting the act's clock.
  void _enRoute(Act a, P2 to) {
    act = a;
    target = to;
  }

  void _go(Act a, double seconds, {P2? to}) {
    act = a;
    time = 0;
    until = seconds;
    target = to;
  }

  double _between(double lo, double hi) => lo + rng.nextDouble() * (hi - lo);
}

/// A butterfly by day: flits around a flower patch and away from cats.
class Butterfly {
  Butterfly(this.patch, this.pos, this.seed);
  final P2 patch;
  P2 pos;
  final double seed;
  double height = 1;
  double heading = 0;
  double flap = 0;
  P2 _target = (0, 0);
  double _retarget = 0;
  double _scared = 0;
  bool visible = true;
}

/// Every ambient creature in the village, stepped together.
class AmbientLife {
  AmbientLife({
    int seed = 1,
    int cats = 2,
    int chickens = 5,
    int ducks = 3,
    bool dog = true,
    int butterflies = 8,
    List<Blocker> extraBlockers = const [],
  }) : _rng = math.Random(seed),
       blockers = [...AmbientLayout.blockers, ...extraBlockers] {
    var i = 0;
    math.Random next() => math.Random(seed * 7919 + i++);
    const catHomes = <P2>[(-4.4, 3.9), (9.4, 6.9)];
    for (var k = 0; k < cats; k++) {
      final c = Creature(Species.cat, k, AmbientLayout.sunnySpots[k], next(), home: catHomes[k % catHomes.length]);
      all.add(c);
    }
    for (var k = 0; k < chickens; k++) {
      final a = k * 1.3;
      all.add(Creature(Species.chicken, k, (2.5 + math.cos(a) * 2.5, 9.5 + math.sin(a) * 1.5), next(), home: AmbientLayout.coopDoor));
    }
    for (var k = 0; k < ducks; k++) {
      final (px, pz) = AmbientLayout.pond;
      all.add(Creature(Species.duck, k, (px + k * 1.2 - 1, pz + 1.5 - k), next(), home: AmbientLayout.duckRoost(k))..act = Act.float);
    }
    if (dog) all.add(Creature(Species.dog, 0, AmbientLayout.doghouseDoor, next(), home: AmbientLayout.doghouseDoor)..act = Act.lie);
    final patches = AmbientLayout.sunnySpots;
    for (var k = 0; k < butterflies; k++) {
      final p = patches[k % patches.length];
      this.butterflies.add(Butterfly(p, (p.$1 + k * 0.3, p.$2 - k * 0.2), k * 1.7));
    }
  }

  final math.Random _rng;
  final List<Blocker> blockers;
  final List<Creature> all = [];

  /// Reduced motion: no sudden dashes. Cats neither bolt from Dash nor
  /// chase butterflies, chickens do not flutter off, and butterflies flit
  /// gently.
  bool calm = false;
  final List<Butterfly> butterflies = [];
  double _clock = 0;

  /// Named sounds the creatures make this frame, with where they are.
  final List<(String, P2)> calls = [];

  Iterable<Creature> of(Species s) => all.where((c) => c.species == s);

  void update(AmbientView v, double dt) {
    calls.clear();
    if (dt <= 0) return;
    _clock += dt;
    for (final b in butterflies) {
      _butterfly(b, v, dt);
    }
    for (final c in all) {
      c.time += dt;
      switch (c.species) {
        case Species.cat:
          _cat(c, v, dt);
        case Species.chicken:
          _chicken(c, v, dt);
        case Species.duck:
          _duck(c, v, dt);
        case Species.dog:
          _dog(c, v, dt);
      }
    }
  }

  // ------------------------------------------------------------ moving

  bool blocked(P2 p, {double margin = 0.2}) => blockers.any((b) => b.contains(p, margin)) || dist(p, (0, -6)) > AmbientLayout.islandRadius;

  /// A free spot within [radius] of [around], or [around] itself.
  P2 _spot(Creature c, P2 around, double radius) {
    for (var k = 0; k < 12; k++) {
      final a = c.rng.nextDouble() * 2 * math.pi, d = math.sqrt(c.rng.nextDouble()) * radius;
      final p = (around.$1 + math.cos(a) * d, around.$2 + math.sin(a) * d);
      if (!blocked(p, margin: 0.5)) return p;
    }
    return around;
  }

  /// Steps [c] towards [to] at [speed], around blockers and llamas; true
  /// once there.
  bool _walk(Creature c, P2 to, double speed, double dt, AmbientView v, {bool land = true}) {
    final dx = to.$1 - c.pos.$1, dz = to.$2 - c.pos.$2;
    final d = math.sqrt(dx * dx + dz * dz);
    if (d < 0.25) {
      c.speed = 0;
      return true;
    }
    var ux = dx / d, uz = dz / d;
    if (land) {
      // Steer around whatever is just ahead.
      for (final b in blockers) {
        final ox = b.at.$1 - c.pos.$1, oz = b.at.$2 - c.pos.$2;
        final od = math.sqrt(ox * ox + oz * oz);
        final reach = b.radius + 1.6;
        if (od > reach || od < 1e-6 || dist(to, b.at) < b.radius) continue;
        final ahead = (ox * ux + oz * uz) / od;
        if (ahead <= 0) continue;
        final k = (1 - od / reach) * ahead * 2.2;
        final (sx, sz) = ox * uz - oz * ux >= 0 ? (-uz, ux) : (uz, -ux);
        ux += sx * k;
        uz += sz * k;
      }
      for (final (p, _) in v.llamas) {
        final ox = c.pos.$1 - p.$1, oz = c.pos.$2 - p.$2;
        final od = math.sqrt(ox * ox + oz * oz);
        if (od < 1.6 && od > 1e-6) {
          ux += ox / od * (1.6 - od);
          uz += oz / od * (1.6 - od);
        }
      }
      final l = math.sqrt(ux * ux + uz * uz);
      if (l > 1e-6) {
        ux /= l;
        uz /= l;
      }
    }
    final step = math.min(d, speed * dt);
    var next = (c.pos.$1 + ux * step, c.pos.$2 + uz * step);
    if (land) next = _pushOut(next);
    c.stride += dist(c.pos, next);
    c.speed = speed;
    c.pos = next;
    c.heading += _angleTo(c.heading, math.atan2(ux, uz)) * math.min(1.0, dt * 10);
    return false;
  }

  P2 _pushOut(P2 p) {
    var q = p;
    // Overlapping blockers can push a point from one into the next.
    for (var pass = 0; pass < 4; pass++) {
      var moved = false;
      for (final b in blockers) {
        final d = dist(q, b.at);
        if (d < b.radius && d > 1e-6) {
          q = (b.at.$1 + (q.$1 - b.at.$1) / d * b.radius, b.at.$2 + (q.$2 - b.at.$2) / d * b.radius);
          moved = true;
        }
      }
      if (!moved) break;
    }
    final c = dist(q, (0, -6));
    if (c > AmbientLayout.islandRadius) {
      q = (q.$1 * AmbientLayout.islandRadius / c, -6 + (q.$2 + 6) * AmbientLayout.islandRadius / c);
    }
    return q;
  }

  void _face(Creature c, P2 at, double dt) {
    c.heading += _angleTo(c.heading, math.atan2(at.$1 - c.pos.$1, at.$2 - c.pos.$2)) * math.min(1.0, dt * 6);
  }

  void _call(Creature c, String name, double chancePerSecond, double dt) {
    if (c.rng.nextDouble() < chancePerSecond * dt) calls.add((name, c.pos));
  }

  // ------------------------------------------------------------ cats

  bool _dashClose(Creature c, AmbientView v, double range) => dist(c.pos, v.dash) < range && v.dashHeight < 4.5;

  void _cat(Creature c, AmbientView v, double dt) {
    c._calm = math.max(0, c._calm - dt);
    if (c.act == Act.climb) {
      _jump(c, dt);
      return;
    }
    final shelter = v.storm, sleep = !v.storm && v.night;
    if (c.perched) {
      c
        ..lift = c.perchHeight
        ..speed = 0;
      // Turn round to look out over the village from the eave.
      final from = c.perchFrom!;
      c.heading += _angleTo(c.heading, math.atan2(from.$1 - c.pos.$1, from.$2 - c.pos.$2)) * math.min(1.0, dt * 3);
      final stay = c.act == Act.perch && !shelter && !sleep && c.time < c.until || c.act == Act.sleep && sleep;
      if (!stay) _jumpTo(c, c.perchFrom!, 0, then: Act.sit);
      return;
    }
    if (c.act != Act.hop) c.lift = 0;

    if (shelter) {
      final spot = AmbientLayout.catShelters[c.index % AmbientLayout.catShelters.length];
      if (c.act == Act.hide) {
        c.speed = 0;
        _face(c, (spot.$1, spot.$2 + 3), dt);
      } else if (_walk(c, spot, 3.0, dt, v)) {
        c._go(Act.hide, 1e9);
      } else {
        c._enRoute(Act.run, spot);
      }
      return;
    }
    if (sleep) {
      if (c.act == Act.sleep) {
        c.speed = 0;
        return;
      }
      if (c.index.isEven) {
        final (spot, height, from) = AmbientLayout.roofPerch(AmbientLayout.roofHuts.first, 0);
        if (_walk(c, from, 1.2, dt, v)) {
          c.perchFrom = from;
          _jumpTo(c, spot, height, then: Act.sleep);
        } else {
          c._enRoute(Act.walk, from);
        }
      } else if (_walk(c, c.home, 1.2, dt, v)) {
        c._go(Act.sleep, 1e9);
      } else {
        c._enRoute(Act.walk, c.home);
      }
      return;
    }
    if (c.act == Act.sleep || c.act == Act.hide) c._go(Act.idle, 1);

    // Dash swooping low sends a cat running.
    if (!calm && c.act != Act.flee && c._calm <= 0 && _dashClose(c, v, 4.2) && (v.dashMoving || dist(c.pos, v.dash) < 2.5)) {
      final dx = c.pos.$1 - v.dash.$1, dz = c.pos.$2 - v.dash.$2;
      final d = math.max(0.1, math.sqrt(dx * dx + dz * dz));
      c._go(Act.flee, c._between(1.4, 2.2), to: _pushOut((c.pos.$1 + dx / d * 7, c.pos.$2 + dz / d * 7)));
      c._calm = 5;
      calls.add(('meow', c.pos));
      return;
    }

    switch (c.act) {
      case Act.flee:
        if (_walk(c, (c.target ?? c.home), 4.2, dt, v) || c.time > c.until) c._go(Act.sit, c._between(2, 4));
      case Act.walk:
        if (_walk(c, (c.target ?? c.home), 1.1, dt, v) || c.time > c.until) {
          final perch = c.perchAt;
          final then = c.next;
          c.next = null;
          if (perch != null) {
            _jumpTo(c, perch, c.perchHeight, then: Act.perch);
          } else if (then != null) {
            c._go(then, c._between(15, 30));
          } else {
            c._go(c.rng.nextBool() ? Act.sit : Act.groom, c._between(3, 7));
          }
        }
      case Act.chase:
        final b = butterflies[c.prey!];
        if (!b.visible || c.time > c.until) {
          c._go(Act.sit, c._between(2, 4));
        } else {
          _walk(c, b.pos, 3.0, dt, v);
          if (dist(c.pos, b.pos) < 0.9) c._go(Act.hop, 0.5);
        }
      case Act.hop:
        c
          ..speed = 0
          ..lift = 0.35 * math.sin(math.pi * (c.time / c.until).clamp(0.0, 1.0));
        if (c.time > c.until) {
          c
            ..lift = 0
            .._go(Act.sit, c._between(2, 4));
        }
      default:
        c.speed = 0;
        if (c.time < c.until) {
          if (c.act == Act.sit || c.act == Act.groom) _call(c, 'meow', 0.012, dt);
        } else {
          _pickCat(c, v);
        }
    }
  }

  void _pickCat(Creature c, AmbientView v) {
    c
      ..perchAt = null
      ..next = null;
    // A butterfly nearby is hard to resist.
    if (v.butterflyHours && !calm) {
      for (var i = 0; i < butterflies.length; i++) {
        final b = butterflies[i];
        if (b.visible && dist(b.pos, c.pos) < 8 && c.rng.nextDouble() < 0.6) {
          c
            ..prey = i
            .._go(Act.chase, c._between(3, 6));
          return;
        }
      }
    }
    final r = c.rng.nextDouble();
    final sunny = v.hour >= 9 && v.hour < 17.5;
    if (r < 0.32) {
      c._go(Act.walk, 25, to: _spot(c, c.pos, 9));
    } else if (r < 0.48) {
      c._go(Act.sit, c._between(3, 7));
    } else if (r < 0.62) {
      c._go(Act.groom, c._between(4, 7));
    } else if (r < 0.82 && sunny) {
      c
        ..next = Act.nap
        .._go(Act.walk, 30, to: AmbientLayout.sunnySpots[c.rng.nextInt(AmbientLayout.sunnySpots.length)]);
    } else {
      final hut = AmbientLayout.roofHuts[c.rng.nextInt(AmbientLayout.roofHuts.length)];
      final (on, h, from) = AmbientLayout.roofPerch(hut, c.index);
      c
        ..perchAt = on
        ..perchHeight = h
        ..perchFrom = from
        .._go(Act.walk, 30, to: from);
    }
  }

  /// Sends cat [c] up onto [hut]'s eave on [side] for a while.
  void sendToRoof(Creature c, String hut, {int side = 0}) {
    final (on, h, from) = AmbientLayout.roofPerch(hut, side);
    c
      ..perchAt = on
      ..perchHeight = h
      ..perchFrom = from
      ..next = null
      .._go(Act.walk, 60, to: from);
  }

  void _jumpTo(Creature c, P2 to, double height, {required Act then}) {
    c
      .._jumpFrom = c.pos
      .._jumpFromLift = c.lift
      ..perchAt = to
      ..perchHeight = height
      ..next = then
      .._go(Act.climb, 0.7);
  }

  void _jump(Creature c, double dt) {
    final t = (c.time / c.until).clamp(0.0, 1.0);
    final from = c._jumpFrom!, to = c.perchAt!;
    c
      ..pos = (from.$1 + (to.$1 - from.$1) * t, from.$2 + (to.$2 - from.$2) * t)
      ..lift = c._jumpFromLift + (c.perchHeight - c._jumpFromLift) * t + 0.9 * math.sin(math.pi * t)
      ..speed = 0;
    if (dist(from, to) > 0.05) c.heading += _angleTo(c.heading, math.atan2(to.$1 - from.$1, to.$2 - from.$2)) * math.min(1.0, dt * 12);
    if (t < 1) return;
    final then = c.next ?? Act.sit;
    c
      ..next = null
      ..perched = c.perchHeight > 0
      ..lift = c.perchHeight
      ..perchAt = null
      .._go(then, then == Act.perch ? c._between(20, 40) : (then == Act.sleep ? 1e9 : c._between(2, 4)));
  }

  // ------------------------------------------------------------ chickens

  static const List<(P2, double)> _chickenRanges = [((1.5, 9.5), 4.5), ((11.0, 11.5), 3.5), ((7.5, 11.0), 2.5)];

  void _chicken(Creature c, AmbientView v, double dt) {
    final indoors = v.coopTime || v.storm;
    if (c.act == Act.inside) {
      c.speed = 0;
      if (indoors) {
        c._delay = c.rng.nextDouble() * 6;
        return;
      }
      c._delay -= dt;
      if (c._delay > 0) return;
      c
        ..visible = true
        ..pos = AmbientLayout.coopDoor
        .._go(Act.idle, 0.5);
      return;
    }
    if (indoors) {
      c.lift = 0;
      if (_walk(c, AmbientLayout.coopDoor, v.storm ? 2.6 : 1.3, dt, v)) {
        c
          ..visible = false
          .._go(Act.inside, 1e9);
      } else {
        c._enRoute(v.storm ? Act.run : Act.walk, AmbientLayout.coopDoor);
      }
      return;
    }

    // Flutter off when a llama walks close or Dash swoops down.
    if (!calm && c.act != Act.flutter) {
      P2? from;
      for (final (p, walking) in v.llamas) {
        if (walking && dist(p, c.pos) < 2.6) from = p;
      }
      if (from == null && dist(v.dash, c.pos) < 2.2 && v.dashHeight < 3.5) from = v.dash;
      if (from != null) {
        final dx = c.pos.$1 - from.$1, dz = c.pos.$2 - from.$2;
        final d = math.max(0.1, math.sqrt(dx * dx + dz * dz));
        c._go(Act.flutter, c._between(0.7, 1.1), to: _pushOut((c.pos.$1 + dx / d * 3.5, c.pos.$2 + dz / d * 3.5)));
        _call(c, 'cluck', 1e9, 1);
        return;
      }
    }

    switch (c.act) {
      case Act.flutter:
        _walk(c, (c.target ?? c.home), 3.6, dt, v);
        c.lift = 0.45 * math.sin(math.pi * (c.time / c.until).clamp(0.0, 1.0));
        if (c.time > c.until) {
          c
            ..lift = 0
            .._go(Act.peck, c._between(1.5, 3));
        }
      case Act.walk:
        if (_walk(c, (c.target ?? c.home), 0.9, dt, v) || c.time > 8) c._go(Act.peck, c._between(1.5, 4.5));
      default:
        c.speed = 0;
        if (c.act == Act.peck) _call(c, 'cluck', 0.02, dt);
        if (c.time < c.until) break;
        final (centre, radius) = _chickenRanges[(c.index + c.rng.nextInt(2)) % _chickenRanges.length];
        if (c.rng.nextDouble() < 0.6) {
          c._go(Act.walk, 8, to: _spot(c, dist(c.pos, centre) > radius ? centre : c.pos, math.min(radius, 2.5)));
        } else {
          c._go(c.rng.nextDouble() < 0.7 ? Act.peck : Act.idle, c._between(1.5, 4));
        }
    }
  }

  // ------------------------------------------------------------ ducks

  bool _onWater(P2 p) {
    final (px, pz) = AmbientLayout.pond;
    if (dist(p, (px, pz)) > AmbientLayout.waterRadius) return false;
    final (a, b) = AmbientLayout.dock;
    return _segmentDistance(p, a, b) > 1.4;
  }

  static double _segmentDistance(P2 p, P2 a, P2 b) {
    final dx = b.$1 - a.$1, dz = b.$2 - a.$2;
    final t = (((p.$1 - a.$1) * dx + (p.$2 - a.$2) * dz) / (dx * dx + dz * dz)).clamp(0.0, 1.0);
    return dist(p, (a.$1 + dx * t, a.$2 + dz * t));
  }

  P2 _waterSpot(Creature c) {
    final (px, pz) = AmbientLayout.pond;
    for (var k = 0; k < 16; k++) {
      final a = c.rng.nextDouble() * 2 * math.pi, d = math.sqrt(c.rng.nextDouble()) * (AmbientLayout.waterRadius - 0.4);
      final p = (px + math.cos(a) * d, pz + math.sin(a) * d);
      if (_onWater(p)) return p;
    }
    return c.home;
  }

  void _duck(Creature c, AmbientView v, double dt) {
    c.lift = 0;
    final roost = v.night || v.storm;
    if (roost) {
      if (c.act != Act.sleep && c.act != Act.hide) {
        if (_swim(c, c.home, v.storm ? 1.1 : 0.55, dt)) c._go(v.storm ? Act.hide : Act.sleep, 1e9);
        c.act = c.act == Act.sleep || c.act == Act.hide ? c.act : Act.paddle;
      } else {
        c.speed = 0;
      }
      return;
    }
    if (c.act == Act.sleep || c.act == Act.hide) c._go(Act.float, 2);

    // Dash skimming the water sends the ducks paddling off.
    if (c.act != Act.run && dist(v.dash, c.pos) < 2.8 && v.dashHeight < 3.5) {
      final dx = c.pos.$1 - v.dash.$1, dz = c.pos.$2 - v.dash.$2;
      final d = math.max(0.1, math.sqrt(dx * dx + dz * dz));
      final away = (c.pos.$1 + dx / d * 3, c.pos.$2 + dz / d * 3);
      c._go(Act.run, 2.5, to: _onWater(away) ? away : _waterSpot(c));
      _call(c, 'quack', 1e9, 1);
      return;
    }
    switch (c.act) {
      case Act.paddle || Act.run:
        if (_swim(c, c.target ?? c.home, c.act == Act.run ? 1.4 : 0.5, dt) || c.time > 25) c._go(Act.float, c._between(3, 8));
      case Act.dabble:
        c.speed = 0;
        if (c.time > c.until) c._go(Act.float, c._between(2, 5));
      default:
        c.speed = 0;
        _call(c, 'quack', 0.01, dt);
        if (c.time < c.until) break;
        final r = c.rng.nextDouble();
        if (r < 0.55) {
          c._go(Act.paddle, 25, to: _waterSpot(c));
        } else if (r < 0.8) {
          c._go(Act.dabble, c._between(1.5, 3));
        } else {
          c._go(Act.float, c._between(3, 6));
        }
    }
  }

  bool _swim(Creature c, P2 to, double speed, double dt) {
    final arrived = _walk(c, to, speed, dt, const AmbientView(hour: 12, storm: false), land: false);
    if (!_onWater(c.pos)) {
      // Back into open water, away from the shore and the dock.
      final (px, pz) = AmbientLayout.pond;
      final d = dist(c.pos, (px, pz));
      if (d > AmbientLayout.waterRadius) {
        c.pos = (px + (c.pos.$1 - px) / d * AmbientLayout.waterRadius, pz + (c.pos.$2 - pz) / d * AmbientLayout.waterRadius);
      }
      final (a, b) = AmbientLayout.dock;
      final sd = _segmentDistance(c.pos, a, b);
      if (sd <= 1.4) {
        final dx = b.$1 - a.$1, dz = b.$2 - a.$2;
        final l = math.sqrt(dx * dx + dz * dz);
        final side = ((c.pos.$1 - a.$1) * -dz + (c.pos.$2 - a.$2) * dx) >= 0 ? 1.0 : -1.0;
        c.pos = (c.pos.$1 - dz / l * side * (1.45 - sd), c.pos.$2 + dx / l * side * (1.45 - sd));
      }
    }
    return arrived;
  }

  // ------------------------------------------------------------ the dog

  void _dog(Creature c, AmbientView v, double dt) {
    c._bored = math.max(0, c._bored - dt);
    c.lift = 0;
    if (v.storm) {
      if (c.act != Act.inside) {
        if (_walk(c, c.home, 3.2, dt, v)) {
          c
            ..visible = false
            .._go(Act.inside, 1e9);
        } else {
          c._enRoute(Act.run, c.home);
        }
      }
      return;
    }
    if (c.act == Act.inside) {
      c
        ..visible = true
        .._go(Act.lie, 3);
    }
    if (v.night) {
      if (c.act == Act.sleep) {
        c.speed = 0;
        _face(c, (c.home.$1 + 1, c.home.$2 + 1), dt);
        return;
      }
      if (_walk(c, c.home, 1.4, dt, v)) {
        c._go(Act.sleep, 1e9);
      } else {
        c._enRoute(Act.walk, c.home);
      }
      return;
    }
    if (c.act == Act.sleep) c._go(Act.lie, 2);

    final dashNear = dist(v.dash, c.pos) < 9 && v.dashHeight < 4.5;
    switch (c.act) {
      case Act.follow:
        final dx = c.pos.$1 - v.dash.$1, dz = c.pos.$2 - v.dash.$2;
        final d = math.max(0.1, math.sqrt(dx * dx + dz * dz));
        final heel = (v.dash.$1 + dx / d * 2.2, v.dash.$2 + dz / d * 2.2);
        if (d > 2.6) {
          _walk(c, heel, d > 6 ? 4.4 : 2.6, dt, v);
        } else {
          c.speed = 0;
          _face(c, v.dash, dt);
        }
        _call(c, 'woof', 0.05, dt);
        if (c.time > c.until || dist(c.pos, c.home) > 34) {
          c._bored = 40;
          c._go(Act.walk, 60, to: c.home);
        }
      case Act.walk || Act.sniff:
        if (_walk(c, (c.target ?? c.home), c.act == Act.sniff ? 0.8 : 1.3, dt, v) || c.time > c.until) {
          c._go(dist(c.pos, c.home) < 1 ? Act.lie : Act.sit, c._between(4, 10));
        }
      default:
        c.speed = 0;
        if (dashNear && c._bored <= 0) {
          c._go(Act.follow, c._between(12, 24));
          _call(c, 'woof', 1e9, 1);
          return;
        }
        if (c.time < c.until) break;
        final r = c.rng.nextDouble();
        if (r < 0.45) {
          c._go(Act.sniff, 14, to: _spot(c, c.home, 7));
        } else if (r < 0.7 && dist(c.pos, c.home) > 1) {
          c._go(Act.walk, 30, to: c.home);
        } else {
          c._go(r < 0.85 ? Act.lie : Act.sit, c._between(5, 12));
        }
    }
  }

  // ------------------------------------------------------------ butterflies

  void _butterfly(Butterfly b, AmbientView v, double dt) {
    b.visible = v.butterflyHours;
    if (!b.visible) return;
    b.flap += dt * 14;
    b._retarget -= dt;
    b._scared = math.max(0, b._scared - dt);
    for (final c in all) {
      if (c.species == Species.cat && dist(c.pos, b.pos) < 1.3 && b.height < 1.6) {
        b._scared = 1.5;
        final dx = b.pos.$1 - c.pos.$1, dz = b.pos.$2 - c.pos.$2;
        final d = math.max(0.1, math.sqrt(dx * dx + dz * dz));
        b._target = (b.pos.$1 + dx / d * 4, b.pos.$2 + dz / d * 4);
        b._retarget = 2;
      }
    }
    if (b._retarget <= 0) {
      final a = _rng.nextDouble() * 2 * math.pi, d = _rng.nextDouble() * 3.2;
      b._target = (b.patch.$1 + math.cos(a) * d, b.patch.$2 + math.sin(a) * d);
      b._retarget = 1.5 + _rng.nextDouble() * 2.5;
    }
    final dx = b._target.$1 - b.pos.$1, dz = b._target.$2 - b.pos.$2;
    final d = math.sqrt(dx * dx + dz * dz);
    final speed = b._scared > 0 ? (calm ? 1.6 : 3.2) : 1.1;
    final wobble = math.sin(_clock * 5.3 + b.seed) * (calm ? 0.3 : 0.9);
    if (d > 0.05) {
      final ux = dx / d, uz = dz / d;
      final step = math.min(d, speed * dt);
      b.pos = (b.pos.$1 + (ux + uz * wobble) * step, b.pos.$2 + (uz - ux * wobble) * step);
      b.heading = math.atan2(ux, uz);
    }
    final wantHeight = b._scared > 0 ? 2.6 : 0.7 + 0.5 * math.sin(_clock * 1.7 + b.seed);
    b.height += (wantHeight - b.height) * math.min(1.0, dt * 2.5);
  }
}

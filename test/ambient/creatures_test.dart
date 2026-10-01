import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/ambient/creatures.dart';
import 'package:llama_village/ambient/layout.dart';
import 'package:llama_village/sim/geo.dart';

const double _dt = 1 / 30;

/// Steps [life] for [seconds] with the view from [view] (by elapsed time).
void run(AmbientLife life, double seconds, AmbientView Function(double t) view) {
  for (var t = 0.0; t < seconds; t += _dt) {
    life.update(view(t), _dt);
  }
}

AmbientView at(
  double hour, {
  bool storm = false,
  P2 dash = (40, 40),
  double dashHeight = 2.6,
  bool dashMoving = false,
  List<(P2, bool)> llamas = const [],
}) => AmbientView(hour: hour, storm: storm, dash: dash, dashHeight: dashHeight, dashMoving: dashMoving, llamas: llamas);

void main() {
  test('every haunt is reachable on foot', () {
    final life = AmbientLife();
    final spots = <String, P2>{
      for (final h in AmbientLayout.roofHuts)
        for (final side in [0, 1]) '$h perch $side': AmbientLayout.roofPerch(h, side).$3,
      for (final (i, s) in AmbientLayout.catShelters.indexed) 'shelter $i': s,
      for (final (i, s) in AmbientLayout.sunnySpots.indexed) 'sunny $i': s,
      for (final c in life.all)
        if (c.species != Species.duck) '${c.species.name}${c.index} home': c.home,
      'coop door': AmbientLayout.coopDoor,
    };
    for (final MapEntry(:key, :value) in spots.entries) {
      expect(life.blocked(value, margin: 0), isFalse, reason: key);
    }
  });

  test('the same seed and inputs give the same creatures', () {
    String snapshot(AmbientLife l) => [
      for (final c in l.all)
        '${c.species.name}${c.index} ${c.act.name} ${c.pos.$1.toStringAsFixed(4)},${c.pos.$2.toStringAsFixed(4)} ${c.lift.toStringAsFixed(3)}',
      for (final b in l.butterflies) '${b.pos.$1.toStringAsFixed(4)},${b.pos.$2.toStringAsFixed(4)}',
    ].join('\n');
    final a = AmbientLife(seed: 5), b = AmbientLife(seed: 5), c = AmbientLife(seed: 6);
    AmbientView day(double t) => at(9 + t / 60, dash: (math.sin(t) * 10, 6), dashMoving: true);
    run(a, 90, day);
    run(b, 90, day);
    run(c, 90, day);
    expect(snapshot(a), snapshot(b));
    expect(snapshot(a), isNot(snapshot(c)));
  });

  test('at night the cats sleep, one up on Pip\'s roof, and the chickens go in', () {
    final life = AmbientLife(seed: 3);
    run(life, 120, (_) => at(23));
    final cats = life.of(Species.cat).toList();
    expect(cats.map((c) => c.act), everyElement(Act.sleep));
    final (spot, height, _) = AmbientLayout.roofPerch(AmbientLayout.roofHuts.first, 0);
    expect(dist(cats[0].pos, spot), lessThan(0.1));
    expect(cats[0].lift, closeTo(height, 1e-6));
    expect(cats[0].perched, isTrue);
    expect(dist(cats[1].pos, cats[1].home), lessThan(0.3));
    expect(life.of(Species.chicken).map((c) => (c.act, c.visible)), everyElement((Act.inside, false)));
    expect(life.of(Species.duck).map((c) => c.act), everyElement(Act.sleep));
    expect(life.of(Species.dog).single.act, Act.sleep);
    expect(life.butterflies.map((b) => b.visible), everyElement(isFalse));
  });

  test('the cat on the roof jumps down in the morning', () {
    final life = AmbientLife(seed: 3);
    run(life, 120, (_) => at(23));
    run(life, 5, (_) => at(9));
    final cat = life.of(Species.cat).first;
    expect(cat.perched, isFalse);
    expect(cat.lift, 0);
  });

  test('in a storm everyone hides', () {
    final life = AmbientLife(seed: 8);
    run(life, 30, (_) => at(11));
    run(life, 60, (_) => at(15, storm: true));
    expect(life.of(Species.chicken).map((c) => c.visible), everyElement(isFalse));
    expect(life.of(Species.dog).single.visible, isFalse);
    expect(life.of(Species.duck).map((c) => c.act), everyElement(Act.hide));
    for (final c in life.of(Species.cat)) {
      expect(c.act, Act.hide);
      expect(AmbientLayout.catShelters.any((s) => dist(s, c.pos) < 0.3), isTrue);
    }
    // And they come back out once it has passed.
    run(life, 30, (_) => at(17.6));
    expect(life.of(Species.chicken).map((c) => c.visible), everyElement(isTrue));
    expect(life.of(Species.dog).single.visible, isTrue);
  });

  test('chickens head into the coop at dusk', () {
    final life = AmbientLife(seed: 2);
    run(life, 10, (_) => at(18));
    expect(life.of(Species.chicken).map((c) => c.visible), everyElement(isTrue));
    run(life, 40, (_) => at(19.9));
    expect(life.of(Species.chicken).map((c) => c.act), everyElement(Act.inside));
  });

  test('a cat runs from Dash swooping low', () {
    final life = AmbientLife(seed: 4, chickens: 0, ducks: 0, dog: false, butterflies: 0);
    run(life, 3, (_) => at(11));
    final cat = life.of(Species.cat).first;
    final start = cat.pos;
    final dash = (start.$1 + 1.5, start.$2);
    life.update(at(11, dash: dash, dashMoving: true), _dt);
    expect(cat.act, Act.flee);
    expect(life.calls.map((c) => c.$1), contains('meow'));
    run(life, 1, (_) => at(11, dash: dash, dashMoving: true));
    expect(dist(cat.pos, dash), greaterThan(dist(start, dash) + 2));
  });

  test('chickens flutter away from a walking llama', () {
    final life = AmbientLife(seed: 4, cats: 0, ducks: 0, dog: false, butterflies: 0);
    run(life, 2, (_) => at(10));
    final hen = life.of(Species.chicken).first;
    final llama = (hen.pos.$1 + 1.2, hen.pos.$2);
    life.update(at(10, llamas: [(llama, true)]), _dt);
    expect(hen.act, Act.flutter);
    expect(life.calls.map((c) => c.$1), contains('cluck'));
    run(life, 0.8, (_) => at(10, llamas: [(llama, true)]));
    expect(dist(hen.pos, llama), greaterThan(2.5));
    expect(hen.lift, greaterThanOrEqualTo(0));
  });

  test('with reduced motion nothing bolts: cats stay put for Dash, hens ignore llamas, no chases', () {
    final life = AmbientLife(seed: 4, ducks: 0, dog: false, butterflies: 0)..calm = true;
    run(life, 3, (_) => at(11));
    final cat = life.of(Species.cat).first, hen = life.of(Species.chicken).first;
    final dash = (cat.pos.$1 + 1.5, cat.pos.$2), llama = (hen.pos.$1 + 1.2, hen.pos.$2);
    life.update(at(11, dash: dash, dashMoving: true, llamas: [(llama, true)]), _dt);
    expect(cat.act, isNot(Act.flee));
    expect(hen.act, isNot(Act.flutter));

    final chaser = AmbientLife(seed: 1, chickens: 0, ducks: 0, dog: false, cats: 1, butterflies: 3)..calm = true;
    run(chaser, 120, (_) {
      expect(chaser.all.single.act, isNot(Act.chase));
      return at(12);
    });
  });

  test('a standing llama does not startle the chickens', () {
    final life = AmbientLife(seed: 4, cats: 0, ducks: 0, dog: false, butterflies: 0);
    run(life, 2, (_) => at(10));
    final hen = life.of(Species.chicken).first;
    life.update(at(10, llamas: [((hen.pos.$1 + 1.2, hen.pos.$2), false)]), _dt);
    expect(hen.act, isNot(Act.flutter));
  });

  test('the dog tags along after Dash, then gets bored and goes home', () {
    final life = AmbientLife(seed: 7, cats: 0, chickens: 0, ducks: 0, butterflies: 0);
    final dog = life.of(Species.dog).single;
    run(life, 1, (_) => at(10));
    final home = dog.home;
    P2 dashAt(double t) => (home.$1 + 5 + t * 0.4, home.$2 + 3);
    var followed = false;
    run(life, 30, (t) {
      followed |= dog.act == Act.follow;
      return at(10, dash: dashAt(t), dashMoving: true);
    });
    expect(followed, isTrue);
    expect(dog.act, isNot(Act.follow), reason: 'bored within 24 s');
    run(life, 40, (t) => at(10, dash: dashAt(30 + t)));
    expect(dog.act, isNot(Act.follow), reason: 'stays bored for a while');
  });

  test('a cat chases a butterfly, which flies off', () {
    final life = AmbientLife(seed: 1, chickens: 0, ducks: 0, dog: false, cats: 1, butterflies: 3);
    var chased = false, scattered = false;
    run(life, 120, (_) {
      final cat = life.all.single;
      chased |= cat.act == Act.chase;
      scattered |= life.butterflies.any((b) => b.height > 1.8);
      return at(12);
    });
    expect(chased, isTrue);
    expect(scattered, isTrue);
  });

  test('night, storm and day can interrupt any errand', () {
    final life = AmbientLife(seed: 9);
    const moods = [(6.2, false), (23.0, false), (12.0, false), (15.0, true), (19.9, false), (9.0, false)];
    for (var k = 0; k < 60; k++) {
      final (hour, storm) = moods[k % moods.length];
      run(life, 0.4 + (k % 5) * 0.7, (t) => at(hour, storm: storm, dash: (k * 1.0 - 20, 6), dashMoving: true));
    }
    expect(life.all, hasLength(11));
  });

  test('over a busy day ducks stay on the water and walkers stay out of buildings', () {
    final life = AmbientLife(seed: 11);
    final rng = math.Random(2);
    var llamas = <(P2, bool)>[];
    var dash = (0.0, 5.5);
    final (px, pz) = AmbientLayout.pond;
    final (dockA, dockB) = AmbientLayout.dock;
    for (var t = 0.0; t < 24 * 30.0; t += _dt) {
      if (t % 4 < _dt) {
        llamas = [for (var k = 0; k < 5; k++) ((rng.nextDouble() * 40 - 20, rng.nextDouble() * 40 - 20), rng.nextBool())];
        dash = (rng.nextDouble() * 40 - 20, rng.nextDouble() * 40 - 20);
      }
      final hour = (6 + t / 30) % 24;
      life.update(at(hour, storm: hour > 15 && hour < 17, llamas: llamas, dash: dash, dashMoving: true), _dt);
      for (final c in life.all) {
        if (c.species == Species.duck) {
          expect(dist(c.pos, (px, pz)), lessThanOrEqualTo(AmbientLayout.waterRadius + 1e-6));
          final dx = dockB.$1 - dockA.$1, dz = dockB.$2 - dockA.$2;
          final k = (((c.pos.$1 - dockA.$1) * dx + (c.pos.$2 - dockA.$2) * dz) / (dx * dx + dz * dz)).clamp(0.0, 1.0);
          expect(dist(c.pos, (dockA.$1 + dx * k, dockA.$2 + dz * k)), greaterThan(1.3), reason: 'duck under the dock at $t');
        } else if (c.visible && !c.perched && c.act != Act.climb) {
          for (final b in life.blockers) {
            expect(
              dist(c.pos, b.at),
              greaterThan(b.radius - 0.05),
              reason: '${c.species.name}${c.index} ${c.act.name} inside ${b.at} at $t',
            );
          }
        }
      }
    }
  });
}

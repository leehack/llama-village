import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/cutscene/festival_show.dart';
import 'package:llama_village/cutscene/timeline.dart';
import 'package:llama_village/sim/geo.dart';
import 'package:vector_math/vector_math.dart' as vm;

const List<String> everyone = ['Pip', 'Mo', 'June', 'Bramble', 'Clover'];
const Map<String, double> paces = {'Pip': 1.7, 'Mo': 1.3, 'June': 1.6, 'Bramble': 1.4, 'Clover': 1.5};

FestivalShow show(List<(String, bool)> singers, {List<String> present = everyone}) =>
    FestivalShow(singers: singers, present: present, paces: paces);

/// [p] in the stage's frame: (across, toward the audience).
(double, double) stageLocal(P2 p) {
  final (ax, az) = placeAnchor('hilltop');
  final (fx, fz) = placeFacing('hilltop');
  final dx = p.$1 - ax, dz = p.$2 - az;
  return (dx * fz - dz * fx, dx * fx + dz * fz);
}

/// On the platform's boards, with room for a llama's body.
bool onPlatform(P2 p) {
  final (x, z) = stageLocal(p);
  return x.abs() < 3.0 && z > -3.9 && z < -1.2;
}

double heightOf(ShowPose p) => groundHeight(p.at.$1, p.at.$2) + p.lift;

/// The heading a yaw faces (a llama faces -Z at yaw 0).
P2 heading(double yaw) => (-math.sin(yaw), -math.cos(yaw));

/// Every moment of [s] at 20 Hz.
Iterable<double> moments(FestivalShow s) sync* {
  for (var t = 0.0; t <= s.end; t += 0.05) {
    yield t;
  }
}

void main() {
  final shows = {
    'three singers': (show([('Pip', false), ('Mo', false), ('June', false)]), ['Pip', 'Mo', 'June']),
    'Mo faints': (show([('Pip', false), ('Mo', true), ('Clover', false)]), ['Pip', 'Mo', 'Clover']),
    'everyone sings': (show([for (final n in everyone) (n, false)]), everyone),
    'one singer, two watching': (show([('June', false)], present: ['Pip', 'June', 'Clover']), ['June']),
  };

  test('each singer steps up to centre stage, sings on the platform and steps back to the line', () {
    for (final MapEntry(key: label, value: (s, _)) in shows.entries) {
      for (final turn in s.turns) {
        final line = s.pose(turn.name, turn.walkOn - 0.01);
        expect(onPlatform(line.at), isTrue, reason: '$label: ${turn.name} waits on the stage');
        expect(heightOf(line), closeTo(FestivalShow.stageTop, 1e-9));
        final mid = s.pose(turn.name, (turn.walkOn + turn.arrive) / 2);
        expect(onPlatform(mid.at), isTrue, reason: '$label: ${turn.name} walks on the boards');
        expect(heightOf(mid), closeTo(FestivalShow.stageTop, 1e-9), reason: 'on the platform, not sunk into it');
        final singing = s.pose(turn.name, turn.singFrom + 0.2);
        expect(dist(singing.at, FestivalShow.centreSpot), lessThan(1e-9));
        expect(heightOf(singing), closeTo(FestivalShow.stageTop, 1e-9));
        final facing = heading(singing.yaw);
        final front = FestivalShow.front;
        expect(facing.$1 * front.x + facing.$2 * front.z, closeTo(1, 1e-9), reason: 'sings to the audience');
        expect(singing.sing, 1);
        expect(line.sing, 0);
        expect(s.pose(turn.name, turn.walkOff + 0.1).sing, 0);
        expect(dist(s.pose(turn.name, turn.back + 0.01).at, line.at), lessThan(1e-9), reason: 'back in its place in the line');
      }
    }
  });

  test('turns run in order on one clock: walk on, song, walk off, then the next', () {
    for (final MapEntry(key: label, value: (s, _)) in shows.entries) {
      ShowTurn? prev;
      for (final turn in s.turns) {
        expect(turn.walkOn, lessThan(turn.arrive), reason: label);
        expect(turn.arrive, lessThan(turn.singFrom));
        expect(turn.singTo - turn.singFrom, closeTo(FestivalShow.singSeconds, 1e-9));
        expect(turn.singTo, lessThan(turn.walkOff));
        expect(turn.walkOff, lessThan(turn.back));
        expect(turn.walkOn, greaterThanOrEqualTo(prev?.singTo ?? FestivalShow.audienceIn), reason: 'one song at a time');
        expect(turn.walkOn, lessThan((prev?.singTo ?? FestivalShow.audienceIn) + 2.5), reason: 'nobody kept waiting');
        expect(s.singerAt(turn.singFrom)?.name, turn.name);
        prev = turn;
      }
      expect(s.judgeAt, greaterThan(prev?.singTo ?? 0));
      expect(s.winnerAt, greaterThan(s.judgeAt), reason: 'the winner is only known at the judging');
      expect(s.winnerAt, lessThan(s.judgeAt + FestivalShow.verdictSeconds + 3));
      expect(s.end, greaterThan(s.winnerAt));
    }
  });

  test('the audience stands in front of the stage, facing it, and watches the singer', () {
    for (final MapEntry(key: label, value: (s, singers)) in shows.entries) {
      expect(s.cast.toSet(), {...singers, ...s.audience}, reason: label);
      for (final name in s.audience) {
        expect(singers, isNot(contains(name)));
        final p = s.pose(name, 1);
        final (x, z) = stageLocal(p.at);
        expect(z, greaterThan(1.5), reason: '$label: $name is in front of the stage');
        expect(p.lift, 0);
        final c = FestivalShow.centreSpot;
        final to = (c.$1 - p.at.$1, c.$2 - p.at.$2);
        final len = math.sqrt(to.$1 * to.$1 + to.$2 * to.$2);
        final h = heading(p.yaw);
        expect((h.$1 * to.$1 + h.$2 * to.$2) / len, closeTo(1, 1e-6), reason: '$name faces centre stage');
        // The bench spans local x -5.1..-3.3, z 1.35..1.85; the weather mast stands at (4.8, 1.2).
        final bx = math.max(0.0, math.max(-5.1 - x, x + 3.3)), bz = math.max(0.0, math.max(1.35 - z, z - 1.85));
        expect(math.sqrt(bx * bx + bz * bz), greaterThan(0.9), reason: '$name clear of the bench');
        expect(math.sqrt((x - 4.8) * (x - 4.8) + (z - 1.2) * (z - 1.2)), greaterThan(0.9), reason: '$name clear of the mast');
        for (final turn in s.turns) {
          expect(s.pose(name, turn.singFrom + 1).look, turn.name, reason: '$name watches ${turn.name}');
        }
      }
    }
  });

  test('nobody overlaps anybody at any moment, whoever wins', () {
    for (final MapEntry(key: label, value: (s, _)) in shows.entries) {
      for (final winner in [null, ...s.turns.where((t) => !t.faints).map((t) => t.name)]) {
        for (final t in moments(s)) {
          final at = {for (final n in s.cast) n: s.pose(n, t, winner: winner).at};
          for (final a in s.cast) {
            for (final b in s.cast) {
              if (a.compareTo(b) >= 0) continue;
              expect(
                dist(at[a]!, at[b]!),
                greaterThanOrEqualTo(FestivalShow.minGap - 0.08),
                reason: '$label (winner $winner): $a and $b at ${t.toStringAsFixed(2)} s',
              );
            }
          }
        }
      }
    }
  });

  test("the audience never comes between a close-up's camera and the singer", () {
    for (final MapEntry(key: label, value: (s, _)) in shows.entries) {
      for (final i in [0, 1]) {
        for (final pose in [FestivalShow.closeUp(i), FestivalShow.closeUp(i, closer: true)]) {
          final forward = (pose.target - pose.eye)..normalize();
          final halfWidth = math.atan(math.tan(pose.fov / 2) * 16 / 9);
          for (final name in s.audience) {
            final (x, z) = s.pose(name, 1).at;
            // The legs, body and head of a llama standing there.
            for (final up in [0.6, 1.2, 1.9]) {
              final p = vm.Vector3(x, groundHeight(x, z) + up, z) - pose.eye;
              final ahead = p.dot(forward);
              final inView = ahead > 0 && math.acos((ahead / p.length).clamp(-1.0, 1.0)) < halfWidth + 0.08;
              expect(inView, isFalse, reason: '$label: $name in close-up $i');
            }
          }
        }
      }
    }
  });

  test('the winner walks into the spotlight and gets the bell; no winner lights nothing', () {
    final (s, _) = shows['three singers']!;
    for (final t in [0.0, s.judgeAt, s.winnerAt, s.end]) {
      expect(s.spotlight(t, null), 0);
      expect(s.bell(t, null), 0);
    }
    expect(s.spotlight(s.winnerAt - 0.4, 'Mo'), 0);
    expect(s.spotlight(s.winnerAt + 0.6, 'Mo'), 1);
    expect(s.bell(s.winnerAt + 0.4, 'Mo'), 0, reason: 'the bell comes after the light');
    expect(s.bell(s.winnerAt + 1.1, 'Mo'), 1);
    final mo = s.pose('Mo', s.winnerAt + 0.1, winner: 'Mo');
    expect(dist(mo.at, FestivalShow.centreSpot), lessThan(1e-9));
    expect(heightOf(mo), closeTo(FestivalShow.stageTop, 1e-9));
    expect(mo.cheer, 1);
    expect(s.pose('Pip', s.winnerAt + 0.1, winner: 'Mo').look, 'Mo');
    expect(s.pose('Bramble', s.winnerAt + 1, winner: 'Mo').cheer, greaterThan(0.5), reason: 'the crowd cheers the winner');
    expect(dist(s.pose('Mo', s.winnerAt + 0.1).at, FestivalShow.centreSpot), greaterThan(1), reason: 'only once named');
  });

  test('Mo faints instead of singing, cannot win, and gets up to leave', () {
    final (s, _) = shows['Mo faints']!;
    final mo = s.turnOf('Mo')!;
    expect(mo.faints, isTrue);
    expect(s.pose('Mo', mo.singFrom + 0.2).sing, 1, reason: 'he opens his mouth');
    expect(s.pose('Mo', mo.faintAt + 0.3).faint, 1);
    expect(s.pose('Mo', mo.faintAt + 0.3).sing, 0);
    expect(s.pose('Mo', mo.walkOff).faint, 0);
    expect(s.pose('Bramble', mo.faintAt + 0.5).cheer, 0, reason: 'nobody cheers a faint');
    expect(s.pose('Bramble', s.turnOf('Pip')!.singTo + 0.5).cheer, greaterThan(0.5), reason: 'they cheer a song');
    final winners = shows['Mo faints']!.$1;
    expect(dist(winners.pose('Mo', winners.winnerAt + 0.1, winner: 'Mo').at, FestivalShow.centreSpot), greaterThan(1));
  });

  test('with nobody singing everyone watches an empty stage and the show ends after the verdict', () {
    final s = show([]);
    expect(s.turns, isEmpty);
    expect(s.audience, everyone);
    expect(s.end, s.judgeAt + 5);
    expect(s.spotlight(s.end, null), 0);
  });

  test('the stage frame matches the platform built in the world', () {
    expect(FestivalShow.stageTop, closeTo(groundHeight(6, -34) + 0.65, 1e-9));
    final (x, z) = stageLocal(FestivalShow.centreSpot);
    expect(x, closeTo(0, 1e-9));
    expect(z, closeTo(-2.0, 1e-9));
    final close = FestivalShow.closeUp(0);
    expect(close.target.y, greaterThan(FestivalShow.stageTop));
    expect(close.fov, defaultFov);
  });
}

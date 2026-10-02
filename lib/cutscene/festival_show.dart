import 'dart:math' as math;

import 'package:vector_math/vector_math.dart' as vm;

import '../sim/geo.dart';
import 'timeline.dart';

/// Where a staged llama is at one moment of the festival show and what it
/// is doing: [lift] metres above the ground (on the stage), turned to
/// [yaw], singing, cheering or fainted (each 0..1), looking at [look].
class ShowPose {
  const ShowPose(this.at, this.yaw, {this.lift = 0, this.sing = 0, this.cheer = 0, this.faint = 0, this.look});
  final P2 at;
  final double yaw;
  final double lift;
  final double sing;
  final double cheer;
  final double faint;
  final String? look;
}

/// A walk across the stage through [stops] at [speed] m/s from [start].
class _Walk {
  _Walk(this.stops, this.start, this.speed) {
    for (var i = 1; i < stops.length; i++) {
      _along.add(_along.last + dist(stops[i - 1], stops[i]));
    }
  }

  final List<P2> stops;
  final double start;
  final double speed;
  final List<double> _along = [0];

  double get length => _along.last;
  double get end => start + length / speed;

  /// The point and heading at [t].
  (P2, P2) at(double t) {
    final d = ((t - start) * speed).clamp(0.0, length);
    var i = 1;
    while (i < stops.length - 1 && _along[i] < d) {
      i++;
    }
    final a = stops[i - 1], b = stops[i];
    final seg = math.max(_along[i] - _along[i - 1], 1e-9);
    final k = ((d - _along[i - 1]) / seg).clamp(0.0, 1.0);
    return ((a.$1 + (b.$1 - a.$1) * k, a.$2 + (b.$2 - a.$2) * k), ((b.$1 - a.$1) / seg, (b.$2 - a.$2) / seg));
  }
}

/// One singer's turn: the walk from the line to centre stage, the song and
/// the walk back.
class ShowTurn {
  ShowTurn._(this.name, this.faints, this._on, this._off, this.singFrom, this.singTo);
  final String name;

  /// Mo's nerves give out: he tips over instead of singing.
  final bool faints;
  final _Walk _on, _off;
  final double singFrom, singTo;

  double get walkOn => _on.start;
  double get arrive => _on.end;
  double get walkOff => _off.start;
  double get back => _off.end;

  /// When a fainting singer hits the stage.
  double get faintAt => singFrom + FestivalShow.faintFall;
}

/// The Berry Festival as a staged show on the hilltop stage. The singers
/// wait in a line at the back of the platform and in turn step forward to
/// centre stage, sing to the audience and step back; the other llamas
/// watch from an arc in front of the stage; then the winner steps forward
/// into the spotlight for the Golden Bell. Pure presentation: the sim
/// decides who sings and who wins.
///
/// Positions come from the stage's frame: the platform built in
/// `VillageWorld._hilltop`, its top [platformTop] metres above the
/// hilltop's ground, spanning local x -3.25..3.25 and z -4.6..-0.6 with the
/// backdrop at z -4.5 and the audience side +z.
class FestivalShow {
  /// [singers] in stage order (name, faints), the llamas [present] on the
  /// hilltop, and each llama's everyday walking pace (m/s).
  FestivalShow({required List<(String, bool)> singers, required List<String> present, required Map<String, double> paces})
    : audience = [
        for (final n in present)
          if (!singers.any((s) => s.$1 == n)) n,
      ] {
    for (final (i, (name, _)) in singers.indexed) {
      _line[name] = local((i - (singers.length - 1) / 2) * math.min(2.5, 5.3 / math.max(1, singers.length - 1)), lineZ);
    }
    for (final (i, name) in audience.indexed) {
      final a = (i - (audience.length - 1) / 2) * 20 * math.pi / 180;
      _seats[name] = local(5.6 * math.sin(a), -1.4 + 5.6 * math.cos(a));
    }
    double speed(String n) => (paces[n] ?? 1.5) * walkBoost;
    var earliest = audienceIn;
    for (final (name, faints) in singers) {
      final path = _pathFrom(_line[name]!);
      final on = _Walk(path, _clearStart(name, earliest, path, speed(name)), speed(name));
      final singFrom = on.end + settle;
      final singTo = singFrom + singSeconds;
      turns.add(ShowTurn._(name, faints, on, _Walk(path.reversed.toList(), singTo + 0.15, speed(name)), singFrom, singTo));
      earliest = singTo + 0.3;
    }
    judgeAt = turns.isEmpty ? audienceIn + 1.8 : turns.last.singTo + 0.5;
    final candidates = [
      for (final t in turns)
        if (!t.faints) t.name,
    ];
    // Every candidate would reach centre stage at the same moment, so the
    // camera and the spotlight are timed before the judging names one; the
    // winner sets off as the verdict's title fades.
    var at = judgeAt + 1.2;
    for (final n in candidates) {
      final path = _pathFrom(_line[n]!);
      at = math.max(at, _Walk(path, _clearStart(n, judgeAt + verdictSeconds - 0.6, path, speed(n)), speed(n)).end);
    }
    for (var tries = 0; candidates.isNotEmpty && tries < 100; tries++) {
      final walks = {for (final n in candidates) n: _Walk(_pathFrom(_line[n]!), 0, speed(n))};
      final arriving = {for (final MapEntry(:key, value: w) in walks.entries) key: _Walk(w.stops, at - w.length / w.speed, w.speed)};
      if (arriving.entries.every((e) => _isClear(e.key, e.value))) {
        _winnerWalks.addAll(arriving);
        break;
      }
      at += 0.1;
    }
    winnerAt = at;
    end = candidates.isEmpty ? judgeAt + 5 : winnerAt + 5.2;
  }

  /// When the first singer may step forward, after the festival's title.
  static const double audienceIn = 3.6;
  static const double singSeconds = 4.4;

  /// Seconds the verdict's title stays up after the judging.
  static const double verdictSeconds = 2.8;

  /// Seconds at centre stage to square up to the audience.
  static const double settle = 0.45;

  /// Seconds from a fainting singer's first note to hitting the stage.
  static const double faintFall = 1.7;

  /// The singers step out a little quicker than their everyday walk.
  static const double walkBoost = 1.15;

  /// Centre to centre, metres two llamas keep apart.
  static const double minGap = 1.25;

  static const double platformTop = 0.65;
  static const double lineZ = -3.65;
  static const P2 centreLocal = (0, -2.0);

  /// The watching llamas, in their order along the arc.
  final List<String> audience;
  final List<ShowTurn> turns = [];
  final Map<String, P2> _line = {}, _seats = {};
  final Map<String, _Walk> _winnerWalks = {};
  late final double judgeAt;

  /// When the winner reaches centre stage (whoever it turns out to be).
  late final double winnerAt;
  late final double end;

  static final P2 _anchor = placeAnchor('hilltop');
  static final P2 _front = placeFacing('hilltop');

  /// The stage's frame: [lx] metres across (to the audience's right) and
  /// [lz] toward the audience from the hilltop's anchor.
  static P2 local(double lx, double lz) {
    final (fx, fz) = _front;
    return (_anchor.$1 + fz * lx + fx * lz, _anchor.$2 - fx * lx + fz * lz);
  }

  /// The world height of the platform's top.
  static double get stageTop => groundHeight(_anchor.$1, _anchor.$2) + platformTop;

  static P2 get centreSpot => local(centreLocal.$1, centreLocal.$2);

  /// Centre stage, on the platform.
  static vm.Vector3 get centre {
    final (x, z) = centreSpot;
    return vm.Vector3(x, stageTop, z);
  }

  /// Toward the audience.
  static vm.Vector3 get front => vm.Vector3(_front.$1, 0, _front.$2);

  /// Across the stage, to the audience's right.
  static vm.Vector3 get right => vm.Vector3(_front.$2, 0, -_front.$1);

  /// Centre stage seen from the audience's side: [side] across, [dist]
  /// metres out and [up] metres higher, looking [aim] above the boards.
  static CameraPose shot(double side, double dist, double up, {double aim = 1.3}) {
    final d = (front + right * side)..normalize();
    return CameraPose(centre + d * dist + vm.Vector3(0, up, 0), centre + vm.Vector3(0, aim, 0));
  }

  /// Turn [i]'s close-up on the singer, from alternate sides, as it
  /// starts and ([closer]) as the song ends. The camera stays inside the
  /// audience's arc, so nobody watching comes between it and the singer.
  static CameraPose closeUp(int i, {bool closer = false}) {
    final side = sideOf(i);
    return closer ? shot(0.24 * side, 4.4, 2.0, aim: 1.65) : shot(0.3 * side, 5.0, 2.2, aim: 1.65);
  }

  /// Which side turn [i]'s close-up looks from: 1 the audience's right.
  static double sideOf(int i) => i.isEven ? 1.0 : -1.0;

  /// Over the singer's shoulder to the audience's faces.
  static CameraPose get crowdShot =>
      CameraPose(centre - front * 2.3 + right * 0.7 + vm.Vector3(0, 3.3, 0), centre + front * 5.8 + vm.Vector3(0, 0.2, 0), fov: 0.62);

  /// Metres above the ground at [p] that puts a llama on the platform.
  static double liftAt(P2 p) => stageTop - groundHeight(p.$1, p.$2);

  /// Where [name] stands when it is not performing: in the singers' line
  /// or on the audience's arc, clear of the bench and the weather mast.
  P2 home(String name) => _line[name] ?? _seats[name] ?? centreSpot;

  bool onStage(String name) => _line.containsKey(name);

  /// Everyone in the show: the singers' line, then the audience.
  List<String> get cast => [..._line.keys, ...audience];

  /// From a place in the line, forward clear of the others, to centre stage.
  static List<P2> _pathFrom(P2 spot) {
    final (x, _) = _toLocal(spot);
    return [spot, local(x, -2.3), centreSpot];
  }

  static (double, double) _toLocal(P2 p) {
    final (fx, fz) = _front;
    final dx = p.$1 - _anchor.$1, dz = p.$2 - _anchor.$2;
    return (dx * fz - dz * fx, dx * fx + dz * fz);
  }

  static double _yaw(P2 heading) => math.atan2(-heading.$1, -heading.$2);

  static double _facingStage(P2 at) {
    final c = centreSpot;
    return _yaw((c.$1 - at.$1, c.$2 - at.$2));
  }

  /// The earliest start from [earliest] at which [name]'s walk keeps
  /// [minGap] from everyone else.
  double _clearStart(String name, double earliest, List<P2> path, double speed) {
    var s = earliest;
    while (!_isClear(name, _Walk(path, s, speed)) && s < earliest + 20) {
      s += 0.1;
    }
    return s;
  }

  bool _isClear(String name, _Walk w) {
    for (var t = w.start; t <= w.end + settle; t += 0.05) {
      final (p, _) = w.at(t);
      for (final other in cast) {
        if (other != name && dist(p, pose(other, t).at) < minGap) return false;
      }
    }
    return true;
  }

  ShowTurn? turnOf(String name) => turns.where((t) => t.name == name).firstOrNull;

  /// Who is out of the line at [t], if anyone: the latest to step out.
  ShowTurn? singerAt(double t) => turns.where((s) => t >= s.walkOn && t < s.back).lastOrNull;

  /// How far the spotlight is up, 0..1, for [winner].
  double spotlight(double t, String? winner) => winner == null ? 0 : applyEase(Ease.inOut, (t - winnerAt + 0.3) / 0.8);

  /// How far the Golden Bell has appeared, 0..1, for [winner].
  double bell(double t, String? winner) => winner == null ? 0 : ((t - winnerAt - 0.5) / 0.5).clamp(0.0, 1.0);

  /// [name]'s pose at [t]; [winner] once the judging has named one.
  ShowPose pose(String name, double t, {String? winner}) {
    final spot = home(name);
    final lift = onStage(name) ? liftAt(spot) : 0.0;
    final win = winner == null ? null : _winnerWalks[winner];
    if (win != null && winner == name && t >= win.start) {
      final (p, heading) = win.at(t);
      final arrived = t >= win.end;
      return ShowPose(p, arrived ? _yaw(_front) : _yaw(heading), lift: liftAt(p), cheer: arrived ? 1 : 0);
    }
    final turn = turnOf(name);
    if (turn != null && t >= turn.walkOn && t < turn.back) return _turnPose(turn, t);
    final looking = win != null && t >= win.start ? winner : singerAt(t)?.name;
    final yaw = onStage(name) ? _yaw(_front) : _facingStage(spot);
    return ShowPose(spot, yaw, lift: lift, cheer: _cheer(name, t, winner), look: looking);
  }

  ShowPose _turnPose(ShowTurn turn, double t) {
    if (t < turn.arrive || t >= turn.walkOff) {
      final (p, heading) = (t < turn.arrive ? turn._on : turn._off).at(t);
      return ShowPose(p, _yaw(heading), lift: liftAt(p));
    }
    final c = centreSpot;
    final lift = liftAt(c);
    final singing = t >= turn.singFrom && t < turn.singTo;
    if (!turn.faints) return ShowPose(c, _yaw(_front), lift: lift, sing: singing ? 1 : 0);
    // Mo opens his mouth, sways, goes down, and gets up again to leave.
    final fall = ((t - turn.singFrom) / faintFall).clamp(0.0, 1.0);
    final up = ((t - turn.singTo + 0.7) / 0.7).clamp(0.0, 1.0);
    return ShowPose(c, _yaw(_front), lift: lift, sing: singing && fall < 0.5 ? 1 : 0, faint: fall * fall * (1 - up));
  }

  /// Everyone else cheers each song (not a faint) and the winner.
  double _cheer(String name, double t, String? winner) {
    double burst(double at) => t < at || t > at + 1.8 ? 0 : math.sin(math.pi * (t - at) / 1.8);
    var c = 0.0;
    for (final s in turns) {
      if (!s.faints && s.name != name) c = math.max(c, burst(s.singTo - 0.2));
    }
    if (winner != null && winner != name) c = math.max(c, burst(winnerAt + 0.4) + (t > winnerAt + 2.2 ? 0.35 : 0));
    return c.clamp(0.0, 1.0);
  }
}

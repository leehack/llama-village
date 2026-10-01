import 'dart:math' as math;

import 'app.dart';
import 'sim/dash.dart';
import 'sim/village.dart';

/// The env-gated capture script: an overview by day, a conversation with
/// bubbles, Dash's options, the inspector and the village at night, then
/// the frame-rate summary.
class Autoplay {
  Autoplay(this.home);
  final VillageHomeState home;

  int _step = 0;
  double _t = 0;
  double _since = 0;
  String? _talked;

  void start() => home.test.log('AUTOPLAY start');

  void _next() {
    _step++;
    _since = 0;
  }

  Future<void>? _shooting;

  void _shot(String name) {
    _shooting = home.test.shot(name).whenComplete(() => _shooting = null);
  }

  void tick(double dt) {
    _t += dt;
    if (_shooting != null) return;
    _since += dt;
    final v = home.village!;
    final stage = home.stage;
    final test = home.test;
    switch (_step) {
      case 0:
        if (_since > 4) {
          _shot('1_overview_day');
          _next();
        }
      case 1:
        final c = v.active.where((c) => v.speech[c.a.name]?.text != null || v.speech[c.b.name]?.text != null).firstOrNull;
        if (c != null) {
          final name = v.speech[c.a.name]?.text != null ? c.a.name : c.b.name;
          home.select(null);
          stage.rig
            ..followName = name
            ..follow = (() => stage.llamas[name]!.position.clone())
            ..distance = 22
            ..pitch = 0.42;
          _next();
        } else if (_since > 150) {
          test.log('AUTOPLAY no conversation seen');
          _next();
          _step++;
        }
      case 2:
        if (_since > 1.6) {
          _shot('2_conversation');
          stage.rig.overview();
          _next();
        }
      case 3:
        final free = v.cast.where((l) => !l.asleep && !l.busyTalking && l.activity.kind != 'walk').toList();
        if (free.isNotEmpty || _since > 30) {
          final l = free.isNotEmpty ? free.first : v.cast.first;
          _talked = l.name;
          home.talkTo(l.name);
          stage.rig
            ..followName = 'Dash'
            ..follow = (() => stage.dash.position.clone())
            ..distance = 24
            ..pitch = 0.45;
          _next();
        }
      case 4:
        final visit = v.dash.visit;
        if (visit != null && visit.stage == VisitStage.choosing && visit.options != null && _since > 1) {
          _shot('3_dash_options');
          home.choose(0);
          _next();
        } else if (visit == null && _since > 2 || _since > 90) {
          test.log('AUTOPLAY visit failed (${visit?.stage})');
          _step = 6;
          _since = 0;
        }
      case 5:
        final visit = v.dash.visit;
        if (visit?.stage == VisitStage.done && _since > 1.2) {
          _shot('3b_dash_reply');
          test.log('DASH reply "${visit!.reply}" ${visit.effects}');
          _next();
        } else if (_since > 60) {
          _next();
        }
      case 6:
        v.dash.leave();
        home.select(_talked ?? 'Pip');
        stage.rig
          ..followName = home.stage.selected
          ..follow = (() => stage.llamas[home.stage.selected]!.position.clone())
          ..distance = 30;
        _next();
      case 7:
        if (_since > 1.5) {
          _shot('4_inspector');
          home.select(null);
          stage.rig.overview();
          home.setSpeed(4);
          _next();
        }
      case 8:
        final hour = v.now.minute / 60;
        if (hour >= 21.6 || hour < 5) {
          home.setSpeed(1);
          stage.rig
            ..yaw = 0.35
            ..pitch = 0.5
            ..distance = 60;
          _next();
        }
      case 9:
        if (_since > 3) {
          _shot('5_night');
          _next();
        }
      case 10:
        if (_since > 1) {
          test.log('FPS ${test.fpsSummary()}');
          test.log(
            'SIM ${v.now.label} conversations=${v.done.length} lines=${v.lines.length} '
            'calls=${v.metrics.calls.length} json=${v.metrics.json}',
          );
          _calls(v);
          test.log('AUTOPLAY done in ${_t.toStringAsFixed(0)} s');
          _next();
          if (test.exitWhenDone) home.quit();
        }
    }
  }

  void _calls(Village v) {
    final byType = <String, List<double>>{};
    for (final c in v.metrics.calls) {
      byType.putIfAbsent(c.type, () => []).add(c.ms);
    }
    for (final e in byType.entries) {
      final s = e.value..sort();
      home.test.log('CALLS ${e.key} n=${s.length} p50=${s[s.length ~/ 2].round()} ms max=${s.last.round()} ms');
    }
    final lateness = v.lines.where((l) => l.shownMs != null).map((l) => l.shownMs! - l.generatedMs).toList();
    if (lateness.isNotEmpty) home.test.log('LINES shown n=${lateness.length} max wait ${lateness.reduce(math.max).round()} ms');
  }
}

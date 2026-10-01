import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../cutscene/timeline.dart';
import '../render/stage.dart';
import '../sim/clock.dart';
import '../sim/story.dart';
import '../sim/village.dart';

/// A story moment waiting to be photographed: once [who] are on screen, or
/// at once when [who] is empty.
class _Want {
  _Want(this.kind, this.weight, this.who, this.dueAt, this.until, this.day, this.minute);
  final String kind;
  final int weight;
  final List<String> who;
  final double dueAt;
  final double until;
  final int day;
  final int minute;
}

/// Takes the storybook's illustrations: small in-engine pictures of the 3D
/// view (no HUD or bubbles) at story moments, through the scene's
/// [RepaintBoundary] at reduced resolution. In play it waits until the
/// llamas involved are on screen; in cutscenes the scene frames them.
class StoryCamera {
  StoryCamera({required this.stage, required this.boundary, this.log});

  final VillageStage stage;
  final GlobalKey boundary;
  final void Function(String)? log;

  /// Width of a picture in pixels.
  static const double width = 480;

  final List<_Want> _wants = [];
  final Set<String> _scenes = {};
  int _establishedDay = 0;
  bool _busy = false;
  double _wall = 0;

  void onEvent(Village v, Map<String, Object?> e) {
    final day = storyDay(v.now), minute = v.now.minute;
    void want(String kind, int weight, List<String> who, {double delay = 0.8, double ttl = 5}) =>
        _wants.add(_Want(kind, weight, who, _wall + delay, _wall + delay + ttl, day, minute));
    switch (e['type']) {
      case 'conversation_start':
        want('talk', 3, [e['a'] as String, e['b'] as String], delay: 1.2);
      case 'world_event':
        final title = e['title'] as String;
        final place = e['place'] as String;
        final here = place == 'everywhere'
            ? <String>[]
            : [
                for (final l in v.cast)
                  if (l.place == place) l.name,
              ];
        if (title == 'Storm') {
          want('storm', 6, const [], delay: 2.5);
        } else if (title == 'Scarf found') {
          want('scarf', 6, here.take(1).toList());
        } else if (place != 'everywhere' && !title.endsWith(' sings') && title != 'Mo faints') {
          want('event', 4, here.take(2).toList());
        }
      case 'thread':
        final to = e['to'] as String;
        if (const {'confessed', 'exposed', 'accepted', 'let down gently'}.contains(to)) want('crush', 7, const ['June', 'Bramble'], ttl: 8);
        if (to == 'returned') want('scarf', 6, const ['Pip'], ttl: 8);
        if (to == 'debunked' || to == 'june exposed') want('rumour', 5, const [], delay: 0.2);
      case 'dash_reply':
        want(e['intent'] == 'gossip' ? 'rumour' : 'dash', e['intent'] == 'gossip' ? 4 : 3, [e['target'] as String], delay: 0.3);
    }
  }

  /// Called once per frame; takes at most one picture at a time.
  void tick(Village v, double dt, {CutscenePlayer? player}) {
    _wall += dt;
    if (_busy) return;
    if (player != null) {
      _cutscene(v, player);
      return;
    }
    _wants.removeWhere((w) => _wall > w.until && !(w.weight >= 5 && w.who.isNotEmpty));
    final day = storyDay(v.now);
    if (_establishedDay != day && (v.now.minute >= 11 * 60) && !v.album.hasDay(day) && !v.isNight) {
      _establishedDay = day;
      _wants.add(_Want('village', 1, const [], _wall, _wall + 1, day, v.now.minute));
    }
    for (final w in _wants.toList()) {
      if (_wall < w.dueAt) continue;
      final late = _wall > w.until;
      if (!late && !_onScreen(w.who)) continue;
      _wants.remove(w);
      // A big moment nobody framed is still worth a picture of the village.
      unawaited(_take(v, w.kind, late ? w.weight - 2 : w.weight, w.day, w.minute, w.who));
      return;
    }
  }

  void _cutscene(Village v, CutscenePlayer p) {
    final name = p.scene.name;
    final t = p.time;
    void once(String key, int weight, {int? day}) {
      if (!_scenes.add('$key/${day ?? storyDay(v.now)}')) return;
      unawaited(_take(v, key, weight, day ?? storyDay(v.now), v.now.minute, const []));
    }

    switch (name) {
      case 'announcement' when t > 3 && t < 6.5:
        once('announcement', 4, day: 1);
      case 'night' when t > 1.0 && t < 1.45:
        once('evening', 2);
      case 'festival' when t > 6 && v.festival.state != 'judged':
        once('festival', 6, day: festivalDay);
      case 'festival' when v.festival.state == 'judged' && t > p.scene.duration - 3:
        once('winner', 7, day: festivalDay);
      case 'ending' when t > p.scene.duration - 4.2:
        once('ending', 10, day: festivalDay);
    }
  }

  bool _onScreen(List<String> who) {
    final size = boundary.currentContext?.size;
    if (size == null || size.isEmpty) return false;
    final eye = stage.rig.eye;
    for (final n in who) {
      final vm.Vector3? p = n == 'Dash' ? stage.dash.position : stage.llamas[n]?.position;
      if (p == null) return false;
      if ((p - eye).length > 70) return false;
      final at = stage.toScreen(p, size);
      if (at == null || at.dx < size.width * 0.08 || at.dx > size.width * 0.92 || at.dy < size.height * 0.1 || at.dy > size.height * 0.85) {
        return false;
      }
    }
    return true;
  }

  Future<void> _take(Village v, String kind, int weight, int day, int minute, List<String> who) async {
    if (!v.album.wouldKeep(day, kind, weight)) return;
    final box = boundary.currentContext?.findRenderObject();
    if (box is! RenderRepaintBoundary || !box.hasSize || box.size.width <= 0) return;
    _busy = true;
    try {
      final image = await box.toImage(pixelRatio: width / box.size.width);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) return;
      final kept = v.album.add(StoryShot(v.album.newId(), day, minute, kind, weight, data.buffer.asUint8List(), who: who));
      log?.call('STORYSHOT $kind day=$day w=$weight ${data.lengthInBytes ~/ 1024} KB kept=$kept');
    } catch (e) {
      log?.call('STORYSHOT failed: $e');
    } finally {
      _busy = false;
    }
  }
}

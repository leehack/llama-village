import 'package:flutter_scene/scene.dart';

import '../cutscene/scenes.dart';
import '../cutscene/timeline.dart';
import '../l10n/app_localizations.dart';
import '../render/stage.dart';
import '../settings.dart';
import '../sim/clock.dart';
import '../sim/endings.dart';
import '../sim/influence.dart';
import '../sim/village.dart';

/// Runs the week's set pieces over a live game: the festival announcement,
/// the night skips, the festival and the ending. It pauses the sim while a
/// scene plays, drives the camera and the sky overrides, and hands over to
/// the epilogue when the ending scene is done.
class Director {
  Director({
    required this.v,
    required this.stage,
    required this.settings,
    required this.onDawn,
    required this.onWeekOver,
    required this.strings,
    this.onEnding,
    this.log,
  }) {
    v.events.listeners.add(_onEvent);
  }

  final Village v;
  final VillageStage stage;
  final VillageSettings settings;

  /// A new morning after a night skip: the app autosaves.
  final void Function(int day) onDawn;
  final void Function(EndingVerdict verdict, Influence influence) onWeekOver;

  /// The ending scene is starting; the storybook starts being written.
  final void Function(EndingVerdict verdict, Influence influence)? onEnding;
  final void Function(String)? log;

  /// The words for the scenes' captions, in the player's language.
  final L10n Function() strings;

  CutscenePlayer? player;
  final List<Cutscene Function()> _queue = [];

  /// Set while the clock still has to reach this morning under a night skip.
  GameTime? _dawn;
  bool _endingStarted = false;
  bool weekDone = false;
  EndingVerdict? verdict;
  Influence? influence;

  late final SceneContext _c = SceneContext(v, stage, strings);

  /// The festival show, kept for the ending scene's last tableau.
  FestivalStaging? get festival => _festival;
  FestivalStaging? _festival;

  final Map<String, double> _music = {};

  /// The cutscene themes' share of the music (by loop name), from the
  /// first scene that scores the music on: the festival, the ending, and
  /// the epilogue and results after it. Null while the day and night
  /// loops have the music to themselves.
  Map<String, double>? get music => _music.isEmpty ? null : _music;

  /// A scene is playing or the night is still being fast-forwarded.
  bool get busy => player != null || _dawn != null;

  /// The night skip finished its scene but the plans are not written yet.
  bool get waitingForDawn => player == null && _dawn != null;

  void dispose() {
    v.events.listeners.remove(_onEvent);
    _clearOverrides();
  }

  void _onEvent(Map<String, Object?> e) {
    if (e['type'] != 'thread' || e['thread'] != 'festival') return;
    if (e['to'] == 'announced') _queue.add(() => announcementScene(_c));
    if (e['to'] == 'performed') {
      _endingStarted = true;
      _queue.add(
        () => festivalScene(_c, _festival = FestivalStaging(_c), judge: () => v.skipTo(GameTime(festivalDay, festivalMinute + 25))),
      );
      _queue.add(_ending);
    }
  }

  void tick(double dt) {
    final dawn = _dawn;
    if (dawn != null && v.skipTo(dawn)) {
      _dawn = null;
      log?.call('NIGHT dawn of day ${v.now.day}');
      onDawn(v.now.day);
      if (player == null) _resume();
    }
    final p = player;
    if (p != null) {
      p.update(dt);
      _music.addAll(p.music);
      final pose = p.camera;
      if (pose != null) {
        stage.rig.override = PerspectiveCamera(position: pose.eye, target: pose.target, fovRadiansY: pose.fov, fovNear: 0.5, fovFar: 400);
      }
      if (p.finished) _ended(p);
      return;
    }
    if (_dawn != null || weekDone) return;
    if (_queue.isNotEmpty) {
      _play(_queue.removeAt(0)());
    } else if (v.weekOver && !_endingStarted) {
      _endingStarted = true;
      _play(_ending());
    } else if (nightDue(v)) {
      _play(_night());
    }
  }

  /// Esc, Space or a click during a scene.
  void skip() => player?.skip();

  Cutscene _night() {
    final dawn = dawnAfter(v.now);
    final evening = dawn.day - 1;
    return nightSkipScene(
      _c,
      nextDay: dawn.day,
      // Through 22:00 (reflections) and 04:30 (plans) while everyone sleeps;
      // the clock reaches 06:00, and the llamas wake, at the dawn shot.
      startNight: () {
        v.abandonConversations();
        v.skipTo(GameTime(dawn.day, 4 * 60 + 31));
      },
      startDawn: () => _dawn = dawn,
      dawnReady: () => _dawn == null,
      dream: (l) => reflectionOf(l, evening),
    );
  }

  Cutscene _ending() {
    final i = measure(v);
    final verdictNow = decideEnding(i);
    influence = i;
    verdict = verdictNow;
    log?.call('ENDING ${verdictNow.ending.name} ${i.toJson()} reasons=${verdictNow.reasons}');
    onEnding?.call(verdictNow, i);
    return endingScene(_c, verdictNow, i, festival: _festival);
  }

  void _play(Cutscene scene) {
    log?.call('CUTSCENE ${scene.name} start at ${v.now}');
    if (scene.pausesSim) v.paused = true;
    v.dash.leave();
    player = CutscenePlayer(scene, reducedMotion: settings.reducedMotion);
    player!.update(0);
  }

  void _ended(CutscenePlayer p) {
    log?.call('CUTSCENE ${p.scene.name} end${p.skipped ? ' (skipped)' : ''} timeouts=${p.timeouts}');
    player = null;
    _clearOverrides();
    if (p.scene.name == 'ending') {
      weekDone = true;
      v.paused = true;
      onWeekOver(verdict!, influence!);
      return;
    }
    if (_queue.isNotEmpty) {
      _play(_queue.removeAt(0)());
      return;
    }
    if (_dawn == null) _resume();
  }

  void _resume() {
    if (!weekDone) v.paused = false;
  }

  void _clearOverrides() {
    stage
      ..hourOverride = null
      ..lightsOut.clear()
      ..unstage();
    stage.rig.override = null;
  }
}

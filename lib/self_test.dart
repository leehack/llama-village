import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'settings.dart';

/// Env-gated self-test hooks, inert by default.
///
/// * `VILLAGE_CAPTURE=1` logs frame rates every two seconds (split by
///   whether the dialogue model was generating) and lets [shot] save PNGs
///   of the app through a [RepaintBoundary] into `VILLAGE_CAPTURE_DIR`.
/// * `VILLAGE_AUTOPLAY=1` runs the capture script (see `autoplay.dart`).
/// * `VILLAGE_EXIT=1` quits once the script is done.
/// * `VILLAGE_MS_PER_MINUTE=n` runs the clock faster for test runs.
/// * `VILLAGE_FPS=n` caps the frame rate at 30, 60 or 120 for the run.
/// * `VILLAGE_AUTOPLAY=week` runs the Festival Week script instead (see
///   `game/week_autoplay.dart`); `VILLAGE_BOT=harmony|drama|quiet` plays
///   Dash by rules; `VILLAGE_TIME_SCALE=32` and `VILLAGE_JUMP_DAY=5`
///   compress the week.
/// * `VILLAGE_SAVE_DIR=dir` keeps saves and the gallery out of the real
///   profile.
/// * `VILLAGE_QUIT_AT=menu|cutscene|generation|story` quits at that moment.
/// * `VILLAGE_MEMLOG=10` logs memory and collection sizes every 10 s
///   (see `game/mem_probe.dart`); `VILLAGE_REPLAY=<seconds>` adds two short
///   games after the week script, each left by "Save and quit to menu";
///   `VILLAGE_KEEP_TICKING=1` keeps the game going while the screen is locked.
/// * `VILLAGE_LANG=en|ko|fr` sets the language for the run; like
///   `VILLAGE_FPS`, it makes the run's settings unsaved defaults.
/// * `VILLAGE_RECORD=<file.json>` plays a new game on the live models and
///   records it for replay (see `sim/session.dart`); `VILLAGE_PLAYBACK=<file>`
///   plays a recorded game again with no model loaded, and
///   `VILLAGE_CINEMATIC=<shots.json>` renders a replay offline (see
///   `cinematic.dart`). All three run the sim on a fixed 60 Hz step and
///   ignore the mouse and keyboard; `VILLAGE_BOT_THINK_MS=<ms>` sets how long
///   the bot looks at Dash's options before choosing.
/// * `VILLAGE_MOTION_LOG=<file.csv>` writes every actor's sim target and
///   drawn pose, speed, gait and yaw each frame, for chasing jitter.
class SelfTest {
  SelfTest._(this._env)
    : capture = _env['VILLAGE_CAPTURE'] == '1',
      autoplay = _env['VILLAGE_AUTOPLAY'] == '1',
      weekScript = _env['VILLAGE_AUTOPLAY'] == 'week';

  factory SelfTest.fromEnvironment() => SelfTest._(Platform.environment);

  final Map<String, String> _env;
  final bool capture;
  final bool autoplay;
  final bool weekScript;

  /// A debug time scale beyond the 4× of the HUD.
  double? get timeScale => double.tryParse(_env['VILLAGE_TIME_SCALE'] ?? '');
  int? get jumpDay => int.tryParse(_env['VILLAGE_JUMP_DAY'] ?? '');
  String? get bot => _env['VILLAGE_BOT'];
  String? get saveDir => _env['VILLAGE_SAVE_DIR'];
  String? get quitAt => _env['VILLAGE_QUIT_AT'];

  /// `VILLAGE_REPLAY=<seconds>`: the week script then plays two more games
  /// that long each, leaving each through "Save and quit to menu".
  double? get replaySeconds => double.tryParse(_env['VILLAGE_REPLAY'] ?? '');

  /// `VILLAGE_KEEP_TICKING=1`: keep the game running without vsync (a
  /// locked screen or a sleeping display), for unattended soak runs.
  bool get keepTicking => _env['VILLAGE_KEEP_TICKING'] == '1';

  /// Seconds between `VILLAGE MEM` lines, or null for none.
  double? get memLogSeconds => double.tryParse(_env['VILLAGE_MEMLOG'] ?? '');

  /// `VILLAGE_MUTE=1`: never opens the audio device. The soundscape still
  /// runs, so a cinematic render logs its soundtrack all the same.
  bool get mute => _env['VILLAGE_MUTE'] == '1';

  bool get exitWhenDone => _env['VILLAGE_EXIT'] == '1';
  int? get msPerMinute => int.tryParse(_env['VILLAGE_MS_PER_MINUTE'] ?? '');
  bool get canned => _env['VILLAGE_CANNED'] == '1';
  int? get seed => int.tryParse(_env['VILLAGE_SEED'] ?? '');

  /// The session file to record the game into, or to play back.
  String? get recordPath => _env['VILLAGE_RECORD'];
  String? get playbackPath => _env['VILLAGE_PLAYBACK'];

  /// The shot list for an offline cinematic render of [playbackPath]
  /// (`VILLAGE_PLAYBACK` is required with it).
  String? get cinematicPath => _env['VILLAGE_CINEMATIC'];

  /// `VILLAGE_MOTION_LOG=<file.csv>`: every actor's sim target and drawn
  /// pose, each frame (see `VillageStage.motionLog`).
  String? get motionLogPath => _env['VILLAGE_MOTION_LOG'];
  String? env(String key) => _env[key];

  /// Recorded and replayed games step the sim by exactly 1/60 s a frame,
  /// so a replay takes the same steps as its recording.
  bool get fixedStep => recordPath != null || playbackPath != null;
  double? get botThinkMs => double.tryParse(_env['VILLAGE_BOT_THINK_MS'] ?? '');

  /// Frame-rate cap for this run, overriding (and not saving) the setting.
  int? get fps => int.tryParse(_env['VILLAGE_FPS'] ?? '');

  /// VILLAGE_LANG=en|ko|fr: the language for this run.
  AppLanguage? get language => AppLanguage.values.where((l) => l.code != null && l.code == _env['VILLAGE_LANG']).firstOrNull;

  final GlobalKey boundaryKey = GlobalKey();
  final Set<String> taken = {};
  String? _dir;
  bool _busy = false;
  final List<double> _raster = [], _build = [];
  final List<double> _total = [];

  /// Milliseconds between rendered frames in the current window.
  final List<double> _intervals = [];
  int _frames = 0;
  int _rendered = 0;
  int _busyFrames = 0;

  /// Milliseconds of sim and scene-sync work per frame.
  final List<double> simMs = [], sceneMs = [];
  bool _capturing = false;
  final Stopwatch _clock = Stopwatch();

  /// Whether the dialogue model is generating, sampled once per frame.
  bool Function() generating = () => false;

  /// The model jobs running now ("dialogue+embed_check"), for the stall count.
  String Function() running = () => '';

  /// Rendered frames, and those more than 20 ms after the previous one, by
  /// the model jobs running when they were rendered.
  final Map<String, int> framesBy = {}, stallsBy = {};

  /// (fps, share of frames with the model generating, milliseconds between
  /// rendered frames) per two-second window.
  final List<(double, double, List<double>)> windows = [];
  double worstFrameMs = 0;

  void start() {
    if (!capture) return;
    final dir = Directory(_env['VILLAGE_CAPTURE_DIR'] ?? '${Directory.systemTemp.path}/village_capture')..createSync(recursive: true);
    _dir = dir.path;
    log('CAPTURE_DIR ${dir.path}');
    _clock.start();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  /// Called once per rendered frame by the game loop, [dt] seconds after
  /// the previous one.
  void frame(double dt) {
    if (!capture) return;
    _rendered++;
    if (dt > 0) _intervals.add(dt * 1000);
    final jobs = running();
    framesBy[jobs] = (framesBy[jobs] ?? 0) + 1;
    if (dt > 0.020) stallsBy[jobs] = (stallsBy[jobs] ?? 0) + 1;
    if (generating()) _busyFrames++;
  }

  void _onTimings(List<ui.FrameTiming> timings) {
    for (final t in timings) {
      _frames++;
      _raster.add(t.rasterDuration.inMicroseconds / 1000);
      _build.add(t.buildDuration.inMicroseconds / 1000);
      _total.add(t.totalSpan.inMicroseconds / 1000);
    }
    final seconds = _clock.elapsedMilliseconds / 1000;
    if (seconds < 2) return;
    String pct(List<double> v, double q) {
      if (v.isEmpty) return '-';
      final s = [...v]..sort();
      return s[(q * (s.length - 1)).round()].toStringAsFixed(1);
    }

    // Flutter frames run at the display's vsync rate; the scene renders on
    // the subset the frame-rate cap lets through.
    final fps = _rendered / seconds;
    final vsync = _frames / seconds;
    final capturing = _capturing;
    _capturing = _busy;
    final busy = _rendered == 0 ? 0.0 : (_busyFrames / _rendered).clamp(0.0, 1.0);
    if (!capturing) {
      windows.add((fps, busy, [..._intervals]));
      for (final t in _total) {
        if (t > worstFrameMs) worstFrameMs = t;
      }
    }
    log(
      'PERF fps=${fps.toStringAsFixed(1)} vsync=${vsync.toStringAsFixed(0)} gen=${(busy * 100).round()}% raster p50=${pct(_raster, .5)} '
      'p99=${pct(_raster, .99)} build p50=${pct(_build, .5)} p99=${pct(_build, .99)} '
      'frame max=${pct(_total, 1)} interval p95=${pct(_intervals, .95)} ms sim p50=${pct(simMs, .5)} p99=${pct(simMs, .99)} '
      'scene p50=${pct(sceneMs, .5)} p99=${pct(sceneMs, .99)}${capturing ? ' (capture)' : ''}',
    );
    simMs.clear();
    sceneMs.clear();
    _frames = 0;
    _rendered = 0;
    _busyFrames = 0;
    _raster.clear();
    _build.clear();
    _intervals.clear();
    _total.clear();
    _clock.reset();
  }

  /// Median fps over windows where the model was generating at least
  /// [minBusy] of the frames (or at most [maxBusy]).
  String fpsSummary() {
    String median(Iterable<double> v) {
      final s = v.toList()..sort();
      return s.isEmpty ? '-' : '${s[s.length ~/ 2].toStringAsFixed(1)} (n=${s.length}, min ${s.first.toStringAsFixed(1)})';
    }

    final warm = windows.skip(2);
    return 'fps generating>=70%: ${median(warm.where((w) => w.$2 >= 0.7).map((w) => w.$1))}; '
        'idle<=10%: ${median(warm.where((w) => w.$2 <= 0.1).map((w) => w.$1))}; '
        'all: ${median(warm.map((w) => w.$1))}; worst frame ${worstFrameMs.toStringAsFixed(0)} ms';
  }

  void log(String message) {
    if (capture || autoplay || weekScript || quitAt != null || memLogSeconds != null || fixedStep) debugPrint('VILLAGE $message');
  }

  /// Saves the app as `<name>.png` once.
  Future<void> shot(String name) async {
    final dir = _dir;
    if (dir == null || _busy || taken.contains(name)) return;
    _busy = true;
    _capturing = true;
    taken.add(name);
    try {
      await SchedulerBinding.instance.endOfFrame;
      await SchedulerBinding.instance.endOfFrame;
      final boundary = boundaryKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) return;
      final image = await boundary.toImage();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      log('SHOT $name');
    } finally {
      _busy = false;
    }
  }
}

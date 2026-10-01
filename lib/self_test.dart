import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Env-gated self-test hooks, inert by default.
///
/// * `VILLAGE_CAPTURE=1` logs frame rates every two seconds (split by
///   whether the dialogue model was generating) and lets [shot] save PNGs
///   of the app through a [RepaintBoundary] into `VILLAGE_CAPTURE_DIR`.
/// * `VILLAGE_AUTOPLAY=1` runs the capture script (see `autoplay.dart`).
/// * `VILLAGE_EXIT=1` quits once the script is done.
/// * `VILLAGE_MS_PER_MINUTE=n` runs the clock faster for test runs.
class SelfTest {
  SelfTest._(this._env) : capture = _env['VILLAGE_CAPTURE'] == '1', autoplay = _env['VILLAGE_AUTOPLAY'] == '1';

  factory SelfTest.fromEnvironment() => SelfTest._(Platform.environment);

  final Map<String, String> _env;
  final bool capture;
  final bool autoplay;

  bool get exitWhenDone => _env['VILLAGE_EXIT'] == '1';
  int? get msPerMinute => int.tryParse(_env['VILLAGE_MS_PER_MINUTE'] ?? '');
  bool get canned => _env['VILLAGE_CANNED'] == '1';
  int? get seed => int.tryParse(_env['VILLAGE_SEED'] ?? '');

  final GlobalKey boundaryKey = GlobalKey();
  final Set<String> taken = {};
  String? _dir;
  bool _busy = false;
  final List<double> _raster = [], _build = [];
  final List<double> _total = [];
  int _frames = 0;
  int _busyFrames = 0;
  final Stopwatch _clock = Stopwatch();

  /// Whether the dialogue model is generating, sampled once per frame.
  bool Function() generating = () => false;

  /// (fps, share of frames with the model generating) per two-second window.
  final List<(double, double)> windows = [];
  double worstFrameMs = 0;

  void start() {
    if (!capture) return;
    final dir = Directory(_env['VILLAGE_CAPTURE_DIR'] ?? '${Directory.systemTemp.path}/village_capture')..createSync(recursive: true);
    _dir = dir.path;
    log('CAPTURE_DIR ${dir.path}');
    _clock.start();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  /// Called once per rendered frame by the game loop.
  void frame() {
    if (!capture) return;
    if (generating()) _busyFrames++;
  }

  void _onTimings(List<ui.FrameTiming> timings) {
    for (final t in timings) {
      _frames++;
      _raster.add(t.rasterDuration.inMicroseconds / 1000);
      _build.add(t.buildDuration.inMicroseconds / 1000);
      final total = t.totalSpan.inMicroseconds / 1000;
      _total.add(total);
      if (total > worstFrameMs) worstFrameMs = total;
    }
    final seconds = _clock.elapsedMilliseconds / 1000;
    if (seconds < 2) return;
    String pct(List<double> v, double q) {
      if (v.isEmpty) return '-';
      final s = [...v]..sort();
      return s[(q * (s.length - 1)).round()].toStringAsFixed(1);
    }

    final fps = _frames / seconds;
    final busy = _frames == 0 ? 0.0 : (_busyFrames / _frames).clamp(0.0, 1.0);
    windows.add((fps, busy));
    log(
      'PERF fps=${fps.toStringAsFixed(1)} gen=${(busy * 100).round()}% raster p50=${pct(_raster, .5)} '
      'p99=${pct(_raster, .99)} build p50=${pct(_build, .5)} p99=${pct(_build, .99)} '
      'frame max=${pct(_total, 1)} ms',
    );
    _frames = 0;
    _busyFrames = 0;
    _raster.clear();
    _build.clear();
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
    if (capture || autoplay) debugPrint('VILLAGE $message');
  }

  /// Saves the app as `<name>.png` once.
  Future<void> shot(String name) async {
    final dir = _dir;
    if (dir == null || _busy || taken.contains(name)) return;
    _busy = true;
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

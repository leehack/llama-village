import 'dart:math' as math;

/// Caps the scene's frame rate by skipping vsync ticks.
///
/// The display ticks at its own rate (up to 120 Hz on ProMotion); [onVsync]
/// says whether a tick should render and, if so, how much real time passed
/// since the last rendered frame, so the sim and animations stay time-based.
class FrameThrottle {
  FrameThrottle(this.fps);

  /// Target frames per second.
  int fps;
  Duration? _last;

  /// Ticks arrive a little early or late; accepting a tick at 80% of the
  /// interval keeps a 60 fps cap on a 120 Hz display at every second tick
  /// instead of slipping to every third.
  static const double tolerance = 0.8;

  /// How long after a rendered frame to ask for the next: early enough
  /// for the vsync it is due on (it lands on the first vsync after the
  /// request), late enough to skip the ones in between.
  Duration get untilNextRequest => Duration(microseconds: math.max(0, (1e6 / fps - 6000).round()));

  /// Returns the seconds since the previous rendered frame when the tick at
  /// [now] should render, or null to skip it.
  double? onVsync(Duration now) {
    final last = _last;
    if (last == null) {
      _last = now;
      return 0;
    }
    final elapsed = (now - last).inMicroseconds / 1e6;
    if (elapsed < tolerance / fps) return null;
    _last = now;
    return elapsed;
  }
}

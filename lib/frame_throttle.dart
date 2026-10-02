import 'dart:math' as math;

/// Caps the scene's frame rate by skipping vsync ticks.
///
/// The display ticks at its own rate (up to 120 Hz on ProMotion); [onVsync]
/// says whether a tick should render and, if so, how much real time passed
/// since the last rendered frame, so the sim and animations stay time-based.
/// Frames are due on a steady cadence of 1/[fps] rather than 1/[fps] after
/// the last one, so a frame that comes a vsync late (the GPU busy with the
/// model) is followed by one back on the cadence instead of shifting every
/// later frame and losing one.
class FrameThrottle {
  FrameThrottle(this.fps);

  /// Target frames per second.
  int fps;
  Duration? _last;

  /// When the next frame is due, in the ticks' clock.
  Duration _due = Duration.zero;

  /// Ticks arrive a little early or late; accepting a tick up to a fifth of
  /// the interval before it is due keeps a 60 fps cap on a 120 Hz display
  /// at every second tick instead of slipping to every third.
  static const double tolerance = 0.8;

  Duration get _interval => Duration(microseconds: (1e6 / fps).round());

  /// How long after the tick at [now] to ask for the next frame: early
  /// enough for the vsync it is due on (it lands on the first vsync after
  /// the request), late enough to skip the ones in between.
  Duration untilNextRequest(Duration now) => Duration(microseconds: math.max(0, (_due - now).inMicroseconds - 6000));

  /// Returns the seconds since the previous rendered frame when the tick at
  /// [now] should render, or null to skip it.
  double? onVsync(Duration now) {
    final last = _last;
    final interval = _interval;
    if (last == null) {
      _last = now;
      _due = now + interval;
      return 0;
    }
    if (now < _due - interval * (1 - tolerance)) return null;
    // More than a frame behind (a hitch, a fps change): start the cadence
    // afresh rather than rendering a burst to catch up.
    _due = now - _due > interval ? now + interval : _due + interval;
    final elapsed = (now - last).inMicroseconds / 1e6;
    _last = now;
    return elapsed;
  }
}

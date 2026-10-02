import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/frame_throttle.dart';

/// Feeds [seconds] of vsync ticks at [hz] (with optional jitter) and returns
/// the rendered frame count and the summed render deltas.
(int, double) run(FrameThrottle t, {required double hz, double seconds = 10, double jitterMs = 0, int seed = 1}) {
  final rng = math.Random(seed);
  var frames = 0;
  var total = 0.0;
  final ticks = (hz * seconds).round();
  for (var i = 0; i <= ticks; i++) {
    final jitter = jitterMs == 0 ? 0.0 : (rng.nextDouble() * 2 - 1) * jitterMs;
    final us = (i * 1e6 / hz + jitter * 1000).round();
    final dt = t.onVsync(Duration(microseconds: us));
    if (dt != null) {
      frames++;
      total += dt;
    }
  }
  return (frames, total);
}

void main() {
  test('the first tick renders with a zero delta', () {
    expect(FrameThrottle(60).onVsync(const Duration(seconds: 3)), 0);
  });

  for (final (hz, cap, expected) in [
    (120.0, 60, 60),
    (120.0, 30, 30),
    (120.0, 120, 120),
    (60.0, 60, 60),
    (60.0, 30, 30),
    (60.0, 120, 60),
  ]) {
    test('$cap fps cap on a ${hz.round()} Hz display renders $expected fps', () {
      final (frames, total) = run(FrameThrottle(cap), hz: hz);
      expect(frames / 10, closeTo(expected, 1));
      expect(total, closeTo(10, 0.02), reason: 'render deltas add up to real time');
    });
  }

  test('vsync jitter does not drop a 60 fps cap on 120 Hz to 40 fps', () {
    final (frames, total) = run(FrameThrottle(60), hz: 120, jitterMs: 1.5);
    expect(frames / 10, closeTo(60, 1));
    expect(total, closeTo(10, 0.02));
  });

  test('skipped ticks return null and the next render carries their time', () {
    final t = FrameThrottle(60);
    t.onVsync(Duration.zero);
    expect(t.onVsync(const Duration(microseconds: 8333)), isNull);
    expect(t.onVsync(const Duration(microseconds: 16667)), closeTo(0.016667, 1e-6));
  });

  test('changing the cap takes effect on the next tick', () {
    final t = FrameThrottle(30);
    t.onVsync(Duration.zero);
    expect(t.onVsync(const Duration(microseconds: 16667)), isNull);
    t.fps = 60;
    expect(t.onVsync(const Duration(microseconds: 33333)), isNotNull);
  });

  test('the next frame is asked for after the vsyncs to skip and before the one it is due on', () {
    for (final hz in [60, 120]) {
      for (final cap in [30, 60, 120]) {
        if (cap > hz) continue;
        final wait = FrameThrottle(cap).untilNextRequest.inMicroseconds / 1e6;
        expect(wait, lessThan(1 / cap - 0.004), reason: '$cap fps on $hz Hz');
        expect(wait, greaterThan(1 / cap - 1 / hz), reason: '$cap fps on $hz Hz');
      }
    }
  });
}

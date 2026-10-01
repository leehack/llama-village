import 'dart:math' as math;

/// SplitMix64, so a save can store the generator's exact position;
/// dart:math's [math.Random] hides its state.
class SimRandom implements math.Random {
  SimRandom(int seed) : state = seed;

  int state;

  /// The state as 16 hex digits (two's complement for negative states).
  String get stateHex => (state >>> 32).toRadixString(16).padLeft(8, '0') + (state & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');

  /// Reads a state written by [stateHex].
  static int parseState(String hex) {
    if (hex.isEmpty || hex.length > 16) throw FormatException('bad generator state', hex);
    var v = 0;
    for (final c in hex.codeUnits) {
      final d = int.parse(String.fromCharCode(c), radix: 16);
      v = (v << 4) | d;
    }
    return v;
  }

  int _next() {
    state += 0x9E3779B97F4A7C15;
    var z = state;
    z = (z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9;
    z = (z ^ (z >>> 27)) * 0x94D049BB133111EB;
    return z ^ (z >>> 31);
  }

  @override
  int nextInt(int max) {
    if (max <= 0) throw RangeError.range(max, 1, null, 'max');
    return (_next() >>> 1) % max;
  }

  @override
  double nextDouble() => (_next() >>> 11) / 9007199254740992.0;

  @override
  bool nextBool() => _next() < 0;
}

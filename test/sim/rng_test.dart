import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/sim/rng.dart';

void main() {
  test('the generator state survives a hex round trip, top bit and all', () {
    final a = SimRandom(42);
    for (var i = 0; i < 5; i++) {
      a.nextInt(100);
    }
    final b = SimRandom(0)..state = SimRandom.parseState(a.stateHex);
    expect(b.state, a.state);
    expect([for (var i = 0; i < 20; i++) b.nextDouble()], [for (var i = 0; i < 20; i++) a.nextDouble()]);
    final negative = SimRandom(-5);
    expect(negative.stateHex, hasLength(16));
    expect(SimRandom.parseState(negative.stateHex), -5);
  });

  test('draws stay in range and look uniform', () {
    final r = SimRandom(7);
    final counts = List.filled(4, 0);
    for (var i = 0; i < 4000; i++) {
      counts[r.nextInt(4)]++;
      expect(r.nextDouble(), inInclusiveRange(0, 1));
    }
    expect(counts.every((c) => c > 850 && c < 1150), isTrue, reason: '$counts');
    expect(() => r.nextInt(0), throwsRangeError);
    expect(() => SimRandom.parseState(''), throwsFormatException);
  });
}

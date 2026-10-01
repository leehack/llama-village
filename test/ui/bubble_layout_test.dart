import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/ui/bubble_layout.dart';

/// A bubble of [w] x [h] whose bottom centre sits at (x, y).
BubbleRequest bubble(String id, double x, double y, {double w = 160, double h = 60}) => BubbleRequest(id, Box(x - w / 2, y - h, w, h));

Map<String, Box> placed(List<BubbleRequest> rs, Map<String, (double, double)> offsets) => {
  for (final r in rs) r.id: r.box.shift(offsets[r.id]!.$1, -offsets[r.id]!.$2),
};

void expectApart(Map<String, Box> boxes, {List<Box> clear = const []}) {
  final list = boxes.entries.toList();
  for (var i = 0; i < list.length; i++) {
    for (var j = i + 1; j < list.length; j++) {
      expect(list[i].value.overlaps(list[j].value, 0), isFalse, reason: '${list[i].key} overlaps ${list[j].key}');
    }
    for (final t in clear) {
      expect(list[i].value.overlaps(t, 0), isFalse, reason: '${list[i].key} covers a tag $t');
    }
  }
}

void main() {
  test('bubbles that do not touch stay where they are', () {
    final rs = [bubble('Pip', 100, 300), bubble('Mo', 400, 300), bubble('June', 700, 200)];
    final out = layoutBubbles(rs);
    expect(out.values, everyElement((0.0, 0.0)));
  });

  test('two speakers side by side: the nearer keeps its spot, the other moves clear', () {
    final rs = [bubble('Pip', 300, 300), bubble('Mo', 330, 280)];
    final out = layoutBubbles(rs);
    expect(out['Pip'], (0.0, 0.0), reason: 'lowest on screen, so nearest');
    expect(out['Mo'], isNot((0.0, 0.0)));
    expectApart(placed(rs, out));
  });

  test('a crowd of five stacks without any overlap or covered name tags', () {
    final rs = [
      bubble('Pip', 300, 300),
      bubble('Mo', 320, 305),
      bubble('June', 290, 296, h: 80),
      bubble('Bramble', 350, 310, w: 220),
      bubble('Clover', 310, 290, w: 120, h: 40),
    ];
    final tags = [for (final r in rs) Box(r.box.left + r.box.width / 2 - 30, r.box.bottom, 60, 20)];
    final out = layoutBubbles(rs, keepClear: tags);
    expectApart(placed(rs, out), clear: tags);
  });

  test('a small sideways nudge beats a tall climb', () {
    final rs = [bubble('Pip', 300, 300), bubble('Mo', 300 + 160 * 0.8, 300)];
    final out = layoutBubbles(rs, gap: 0);
    final (dx, dy) = out['Mo']!;
    expect(dy, 0, reason: 'no need to rise');
    expect(dx, greaterThan(0));
    expectApart(placed(rs, out));
  });

  test('a bubble pushed off the top of the screen slides aside instead', () {
    final rs = [bubble('Mo', 300, 110, w: 200), bubble('Pip', 380, 95, w: 200)];
    const screen = Box(0, 0, 1000, 800);
    final out = layoutBubbles(rs, screen: screen);
    final boxes = placed(rs, out);
    expectApart(boxes);
    for (final b in boxes.values) {
      expect(b.top, greaterThanOrEqualTo(0), reason: '$b');
    }
    expect(out['Pip']!.$1, greaterThan(0), reason: 'away from Mo, keeping it over its own speaker');
  });

  test('the layout does not depend on the input order', () {
    final rs = [bubble('Pip', 300, 300), bubble('Mo', 330, 280), bubble('June', 280, 260)];
    expect(layoutBubbles(rs.reversed.toList()), layoutBubbles(rs));
  });

  test('the smoother eases towards the layout and forgets gone bubbles', () {
    final s = BubbleSmoother();
    expect(s.step({'Pip': (0, 0)}, 1 / 60), {'Pip': (0.0, 0.0)});
    var now = s.step({'Pip': (0, 100)}, 1 / 60);
    expect(now['Pip']!.$2, inExclusiveRange(0, 100));
    for (var i = 0; i < 60; i++) {
      now = s.step({'Pip': (0, 100), 'Mo': (10, 0)}, 1 / 60);
    }
    expect(now['Pip']!.$2, closeTo(100, 0.5));
    expect(now['Mo'], (10.0, 0.0), reason: 'a new bubble starts at its spot');
    expect(s.step({'Mo': (10, 0)}, 1 / 60).keys, ['Mo']);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../render/stage.dart';
import '../sim/village.dart';
import 'bubble_layout.dart';
import 'fonts.dart';
import 'ko_text.dart';
import 'palette.dart';

/// Name tags and speech/thought bubbles, pinned above each speaker's head.
/// The first time a bubble is drawn it is acknowledged to the sim, which
/// starts its display time then.
class BubbleLayer extends StatelessWidget {
  const BubbleLayer({
    super.key,
    required this.village,
    required this.stage,
    required this.size,
    required this.wall,
    this.textScale = 1,
    this.highContrast = false,
  });

  final Village village;
  final VillageStage stage;
  final Size size;
  final double wall;
  final double textScale;
  final bool highContrast;

  static final Expando<_Spacing> _spacing = Expando();

  @override
  Widget build(BuildContext context) {
    final eye = stage.rig.eye;
    final korean = koreanUi(context);
    final spacing = _spacing[village] ??= _Spacing();
    final items = <_Item>[];
    final names = [...village.cast.map((l) => l.name), 'Dash'];
    for (final name in names) {
      final head = stage.headOf(name);
      final p = stage.toScreen(head, size);
      if (p == null || p.dx < -200 || p.dy < -200 || p.dx > size.width + 200 || p.dy > size.height + 200) continue;
      final depth = (head - eye).length;
      final near = (1.25 - depth / 160).clamp(0.6, 1.0);
      final l = village.maybeByName(name);
      if (l != null && !stage.llamas[name]!.visible) continue;
      final s = village.speech[name];
      if (s != null && s.text != null && s.shownAtMs == null) {
        SchedulerBinding.instance.addPostFrameCallback((_) => village.ackBubble(s.id));
      }
      items.add(_Item(name, p, depth, near, s, l == null ? null : activityIcon(l.activity.kind)));
    }

    // Keep bubbles in a crowd from covering each other or the name tags.
    final tags = <Box>[];
    final requests = <BubbleRequest>[];
    for (final it in items) {
      final tag = spacing.tagSize(it.name, it.icon != null, korean) * it.near;
      tags.add(Box(it.at.dx - tag.width / 2, it.at.dy - tag.height, tag.width, tag.height));
      final s = it.speech;
      if (s == null) continue;
      final b = spacing.bubbleSize(s, textScale, highContrast, korean) * it.near;
      requests.add(BubbleRequest(it.name, Box(it.at.dx - b.width / 2, it.at.dy - tag.height - b.height, b.width, b.height)));
    }
    final offsets = spacing.smoother.step(
      layoutBubbles(requests, keepClear: tags, screen: Box(8, 8, size.width - 16, size.height - 16)),
      spacing.tick(wall),
    );

    final leaders = <(Offset, Offset, Color)>[];
    items.sort((a, b) => b.depth.compareTo(a.depth));
    final children = <Widget>[];
    for (final it in items) {
      final (dx, dy) = offsets[it.name] ?? (0.0, 0.0);
      final s = it.speech;
      if (s != null && dx * dx + dy * dy > 16) {
        final tagTop = it.at.dy - spacing.tagSize(it.name, it.icon != null, korean).height * it.near;
        leaders.add((Offset(it.at.dx + dx, tagTop - dy), Offset(it.at.dx, tagTop), accentOf(it.name)));
      }
      children.add(
        Positioned(
          left: it.at.dx,
          top: it.at.dy,
          child: FractionalTranslation(
            translation: const Offset(-0.5, -1),
            child: Transform.scale(
              scale: it.near,
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (s != null)
                    Transform.translate(
                      offset: Offset(dx / it.near, -dy / it.near),
                      child: _Bubble(speech: s, wall: wall, textScale: textScale, highContrast: highContrast, korean: korean),
                    ),
                  _NameTag(name: it.name, icon: it.icon, selected: stage.selected == it.name, korean: korean),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (leaders.isNotEmpty) Positioned.fill(child: CustomPaint(painter: LeaderLines(leaders))),
          ...children,
        ],
      ),
    );
  }
}

class _Item {
  _Item(this.name, this.at, this.depth, this.near, this.speech, this.icon);
  final String name;
  final Offset at;
  final double depth, near;
  final Speech? speech;
  final IconData? icon;
}

/// Measured bubble and tag sizes, and the eased bubble offsets.
class _Spacing {
  final BubbleSmoother smoother = BubbleSmoother();
  final Map<(int, String?, double, bool, bool), Size> _bubbles = {};
  final Map<(String, bool, bool), Size> _tags = {};
  double? _lastWall;

  double tick(double wall) {
    final dt = _lastWall == null ? 1.0 : (wall - _lastWall!).clamp(0.0, 1.0);
    _lastWall = wall;
    return dt;
  }

  Size bubbleSize(Speech s, double scale, bool highContrast, bool korean) {
    if (_bubbles.length > 64) _bubbles.clear();
    return _bubbles.putIfAbsent((s.id, s.text, scale, highContrast, korean), () {
      final thought = s.kind == SpeechKind.thought;
      final text = s.text;
      final border = highContrast ? 6 : 4;
      final painter = TextPainter(
        text: TextSpan(
          text: text == null ? '...' : keepWords(text, korean: korean),
          style: text == null
              ? _dotsStyle(scale, highContrast)
              : _textStyle(thought: thought, scale: scale, highContrast: highContrast, korean: korean, text: text),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: _bubbleMaxWidth * scale - 24 - border);
      final size = Size(painter.width + 24 + border, painter.height + 16 + border + (thought ? 19 : 8));
      painter.dispose();
      return size;
    });
  }

  Size tagSize(String name, bool icon, bool korean) => _tags.putIfAbsent((name, icon, korean), () {
    final painter = TextPainter(
      text: TextSpan(
        text: keepWords(name, korean: korean),
        style: _tagStyle(korean),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final size = Size(painter.width + 14 + 3 + (icon ? 15 : 0), painter.height + 4 + 3 + 4);
    painter.dispose();
    return size;
  });
}

/// Thin lines from a lifted bubble down to its speaker's name tag (or, in
/// a cutscene, to the spot a dream bubble belongs to).
class LeaderLines extends CustomPainter {
  LeaderLines(this.lines);
  final List<(Offset, Offset, Color)> lines;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (from, to, color) in lines) {
      canvas.drawLine(
        from,
        to,
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(LeaderLines old) => true;
}

const double _bubbleMaxWidth = 250;
TextStyle _tagStyle(bool korean) => Face.ui.on(
  const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
  korean: korean,
);
TextStyle _dotsStyle(double scale, bool highContrast) =>
    TextStyle(fontSize: 18 * scale, height: 0.9, fontWeight: FontWeight.w900, color: highContrast ? Colors.black : ink, letterSpacing: 2);

TextStyle _textStyle({
  required bool thought,
  required double scale,
  required bool highContrast,
  required bool korean,
  required String text,
}) => Face.display.on(
  TextStyle(
    fontSize: 13 * scale,
    height: 1.25,
    color: highContrast
        ? Colors.black
        : thought
        ? const Color(0xFF4A4560)
        : ink,
    fontStyle: thought ? FontStyle.italic : FontStyle.normal,
    fontWeight: highContrast ? FontWeight.w800 : FontWeight.w600,
  ),
  korean: korean,
  text: text,
);

class _NameTag extends StatelessWidget {
  const _NameTag({required this.name, required this.icon, required this.selected, required this.korean});
  final String name;
  final IconData? icon;
  final bool selected;
  final bool korean;

  @override
  Widget build(BuildContext context) {
    final c = accentOf(name);
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? c : const Color(0xCC2A2733),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: c, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KoText(name, style: _tagStyle(korean)),
          if (icon != null) ...[const SizedBox(width: 3), Icon(icon, size: 12, color: Colors.white)],
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.speech, required this.wall, required this.textScale, required this.highContrast, required this.korean});
  final Speech speech;
  final double wall;
  final double textScale;
  final bool highContrast;
  final bool korean;

  @override
  Widget build(BuildContext context) {
    final thought = speech.kind == SpeechKind.thought;
    final text = speech.text;
    final dots = '.' * (1 + (wall * 3).floor() % 3);
    final body = text == null
        ? KoText(dots.padRight(3), style: _dotsStyle(textScale, highContrast))
        : KoText(
            text,
            textAlign: TextAlign.center,
            style: _textStyle(thought: thought, scale: textScale, highContrast: highContrast, korean: korean, text: text),
          );
    final accent = highContrast ? Colors.black : accentOf(speech.who);
    final fill = highContrast
        ? Colors.white
        : thought
        ? const Color(0xF2EEEAFB)
        : const Color(0xF7FFFFFF);
    final edge = highContrast
        ? Colors.black
        : thought
        ? const Color(0xFFB9B0E0)
        : accent;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: _bubbleMaxWidth * textScale),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(thought ? 22 : 12),
              border: Border.all(color: edge, width: highContrast ? 3 : (thought ? 1.5 : 2)),
              boxShadow: const [BoxShadow(blurRadius: 10, color: Color(0x40000000), offset: Offset(0, 3))],
            ),
            child: body,
          ),
          if (thought)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(children: [_dot(9, fill, edge), const SizedBox(height: 2), _dot(6, fill, edge)]),
            )
          else
            CustomPaint(size: const Size(16, 8), painter: _Tail(accent, fill)),
        ],
      ),
    );
  }

  Widget _dot(double d, Color fill, Color edge) => Container(
    width: d,
    height: d,
    decoration: BoxDecoration(
      color: fill,
      shape: BoxShape.circle,
      border: Border.all(color: edge, width: 1.2),
    ),
  );
}

class _Tail extends CustomPainter {
  _Tail(this.color, this.fill);
  final Color color;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    final inner = Path()
      ..moveTo(3, -1)
      ..lineTo(size.width - 3, -1)
      ..lineTo(size.width / 2, size.height - 3.5)
      ..close();
    canvas.drawPath(inner, Paint()..color = fill);
  }

  @override
  bool shouldRepaint(_Tail old) => old.color != color || old.fill != fill;
}

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../render/stage.dart';
import '../sim/village.dart';
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

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    final eye = stage.rig.eye;
    final entries = <(double, Widget)>[];
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
      entries.add((
        depth,
        Positioned(
          left: p.dx,
          top: p.dy,
          child: FractionalTranslation(
            translation: const Offset(-0.5, -1),
            child: Transform.scale(
              scale: near,
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (s != null) _Bubble(speech: s, wall: wall, textScale: textScale, highContrast: highContrast),
                  _NameTag(name: name, icon: l == null ? null : activityIcon(l.activity.kind), selected: stage.selected == name),
                ],
              ),
            ),
          ),
        ),
      ));
    }
    entries.sort((a, b) => b.$1.compareTo(a.$1));
    children.addAll(entries.map((e) => e.$2));
    return IgnorePointer(
      child: Stack(clipBehavior: Clip.none, children: children),
    );
  }
}

class _NameTag extends StatelessWidget {
  const _NameTag({required this.name, required this.icon, required this.selected});
  final String name;
  final IconData? icon;
  final bool selected;

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
          Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
          ),
          if (icon != null) ...[const SizedBox(width: 3), Icon(icon, size: 12, color: Colors.white)],
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.speech, required this.wall, required this.textScale, required this.highContrast});
  final Speech speech;
  final double wall;
  final double textScale;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    final thought = speech.kind == SpeechKind.thought;
    final text = speech.text;
    final dots = '.' * (1 + (wall * 3).floor() % 3);
    final body = text == null
        ? Text(
            dots.padRight(3),
            style: TextStyle(
              fontSize: 18 * textScale,
              height: 0.9,
              fontWeight: FontWeight.w900,
              color: highContrast ? Colors.black : ink,
              letterSpacing: 2,
            ),
          )
        : Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13 * textScale,
              height: 1.25,
              color: highContrast
                  ? Colors.black
                  : thought
                  ? const Color(0xFF4A4560)
                  : ink,
              fontStyle: thought ? FontStyle.italic : FontStyle.normal,
              fontWeight: highContrast ? FontWeight.w800 : FontWeight.w600,
            ),
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
      constraints: BoxConstraints(maxWidth: 250 * textScale),
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

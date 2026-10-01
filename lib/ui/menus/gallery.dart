import 'package:flutter/material.dart';

import '../../sim/endings.dart';
import '../palette.dart';
import 'menu_kit.dart';

/// The endings gallery: unlocked endings in colour, locked ones as
/// silhouettes with a hint.
class EndingsGallery extends StatelessWidget {
  const EndingsGallery({super.key, required this.unlocked, required this.onClose});
  final Set<Ending> unlocked;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => MenuCard(
    width: 860,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MenuHeader(title: 'Endings', subtitle: '${unlocked.length} of ${Ending.values.length} unlocked', onClose: onClose),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in Ending.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _EndingCard(ending: e, open: unlocked.contains(e)),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

const Map<Ending, (Color, Color)> _sky = {
  Ending.harmonyFestival: (Color(0xFF2B3A67), Color(0xFFF2A65A)),
  Ending.dramaLlama: (Color(0xFF3A2440), Color(0xFFB03A48)),
  Ending.quietValley: (Color(0xFF3D6E8C), Color(0xFFB8D8A0)),
};

class _EndingCard extends StatelessWidget {
  const _EndingCard({required this.ending, required this.open});
  final Ending ending;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final info = endingInfo[ending]!;
    final (top, bottom) = _sky[ending]!;
    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: open ? [top, bottom] : const [Color(0xFF1A1822), Color(0xFF2A2733)],
        ),
        border: Border.all(color: open ? gold : const Color(0x33FFFFFF), width: open ? 2 : 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(
              child: CustomPaint(size: const Size(150, 120), painter: LlamaSilhouette(open ? Colors.white : const Color(0xFF0E0D13))),
            ),
          ),
          Text(
            open ? info.title : '? ? ?',
            style: menuText(20, weight: FontWeight.w900, color: open ? gold : Colors.white38),
          ),
          const SizedBox(height: 4),
          Text(
            open ? info.blurb : info.hint,
            style: menuText(12.5, color: open ? Colors.white : Colors.white54).copyWith(fontStyle: open ? null : FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

/// A simple standing llama, filled with one colour.
class LlamaSilhouette extends CustomPainter {
  LlamaSilhouette(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 150;
    final p = Paint()..color = color;
    canvas
      ..save()
      ..scale(s);
    canvas.drawRRect(RRect.fromLTRBR(30, 52, 112, 86, const Radius.circular(18)), p);
    canvas.drawRRect(RRect.fromLTRBR(92, 14, 110, 70, const Radius.circular(9)), p);
    canvas.drawRRect(RRect.fromLTRBR(92, 6, 128, 26, const Radius.circular(10)), p);
    canvas.drawPath(
      Path()
        ..moveTo(95, 10)
        ..lineTo(97, -4)
        ..lineTo(102, 9)
        ..close()
        ..moveTo(103, 9)
        ..lineTo(106, -3)
        ..lineTo(109, 10)
        ..close(),
      p,
    );
    for (final x in [34.0, 48.0, 90.0, 102.0]) {
      canvas.drawRRect(RRect.fromLTRBR(x, 78, x + 9, 118, const Radius.circular(4)), p);
    }
    canvas.drawCircle(const Offset(30, 60), 7, p);
    canvas.restore();
  }

  @override
  bool shouldRepaint(LlamaSilhouette old) => old.color != color;
}

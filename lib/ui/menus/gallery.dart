import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../sim/endings.dart';
import '../../sim/storybook.dart';
import '../fonts.dart';
import '../ko_text.dart';
import '../palette.dart';
import '../strings.dart';
import 'menu_kit.dart';

/// The endings gallery: unlocked endings in colour, locked ones as
/// silhouettes with a hint.
class EndingsGallery extends StatelessWidget {
  const EndingsGallery({super.key, required this.unlocked, required this.onClose, this.books = const [], this.onOpenBook});
  final Set<Ending> unlocked;
  final VoidCallback onClose;

  /// Storybooks of finished weeks, newest first.
  final List<Storybook> books;
  final ValueChanged<Storybook>? onOpenBook;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return MenuCard(
      width: 860,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MenuHeader(title: l.endings, subtitle: l.unlockedCount(unlocked.length, Ending.values.length), onClose: onClose),
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
          const SizedBox(height: 18),
          KoText(
            l.storybooksSection.toUpperCase(),
            style: Face.display.of(context, menuText(11, weight: FontWeight.w900, color: gold).copyWith(letterSpacing: 1.2)),
          ),
          const SizedBox(height: 8),
          if (books.isEmpty)
            KoText(l.noStorybooks, style: menuText(12.5, color: Colors.white54))
          else
            SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: books.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => _BookTile(book: books[i], onTap: onOpenBook == null ? null : () => onOpenBook!(books[i])),
              ),
            ),
        ],
      ),
    );
  }
}

/// One storybook on the gallery shelf: its cover picture, title and ending.
class _BookTile extends StatelessWidget {
  const _BookTile({required this.book, required this.onTap});
  final Storybook book;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final cover = book.pages.first.shot;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Row(
          children: [
            Container(
              width: 84,
              decoration: BoxDecoration(
                color: const Color(0xFF5B3A22),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFB0874A), width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: cover == null
                  ? const Icon(Icons.menu_book, color: Color(0xFFF7EFDC))
                  : Image.memory(
                      cover,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.menu_book, color: Color(0xFFF7EFDC)),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  KoText(
                    book.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Face.display.of(context, menuText(13, weight: FontWeight.w800), text: book.title),
                  ),
                  const SizedBox(height: 4),
                  KoText(l.endingName(book.ending), style: menuText(11.5, color: gold)),
                  KoText(DateFormat.yMMMd(l.localeName).format(book.finishedAt.toLocal()), style: menuText(11, color: Colors.white54)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
    final l = L10n.of(context);
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
          KoText(
            open ? l.endingName(ending) : l.lockedTitle,
            style: Face.display.of(context, menuText(20, weight: FontWeight.w900, color: open ? gold : Colors.white38)),
          ),
          const SizedBox(height: 4),
          KoText(
            open ? l.endingBlurb(ending.name) : l.endingHint(ending.name),
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

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../sim/storybook.dart';
import '../fonts.dart';
import '../ko_text.dart';
import '../portrait.dart';
import '../strings.dart';
import 'gallery.dart';

const String _display = 'Hoefler Text';
const String _body = 'Baskerville';

/// Serif faces on macOS; Korean pages are set in Gowun Batang instead (see
/// [Face.serif]).
const List<String> _fallback = ['Georgia', 'Times New Roman'];

const Color _paper = Color(0xFFF7EFDC);
const Color _paperEdge = Color(0xFFE6D6B4);
const Color _inkBrown = Color(0xFF3B2A1A);
const Color _sepia = Color(0xFF7A5634);
const Color _gilt = Color(0xFFB0874A);

TextStyle _serif(
  BuildContext context,
  double size, {
  String family = _body,
  FontWeight weight = FontWeight.w400,
  Color color = _inkBrown,
  FontStyle? style,
  double height = 1.5,
}) => Face.serif.of(
  context,
  TextStyle(
    fontFamily: family,
    fontFamilyFallback: _fallback,
    fontSize: size,
    fontWeight: weight,
    color: color,
    fontStyle: style,
    height: height,
  ),
);

const List<String> _nth = ['first', 'second', 'third', 'fourth', 'fifth'];

/// The storybook: a two-page spread per page (picture left, text right),
/// turned with ←/→, the arrows or a click on either page; Esc closes it.
/// Pages still being written show their text as it streams in.
class StorybookView extends StatefulWidget {
  const StorybookView({super.key, required this.book, required this.onClose, this.changes, this.reducedMotion = false, this.onClick});
  final Storybook book;
  final VoidCallback onClose;

  /// Fires while pages are being written, so they redraw.
  final Listenable? changes;
  final bool reducedMotion;
  final VoidCallback? onClick;

  @override
  State<StorybookView> createState() => StorybookViewState();
}

class StorybookViewState extends State<StorybookView> with TickerProviderStateMixin {
  final FocusNode _focus = FocusNode(debugLabel: 'storybook');
  late final AnimationController _turn = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  int page = 0;
  int _from = 0;

  int get count => widget.book.pages.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _turn.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// Turns to [to], animating unless motion is reduced.
  void turnTo(int to) {
    if (to < 0 || to >= count || to == page) return;
    widget.onClick?.call();
    setState(() {
      _from = page;
      page = to;
    });
    if (widget.reducedMotion) {
      _turn.value = 1;
    } else {
      _turn.forward(from: 0);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.pageDown) {
      turnTo(page + 1);
    } else if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.pageUp) {
      turnTo(page - 1);
    } else if (k == LogicalKeyboardKey.escape) {
      if (e is KeyDownEvent) widget.onClose();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: ColoredBox(
        color: const Color(0xE6120E16),
        child: LayoutBuilder(
          builder: (context, box) {
            final width = math.min(box.maxWidth - 160, (box.maxHeight - 120) * 1.5).clamp(480.0, 1180.0);
            final height = width / 1.5;
            return Stack(
              children: [
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Arrow(icon: Icons.chevron_left, tooltip: l.tipPrevPage, onTap: page > 0 ? () => turnTo(page - 1) : null),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: width,
                        height: height,
                        child: ListenableBuilder(
                          listenable: Listenable.merge([_turn, if (widget.changes != null) widget.changes!]),
                          builder: (context, _) => _spread(l, width, height),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _Arrow(icon: Icons.chevron_right, tooltip: l.tipNextPage, onTap: page < count - 1 ? () => turnTo(page + 1) : null),
                    ],
                  ),
                ),
                Positioned(
                  top: 18,
                  right: 18,
                  child: IconButton(
                    tooltip: l.tipCloseBook,
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, color: Colors.white70, size: 28),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 22,
                  child: _Dots(count: count, page: page, written: [for (final p in widget.book.pages) p.written], onTap: turnTo),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _spread(L10n l, double width, double height) {
    final half = width / 2;
    final t = Curves.easeInOut.transform(_turn.value);
    final turning = _turn.isAnimating && _from != page;
    final forward = page > _from;
    Widget left(int i) => _Half(left: true, child: _leftOf(l, i));
    Widget right(int i) => _Half(left: false, child: _rightOf(l, i));
    // A forward turn lifts the old right page over the spine onto the left;
    // its back is the new left page. A backward turn mirrors it.
    final baseLeft = turning ? (forward ? _from : page) : page;
    final baseRight = turning ? (forward ? page : _from) : page;
    Widget? leaf;
    if (turning) {
      final firstHalf = t < 0.5;
      final angle = (firstHalf ? t : 1 - t) * math.pi;
      final shade = (math.sin(angle) * 0.35).clamp(0.0, 0.35);
      final Widget face;
      final bool onRight;
      if (forward) {
        onRight = firstHalf;
        face = firstHalf ? right(_from) : left(page);
      } else {
        onRight = !firstHalf;
        face = firstHalf ? left(_from) : right(page);
      }
      final matrix = Matrix4.identity()
        ..setEntry(3, 2, 0.0011)
        ..rotateY(onRight ? -angle : angle);
      leaf = Positioned(
        left: onRight ? half : 0,
        width: half,
        top: 0,
        bottom: 0,
        child: Transform(
          alignment: onRight ? Alignment.centerLeft : Alignment.centerRight,
          transform: matrix,
          child: Stack(
            fit: StackFit.expand,
            children: [
              face,
              IgnorePointer(
                child: ColoredBox(color: Colors.black.withValues(alpha: shade)),
              ),
            ],
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(blurRadius: 40, spreadRadius: 4, color: Color(0x99000000), offset: Offset(0, 14))],
        color: const Color(0xFF5B3A22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              width: half - 7,
              top: 0,
              bottom: 0,
              child: GestureDetector(onTap: () => turnTo(page - 1), child: left(baseLeft)),
            ),
            Positioned(
              left: half - 7,
              right: 0,
              top: 0,
              bottom: 0,
              child: GestureDetector(onTap: () => turnTo(page + 1), child: right(baseRight)),
            ),
            const Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: _SpinePainter())),
            ),
            ?leaf,
          ],
        ),
      ),
    );
  }

  Widget _leftOf(L10n l, int i) {
    final p = widget.book.pages[i];
    final caption = switch (p.kind) {
      PageKind.cover => l.storySeries,
      PageKind.day => l.storyDayCaption(p.day!, l.countdownFor(p.day!)),
      PageKind.ending => l.endingName(widget.book.ending),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 30, 30, 22),
      child: Column(
        children: [
          const Spacer(),
          AspectRatio(
            aspectRatio: 16 / 10,
            child: _Illustration(png: p.shot, star: pageStar(p)),
          ),
          const SizedBox(height: 14),
          KoText(
            caption,
            textAlign: TextAlign.center,
            style: _serif(context, 15, family: _display, style: FontStyle.italic, color: _sepia),
          ),
          const Spacer(),
          if (i > 0) _PageNumber(i * 2),
        ],
      ),
    );
  }

  Widget _rightOf(L10n l, int i) {
    final p = widget.book.pages[i];
    if (p.kind == PageKind.cover) return _cover(l);
    final title = p.kind == PageKind.day ? l.storyDayTitle(_nth[(p.day! - 1).clamp(0, 4)]) : l.storyEndingTitle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 34, 40, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KoText(
            title,
            textAlign: TextAlign.center,
            style: _serif(context, 26, family: _display, weight: FontWeight.w600, style: FontStyle.italic),
          ),
          const _Flourish(),
          const SizedBox(height: 10),
          Expanded(
            child: p.text != null
                ? SingleChildScrollView(child: DropCapText(p.text!, style: _serif(context, 18.5)))
                : _Writing(draft: p.draft, pulse: _pulse, waiting: l.storyQuill),
          ),
          if (p.kind == PageKind.ending && p.text != null)
            KoText(
              l.theEnd,
              textAlign: TextAlign.center,
              style: _serif(context, 18, family: _display, style: FontStyle.italic, color: _sepia),
            ),
          const SizedBox(height: 6),
          _PageNumber(i * 2 + 1),
        ],
      ),
    );
  }

  Widget _cover(L10n l) {
    final b = widget.book;
    final written = b.writtenCount, total = b.textPages;
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 50, 40, 30),
      child: Column(
        children: [
          const Spacer(),
          KoText(
            b.title,
            textAlign: TextAlign.center,
            style: _serif(context, 38, family: _display, weight: FontWeight.w600, style: FontStyle.italic, height: 1.2),
          ),
          const SizedBox(height: 16),
          const _Flourish(width: 180),
          const SizedBox(height: 16),
          KoText(
            l.endingName(b.ending),
            textAlign: TextAlign.center,
            style: _serif(context, 18, family: _display, color: _sepia),
          ),
          const Spacer(),
          KoText(
            written < total ? l.storyStillWriting(written, total) : l.storyBegin,
            textAlign: TextAlign.center,
            style: _serif(context, 14, style: FontStyle.italic, color: _sepia),
          ),
        ],
      ),
    );
  }
}

/// A paragraph whose first letter drops three lines deep; the lines beside
/// it wrap short and the rest run full width.
class DropCapText extends StatelessWidget {
  const DropCapText(this.text, {super.key, required this.style, this.lines = 3});
  final String text;
  final TextStyle style;
  final int lines;

  @override
  Widget build(BuildContext context) {
    final trimmed = text.trim();
    // Measure with the same merged style the Text widgets below use.
    final style = DefaultTextStyle.of(context).style.merge(this.style);
    if (trimmed.length < 2) return KoText(trimmed, style: style);
    final chars = trimmed.characters;
    final cap = chars.first;
    final rest = keepWords(chars.skip(1).toString(), korean: koreanUi(context));
    return LayoutBuilder(
      builder: (context, box) {
        final scaler = MediaQuery.textScalerOf(context);
        final lineHeight = scaler.scale(style.fontSize!) * (style.height ?? 1.2);
        final korean = koreanUi(context) || hasHangul(cap);
        final capStyle = style.copyWith(
          fontFamily: korean ? null : _display,
          fontWeight: korean ? FontWeight.w700 : null,
          fontSize: lineHeight * lines * 0.92,
          height: 1.0,
          color: const Color(0xFF8C3B2A),
        );
        final capPainter = TextPainter(
          text: TextSpan(text: cap, style: capStyle),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
        )..layout();
        final capWidth = capPainter.width + 8;
        capPainter.dispose();
        final narrow = box.maxWidth - capWidth;
        final body = TextPainter(
          text: TextSpan(text: rest, style: style),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
        )..layout(maxWidth: narrow);
        final metrics = body.computeLineMetrics();
        var split = rest.length;
        if (metrics.length > lines) {
          final line = metrics[lines - 1];
          final middle = line.baseline - line.ascent / 2;
          split = body.getLineBoundary(body.getPositionForOffset(Offset(narrow - 1, middle))).end;
        }
        body.dispose();
        final head = rest.substring(0, split).trimRight();
        final tail = rest.substring(split).trimLeft();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: capWidth,
                  child: KoText(cap, style: capStyle),
                ),
                Expanded(child: KoText(head, style: style)),
              ],
            ),
            if (tail.isNotEmpty) KoText(tail, style: style),
          ],
        );
      },
    );
  }
}

class _Writing extends StatelessWidget {
  const _Writing({required this.draft, required this.pulse, required this.waiting});
  final String draft;
  final Animation<double> pulse;
  final String waiting;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: pulse,
    builder: (context, _) {
      final glow = 0.35 + 0.35 * (0.5 + 0.5 * math.sin(pulse.value * 2 * math.pi));
      if (draft.trim().isNotEmpty) {
        return SingleChildScrollView(
          reverse: true,
          child: KoText.rich(
            TextSpan(
              children: [
                TextSpan(text: draft.trim()),
                TextSpan(
                  text: ' ✒',
                  style: TextStyle(color: _sepia.withValues(alpha: glow)),
                ),
              ],
            ),
            style: _serif(context, 18.5),
          ),
        );
      }
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_edu, size: 44, color: _sepia.withValues(alpha: glow + 0.2)),
          const SizedBox(height: 12),
          KoText(
            waiting,
            textAlign: TextAlign.center,
            style: _serif(context, 16, style: FontStyle.italic, color: _sepia),
          ),
          const SizedBox(height: 18),
          for (final w in const [0.92, 0.84, 0.88, 0.6])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: FractionallySizedBox(
                widthFactor: w,
                child: Container(
                  height: 9,
                  decoration: BoxDecoration(
                    color: _paperEdge.withValues(alpha: glow + 0.3),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _Half extends StatelessWidget {
  const _Half({required this.child, required this.left});
  final Widget child;
  final bool left;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.horizontal(left: Radius.circular(left ? 6 : 0), right: Radius.circular(left ? 0 : 6)),
    child: CustomPaint(
      painter: _PaperPainter(left: left),
      child: child,
    ),
  );
}

/// Warm paper with a faint grain, darker toward the edges and the spine.
class _PaperPainter extends CustomPainter {
  const _PaperPainter({required this.left});
  final bool left;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(left ? 0.2 : -0.2, -0.1),
          radius: 1.1,
          colors: const [_paper, Color(0xFFEFE2C3), _paperEdge],
          stops: const [0.0, 0.75, 1.0],
        ).createShader(rect),
    );
    final r = math.Random(left ? 11 : 17);
    final dot = Paint();
    for (var i = 0; i < 1400; i++) {
      dot.color = (r.nextBool() ? const Color(0xFF8A6A3F) : Colors.white).withValues(alpha: 0.03 + r.nextDouble() * 0.05);
      canvas.drawCircle(Offset(r.nextDouble() * size.width, r.nextDouble() * size.height), 0.4 + r.nextDouble() * 0.9, dot);
    }
    final fibre = Paint()
      ..color = const Color(0x0F6B4A2A)
      ..strokeWidth = 0.6;
    for (var i = 0; i < 70; i++) {
      final o = Offset(r.nextDouble() * size.width, r.nextDouble() * size.height);
      final a = r.nextDouble() * math.pi;
      final l = 6 + r.nextDouble() * 14;
      canvas.drawLine(o, o + Offset(math.cos(a) * l, math.sin(a) * l), fibre);
    }
  }

  @override
  bool shouldRepaint(_PaperPainter old) => old.left != left;
}

class _SpinePainter extends CustomPainter {
  const _SpinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final rect = Rect.fromLTWH(x - 26, 0, 52, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x00000000), Color(0x33000000), Color(0x55000000), Color(0x33000000), Color(0x00000000)],
          stops: [0, 0.4, 0.5, 0.6, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SpinePainter old) => false;
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.png, this.star});
  final Uint8List? png;

  /// The llama whose portrait stands in for a missing picture.
  final String? star;

  Widget get _painted => star == null
      ? const CustomPaint(painter: _PaintedValley(), size: Size.infinite)
      : LayoutBuilder(
          builder: (context, box) => Stack(
            alignment: Alignment.center,
            children: [
              const CustomPaint(painter: _PaintedValley(llama: false), size: Size.infinite),
              LlamaPortrait(star!, size: box.maxHeight * 0.78),
            ],
          ),
        );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: const Color(0xFFFBF6EA),
      border: Border.all(color: _gilt, width: 2),
      boxShadow: const [BoxShadow(blurRadius: 8, color: Color(0x33000000), offset: Offset(0, 3))],
    ),
    child: Container(
      decoration: BoxDecoration(border: Border.all(color: _sepia.withValues(alpha: 0.6))),
      child: ClipRect(
        child: png == null
            ? _painted
            : ColorFiltered(
                // A touch of warmth, so the render sits on the paper like a print.
                colorFilter: const ColorFilter.matrix([
                  0.95, 0.08, 0.02, 0, 6, //
                  0.04, 0.92, 0.04, 0, 4,
                  0.02, 0.06, 0.82, 0, 0,
                  0, 0, 0, 1, 0,
                ]),
                child: SizedBox.expand(
                  child: Image.memory(
                    png!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, _, _) => _painted,
                  ),
                ),
              ),
      ),
    ),
  );
}

/// The picture for a page that has none: hills, a sun and a llama.
class _PaintedValley extends CustomPainter {
  const _PaintedValley({this.llama = true});
  final bool llama;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF6D9A8), Color(0xFFEFC58E)],
        ).createShader(rect),
    );
    canvas.drawCircle(Offset(size.width * 0.75, size.height * 0.3), size.height * 0.1, Paint()..color = const Color(0xFFF2A65A));
    Path hill(double y, double amp, double phase) {
      final p = Path()..moveTo(0, size.height);
      for (var x = 0.0; x <= size.width; x += 8) {
        p.lineTo(x, size.height * y + math.sin(x / size.width * math.pi * 2 + phase) * amp);
      }
      return p
        ..lineTo(size.width, size.height)
        ..close();
    }

    canvas.drawPath(hill(0.62, size.height * 0.05, 0.5), Paint()..color = const Color(0xFFA8C686));
    canvas.drawPath(hill(0.74, size.height * 0.04, 2.1), Paint()..color = const Color(0xFF7FA866));
    if (!llama) return;
    canvas.save();
    canvas.translate(size.width * 0.32, size.height * 0.5);
    LlamaSilhouette(const Color(0xFF5B4632)).paint(canvas, Size(size.width * 0.3, size.width * 0.24));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PaintedValley old) => old.llama != llama;
}

class _Flourish extends StatelessWidget {
  const _Flourish({this.width = 120});
  final double width;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: width / 2 - 10, height: 1, color: _gilt),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.local_florist, size: 12, color: _gilt),
        ),
        Container(width: width / 2 - 10, height: 1, color: _gilt),
      ],
    ),
  );
}

class _PageNumber extends StatelessWidget {
  const _PageNumber(this.n);
  final int n;

  @override
  Widget build(BuildContext context) => KoText(
    '— $n —',
    textAlign: TextAlign.center,
    style: _serif(context, 12.5, color: _sepia),
  );
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton.filled(
    tooltip: tooltip,
    onPressed: onTap,
    iconSize: 30,
    style: IconButton.styleFrom(backgroundColor: const Color(0x33FFFFFF), disabledBackgroundColor: const Color(0x11FFFFFF)),
    icon: Icon(icon, color: onTap == null ? Colors.white24 : Colors.white),
  );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.page, required this.written, required this.onTap});
  final int count;
  final int page;
  final List<bool> written;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < count; i++)
        GestureDetector(
          onTap: () => onTap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == page ? 22 : 9,
            height: 9,
            decoration: BoxDecoration(
              color: i == page ? _gilt : (written[i] ? Colors.white54 : Colors.white24),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
    ],
  );
}

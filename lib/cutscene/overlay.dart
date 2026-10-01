import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../render/stage.dart';
import '../ui/bubble_layout.dart';
import '../ui/bubbles.dart';
import '../ui/fonts.dart';
import '../ui/ko_text.dart';
import '../ui/palette.dart';
import 'timeline.dart';

/// Draws a playing cutscene over the scene: letterbox bars, the fade,
/// subtitles, dream and song bubbles pinned to the world, title cards and
/// the skip hint. A click anywhere skips.
class CutsceneOverlay extends StatelessWidget {
  const CutsceneOverlay({
    super.key,
    required this.player,
    required this.stage,
    required this.size,
    required this.onSkip,
    this.textScale = 1,
    this.highContrast = false,
    this.wall = 0,
  });

  final CutscenePlayer player;
  final VillageStage stage;
  final Size size;
  final VoidCallback onSkip;
  final double textScale;
  final bool highContrast;
  final double wall;

  static final Expando<_DreamSpacing> _spacing = Expando();

  @override
  Widget build(BuildContext context) {
    final bar = size.height * 0.11 * player.letterbox;
    final dots = '.' * (1 + (wall * 3).floor() % 3);
    final spacing = _spacing[player] ??= _DreamSpacing();
    final children = <Widget>[];
    final leaders = <(Offset, Offset, Color)>[];
    final l = L10n.of(context);
    final korean = koreanUi(context);
    final offsets = _stackDreams(spacing, bar, dots, l, korean);
    for (final (cue, alpha) in player.texts) {
      final text = cue.text ?? dots;
      switch (cue.kind) {
        case TextKind.subtitle:
          children.add(
            Positioned(
              left: 40,
              right: 40,
              bottom: bar + 22,
              child: Opacity(
                opacity: alpha,
                child: Center(
                  child: _Subtitle(speaker: cue.speaker, text: text, scale: textScale, highContrast: highContrast, korean: korean),
                ),
              ),
            ),
          );
        case TextKind.dream || TextKind.song:
          final anchor = cue.anchor;
          final at = anchor == null ? null : stage.toScreen(anchor, size);
          if (at == null) continue;
          final (dx, dy) = offsets[cue] ?? (0.0, 0.0);
          if (dx * dx + dy * dy > 16) {
            final color = cue.speaker == null || highContrast ? Colors.white : accentOf(cue.speaker!);
            leaders.add((Offset(at.dx + dx, at.dy - dy), at, color.withValues(alpha: color.a * alpha)));
          }
          children.add(
            Positioned(
              left: at.dx + dx,
              top: at.dy - dy,
              child: FractionalTranslation(
                translation: const Offset(-0.5, -1),
                child: Opacity(
                  opacity: alpha,
                  child: _Dream(
                    speaker: cue.speaker,
                    text: _dreamText(cue, text),
                    scale: textScale,
                    highContrast: highContrast,
                    song: cue.kind == TextKind.song,
                    korean: korean,
                  ),
                ),
              ),
            ),
          );
        case TextKind.title:
          children.add(
            Positioned.fill(
              child: Opacity(
                opacity: alpha,
                child: Center(
                  child: _Title(title: text, subtitle: cue.subtitle, scale: textScale, korean: korean),
                ),
              ),
            ),
          );
      }
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onSkip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (player.fade > 0)
            Positioned.fill(
              child: ColoredBox(color: Colors.black.withValues(alpha: player.fade)),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: bar,
            child: const ColoredBox(color: Colors.black),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bar,
            child: const ColoredBox(color: Colors.black),
          ),
          if (leaders.isNotEmpty) Positioned.fill(child: CustomPaint(painter: LeaderLines(leaders))),
          ...children,
          Positioned(
            right: 20,
            bottom: bar > 30 ? bar / 2 - 9 : 14,
            child: KoText(
              player.waiting ? '${l.llamasThinking}$dots   ·   ${l.skipHint}' : l.skipHint,
              style: const TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Lays out the dream and song bubbles like speech bubbles, so the
  /// festival's singers and the night's dreamers never cover each other or
  /// the subtitle, and stay between the letterbox bars.
  Map<TextCue, (double, double)> _stackDreams(_DreamSpacing spacing, double bar, String dots, L10n l, bool korean) {
    final requests = <BubbleRequest>[];
    final byId = <String, TextCue>{};
    final keepClear = <Box>[];
    for (final (cue, _) in player.texts) {
      final text = cue.text ?? dots;
      if (cue.kind == TextKind.subtitle) {
        final sub = spacing.subtitleSize(cue.speaker, text, textScale, math.max(0.0, size.width - 80), korean);
        keepClear.add(Box((size.width - sub.width) / 2, size.height - bar - 22 - sub.height, sub.width, sub.height));
        continue;
      }
      if (cue.kind != TextKind.dream && cue.kind != TextKind.song) continue;
      final anchor = cue.anchor;
      final at = anchor == null ? null : stage.toScreen(anchor, size);
      if (at == null) continue;
      final b = spacing.dreamSize(cue, _dreamText(cue, text), textScale, highContrast, _dreamLabel(cue, l), korean);
      final id = '${identityHashCode(cue)}';
      byId[id] = cue;
      requests.add(BubbleRequest(id, Box(at.dx - b.width / 2, at.dy - b.height, b.width, b.height)));
    }
    if (requests.isEmpty) return const {};
    final laid = spacing.smoother.step(
      layoutBubbles(requests, keepClear: keepClear, screen: Box(8, bar + 8, size.width - 16, size.height - 2 * bar - 16)),
      spacing.tick(wall),
    );
    return {for (final MapEntry(:key, :value) in laid.entries) byId[key]!: value};
  }
}

String _dreamText(TextCue cue, String text) => cue.kind == TextKind.song && cue.text != null ? '♪ $text ♪' : text;

/// The name over a dream or song bubble: "Pip dreams…", or the singer.
String? _dreamLabel(TextCue cue, L10n l) {
  final speaker = cue.speaker;
  if (speaker == null) return null;
  return cue.kind == TextKind.song ? speaker : l.dreams(speaker);
}

/// Measured dream, song and subtitle sizes, and the eased dream offsets.
class _DreamSpacing {
  final BubbleSmoother smoother = BubbleSmoother();
  final Map<(TextCue, String, double, bool, String?, bool), Size> _dreams = {};
  final Map<(String?, String, double, double, bool), Size> _subtitles = {};
  double? _lastWall;

  double tick(double wall) {
    final dt = _lastWall == null ? 1.0 : (wall - _lastWall!).clamp(0.0, 1.0);
    _lastWall = wall;
    return dt;
  }

  Size dreamSize(TextCue cue, String text, double scale, bool highContrast, String? label, bool korean) {
    if (_dreams.length > 64) _dreams.clear();
    return _dreams.putIfAbsent((cue, text, scale, highContrast, label, korean), () {
      final song = cue.kind == TextKind.song;
      final border = highContrast ? 6.0 : 4.0;
      final inner = 300 * scale - 32 - border;
      final body = TextPainter(
        text: TextSpan(
          text: keepWords(text, korean: korean),
          style: _dreamStyle(scale, highContrast, song: song, korean: korean, text: text),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: inner);
      var width = body.width, height = body.height;
      body.dispose();
      if (label != null) {
        final painter = TextPainter(
          text: TextSpan(
            text: keepWords(label, korean: korean),
            style: _speakerStyle(scale, korean),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: inner);
        width = math.max(width, painter.width);
        height += painter.height;
        painter.dispose();
      }
      return Size(width + 32 + border, height + 22 + border + (song ? 0 : 3 + 12 + 3 + 7));
    });
  }

  Size subtitleSize(String? speaker, String text, double scale, double maxWidth, bool korean) {
    if (_subtitles.length > 16) _subtitles.clear();
    return _subtitles.putIfAbsent((speaker, text, scale, maxWidth, korean), () {
      final painter = TextPainter(
        text: keepWordsSpan(
          TextSpan(
            children: [
              if (speaker != null)
                TextSpan(
                  text: '$speaker  ',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              TextSpan(text: text),
            ],
            style: _subtitleStyle(scale, korean),
          ),
          korean: korean,
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: math.max(0.0, math.min(820 * scale, maxWidth) - 36));
      final size = Size(painter.width + 36 + 4, painter.height + 20 + 4);
      painter.dispose();
      return size;
    });
  }
}

TextStyle _subtitleStyle(double scale, bool korean) => Face.ui.on(
  TextStyle(fontSize: 19 * scale, height: 1.35, color: Colors.white, fontWeight: FontWeight.w600),
  korean: korean,
);

TextStyle _speakerStyle(double scale, bool korean) => Face.ui.on(
  TextStyle(fontSize: 11 * scale, fontWeight: FontWeight.w900),
  korean: korean,
);

TextStyle _dreamStyle(double scale, bool highContrast, {required bool song, required bool korean, required String text}) => Face.display.on(
  TextStyle(
    fontSize: 14 * scale,
    height: 1.3,
    fontStyle: song ? FontStyle.normal : FontStyle.italic,
    fontWeight: highContrast ? FontWeight.w800 : FontWeight.w600,
    color: highContrast ? Colors.black : ink,
  ),
  korean: korean,
  text: text,
);

class _Subtitle extends StatelessWidget {
  const _Subtitle({required this.speaker, required this.text, required this.scale, required this.highContrast, required this.korean});
  final String? speaker;
  final String text;
  final double scale;
  final bool highContrast;
  final bool korean;

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(maxWidth: 820 * scale),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    decoration: BoxDecoration(
      color: highContrast ? Colors.black : const Color(0xB0101018),
      borderRadius: BorderRadius.circular(12),
      border: highContrast ? Border.all(color: Colors.white, width: 2) : null,
    ),
    child: KoText.rich(
      TextSpan(
        children: [
          if (speaker != null)
            TextSpan(
              text: '$speaker  ',
              style: TextStyle(color: highContrast ? gold : accentOf(speaker!), fontWeight: FontWeight.w900),
            ),
          TextSpan(text: text),
        ],
      ),
      textAlign: TextAlign.center,
      style: _subtitleStyle(scale, korean),
    ),
  );
}

class _Dream extends StatelessWidget {
  const _Dream({
    required this.speaker,
    required this.text,
    required this.scale,
    required this.highContrast,
    required this.song,
    required this.korean,
  });
  final String? speaker;
  final String text;
  final double scale;
  final bool highContrast;
  final bool song;
  final bool korean;

  @override
  Widget build(BuildContext context) {
    final fill = highContrast
        ? Colors.white
        : song
        ? const Color(0xF5FFF6D8)
        : const Color(0xEEE6E0FF);
    final edge = highContrast
        ? Colors.black
        : speaker == null
        ? const Color(0xFFB9B0E0)
        : accentOf(speaker!);
    Widget puff(double d) => Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: edge, width: 1.5),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: 300 * scale),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: edge, width: highContrast ? 3 : 2),
            boxShadow: [BoxShadow(blurRadius: 24, color: (song ? gold : const Color(0xFF9D8CFF)).withValues(alpha: 0.45))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (speaker != null)
                KoText(
                  song ? speaker! : L10n.of(context).dreams(speaker!),
                  style: _speakerStyle(scale, korean).copyWith(color: highContrast ? Colors.black : edge),
                ),
              KoText(
                text,
                textAlign: TextAlign.center,
                style: _dreamStyle(scale, highContrast, song: song, korean: korean, text: text),
              ),
            ],
          ),
        ),
        if (!song) ...[const SizedBox(height: 3), puff(12), const SizedBox(height: 3), puff(7)],
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.title, required this.subtitle, required this.scale, required this.korean});
  final String title;
  final String? subtitle;
  final double scale;
  final bool korean;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      KoText(
        title,
        textAlign: TextAlign.center,
        style: Face.display.on(
          TextStyle(fontSize: 66 * scale, fontWeight: FontWeight.w900, color: gold, letterSpacing: 1, shadows: _glow),
          korean: korean,
          text: title,
        ),
      ),
      if (subtitle != null)
        KoText(
          subtitle!,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20 * scale, fontWeight: FontWeight.w700, color: Colors.white, shadows: _glow),
        ),
    ],
  );
}

const List<Shadow> _glow = [Shadow(blurRadius: 18, color: Color(0xCC000000)), Shadow(blurRadius: 4, color: Color(0x99000000))];

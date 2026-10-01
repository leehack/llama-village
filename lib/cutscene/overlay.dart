import 'package:flutter/material.dart';

import '../render/stage.dart';
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

  @override
  Widget build(BuildContext context) {
    final bar = size.height * 0.11 * player.letterbox;
    final dots = '.' * (1 + (wall * 3).floor() % 3);
    final children = <Widget>[];
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
                  child: _Subtitle(speaker: cue.speaker, text: text, scale: textScale, highContrast: highContrast),
                ),
              ),
            ),
          );
        case TextKind.dream || TextKind.song:
          final anchor = cue.anchor;
          final at = anchor == null ? null : stage.toScreen(anchor, size);
          if (at == null) continue;
          children.add(
            Positioned(
              left: at.dx,
              top: at.dy,
              child: FractionalTranslation(
                translation: const Offset(-0.5, -1),
                child: Opacity(
                  opacity: alpha,
                  child: _Dream(
                    speaker: cue.speaker,
                    text: cue.kind == TextKind.song && cue.text != null ? '♪ $text ♪' : text,
                    scale: textScale,
                    highContrast: highContrast,
                    song: cue.kind == TextKind.song,
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
                  child: _Title(title: text, subtitle: cue.subtitle, scale: textScale),
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
          ...children,
          Positioned(
            right: 20,
            bottom: bar > 30 ? bar / 2 - 9 : 14,
            child: Text(
              player.waiting ? 'the llamas are thinking$dots   ·   Esc / Space / click to skip' : 'Esc / Space / click to skip',
              style: const TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Subtitle extends StatelessWidget {
  const _Subtitle({required this.speaker, required this.text, required this.scale, required this.highContrast});
  final String? speaker;
  final String text;
  final double scale;
  final bool highContrast;

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(maxWidth: 820 * scale),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    decoration: BoxDecoration(
      color: highContrast ? Colors.black : const Color(0xB0101018),
      borderRadius: BorderRadius.circular(12),
      border: highContrast ? Border.all(color: Colors.white, width: 2) : null,
    ),
    child: Text.rich(
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
      style: TextStyle(fontSize: 19 * scale, height: 1.35, color: Colors.white, fontWeight: FontWeight.w600),
    ),
  );
}

class _Dream extends StatelessWidget {
  const _Dream({required this.speaker, required this.text, required this.scale, required this.highContrast, required this.song});
  final String? speaker;
  final String text;
  final double scale;
  final bool highContrast;
  final bool song;

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
                Text(
                  song ? speaker! : '$speaker dreams…',
                  style: TextStyle(fontSize: 11 * scale, fontWeight: FontWeight.w900, color: highContrast ? Colors.black : edge),
                ),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14 * scale,
                  height: 1.3,
                  fontStyle: song ? FontStyle.normal : FontStyle.italic,
                  fontWeight: highContrast ? FontWeight.w800 : FontWeight.w600,
                  color: highContrast ? Colors.black : ink,
                ),
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
  const _Title({required this.title, required this.subtitle, required this.scale});
  final String title;
  final String? subtitle;
  final double scale;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 66 * scale, fontWeight: FontWeight.w900, color: gold, letterSpacing: 1, shadows: _glow),
      ),
      if (subtitle != null)
        Text(
          subtitle!,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20 * scale, fontWeight: FontWeight.w700, color: Colors.white, shadows: _glow),
        ),
    ],
  );
}

const List<Shadow> _glow = [Shadow(blurRadius: 18, color: Color(0xCC000000)), Shadow(blurRadius: 4, color: Color(0x99000000))];

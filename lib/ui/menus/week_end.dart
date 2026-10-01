import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../sim/endings.dart';
import '../../sim/influence.dart';
import '../palette.dart';
import '../portrait.dart';
import '../strings.dart';
import 'menu_kit.dart';
import '../fonts.dart';

/// One card per llama with its epilogue line ("…" while it is written).
class EpilogueView extends StatelessWidget {
  const EpilogueView({super.key, required this.lines, required this.onContinue, required this.wall, this.textScale = 1});
  final Map<String, String?> lines;
  final VoidCallback? onContinue;
  final double wall;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final dots = '.' * (1 + (wall * 3).floor() % 3);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l.afterTheFestival,
          style: Face.display.of(context, menuText(34, weight: FontWeight.w900, color: gold).copyWith(shadows: textShadow)),
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final MapEntry(key: name, value: line) in lines.entries)
              Container(
                width: 240 * textScale,
                height: 190 * textScale,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xF0221F2B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border(top: BorderSide(color: accentOf(name), width: 6)),
                  boxShadow: const [BoxShadow(blurRadius: 20, color: Color(0x55000000))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        LlamaPortrait(name, size: 46 * textScale),
                        const SizedBox(width: 10),
                        Text(
                          name,
                          style: Face.display.of(context, menuText(19 * textScale, weight: FontWeight.w900, color: accentOf(name))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: AnimatedOpacity(
                        opacity: line == null ? 0.6 : 1,
                        duration: const Duration(milliseconds: 400),
                        child: Text(line ?? dots, style: menuText(14 * textScale, height: 1.4).copyWith(fontStyle: FontStyle.italic)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: 320,
          child: MenuButton(
            label: onContinue == null ? l.remembering : l.seeWeek,
            icon: Icons.arrow_forward,
            primary: true,
            onTap: onContinue,
          ),
        ),
      ],
    );
  }
}

/// The week's numbers, the ending and whether it was newly unlocked.
class ResultsView extends StatelessWidget {
  const ResultsView({
    super.key,
    required this.verdict,
    required this.influence,
    required this.newlyUnlocked,
    required this.onMenu,
    this.onStory,
    this.storyStatus,
  });
  final EndingVerdict verdict;
  final Influence influence;
  final bool newlyUnlocked;
  final VoidCallback onMenu;

  /// Opens the week's storybook.
  final VoidCallback? onStory;

  /// How far the storybook is ("4 of 6 pages written").
  final String? storyStatus;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final i = influence;
    final beliefs = i.falseBeliefs;
    return MenuCard(
      width: 820,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: newlyUnlocked ? gold : const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(20)),
            child: Text(
              (newlyUnlocked ? l.endingUnlocked : l.endingAlready).toUpperCase(),
              style: menuText(11, weight: FontWeight.w900, color: newlyUnlocked ? ink : Colors.white70).copyWith(letterSpacing: 1.2),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.endingName(verdict.ending),
            style: Face.display.of(context, menuText(40, weight: FontWeight.w900, color: gold)),
          ),
          Text(l.endingBlurb(verdict.ending.name), style: menuText(14, color: Colors.white70)),
          const SizedBox(height: 6),
          Text(l.why(verdict.why.map(l.reasonOf).join('; ')), style: menuText(12.5, color: Colors.white54)),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Stat(l.statHarmony, l.harmonyValue(l.number(i.harmony)), l.harmonyNote),
                    _Meter(value: (i.harmony + 10) / 20),
                    const SizedBox(height: 12),
                    _Stat(
                      l.statTruth,
                      beliefs.isEmpty ? l.noFalseBeliefs : l.falseBeliefs(beliefs.length),
                      beliefs.isEmpty
                          ? l.everyRumourRight
                          : beliefs.take(3).map((b) => '${b.believer}: ${l.factLabel(b.factId, b.short)}').join(' · ') +
                                (beliefs.length > 3 ? ' · ${l.moreBeliefs(beliefs.length - 3)}' : ''),
                    ),
                    const SizedBox(height: 12),
                    _Stat(l.statPipMo, l.pipMoArc(i.pipMo.name), l.pipMoNote),
                    const SizedBox(height: 12),
                    _Stat(l.statBramble, l.brambleArc(i.bramble.name), l.brambleNote),
                    const SizedBox(height: 12),
                    _Stat(l.statFestival, i.festivalWinner == null ? l.noWinner : l.wonBell(i.festivalWinner!), ''),
                  ],
                ),
              ),
              const SizedBox(width: 28),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Stat(l.statTrust, l.number(i.meanTrust), l.trustNote),
                    const SizedBox(height: 8),
                    for (final MapEntry(key: n, value: t) in i.dashTrust.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 70,
                              child: Text(
                                n,
                                style: menuText(13, weight: FontWeight.w800, color: accentOf(n)),
                              ),
                            ),
                            Expanded(
                              child: _Meter(value: (t + 10) / 20, color: accentOf(n), centre: true),
                            ),
                            SizedBox(
                              width: 34,
                              child: Text(
                                '$t',
                                textAlign: TextAlign.right,
                                style: menuText(12.5, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onStory != null)
                SizedBox(
                  width: 280,
                  child: MenuButton(label: l.readStory, icon: Icons.menu_book, primary: true, detail: storyStatus, onTap: onStory),
                ),
              const SizedBox(width: 12),
              SizedBox(
                width: 240,
                child: MenuButton(label: l.backToTitle, icon: Icons.home_outlined, primary: onStory == null, onTap: onMenu),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.note);
  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: Face.display.of(context, menuText(10.5, weight: FontWeight.w900, color: gold).copyWith(letterSpacing: 1.1)),
      ),
      Text(value, style: menuText(17, weight: FontWeight.w800)),
      if (note.isNotEmpty) Text(note, style: menuText(11.5, color: Colors.white54)),
    ],
  );
}

class _Meter extends StatelessWidget {
  const _Meter({required this.value, this.color = gold, this.centre = false});
  final double value;
  final Color color;
  final bool centre;

  @override
  Widget build(BuildContext context) => Container(
    height: 8,
    margin: const EdgeInsets.only(top: 6),
    decoration: BoxDecoration(color: const Color(0x22FFFFFF), borderRadius: BorderRadius.circular(4)),
    child: LayoutBuilder(
      builder: (context, box) {
        final v = value.clamp(0.0, 1.0);
        final w = box.maxWidth;
        final from = centre ? (v < 0.5 ? v * w : w / 2) : 0.0;
        final to = centre ? (v < 0.5 ? w / 2 : v * w) : v * w;
        return Stack(
          children: [
            Positioned(
              left: from,
              width: (to - from).clamp(2.0, w),
              top: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            if (centre)
              Positioned(
                left: w / 2 - 0.5,
                width: 1,
                top: -2,
                bottom: -2,
                child: const ColoredBox(color: Colors.white38),
              ),
          ],
        );
      },
    ),
  );
}

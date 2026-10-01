import 'package:flutter/material.dart';

import '../../sim/endings.dart';
import '../../sim/influence.dart';
import '../palette.dart';
import '../portrait.dart';
import 'menu_kit.dart';

/// One card per llama with its epilogue line ("…" while it is written).
class EpilogueView extends StatelessWidget {
  const EpilogueView({super.key, required this.lines, required this.onContinue, required this.wall, this.textScale = 1});
  final Map<String, String?> lines;
  final VoidCallback? onContinue;
  final double wall;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final dots = '.' * (1 + (wall * 3).floor() % 3);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'After the festival…',
          style: menuText(34, weight: FontWeight.w900, color: gold).copyWith(shadows: textShadow),
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
                          style: menuText(19 * textScale, weight: FontWeight.w900, color: accentOf(name)),
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
            label: onContinue == null ? 'The llamas are remembering…' : 'See how the week went',
            icon: Icons.arrow_forward,
            primary: true,
            onTap: onContinue,
          ),
        ),
      ],
    );
  }
}

String pipMoLabel(PipMoArc a) => switch (a) {
  PipMoArc.reconciled => 'made up',
  PipMoArc.rift => 'fell out',
  PipMoArc.unresolved => 'left unsaid',
};

String brambleLabel(BrambleArc a) => switch (a) {
  BrambleArc.accepted => 'confessed, and June said yes',
  BrambleArc.declined => 'confessed; June let him down gently',
  BrambleArc.exposedDeclined => 'exposed by gossip; June said no',
  BrambleArc.revealed => 'out in the open, still unanswered',
  BrambleArc.secret => 'still a secret',
};

/// The week's numbers, the ending and whether it was newly unlocked.
class ResultsView extends StatelessWidget {
  const ResultsView({super.key, required this.verdict, required this.influence, required this.newlyUnlocked, required this.onMenu});
  final EndingVerdict verdict;
  final Influence influence;
  final bool newlyUnlocked;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final info = endingInfo[verdict.ending]!;
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
              newlyUnlocked ? 'ENDING UNLOCKED' : 'ENDING (ALREADY UNLOCKED)',
              style: menuText(11, weight: FontWeight.w900, color: newlyUnlocked ? ink : Colors.white70).copyWith(letterSpacing: 1.2),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            info.title,
            style: menuText(40, weight: FontWeight.w900, color: gold),
          ),
          Text(info.blurb, style: menuText(14, color: Colors.white70)),
          const SizedBox(height: 6),
          Text('Why: ${verdict.reasons.join('; ')}.', style: menuText(12.5, color: Colors.white54)),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Stat('Harmony', '${i.harmony.toStringAsFixed(1)} / 10', 'mean friendship among the five'),
                    _Meter(value: (i.harmony + 10) / 20),
                    const SizedBox(height: 12),
                    _Stat(
                      'Truth',
                      beliefs.isEmpty ? 'no false beliefs' : '${beliefs.length} false belief${beliefs.length == 1 ? '' : 's'}',
                      beliefs.isEmpty
                          ? 'every rumour was put right'
                          : beliefs.take(3).map((b) => '${b.believer}: ${b.short}').join(' · ') +
                                (beliefs.length > 3 ? ' · +${beliefs.length - 3} more' : ''),
                    ),
                    const SizedBox(height: 12),
                    _Stat('Pip and Mo', pipMoLabel(i.pipMo), 'the scarf, the bread rumour and the Golden Bell'),
                    const SizedBox(height: 12),
                    _Stat("Bramble's poems", brambleLabel(i.bramble), 'his secret crush on June'),
                    const SizedBox(height: 12),
                    _Stat('Festival', i.festivalWinner == null ? 'no winner' : '${i.festivalWinner} won the Golden Bell', ''),
                  ],
                ),
              ),
              const SizedBox(width: 28),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Stat('Trust in Dash', i.meanTrust.toStringAsFixed(1), 'how each llama feels about you, -10 to 10'),
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
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 240,
              child: MenuButton(label: 'Back to the title', icon: Icons.home_outlined, primary: true, onTap: onMenu),
            ),
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
        style: menuText(10.5, weight: FontWeight.w900, color: gold).copyWith(letterSpacing: 1.1),
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

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../fonts.dart';
import '../palette.dart';
import 'menu_kit.dart';

/// (what, who and licence) rows of the credits, by section.
List<(String, List<(String, String)>)> creditSections(L10n l) => [
  (
    l.creditsModels,
    [
      ('Gemma 4 E2B, instruction-tuned (gemma-4-E2B-it, Q4_K_S GGUF)', l.creditsGemma),
      ('EmbeddingGemma 300M (Q8_0 GGUF)', l.creditsEmbedding),
      (l.creditsLayaName, l.creditsLaya),
    ],
  ),
  (
    l.creditsEngines,
    [
      ('llamadart', l.creditsLlamadart),
      ('flutter_scene', l.creditsScene),
      ('flutter_soloud', l.creditsSoloud),
      ('Flutter, shared_preferences, path_provider, intl', l.creditsFlutter),
    ],
  ),
  (l.creditsFonts, [('Gowun Dodum', l.creditsGowunDodum), ('Jua', l.creditsJua), ('Gowun Batang', l.creditsGowunBatang)]),
  (l.creditsSound, [(l.creditsSynth, l.creditsSynthNote)]),
];

class CreditsView extends StatelessWidget {
  const CreditsView({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return MenuCard(
      width: 640,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MenuHeader(title: l.credits, subtitle: l.creditsSubtitle, onClose: onClose),
            const SizedBox(height: 10),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (section, rows) in creditSections(l)) ...[
                      const SizedBox(height: 12),
                      Text(
                        section.toUpperCase(),
                        style: Face.display.of(context, menuText(11, weight: FontWeight.w900, color: gold).copyWith(letterSpacing: 1.2)),
                      ),
                      for (final (what, who) in rows)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(what, style: menuText(14.5, weight: FontWeight.w800)),
                              Text(who, style: menuText(12.5, color: Colors.white70)),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

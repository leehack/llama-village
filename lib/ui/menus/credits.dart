import 'package:flutter/material.dart';

import '../palette.dart';
import 'menu_kit.dart';

/// (what, who and licence) rows of the credits, by section.
const List<(String, List<(String, String)>)> creditSections = [
  (
    'Models (all run on this Mac, nothing is downloaded)',
    [
      (
        'Gemma 4 E2B, instruction-tuned (gemma-4-E2B-it, Q4_K_S GGUF)',
        'Google DeepMind. Dialogue, plans, thoughts, Dash\'s options, epilogues. Used under the Gemma 4 licence (Apache License 2.0), '
            'ai.google.dev/gemma/docs/gemma_4_license.',
      ),
      (
        'EmbeddingGemma 300M (Q8_0 GGUF)',
        'Google DeepMind. Checks which facts were actually said. Gemma is provided under and subject to the Gemma Terms of Use '
            'found at ai.google.dev/gemma/terms.',
      ),
      ('Laya decision model (optional)', 'Picks casual conversation topics when it is installed.'),
    ],
  ),
  (
    'Engines and libraries',
    [
      ('llamadart', 'MIT License, © 2024 Jhin Lee. Runs llama.cpp (MIT License, © the ggml authors) on Metal.'),
      ('flutter_scene', 'MIT License, © 2023 Brandon DeRosier. The 3D village, on Flutter GPU.'),
      ('flutter_soloud', 'MIT License, © 2024 the flutter_soloud authors, with the SoLoud engine (zlib/libpng licence, © Jari Komppa).'),
      ('Flutter, shared_preferences, path_provider', 'BSD 3-Clause License, © the Flutter authors.'),
    ],
  ),
  (
    'Sound',
    [
      (
        'Music and sounds synthesized in code',
        'tool/audio/gen_audio.py: additive synthesis, shaped noise and an FFT reverb. Nothing is sampled or downloaded.',
      ),
    ],
  ),
];

class CreditsView extends StatelessWidget {
  const CreditsView({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => MenuCard(
    width: 640,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 620),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MenuHeader(title: 'Credits', subtitle: 'Llama Village: Festival Week', onClose: onClose),
          const SizedBox(height: 10),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (section, rows) in creditSections) ...[
                    const SizedBox(height: 12),
                    Text(
                      section.toUpperCase(),
                      style: menuText(11, weight: FontWeight.w900, color: gold).copyWith(letterSpacing: 1.2),
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

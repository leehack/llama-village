import 'package:flutter/material.dart';

import '../render/llama_rig.dart';
import 'palette.dart';

/// A llama's head-and-shoulders portrait, pre-rendered from its model by
/// `tool/blender/portraits.py`.
ImageProvider portraitFor(String llamaName) => AssetImage('assets/portraits/${llamaSpecs[llamaName]?.id ?? llamaName.toLowerCase()}.png');

/// [portraitFor] in a round frame tinted with the llama's accent colour.
class LlamaPortrait extends StatelessWidget {
  const LlamaPortrait(this.name, {super.key, this.size = 56});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [Color.lerp(accent, Colors.white, 0.55)!, Color.lerp(accent, Colors.white, 0.15)!]),
        border: Border.all(color: Colors.white, width: size / 28),
        boxShadow: const [BoxShadow(blurRadius: 6, color: Color(0x55000000))],
      ),
      child: ClipOval(
        child: Image(
          image: portraitFor(name),
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

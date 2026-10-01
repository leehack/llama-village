import 'package:flutter/material.dart';

import '../render/world.dart';

const Color ink = Color(0xFF2A2733);
const Color paper = Color(0xFFFFFBF2);
const Color panel = Color(0xEE2A2733);
const Color panelLight = Color(0xF5FFFBF2);
const Color gold = Color(0xFFFFD25E);
const Color dashBlue = Color(0xFF3E8EF0);

/// A llama's accent colour (its scarf and roof); Dash is blue.
Color accentOf(String name) {
  if (name == 'Dash') return dashBlue;
  final c = llamaColors[name];
  return c == null ? Colors.grey : Color(0xFF000000 | c.$2);
}

const List<Shadow> textShadow = [Shadow(blurRadius: 6, color: Color(0x88000000))];

/// An icon for what a llama is doing, shown on its name tag.
IconData? activityIcon(String kind) => switch (kind) {
  'eat' => Icons.restaurant,
  'work' => Icons.handyman,
  'nap' || 'sleep' => Icons.bedtime,
  'search' => Icons.search,
  'practise' => Icons.music_note,
  'flowers' => Icons.local_florist,
  'watch' => Icons.celebration,
  'wait' => Icons.hourglass_bottom,
  'talk' => Icons.forum,
  _ => null,
};

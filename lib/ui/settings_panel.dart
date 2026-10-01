import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../render/quality.dart';
import '../settings.dart';
import 'fonts.dart';
import 'ko_text.dart';
import 'palette.dart';

/// The settings card: graphics, audio, gameplay and accessibility. Used
/// under the top bar in game and centred in the menus.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key, required this.settings, required this.onClick, required this.onClose, this.maxHeight = 640});
  final VillageSettings settings;

  /// Plays the UI click.
  final VoidCallback onClick;
  final VoidCallback onClose;
  final double maxHeight;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) {
      final l = L10n.of(context);
      return Container(
        width: 400,
        constraints: BoxConstraints(maxHeight: maxHeight),
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 14),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(blurRadius: 18, color: Color(0x44000000), offset: Offset(0, 4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                KoText(
                  l.settings,
                  style: Face.display.of(context, const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
                const Spacer(),
                IconButton(
                  tooltip: l.close,
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Section(l.sectionLanguage),
                    _segments<AppLanguage>(
                      {for (final a in AppLanguage.values) a: a.nativeName ?? l.languageSystem},
                      settings.language,
                      (v) => settings.language = v,
                    ),
                    const SizedBox(height: 4),
                    KoText(l.languageNote, style: _note),
                    _Section(l.sectionGraphics),
                    KoText(l.frameRate, style: _label),
                    const SizedBox(height: 6),
                    _segments<int>({for (final f in VillageSettings.fpsChoices) f: l.fpsChoice(f)}, settings.fps, (v) => settings.fps = v),
                    const SizedBox(height: 4),
                    KoText(l.promotionNote, style: _note),
                    const SizedBox(height: 10),
                    KoText(l.graphicsQuality, style: _label),
                    const SizedBox(height: 6),
                    _segments<GraphicsQuality>(
                      {for (final q in GraphicsQuality.values) q: l.quality(q.name)},
                      settings.quality,
                      (v) => settings.quality = v,
                    ),
                    _Section(l.sectionAudio),
                    _volume(l.music, settings.musicVolume, (v) => settings.musicVolume = v),
                    _volume(l.soundEffects, settings.sfxVolume, (v) => settings.sfxVolume = v),
                    _switch(l.muteAll, settings.muted, (v) => settings.muted = v),
                    _Section(l.sectionGameplay),
                    KoText(l.textSpeed, style: _label),
                    const SizedBox(height: 6),
                    _segments<TextSpeed>(
                      {for (final t in TextSpeed.values) t: l.speedName(t.name)},
                      settings.textSpeed,
                      (v) => settings.textSpeed = v,
                    ),
                    const SizedBox(height: 10),
                    KoText(l.startingSpeed, style: _label),
                    const SizedBox(height: 6),
                    _segments<int>(
                      {for (final s in VillageSettings.speedChoices) s: l.speedChoice(s)},
                      settings.defaultSpeed,
                      (v) => settings.defaultSpeed = v,
                    ),
                    _Section(l.sectionAccessibility),
                    KoText(l.textSize, style: _label),
                    const SizedBox(height: 6),
                    _segments<TextSize>(
                      {for (final t in TextSize.values) t: l.sizeName(t.name)},
                      settings.textSize,
                      (v) => settings.textSize = v,
                    ),
                    const SizedBox(height: 4),
                    _switch(l.reducedMotion, settings.reducedMotion, (v) => settings.reducedMotion = v),
                    KoText(l.reducedMotionNote, style: _note),
                    _switch(l.highContrast, settings.highContrast, (v) => settings.highContrast = v),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _segments<T>(Map<T, String> choices, T selected, ValueChanged<T> onChanged) => SegmentedButton<T>(
    showSelectedIcon: false,
    segments: [for (final e in choices.entries) ButtonSegment(value: e.key, label: KoText(e.value))],
    selected: {selected},
    onSelectionChanged: (s) {
      onClick();
      onChanged(s.first);
    },
    style: SegmentedButton.styleFrom(foregroundColor: Colors.white, selectedForegroundColor: ink, selectedBackgroundColor: gold),
  );

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    activeThumbColor: gold,
    title: KoText(label, style: _label),
    value: value,
    onChanged: (v) {
      onChanged(v);
      onClick();
    },
  );
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: KoText(
      title.toUpperCase(),
      style: Face.display.of(context, const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: gold)),
    ),
  );
}

const TextStyle _label = TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white);
const TextStyle _note = TextStyle(fontSize: 11, color: Colors.white60);

Widget _volume(String label, double value, ValueChanged<double> onChanged) => Row(
  children: [
    SizedBox(width: 104, child: KoText(label, style: _label)),
    Expanded(
      child: Slider(value: value, onChanged: onChanged, activeColor: gold, inactiveColor: Colors.white24),
    ),
    SizedBox(
      width: 34,
      child: KoText(
        '${(value * 100).round()}',
        textAlign: TextAlign.right,
        style: const TextStyle(fontSize: 12, color: Colors.white70),
      ),
    ),
  ],
);

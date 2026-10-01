import 'package:flutter/material.dart';

import '../render/quality.dart';
import '../settings.dart';
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
    builder: (context, _) => Container(
      width: 380,
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
              const Text(
                'Settings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Close',
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
                  const _Section('Graphics'),
                  const Text('Frame rate', style: _label),
                  const SizedBox(height: 6),
                  _segments<int>({for (final f in VillageSettings.fpsChoices) f: '$f fps'}, settings.fps, (v) => settings.fps = v),
                  const SizedBox(height: 4),
                  const Text('120 fps needs a ProMotion display.', style: _note),
                  const SizedBox(height: 10),
                  const Text('Graphics quality', style: _label),
                  const SizedBox(height: 6),
                  _segments<GraphicsQuality>(
                    {for (final q in GraphicsQuality.values) q: q.label},
                    settings.quality,
                    (v) => settings.quality = v,
                  ),
                  const _Section('Audio'),
                  _volume('Music', settings.musicVolume, (v) => settings.musicVolume = v),
                  _volume('Sound effects', settings.sfxVolume, (v) => settings.sfxVolume = v),
                  _switch('Mute all', settings.muted, (v) => settings.muted = v),
                  const _Section('Gameplay'),
                  const Text('Text speed', style: _label),
                  const SizedBox(height: 6),
                  _segments<TextSpeed>(
                    const {TextSpeed.slow: 'Slow', TextSpeed.normal: 'Normal', TextSpeed.fast: 'Fast'},
                    settings.textSpeed,
                    (v) => settings.textSpeed = v,
                  ),
                  const SizedBox(height: 10),
                  const Text('Starting time speed', style: _label),
                  const SizedBox(height: 6),
                  _segments<int>(
                    {for (final s in VillageSettings.speedChoices) s: '$s×'},
                    settings.defaultSpeed,
                    (v) => settings.defaultSpeed = v,
                  ),
                  const _Section('Accessibility'),
                  const Text('Text size', style: _label),
                  const SizedBox(height: 6),
                  _segments<TextSize>(
                    const {TextSize.normal: 'Normal', TextSize.large: 'Large', TextSize.larger: 'Larger'},
                    settings.textSize,
                    (v) => settings.textSize = v,
                  ),
                  const SizedBox(height: 4),
                  _switch('Reduced motion', settings.reducedMotion, (v) => settings.reducedMotion = v),
                  const Text(
                    'Shorter camera moves in cutscenes, no camera shake, a slower menu flyover, calmer animals and fewer particles.',
                    style: _note,
                  ),
                  _switch('High-contrast bubbles', settings.highContrast, (v) => settings.highContrast = v),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _segments<T>(Map<T, String> choices, T selected, ValueChanged<T> onChanged) => SegmentedButton<T>(
    showSelectedIcon: false,
    segments: [for (final e in choices.entries) ButtonSegment(value: e.key, label: Text(e.value))],
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
    title: Text(label, style: _label),
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
    child: Text(
      title.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: gold),
    ),
  );
}

const TextStyle _label = TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white);
const TextStyle _note = TextStyle(fontSize: 11, color: Colors.white60);

Widget _volume(String label, double value, ValueChanged<double> onChanged) => Row(
  children: [
    SizedBox(width: 104, child: Text(label, style: _label)),
    Expanded(
      child: Slider(value: value, onChanged: onChanged, activeColor: gold, inactiveColor: Colors.white24),
    ),
    SizedBox(
      width: 34,
      child: Text(
        '${(value * 100).round()}',
        textAlign: TextAlign.right,
        style: const TextStyle(fontSize: 12, color: Colors.white70),
      ),
    ),
  ],
);

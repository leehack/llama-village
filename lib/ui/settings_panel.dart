import 'package:flutter/material.dart';

import '../settings.dart';
import 'palette.dart';

/// The settings card under the top bar.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key, required this.settings, required this.onClick, required this.onClose});
  final VillageSettings settings;

  /// Plays the UI click.
  final VoidCallback onClick;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) => Container(
      width: 320,
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
          const Text('Frame rate', style: _label),
          const SizedBox(height: 6),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [for (final f in VillageSettings.fpsChoices) ButtonSegment(value: f, label: Text('$f fps'))],
            selected: {settings.fps},
            onSelectionChanged: (s) {
              onClick();
              settings.fps = s.first;
            },
            style: SegmentedButton.styleFrom(foregroundColor: Colors.white, selectedForegroundColor: ink, selectedBackgroundColor: gold),
          ),
          const SizedBox(height: 4),
          const Text('120 fps needs a ProMotion display.', style: TextStyle(fontSize: 11, color: Colors.white60)),
          const SizedBox(height: 10),
          _volume('Music', settings.musicVolume, (v) => settings.musicVolume = v),
          _volume('Sound effects', settings.sfxVolume, (v) => settings.sfxVolume = v),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeThumbColor: gold,
            title: const Text('Mute all', style: _label),
            value: settings.muted,
            onChanged: (v) {
              settings.muted = v;
              onClick();
            },
          ),
        ],
      ),
    ),
  );
}

const TextStyle _label = TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white);

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

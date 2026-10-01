import 'package:flutter/material.dart';

import '../settings.dart';
import 'palette.dart';

/// The settings card under the top bar.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key, required this.settings, required this.onClose});
  final VillageSettings settings;
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
          const Text(
            'Frame rate',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 6),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [for (final f in VillageSettings.fpsChoices) ButtonSegment(value: f, label: Text('$f fps'))],
            selected: {settings.fps},
            onSelectionChanged: (s) => settings.fps = s.first,
            style: SegmentedButton.styleFrom(foregroundColor: Colors.white, selectedForegroundColor: ink, selectedBackgroundColor: gold),
          ),
          const SizedBox(height: 4),
          const Text('120 fps needs a ProMotion display.', style: TextStyle(fontSize: 11, color: Colors.white60)),
        ],
      ),
    ),
  );
}

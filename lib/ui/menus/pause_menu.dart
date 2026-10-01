import 'package:flutter/material.dart';

import '../../game/save_store.dart';
import '../palette.dart';
import 'menu_kit.dart';

/// The pause menu (Esc): resume, save to a slot, settings, back to the
/// title, or quit.
class PauseMenu extends StatefulWidget {
  const PauseMenu({
    super.key,
    required this.when,
    required this.slots,
    required this.onResume,
    required this.onSave,
    required this.onSettings,
    required this.onSaveAndQuit,
    required this.onQuit,
  });

  /// "Day 2, 14:05".
  final String when;

  /// The manual slots, empty ones as null.
  final Map<String, SaveInfo?> slots;
  final VoidCallback onResume;
  final Future<void> Function(String slot) onSave;
  final VoidCallback onSettings;
  final VoidCallback onSaveAndQuit;
  final VoidCallback onQuit;

  @override
  State<PauseMenu> createState() => _PauseMenuState();
}

class _PauseMenuState extends State<PauseMenu> {
  bool _saving = false;
  String? _saved;

  Future<void> _save(String slot) async {
    setState(() => _saving = true);
    try {
      await widget.onSave(slot);
      _saved = slot;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => MenuCard(
    width: 400,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Paused',
          style: menuText(30, weight: FontWeight.w900, color: gold),
        ),
        Text(widget.when, style: menuText(13, color: Colors.white70)),
        const SizedBox(height: 16),
        MenuButton(label: 'Resume', icon: Icons.play_arrow_rounded, primary: true, autofocus: true, onTap: widget.onResume),
        const SizedBox(height: 8),
        Text(
          'SAVE GAME',
          style: menuText(11, weight: FontWeight.w900, color: gold).copyWith(letterSpacing: 1.2),
        ),
        for (final MapEntry(key: slot, value: info) in widget.slots.entries)
          MenuButton(
            label: 'Slot ${slot.substring(4)}${_saved == slot ? '  ✓ saved' : ''}',
            icon: Icons.save_outlined,
            detail: info == null ? 'empty' : info.when,
            onTap: _saving ? null : () => _save(slot),
          ),
        const SizedBox(height: 8),
        MenuButton(label: 'Settings', icon: Icons.tune, onTap: widget.onSettings),
        MenuButton(
          label: 'Save and quit to menu',
          icon: Icons.home_outlined,
          detail: 'Saves to the autosave slot',
          onTap: _saving ? null : widget.onSaveAndQuit,
        ),
        MenuButton(label: 'Quit game', icon: Icons.logout, onTap: widget.onQuit),
        const SizedBox(height: 4),
        Text(
          'Esc resumes',
          textAlign: TextAlign.center,
          style: menuText(11, color: Colors.white38),
        ),
      ],
    ),
  );
}

/// A small banner that fades away, for "Saved to Slot 2".
class Toast extends StatelessWidget {
  const Toast({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(12)),
    child: Text(text, style: menuText(13.5, weight: FontWeight.w700)),
  );
}

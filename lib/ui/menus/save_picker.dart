import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../game/save_store.dart';
import '../../l10n/app_localizations.dart';
import '../fonts.dart';
import '../ko_text.dart';
import '../palette.dart';
import '../strings.dart';
import 'gallery.dart';
import 'menu_kit.dart';

/// Continue's slot picker: the autosave and the three manual slots, each
/// with its picture, day and time and playtime. Empty and damaged slots
/// cannot be picked.
class SavePicker extends StatelessWidget {
  const SavePicker({super.key, required this.slots, required this.onPick, required this.onClose});

  /// Every slot of [SaveStore.allSlots], empty ones as null.
  final Map<String, SaveInfo?> slots;
  final ValueChanged<SaveInfo> onPick;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final first = SaveStore.allSlots.where((s) => slots[s]?.damaged == false).firstOrNull;
    return MenuCard(
      width: 900,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MenuHeader(title: l.continueGame, subtitle: l.pickSave, onClose: onClose),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final slot in SaveStore.allSlots)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _SlotTile(slot: slot, info: slots[slot], autofocus: slot == first, onPick: onPick),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.slot, required this.info, required this.autofocus, required this.onPick});
  final String slot;
  final SaveInfo? info;
  final bool autofocus;
  final ValueChanged<SaveInfo> onPick;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final save = info;
    final open = save != null && !save.damaged;
    final name = slot == SaveStore.autoSlot ? l.autosave : l.slotN(int.parse(slot.substring(4)));
    return Material(
      color: open ? const Color(0x1FFFFFFF) : const Color(0x0DFFFFFF),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        autofocus: autofocus,
        borderRadius: BorderRadius.circular(14),
        onTap: open ? () => onPick(save) : null,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: open ? gold.withValues(alpha: 0.5) : const Color(0x22FFFFFF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: ClipRRect(borderRadius: BorderRadius.circular(8), child: _picture(save)),
              ),
              const SizedBox(height: 10),
              KoText(
                name,
                style: Face.display.of(context, menuText(17, weight: FontWeight.w900, color: open ? gold : Colors.white54)),
              ),
              const SizedBox(height: 2),
              if (save == null)
                KoText(l.empty, style: menuText(13, color: Colors.white38))
              else if (save.damaged) ...[
                KoText(l.damaged, style: menuText(13, color: const Color(0xFFE88A7A))),
                KoText(l.saveCannotLoad, style: menuText(11.5, color: Colors.white38)),
              ] else ...[
                KoText(l.saveWhen(save), style: menuText(14, weight: FontWeight.w800)),
                KoText(l.savePlaytime(save), style: menuText(12, color: Colors.white70)),
                KoText(
                  l.savedOn(DateFormat.MMMd(l.localeName).add_Hm().format(save.savedAt!.toLocal())),
                  style: menuText(11, color: Colors.white38),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _picture(SaveInfo? save) {
    final thumbnail = save?.thumbnail;
    if (thumbnail != null) {
      return Image.memory(
        thumbnail,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => _placeholder(save),
      );
    }
    return _placeholder(save);
  }

  /// An empty or damaged slot, or a save from before thumbnails.
  Widget _placeholder(SaveInfo? save) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1A1822), Color(0xFF2A2733)]),
    ),
    child: Center(
      child: save == null
          ? const Icon(Icons.crop_free, size: 34, color: Colors.white24)
          : save.damaged
          ? const Icon(Icons.broken_image_outlined, size: 34, color: Color(0xFFE88A7A))
          : CustomPaint(size: const Size(90, 72), painter: LlamaSilhouette(Colors.white38)),
    ),
  );
}

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../palette.dart';

TextStyle menuText(double size, {FontWeight weight = FontWeight.w600, Color color = Colors.white, double height = 1.3}) =>
    TextStyle(fontSize: size, fontWeight: weight, color: color, height: height);

/// The dark rounded card every menu sits on.
class MenuCard extends StatelessWidget {
  const MenuCard({super.key, required this.child, this.width, this.padding = const EdgeInsets.fromLTRB(28, 24, 28, 24)});
  final Widget child;
  final double? width;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: padding,
    decoration: BoxDecoration(
      color: const Color(0xF0221F2B),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0x33FFFFFF)),
      boxShadow: const [BoxShadow(blurRadius: 30, color: Color(0x66000000), offset: Offset(0, 8))],
    ),
    child: child,
  );
}

/// A full-width menu button with an optional second line.
class MenuButton extends StatelessWidget {
  const MenuButton({
    super.key,
    required this.label,
    required this.onTap,
    this.detail,
    this.icon,
    this.primary = false,
    this.autofocus = false,
  });
  final String label;
  final String? detail;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool primary;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = !enabled
        ? Colors.white30
        : primary
        ? ink
        : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: primary && enabled ? gold : const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          autofocus: autofocus,
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              children: [
                if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: menuText(16, weight: FontWeight.w800, color: fg),
                      ),
                      if (detail != null)
                        Text(detail!, style: menuText(11.5, color: primary && enabled ? ink.withValues(alpha: 0.7) : Colors.white54)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A heading row with a close button.
class MenuHeader extends StatelessWidget {
  const MenuHeader({super.key, required this.title, required this.onClose, this.subtitle});
  final String title;
  final String? subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: menuText(26, weight: FontWeight.w900, color: gold),
            ),
            if (subtitle != null) Text(subtitle!, style: menuText(13, color: Colors.white70)),
          ],
        ),
      ),
      IconButton(
        tooltip: L10n.of(context).close,
        onPressed: onClose,
        icon: const Icon(Icons.close, color: Colors.white70),
      ),
    ],
  );
}

/// Dims whatever is behind a menu.
class Scrim extends StatelessWidget {
  const Scrim({super.key, required this.child, this.opacity = 0.45});
  final Widget child;
  final double opacity;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black.withValues(alpha: opacity),
    child: Center(child: child),
  );
}

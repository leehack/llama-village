import 'package:flutter/material.dart';

import '../../game/save_store.dart';
import '../../l10n/app_localizations.dart';
import '../palette.dart';
import '../strings.dart';
import 'menu_kit.dart';
import '../fonts.dart';

/// The title screen, over the drone flyover of the village.
class StartMenu extends StatelessWidget {
  const StartMenu({
    super.key,
    required this.save,
    required this.status,
    required this.onNew,
    required this.onContinue,
    required this.onEndings,
    required this.onSettings,
    required this.onCredits,
    required this.onQuit,
    this.busy,
  });

  /// The save Continue would load, if any.
  final SaveInfo? save;

  /// The models' state ("Loading the dialogue model… 40%").
  final String status;

  /// Shown instead of the buttons while a game is starting.
  final String? busy;
  final VoidCallback onNew;
  final VoidCallback onContinue;
  final VoidCallback onEndings;
  final VoidCallback onSettings;
  final VoidCallback onCredits;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xCC14121C), Color(0x6614121C), Color(0x0014121C)], stops: [0, 0.4, 0.7]),
          ),
        ),
        Positioned(
          left: 64,
          top: 0,
          bottom: 0,
          child: Center(
            child: SizedBox(
              width: 470,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.appTitle,
                    style: Face.display.of(
                      context,
                      menuText(54, weight: FontWeight.w900, color: gold, height: 1.0).copyWith(shadows: textShadow),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.appSubtitle,
                    style: Face.display.of(
                      context,
                      menuText(20, weight: FontWeight.w800, color: Colors.white).copyWith(shadows: textShadow),
                    ),
                  ),
                  Text(
                    l.titleTagline,
                    style: menuText(14, color: Colors.white70).copyWith(shadows: textShadow),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 340,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (busy != null)
                          MenuCard(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: gold)),
                                const SizedBox(width: 14),
                                Expanded(child: Text(busy!, style: menuText(14))),
                              ],
                            ),
                          )
                        else ...[
                          MenuButton(label: l.newGame, icon: Icons.play_arrow_rounded, primary: true, autofocus: true, onTap: onNew),
                          MenuButton(
                            label: l.continueGame,
                            icon: Icons.history,
                            detail: save == null ? l.noSave : l.saveDetail(l.saveWhen(save!), l.saveName(save!)),
                            onTap: save == null ? null : onContinue,
                          ),
                          MenuButton(label: l.endings, icon: Icons.auto_awesome, onTap: onEndings),
                          MenuButton(label: l.settings, icon: Icons.tune, onTap: onSettings),
                          MenuButton(label: l.credits, icon: Icons.favorite_border, onTap: onCredits),
                          MenuButton(label: l.quit, icon: Icons.logout, onTap: onQuit),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 64,
          bottom: 22,
          child: Text(
            status,
            style: menuText(12, color: Colors.white60).copyWith(shadows: textShadow),
          ),
        ),
      ],
    );
  }
}

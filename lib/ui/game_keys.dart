import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The root keyboard handler of the 3D view.
///
/// On macOS a key event the framework leaves unhandled goes on to AppKit,
/// which plays the system error beep. So this consumes every event for the
/// game keys (down, repeat and up), and any other key while the view itself
/// holds focus. It leaves alone menu shortcuts (Cmd or Ctrl held, so Cmd-Q
/// still quits), bare modifier keys, everything while a text field is
/// focused, and non-game keys while a control such as a button is focused,
/// so Enter can still press it.
class GameKeys extends StatelessWidget {
  const GameKeys({super.key, required this.focusNode, required this.onPress, required this.child});

  final FocusNode focusNode;

  /// Called on key down for a game key, with the root focused or a
  /// non-text control focused.
  final void Function(LogicalKeyboardKey key) onPress;
  final Widget child;

  static final Set<LogicalKeyboardKey> gameKeys = {
    LogicalKeyboardKey.keyW,
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyS,
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.keyQ,
    LogicalKeyboardKey.keyE,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.keyF,
    LogicalKeyboardKey.keyO,
    LogicalKeyboardKey.escape,
  };

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    final keyboard = HardwareKeyboard.instance;
    final key = e.logicalKey;
    if (keyboard.isMetaPressed || keyboard.isControlPressed) return KeyEventResult.ignored;
    if (key.synonyms.isNotEmpty || key == LogicalKeyboardKey.capsLock || key == LogicalKeyboardKey.fn) {
      return KeyEventResult.ignored;
    }
    if (_textFocused()) return KeyEventResult.ignored;
    if (gameKeys.contains(key)) {
      if (e is KeyDownEvent) onPress(key);
      return KeyEventResult.handled;
    }
    return node.hasPrimaryFocus ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  static bool _textFocused() {
    final context = FocusManager.instance.primaryFocus?.context;
    return context != null && (context.widget is EditableText || context.findAncestorWidgetOfExactType<EditableText>() != null);
  }

  @override
  Widget build(BuildContext context) => Focus(focusNode: focusNode, autofocus: true, onKeyEvent: _onKey, child: child);
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/ui/game_keys.dart';

/// A key event the framework reports as unhandled goes on to AppKit, which
/// beeps; these send events through the macOS key path and check the result.
void main() {
  late FocusNode root;
  late FocusNode field;
  late FocusNode button;
  late List<LogicalKeyboardKey> pressed;
  late int buttonPresses;

  Future<void> pump(WidgetTester tester) async {
    root = FocusNode();
    field = FocusNode();
    button = FocusNode();
    pressed = [];
    buttonPresses = 0;
    addTearDown(root.dispose);
    addTearDown(field.dispose);
    addTearDown(button.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: GameKeys(
            focusNode: root,
            onPress: pressed.add,
            child: Column(
              children: [
                TextField(focusNode: field),
                TextButton(focusNode: button, onPressed: () => buttonPresses++, child: const Text('OK')),
              ],
            ),
          ),
        ),
      ),
    );
    root.requestFocus();
    await tester.pump();
  }

  Future<List<bool>> downRepeatUp(WidgetTester tester, LogicalKeyboardKey key) async => [
    await tester.sendKeyDownEvent(key, platform: 'macos'),
    await tester.sendKeyRepeatEvent(key, platform: 'macos'),
    await tester.sendKeyUpEvent(key, platform: 'macos'),
  ];

  testWidgets('holding WASD is handled on down, repeat and up', (tester) async {
    await pump(tester);
    for (final k in [LogicalKeyboardKey.keyW, LogicalKeyboardKey.keyA, LogicalKeyboardKey.keyS, LogicalKeyboardKey.keyD]) {
      expect(await downRepeatUp(tester, k), [true, true, true], reason: k.keyLabel);
    }
    expect(pressed, [LogicalKeyboardKey.keyW, LogicalKeyboardKey.keyA, LogicalKeyboardKey.keyS, LogicalKeyboardKey.keyD]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('every game key is handled and pressed once', (tester) async {
    await pump(tester);
    for (final k in GameKeys.gameKeys) {
      expect(await downRepeatUp(tester, k), [true, true, true], reason: k.debugName);
    }
    expect(pressed, GameKeys.gameKeys.toList());
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('other keys are swallowed while the view has focus', (tester) async {
    await pump(tester);
    for (final k in [LogicalKeyboardKey.keyK, LogicalKeyboardKey.digit7, LogicalKeyboardKey.tab, LogicalKeyboardKey.enter]) {
      expect(await downRepeatUp(tester, k), [true, true, true], reason: k.debugName);
    }
    expect(pressed, isEmpty);
    expect(root.hasPrimaryFocus, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('Cmd-Q and bare modifiers pass through to the menu', (tester) async {
    await pump(tester);
    expect(await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft, platform: 'macos'), isFalse);
    expect(await tester.sendKeyDownEvent(LogicalKeyboardKey.keyQ, platform: 'macos'), isFalse);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyQ, platform: 'macos');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft, platform: 'macos');
    expect(await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft, platform: 'macos'), isFalse);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft, platform: 'macos');
    expect(pressed, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('keys are left to a focused text field', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(field.hasPrimaryFocus, isTrue);
    expect(await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW, platform: 'macos'), isFalse);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW, platform: 'macos');
    expect(pressed, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('Enter still presses a focused button', (tester) async {
    await pump(tester);
    button.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter, platform: 'macos');
    await tester.pump();
    expect(buttonPresses, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}

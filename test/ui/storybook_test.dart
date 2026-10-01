import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/l10n/app_localizations.dart';
import 'package:llama_village/sim/endings.dart';
import 'package:llama_village/sim/storybook.dart';
import 'package:llama_village/ui/menus/storybook.dart';

Storybook _book() => Storybook(
  id: 'w',
  title: storyTitle,
  ending: Ending.dramaLlama,
  finishedAt: DateTime.utc(2026),
  pages: [
    StoryPage(PageKind.cover),
    StoryPage(PageKind.day, day: 1, text: 'Once upon a time, a little blue bird flew into Berry Valley. Everyone was busy.'),
    StoryPage(PageKind.day, day: 2)..draft = 'On the second day, June',
    StoryPage(PageKind.ending, shot: Uint8List(0)),
  ],
);

void main() {
  testWidgets('the storybook turns with the arrow keys and clicks and closes on Esc', (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var closed = 0;
    final key = GlobalKey<StorybookViewState>();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: StorybookView(key: key, book: _book(), reducedMotion: true, onClose: () => closed++),
      ),
    );
    await tester.pump();
    expect(find.text(storyTitle), findsOneWidget);
    expect(find.textContaining('still writing… 1 of 3 pages'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(key.currentState!.page, 1);
    expect(find.text('The First Day'), findsOneWidget);
    expect(find.text('O'), findsOneWidget, reason: 'the first letter is a drop cap');

    await tester.tap(find.byTooltip('Next page (→)'));
    await tester.pump();
    expect(key.currentState!.page, 2);
    expect(find.textContaining('On the second day, June'), findsOneWidget, reason: 'a page being written streams in');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(key.currentState!.page, 3, reason: 'the last page stays put');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(key.currentState!.page, 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(closed, 1);
  });
}

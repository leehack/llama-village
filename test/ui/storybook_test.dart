import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/l10n/app_localizations.dart';
import 'package:llama_village/sim/endings.dart';
import 'package:llama_village/sim/storybook.dart';
import 'package:llama_village/ui/menus/storybook.dart';
import 'package:llama_village/ui/portrait.dart';

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
    final portrait = tester.widget<LlamaPortrait>(find.byType(LlamaPortrait));
    expect(portrait.name, 'Pip', reason: 'a page without a picture shows its lead llama');

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

  test('a page without a picture is about the llama it names most', () {
    StoryPage day(int d, String text) => StoryPage(PageKind.day, day: d, text: text);
    expect(pageStar(day(1, 'June met Mo. Mo smiled, and Mo sang.')), 'Mo');
    expect(pageStar(day(2, 'Clover은 June에게 말했어요. June은 웃었어요. Clover도요.')), 'Clover', reason: 'ties go to the first named');
    expect(pageStar(day(3, 'The wind blew all day.')), 'Bramble', reason: "else the day's lead");
    expect(pageStar(StoryPage(PageKind.ending, text: 'And so it ended.')), isNull);
    expect(pageStar(StoryPage(PageKind.cover)), isNull);
  });

  testWidgets('a long page at a large text size fits on the page without scrolling', (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final long = List.filled(6, 'Clover rang her bell and announced the Berry Festival on the hilltop by evening.').join(' ');
    final book = Storybook(
      id: 'w',
      title: storyTitle,
      ending: Ending.dramaLlama,
      finishedAt: DateTime.utc(2026),
      pages: [
        StoryPage(PageKind.cover),
        StoryPage(PageKind.day, day: 1, text: long),
      ],
    );
    final key = GlobalKey<StorybookViewState>();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1600, 1000), textScaler: TextScaler.linear(1.3)),
          child: StorybookView(key: key, book: book, reducedMotion: true, onClose: () {}),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(
      find.descendant(of: find.byType(SingleChildScrollView), matching: find.byType(Scrollable)).last,
    );
    expect(scroll.position.maxScrollExtent, 0, reason: 'the last line is cut off');
  });
}

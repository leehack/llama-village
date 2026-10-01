import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/game/save_store.dart';
import 'package:llama_village/l10n/app_localizations.dart';
import 'package:llama_village/sim/endings.dart';
import 'package:llama_village/sim/influence.dart';
import 'package:llama_village/ui/menus/gallery.dart';
import 'package:llama_village/ui/menus/pause_menu.dart';
import 'package:llama_village/ui/menus/start_menu.dart';
import 'package:llama_village/ui/menus/week_end.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: L10n.localizationsDelegates,
  supportedLocales: L10n.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('the title screen offers Continue only when a save loads', (tester) async {
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var continued = 0;
    Widget menu(SaveInfo? save) => _host(
      StartMenu(
        save: save,
        status: 'Ready',
        onNew: () {},
        onContinue: () => continued++,
        onEndings: () {},
        onSettings: () {},
        onCredits: () {},
        onQuit: () {},
      ),
    );
    await tester.pumpWidget(menu(null));
    expect(find.text('No saved game yet'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    expect(continued, 0);
    await tester.pumpWidget(menu(SaveInfo('autosave', savedAt: DateTime(2026), day: 3, time: '06:00')));
    expect(find.text('Day 3, 06:00 · Autosave'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    expect(continued, 1);
  });

  testWidgets('the pause menu saves to the slot that was tapped', (tester) async {
    tester.view
      ..physicalSize = const Size(1440, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final saved = <String>[];
    await tester.pumpWidget(
      _host(
        PauseMenu(
          when: 'Day 2, 10:00',
          slots: {
            'slot1': null,
            'slot2': SaveInfo('slot2', savedAt: DateTime(2026), day: 1, time: '09:00'),
            'slot3': null,
          },
          onResume: () {},
          onSave: (slot) async => saved.add(slot),
          onSettings: () {},
          onSaveAndQuit: () {},
          onQuit: () {},
        ),
      ),
    );
    expect(find.text('Day 1, 09:00'), findsOneWidget);
    await tester.tap(find.text('Slot 3'));
    await tester.pumpAndSettle();
    expect(saved, ['slot3']);
    expect(find.textContaining('✓ saved'), findsOneWidget);
  });

  testWidgets('locked endings show their hint, unlocked ones their title', (tester) async {
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(EndingsGallery(unlocked: const {Ending.dramaLlama}, onClose: () {})));
    expect(find.text('1 of 3 unlocked'), findsOneWidget);
    expect(find.text('Drama Llama'), findsOneWidget);
    expect(find.text('Harmony Festival'), findsNothing);
    expect(find.text(endingInfo[Ending.harmonyFestival]!.hint), findsOneWidget);

    await tester.pumpWidget(
      _host(
        EndingsGallery(unlocked: const {Ending.dramaLlama}, onClose: () {}),
        locale: const Locale('fr'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 sur 3 débloquées'), findsOneWidget);
    expect(find.text('Lama Drama'), findsOneWidget);
    expect(find.text('LIVRES D\'HISTOIRES'), findsOneWidget);
  });

  testWidgets('the results show the ending, why, and each llama\'s trust', (tester) async {
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final i = Influence(
      harmony: 2.5,
      falseBeliefs: const [],
      pipMo: PipMoArc.reconciled,
      bramble: BrambleArc.accepted,
      dashTrust: {for (final n in llamaNames) n: 3},
      festivalWinner: 'Mo',
      festivalHeld: true,
    );
    await tester.pumpWidget(_host(ResultsView(verdict: decideEnding(i), influence: i, newlyUnlocked: true, onMenu: () {})));
    expect(find.text('ENDING UNLOCKED'), findsOneWidget);
    expect(find.text('Harmony Festival'), findsOneWidget);
    expect(find.text('made up'), findsOneWidget);
    expect(find.text('Mo won the Golden Bell'), findsOneWidget);
    expect(find.text('3'), findsNWidgets(5));
  });

  testWidgets('the results read in Korean, reasons and arcs included', (tester) async {
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final i = Influence(
      harmony: 0.2,
      falseBeliefs: const [FalseBelief('bread_rumour', "Mo's bread rumour", 'Pip')],
      pipMo: PipMoArc.rift,
      bramble: BrambleArc.secret,
      dashTrust: {for (final n in llamaNames) n: -1},
      festivalWinner: 'Pip',
      festivalHeld: true,
    );
    final verdict = decideEnding(i);
    expect(verdict.ending, Ending.dramaLlama);
    await tester.pumpWidget(
      _host(
        ResultsView(verdict: verdict, influence: i, newlyUnlocked: false, onMenu: () {}),
        locale: const Locale('ko'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('드라마 라마'), findsOneWidget);
    expect(find.text('이유: 우정이 틀어졌어요 (화합 0.2); Pip과 Mo가 사이가 틀어졌어요.'), findsOneWidget);
    expect(find.text('사이가 틀어졌어요'), findsOneWidget);
    expect(find.text('Pip: Mo의 빵 소문'), findsOneWidget);
    expect(find.text('Pip이 황금 종을 받았어요'), findsOneWidget);
    expect(find.text('타이틀로 돌아가기'), findsOneWidget);
  });
}

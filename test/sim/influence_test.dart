import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/sim/facts.dart';
import 'package:llama_village/sim/influence.dart';

import 'harness.dart';

void main() {
  test('harmony is the mean of the twenty directed friendships among the five', () {
    final v = testVillage();
    expect(harmonyOf(v), closeTo(42 / 20, 1e-9), reason: 'the cast starts at 42 summed over 20 pairs');
    for (final l in v.cast) {
      for (final n in llamaNames) {
        if (n != l.name) l.friendship[n] = 4;
      }
      l.friendship['Dash'] = -10;
    }
    expect(harmonyOf(v), 4, reason: 'friendship toward Dash does not count');
    v.byName('Pip').friendship['Mo'] = -6;
    expect(harmonyOf(v), closeTo((19 * 4 - 6) / 20, 1e-9));
  });

  test('false beliefs count believing llamas per false fact, never Dash', () {
    final v = testVillage();
    final start = falseBeliefsOf(v);
    expect([for (final b in start) b.believer]..sort(), ['Clover', 'Pip']);
    expect(start.every((b) => b.factId == 'bread_rumour'), isTrue);

    v.newFact('dash_rumour1', 'Mo stole a pie.', 'the pie', kind: FactKind.rumour, truth: false, origin: 'Dash');
    v.kb.learn('Dash', 'dash_rumour1', 'own', v.now, believes: false);
    v.kb.learn('June', 'dash_rumour1', 'told', v.now, from: 'Dash');
    v.kb.learn('Mo', 'dash_rumour1', 'told', v.now, from: 'Dash', believes: false);
    expect(falseBeliefsOf(v).length, 3);

    v.kb.learn('Pip', 'bread_truth', 'told', v.now, from: 'Dash');
    expect(falseBeliefsOf(v).map((b) => b.believer), isNot(contains('Pip')), reason: 'the truth drops the rumour');
  });

  test('Pip and Mo reconcile only when they like each other, the scarf is back and the rumour is gone', () {
    final v = testVillage();
    final pip = v.byName('Pip'), mo = v.byName('Mo');
    expect(pipMoArc(v), PipMoArc.unresolved);
    pip.friendship['Mo'] = 4;
    mo.friendship['Pip'] = 6;
    v.scarf.state = 'returned';
    v.kb.learn('Pip', 'bread_truth', 'told', v.now, from: 'Bramble');
    expect(pipMoArc(v), PipMoArc.reconciled);
    v.scarf.state = 'missing';
    expect(pipMoArc(v), PipMoArc.unresolved);
    mo.friendship['Pip'] = -3;
    expect(pipMoArc(v), PipMoArc.rift);
  });

  test('a reconciliation needs Pip to stop believing the bread rumour', () {
    final v = testVillage();
    v.byName('Pip').friendship['Mo'] = 5;
    v.byName('Mo').friendship['Pip'] = 5;
    v.scarf.state = 'returned';
    expect(pipMoArc(v), PipMoArc.unresolved);
  });

  test("Bramble's arc follows the crush thread", () {
    final v = testVillage();
    expect(brambleArc(v), BrambleArc.secret);
    v.crush.state = 'exposed';
    expect(brambleArc(v), BrambleArc.revealed);
    v.crush
      ..state = 'let down gently'
      ..revealedBy = 'June';
    expect(brambleArc(v), BrambleArc.exposedDeclined);
    v.crush.revealedBy = 'Bramble';
    expect(brambleArc(v), BrambleArc.declined);
    v.crush.state = 'accepted';
    expect(brambleArc(v), BrambleArc.accepted);
  });

  test('measure reads trust in Dash per llama and the festival result', () {
    final v = testVillage();
    v.byName('June').friendship['Dash'] = 4;
    v.byName('Mo').friendship['Dash'] = -2;
    var i = measure(v);
    expect(i.dashTrust, {'Pip': 0, 'Mo': -2, 'June': 4, 'Bramble': 0, 'Clover': 0});
    expect(i.meanTrust, closeTo(0.4, 1e-9));
    expect(i.festivalHeld, isFalse);
    v.festival
      ..state = 'judged'
      ..winner = 'Mo';
    i = measure(v);
    expect(i.festivalHeld, isTrue);
    expect(i.festivalWinner, 'Mo');
  });
}

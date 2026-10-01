import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/sim/endings.dart';
import 'package:llama_village/sim/influence.dart';

Influence influence({
  double harmony = 2,
  int falseBeliefs = 0,
  PipMoArc pipMo = PipMoArc.unresolved,
  BrambleArc bramble = BrambleArc.secret,
  int trust = 2,
  bool festival = true,
}) => Influence(
  harmony: harmony,
  falseBeliefs: [for (var i = 0; i < falseBeliefs; i++) FalseBelief('f$i', 'lie $i', llamaNames[i % 5])],
  pipMo: pipMo,
  bramble: bramble,
  dashTrust: {for (final n in llamaNames) n: trust},
  festivalWinner: festival ? 'Pip' : null,
  festivalHeld: festival,
);

void main() {
  test('a kind, truthful, trusted week with a festival winner is the Harmony Festival', () {
    final v = decideEnding(influence());
    expect(v.ending, Ending.harmonyFestival);
    expect(v.reasons, hasLength(4));
  });

  test('Harmony needs every condition at its threshold', () {
    expect(decideEnding(influence(harmony: harmonyNeeded)).ending, Ending.harmonyFestival);
    expect(decideEnding(influence(harmony: harmonyNeeded - 0.01)).ending, Ending.quietValley);
    expect(decideEnding(influence(falseBeliefs: 1)).ending, Ending.quietValley);
    expect(decideEnding(influence(trust: 1)).ending, Ending.quietValley);
    expect(decideEnding(influence(festival: false)).ending, Ending.quietValley);
    expect(decideEnding(influence(pipMo: PipMoArc.rift)).ending, Ending.quietValley, reason: 'a Pip-Mo rift spoils harmony');
    expect(
      decideEnding(influence(bramble: BrambleArc.exposedDeclined)).ending,
      Ending.harmonyFestival,
      reason: "Bramble's crush going badly alone does not",
    );
  });

  test('enough lies make Drama Llama on their own', () {
    expect(decideEnding(influence(falseBeliefs: dramaFalseBeliefs - 1)).ending, Ending.quietValley);
    final v = decideEnding(influence(falseBeliefs: dramaFalseBeliefs));
    expect(v.ending, Ending.dramaLlama);
    expect(v.reasons.single, contains('false beliefs'));
  });

  test('two other drama signs make Drama Llama; one does not', () {
    expect(decideEnding(influence(harmony: sourHarmony - 0.1)).ending, Ending.quietValley);
    expect(decideEnding(influence(harmony: sourHarmony - 0.1, pipMo: PipMoArc.rift)).ending, Ending.dramaLlama);
    expect(decideEnding(influence(bramble: BrambleArc.exposedDeclined, festival: false)).ending, Ending.dramaLlama);
    expect(decideEnding(influence(bramble: BrambleArc.declined, festival: false)).ending, Ending.quietValley);
  });

  test('a week where Dash did nothing is the Quiet Valley, and says why', () {
    final v = decideEnding(influence(trust: 0, falseBeliefs: 2));
    expect(v.ending, Ending.quietValley);
    expect(v.reasons, containsAll(['2 false beliefs left', 'trust in Dash only 0.0']));
  });

  test('every ending has gallery copy', () {
    for (final e in Ending.values) {
      expect(endingInfo[e]!.title, isNotEmpty);
      expect(endingInfo[e]!.hint, isNotEmpty);
    }
  });
}

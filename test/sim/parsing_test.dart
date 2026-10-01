import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/sim/clock.dart';
import 'package:llama_village/sim/dash.dart';
import 'package:llama_village/sim/dialogue.dart';
import 'package:llama_village/sim/facts.dart';
import 'package:llama_village/sim/village.dart';

void main() {
  test('parseLine strips names, quotes and markdown and keeps two sentences', () {
    expect(parseLine('Pip: "Oh, **darling**! You look divine. Truly. Again."', ['Pip']), 'Oh, darling! You look divine.');
    expect(parseLine('Hi', ['Pip']), isNull);
    expect(parseLine('Same old line here.', ['Pip'], previous: ['same old line here']), isNull);
  });

  test('parseSchedule needs five usable blocks', () {
    const raw = '06 bakery | bake\n08 pond | swim\n10:00 hilltop - look\n12 home | lunch\n14 berry bushes | pick\nnonsense';
    final plan = parseSchedule(raw, [6, 8, 10, 12, 14, 16, 18, 20])!;
    expect(plan[10], ('hilltop', 'look'));
    expect(plan[14]!.$1, 'berry bushes');
    expect(parseSchedule('06 bakery | bake', [6, 8]), isNull);
  });

  test('Dash\'s options come from the grammar\'s JSON, in the requested order', () {
    final picked = ['gossip', 'compliment', 'help', 'tease'];
    final o = dashOptionsFrom(
      {
        'compliment': 'You look lovely today, Mo.',
        'gossip': 'June hides berries under her bed.',
        'help': '<Can I knead some dough?>',
        'tease': 'hi',
      },
      picked,
      about: 'June',
    )!;
    expect(o.map((x) => x.intent), ['gossip', 'compliment', 'help']);
    expect(o.first.about, 'June');
    expect(o.last.text, 'Can I knead some dough?');
    expect(dashOptionsFrom({'compliment': 'You look lovely today.'}, picked), isNull);
    final schema = dashOptionSchema(picked);
    expect(schema['required'], picked);
    expect((schema['properties'] as Map).keys, picked);
  });

  test('believing a disproof drops belief in the rumour, and its owner cannot clear it alone', () {
    final kb = KnowledgeBase();
    kb.add(Fact(id: 'r', text: 'rumour', truth: false, origin: 'June', kind: FactKind.rumour, created: backstory, short: 'r'));
    kb.add(
      Fact(
        id: 't',
        text: 'truth',
        truth: true,
        origin: 'Mo',
        kind: FactKind.news,
        created: backstory,
        short: 't',
        contradicts: 'r',
        interested: 'Mo',
      ),
    );
    const t = GameTime(1, 400);
    kb.learn('Pip', 'r', 'told', t, from: 'June');
    kb.learn('Pip', 't', 'told', t, from: 'Mo');
    expect(kb.believes('Pip', 'r'), isTrue, reason: 'Mo clearing his own name does not convince Pip');
    kb.learn('Clover', 'r', 'told', t, from: 'June');
    kb.learn('Clover', 't', 'told', t, from: 'Bramble');
    expect(kb.believes('Clover', 'r'), isFalse);
    expect(kb.believes('Clover', 't'), isTrue);
  });

  test('how a fact was learned reads as the inspector tag', () {
    expect(howLearned(Knowing('told', 'June', backstory, believes: true), own: false), 'heard from June; maybe untrue');
    expect(howLearned(Knowing('told', 'June', backstory, believes: false), own: false), 'heard from June; does not believe it');
    expect(howLearned(Knowing('own', null, backstory, believes: true), own: true), 'own secret');
    expect(howLearned(Knowing('saw', null, backstory, believes: true), own: false), 'saw it');
  });

  test('game time labels and relative times', () {
    const t = GameTime(2, 9 * 60 + 5);
    expect(t.label, 'D2 09:05');
    expect(t.plus(15 * 60).label, 'D3 00:05');
    expect(t.relative(const GameTime(1, 19 * 60)), 'yesterday evening');
    expect(t.relative(const GameTime(2, 9 * 60)), 'just now');
  });
}

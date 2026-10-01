import 'village.dart';

const List<String> llamaNames = ['Pip', 'Mo', 'June', 'Bramble', 'Clover'];

/// Where Pip and Mo stand at the end of the week.
enum PipMoArc { reconciled, unresolved, rift }

/// How Bramble's secret crush on June played out.
enum BrambleArc { secret, revealed, accepted, declined, exposedDeclined }

/// A false fact a llama still believes.
class FalseBelief {
  const FalseBelief(this.factId, this.short, this.believer);
  final String factId;
  final String short;
  final String believer;
}

/// What Dash changed, read off the sim state. Every number here is a pure
/// function of the village, so the endings rules can be tested on it.
class Influence {
  const Influence({
    required this.harmony,
    required this.falseBeliefs,
    required this.pipMo,
    required this.bramble,
    required this.dashTrust,
    required this.festivalWinner,
    required this.festivalHeld,
  });

  /// Mean friendship among the five llamas (both directions), -10..10.
  final double harmony;
  final List<FalseBelief> falseBeliefs;
  final PipMoArc pipMo;
  final BrambleArc bramble;

  /// Each llama's friendship toward Dash, -10..10.
  final Map<String, int> dashTrust;
  final String? festivalWinner;
  final bool festivalHeld;

  double get meanTrust => dashTrust.isEmpty ? 0 : dashTrust.values.fold<int>(0, (a, b) => a + b) / dashTrust.length;

  Map<String, Object?> toJson() => {
    'harmony': harmony,
    'falseBeliefs': [for (final b in falseBeliefs) '${b.believer}: ${b.short}'],
    'pipMo': pipMo.name,
    'bramble': bramble.name,
    'dashTrust': dashTrust,
    'festivalWinner': festivalWinner,
    'festivalHeld': festivalHeld,
  };
}

/// Mean of every directed friendship between two of the five llamas.
double harmonyOf(Village v) {
  var sum = 0, n = 0;
  for (final a in llamaNames) {
    for (final b in llamaNames) {
      if (a == b) continue;
      sum += v.byName(a).friendship[b] ?? 0;
      n++;
    }
  }
  return sum / n;
}

/// Every (false fact, llama) pair where the llama still believes it. Dash
/// knows its own lies are lies, so it is never counted.
List<FalseBelief> falseBeliefsOf(Village v) => [
  for (final f in v.kb.facts.values)
    if (!f.truth)
      for (final n in llamaNames)
        if (v.kb.believes(n, f.id)) FalseBelief(f.id, f.short, n),
];

/// Reconciled: both like each other (3+), the scarf is back and Pip no
/// longer believes the bread rumour. Rift: either one dislikes the other (-3
/// or lower).
PipMoArc pipMoArc(Village v) {
  final pip = v.byName('Pip').friendship['Mo'] ?? 0;
  final mo = v.byName('Mo').friendship['Pip'] ?? 0;
  if (pip <= -3 || mo <= -3) return PipMoArc.rift;
  if (pip >= 3 && mo >= 3 && v.scarf.state == 'returned' && !v.kb.believes('Pip', 'bread_rumour')) return PipMoArc.reconciled;
  return PipMoArc.unresolved;
}

BrambleArc brambleArc(Village v) {
  final c = v.crush;
  return switch (c.state) {
    'accepted' => BrambleArc.accepted,
    'let down gently' => c.revealedBy == 'Bramble' ? BrambleArc.declined : BrambleArc.exposedDeclined,
    'confessed' || 'exposed' => BrambleArc.revealed,
    _ => BrambleArc.secret,
  };
}

Influence measure(Village v) => Influence(
  harmony: harmonyOf(v),
  falseBeliefs: falseBeliefsOf(v),
  pipMo: pipMoArc(v),
  bramble: brambleArc(v),
  dashTrust: {for (final n in llamaNames) n: v.byName(n).friendship['Dash'] ?? 0},
  festivalWinner: v.festival.winner,
  festivalHeld: v.festival.state == 'judged' && v.festival.winner != null,
);

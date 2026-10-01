import 'influence.dart';

enum Ending { harmonyFestival, dramaLlama, quietValley }

/// Gallery copy for one ending.
class EndingInfo {
  const EndingInfo(this.title, this.blurb, this.hint);
  final String title;
  final String blurb;

  /// Shown on the locked silhouette.
  final String hint;
}

const Map<Ending, EndingInfo> endingInfo = {
  Ending.harmonyFestival: EndingInfo(
    'Harmony Festival',
    'Every rumour put right, every llama on the hilltop, and the lanterns burn till dawn.',
    'Win the llamas over, set the record straight, and bring them closer.',
  ),
  Ending.dramaLlama: EndingInfo(
    'Drama Llama',
    'Whispers, feuds and a festival nobody will forget, for all the wrong reasons.',
    'A little bird with a loose beak can stir up a lot.',
  ),
  Ending.quietValley: EndingInfo(
    'Quiet Valley',
    'The week passed gently. Dash watched, and the valley mostly minded its own business.',
    'Sometimes the valley is happiest left alone.',
  ),
};

/// The thresholds the rules use.
const int dramaFalseBeliefs = 4;
const double sourHarmony = 0.5;
const double harmonyNeeded = 1.5;
const double trustNeeded = 1.5;

/// The ending, with the reasons that decided it (for the results screen).
class EndingVerdict {
  const EndingVerdict(this.ending, this.reasons);
  final Ending ending;
  final List<String> reasons;
}

/// Signs of drama: lies in circulation, soured friendships, a Pip-Mo rift,
/// a crush aired by someone else and turned down, a festival without a
/// winner.
List<String> dramaSigns(Influence i) => [
  if (i.falseBeliefs.length >= dramaFalseBeliefs) '${i.falseBeliefs.length} false beliefs still going round',
  if (i.harmony < sourHarmony) 'friendships soured (harmony ${i.harmony.toStringAsFixed(1)})',
  if (i.pipMo == PipMoArc.rift) 'Pip and Mo fell out',
  if (i.bramble == BrambleArc.exposedDeclined) "Bramble's crush was aired by someone else, and June said no",
  if (!i.festivalHeld) 'the festival had no winner',
];

/// The rules, in order:
///
/// 1. Drama Llama: at least [dramaFalseBeliefs] false beliefs, or two or
///    more other [dramaSigns].
/// 2. Harmony Festival: the festival crowned a winner, no false belief is
///    left, harmony is at least [harmonyNeeded], mean trust in Dash at least
///    [trustNeeded], and Pip and Mo did not fall out. (A single other sign,
///    such as Bramble's crush going badly, does not spoil it.)
/// 3. Quiet Valley otherwise.
EndingVerdict decideEnding(Influence i) {
  final signs = dramaSigns(i);
  if (i.falseBeliefs.length >= dramaFalseBeliefs || signs.length >= 2) return EndingVerdict(Ending.dramaLlama, signs);
  final harmony = <String>[
    if (i.festivalHeld) 'the festival crowned ${i.festivalWinner}',
    if (i.falseBeliefs.isEmpty) 'every false rumour was put right',
    if (i.harmony >= harmonyNeeded) 'harmony ${i.harmony.toStringAsFixed(1)}',
    if (i.meanTrust >= trustNeeded) 'the llamas trust Dash (${i.meanTrust.toStringAsFixed(1)})',
  ];
  final rift = i.pipMo == PipMoArc.rift;
  if (!rift && harmony.length == 4) return EndingVerdict(Ending.harmonyFestival, harmony);
  return EndingVerdict(Ending.quietValley, [
    ...signs,
    if (i.falseBeliefs.isNotEmpty) '${i.falseBeliefs.length} false belief${i.falseBeliefs.length == 1 ? '' : 's'} left',
    if (i.harmony < harmonyNeeded) 'harmony only ${i.harmony.toStringAsFixed(1)}',
    if (i.meanTrust < trustNeeded) 'trust in Dash only ${i.meanTrust.toStringAsFixed(1)}',
  ]);
}

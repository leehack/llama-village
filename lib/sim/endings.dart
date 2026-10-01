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

/// One reason behind an ending, for the results screen and the drama
/// ending's captions. [kind]: falseBeliefs, soured, rift, crushExposed,
/// noWinner, crowned, allRight, harmony, trust, beliefsLeft, harmonyOnly or
/// trustOnly.
class EndingReason {
  const EndingReason(this.kind, {this.count, this.value, this.name});
  final String kind;
  final int? count;
  final double? value;
  final String? name;

  String get english {
    final v = value?.toStringAsFixed(1);
    return switch (kind) {
      'falseBeliefs' => '$count false beliefs still going round',
      'soured' => 'friendships soured (harmony $v)',
      'rift' => 'Pip and Mo fell out',
      'crushExposed' => "Bramble's crush was aired by someone else, and June said no",
      'noWinner' => 'the festival had no winner',
      'crowned' => 'the festival crowned $name',
      'allRight' => 'every false rumour was put right',
      'harmony' => 'harmony $v',
      'trust' => 'the llamas trust Dash ($v)',
      'beliefsLeft' => '$count false belief${count == 1 ? '' : 's'} left',
      'harmonyOnly' => 'harmony only $v',
      'trustOnly' => 'trust in Dash only $v',
      _ => kind,
    };
  }

  @override
  String toString() => english;
}

/// The ending, with the reasons that decided it (for the results screen).
class EndingVerdict {
  const EndingVerdict(this.ending, this.why);
  final Ending ending;
  final List<EndingReason> why;

  List<String> get reasons => [for (final r in why) r.english];
}

/// Signs of drama: lies in circulation, soured friendships, a Pip-Mo rift,
/// a crush aired by someone else and turned down, a festival without a
/// winner.
List<EndingReason> dramaSigns(Influence i) => [
  if (i.falseBeliefs.length >= dramaFalseBeliefs) EndingReason('falseBeliefs', count: i.falseBeliefs.length),
  if (i.harmony < sourHarmony) EndingReason('soured', value: i.harmony),
  if (i.pipMo == PipMoArc.rift) const EndingReason('rift'),
  if (i.bramble == BrambleArc.exposedDeclined) const EndingReason('crushExposed'),
  if (!i.festivalHeld) const EndingReason('noWinner'),
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
  final harmony = <EndingReason>[
    if (i.festivalHeld) EndingReason('crowned', name: i.festivalWinner),
    if (i.falseBeliefs.isEmpty) const EndingReason('allRight'),
    if (i.harmony >= harmonyNeeded) EndingReason('harmony', value: i.harmony),
    if (i.meanTrust >= trustNeeded) EndingReason('trust', value: i.meanTrust),
  ];
  final rift = i.pipMo == PipMoArc.rift;
  if (!rift && harmony.length == 4) return EndingVerdict(Ending.harmonyFestival, harmony);
  return EndingVerdict(Ending.quietValley, [
    ...signs,
    if (i.falseBeliefs.isNotEmpty) EndingReason('beliefsLeft', count: i.falseBeliefs.length),
    if (i.harmony < harmonyNeeded) EndingReason('harmonyOnly', value: i.harmony),
    if (i.meanTrust < trustNeeded) EndingReason('trustOnly', value: i.meanTrust),
  ]);
}

/// The templates of the sentences the sim shows the player. Each has a
/// `say…` message in the ARB files (see `SimWords.say` in the UI).
enum SaidKey {
  /// Text that needs no template: a model-written line, or a save's text
  /// from before templates.
  raw,

  scarfMissingTitle,
  scarfMissingHome,
  scarfMissingAway,
  scarfFoundTitle,
  scarfFound,
  scarfReturnedTitle,
  scarfReturned,
  festivalAnnouncedTitle,
  festivalAnnounced,
  pipSignsUpTitle,
  pipSignsUp,
  festivalTitle,
  festivalGathers,
  festivalNoSingers,
  pipSingsTitle,
  pipSings,
  moFaintsTitle,
  moFaints,
  singsTitle,
  moSings,
  llamaSings,
  goldenBellTitle,
  goldenBell,
  goldenBellStory,
  stormTitle,
  storm,
  stormClearsTitle,
  stormClears,
  honeyLoafTitle,
  honeyLoaf,
  rehearsalTitle,
  rehearsalEmpty,
  rehearsal,
  lanternsTitle,
  lanterns,

  logEvent,
  logEventSeen,
  talkStarted,
  talkStartedAbout,
  nowKnows,
  nowKnowsDoubts,
  overheard,
  sawArgue,
  dashVisit,
  dashEffect,
  threadTurn,
  threadNote,

  whyPipNoticed,
  whyPipFoundHerself,
  whyFoundIt,
  whyGaveBack,
  whyAnnounced,
  whyJoinedPip,
  whyNoSingers,
  whySang,
  whyWon,
  whyNoWinner,
  howNobodySang,
  howDeal,
  howDealKnown,
  howFair,
  whyJuneFoundPoem,
  whyJuneSawFlowers,
  whyBrambleTold,
  whyJuneHeard,
  whyJuneOverheard,
  whyJuneHeardFlowers,
  whyCrushConfessed,
  whyCrushExposed,
  whyNobodyBelieves,
  whyJuneExposed,
  whyStormArrived,
  whySkyCleared,
  whyDay,
  confMoTold,
  confPipOverheard,
  confPipLearned,

  searchNothing,
  pondNothing,
  signsUp,
  howToldClover,
  howCloverTalked,
  moBraver,
  moTookBack,
  juneFindsPoem,
  flowersUnseen,
  flowersSeen,
  sayGoodnight,
  breakOffFestival,
  morning,
  liesAwake,
  hearsPip,
  planned,

  goalFetchScarf,
  goalAskSeen,
  goalFindScarf,
  goalSearchScarf,
  goalMoFish,
  goalHelpPip,
  goalGiveBackMo,
  goalGiveBack,
  goalMoGuilty,
  goalBeAtFestival,
  goalSetUpStage,
  goalRecruitMo,
  goalTellClover,
  goalMoScared,
  goalMoTempted,
  goalMoAlmost,
  goalPractise,
  goalWinBell,
  goalLeaveFlowers,
  goalTellJune,
  goalFindWhoFlowers,
  goalTalkBramble,
  goalFaceJune,
  goalSpreadRumour,
  goalClearName,
  goalSetRecord,
  goalWarnToday,
  goalWarnDay,
  goalRunRehearsal,
  goalGoRehearsal,

  whyHunger,
  whyEnergy,
  whyPlanWork,
  whyAtWorkplace,
  whyNight,
  whyPlan,
  whyWaiting,
  whyFood,
  whyRest,
  whyWork,
  whyCompany,
  whyBedtime,
  whyShelter,
  whyNothing,

  storyThread,
  storyTalk,
  storyTalkAbout,
  storyConfided,
  storyHeard,
  storyGossip,
  storyDash,

  factPipTune,
  factMoScarf,
  factScarfWhere,
  factJuneRumour,
  factBreadRumour,
  factBreadTruth,
  factBramblePoems,
  factWildflowers,
  factCloverDeal,
  factStormForecast,
  factMoVoice,
  factHoneyLoaf,
  factRehearsal,
  factRehearsalEmpty,
  factLanterns,
  factScarfMissing,
  factScarfFound,
  factScarfReturned,
  factFestival,
  factSigned,
  factMoFainted,
  factFestivalWinner,
  factAnonPoem,
  factBrambleFlowers,
  factStormHit,
  factBrambleRight,
  factStormPassed,
  factGift,
  factArgument,

  endWeek,
  endNoWinner,
  endRumoursNone,
  endRumoursFew,
  endRumoursMany,
  endFond,
  endSoured,
  endMixed,
  endArc,
  endHappiest,
  endDashCross,
  endDashFond,
  endDashUnsure,
  quietDay,
}

/// A sentence the player reads, kept as a template and its arguments so the
/// UI can say it in the player's language. [english] is the sim's own
/// wording, which prompts, transcripts and the sim's logic keep using.
///
/// Arguments are JSON values: names, place ids, numbers, lists of names, and
/// nested [Said]s (as their JSON).
class Said {
  const Said(this.key, this.english, [this.args = const {}]);

  /// Text shown as it is in every language.
  const Said.raw(this.english) : key = SaidKey.raw, args = const {};

  final SaidKey key;
  final String english;
  final Map<String, Object?> args;

  String str(String name) => args[name] as String? ?? '';
  int number(String name) => (args[name] as num?)?.toInt() ?? 0;
  List<String> names(String name) => (args[name] as List?)?.cast<String>() ?? const [];
  Said? said(String name) => switch (args[name]) {
    final Said s => s,
    final Map<Object?, Object?> m => Said.fromJson(m.cast<String, Object?>()),
    _ => null,
  };
  List<Said> saids(String name) => [
    for (final s in (args[name] as List?) ?? const [])
      if (s is Said) s else Said.fromJson((s as Map).cast<String, Object?>()),
  ];

  Map<String, Object?> toJson() => {
    'k': key.name,
    'en': english,
    if (args.isNotEmpty) 'a': {for (final e in args.entries) e.key: _json(e.value)},
  };

  /// A save's sentence; a template this build no longer has reads as its
  /// English.
  static Said fromJson(Map<String, Object?> j) {
    final key = SaidKey.values.asNameMap()[j['k']];
    final english = j['en'] as String? ?? '';
    if (key == null) return Said.raw(english);
    return Said(key, english, (j['a'] as Map?)?.cast<String, Object?>() ?? const {});
  }

  static Said? maybe(Object? j) => j is Map ? fromJson(j.cast<String, Object?>()) : null;

  @override
  String toString() => english;
}

Object? _json(Object? v) => switch (v) {
  final Said s => s.toJson(),
  final List<Object?> l => [for (final x in l) _json(x)],
  _ => v,
};

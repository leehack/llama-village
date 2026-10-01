import 'package:intl/intl.dart';

import '../game/save_store.dart';
import '../l10n/app_localizations.dart';
import '../sim/cast.dart';
import '../sim/clock.dart';
import '../sim/dash.dart';
import '../sim/endings.dart';
import '../sim/laya_roles.dart';
import '../sim/places.dart';
import '../sim/said.dart';
import '../sim/village.dart';

/// The sim's English names and labels, said in the player's language.
extension SimWords on L10n {
  /// "the pond", "Pip's hut".
  String placeName(String place) {
    if (isHut(place)) return hut(place.substring(0, place.length - "'s hut".length));
    return this.place(place == 'berry bushes' ? 'berryBushes' : place);
  }

  /// "3 days to the festival", "after the festival".
  String countdownFor(int day) {
    final left = festivalDay - day;
    return left < 0 ? afterFestival : countdown(left);
  }

  /// The subtitle of a morning's "Day N" card.
  String dayCardLine(int day) {
    final left = festivalDay - day;
    return left < 0 ? afterFestival : countdownTitle(left);
  }

  String number(double v) => NumberFormat('0.0', localeName).format(v);

  String moodOf(Llama l) => mood(l.moodWord);

  String reaction(String name, int level) => reactionLine(name, reactionLevels[level]);

  /// A fact's short label: localised for the story's facts, else the sim's
  /// English.
  String factLabel(String id, String short) {
    final m = RegExp(r"^(\w+) and (\w+) arguing$").firstMatch(short);
    if (id.startsWith('argument') && m != null) return factArgument(m.group(1)!, m.group(2)!);
    if (id.startsWith('gift')) return factDashGift(short.replaceFirst("Dash's gift to ", ''));
    if (id.startsWith('dash_rumour')) return factDashRumour(short.replaceFirst('what Dash said about ', ''));
    if (id.endsWith('_signed')) return factSigned(short.replaceFirst(' entering the contest', ''));
    return switch (id) {
      'pip_tune' => factPipTune,
      'mo_scarf' => factMoScarf,
      'scarf_where' => factScarfWhere,
      'june_rumour' => factJuneRumour,
      'bread_rumour' => factBreadRumour,
      'bread_truth' => factBreadTruth,
      'bramble_poems' => factBramblePoems,
      'wildflowers' => factWildflowers,
      'clover_deal' => factCloverDeal,
      'storm_forecast' => factStormForecast,
      'mo_voice' => factMoVoice,
      'honey_loaf' => factHoneyLoaf,
      'rehearsal' => factRehearsal,
      'lanterns' => factLanterns,
      'scarf_missing' => factScarfMissing,
      'scarf_found' => factScarfFound,
      'scarf_returned' => factScarfReturned,
      'festival' => factFestival,
      'mo_fainted' => factMoFainted,
      'festival_winner' => factFestivalWinner,
      'anon_poem' => factAnonPoem,
      'bramble_flowers' => factBrambleFlowers,
      'storm_hit' => factStormHit,
      'bramble_right' => factBrambleRight,
      'storm_passed' => factStormPassed,
      _ => short,
    };
  }

  /// The inspector's "how learned" tag.
  String howOf(KnownFact k) {
    final knowing = k.knowing;
    if (knowing == null) return k.how;
    final from = knowing.from ?? '';
    return switch (knowing.how) {
      'own' when k.own => howOwnSecret,
      'own' => howKnows,
      'saw' => howSaw,
      'announced' => howAnnounced,
      'overheard' when !knowing.believes => howOverheardDoubt(from),
      'overheard' => howOverheard(from),
      _ when !knowing.believes => howHeardDoubt(from),
      _ => howHeard(from),
    };
  }

  /// What a llama is doing, as the inspector says it.
  String activityOf(Village v, Llama l) {
    final a = l.activity;
    final why = localeName == 'en' && a.label != null && a.label!.isNotEmpty ? ' (${a.label})' : '';
    return switch (a.kind) {
      'walk' => '${activityWalk(placeName(a.dest!))}$why',
      'talk' => activityTalk(a.with_ ?? '', placeName(l.place)),
      'sleep' => activitySleep(placeName(l.place)),
      'idle' => activityIdle(placeName(l.place)),
      _ => '${activityAt(a.kind, placeName(l.place))}$why',
    };
  }

  String choiceOf(DecisionOption o) => o.dest == null ? choice(o.kind) : choiceTo(choice(o.kind), placeName(o.dest!));

  String effectOf(DashEffect e) => switch (e.kind) {
    'trust' => effectTrust(e.name, _signed(e.delta!), e.now!, _signed(e.mood!)),
    'rumour' => e.believes! ? effectRumourBelieved(e.name, e.about!) : effectRumourDoubted(e.name, e.about!),
    'praise' => e.believes! ? effectWarms(e.name, e.about!) : effectShrugs(e.name, e.about!),
    'knows' => effectNowKnows(e.name, factLabel(e.fact!, e.short!)),
    'confides' => effectConfides(e.name, factLabel(e.fact!, e.short!)),
    'work' => effectWork(e.name),
    'courage' => effectCourage(e.now!),
    _ => e.english,
  };

  String noticeOf(DashNotice n) => switch (n.kind) {
    'asleep' => noticeAsleep(n.name),
    'rush' => noticeRush(n.name),
    'fellAsleep' => noticeFellAsleep(n.name),
    'catchUp' => noticeCatchUp(n.name),
    'waitTalk' => noticeWaitTalk(n.name),
    'hurriesOff' => noticeHurriesOff(n.name),
    _ => n.english,
  };

  String reasonOf(EndingReason r) => switch (r.kind) {
    'falseBeliefs' => reasonFalseBeliefs(r.count!),
    'soured' => reasonSoured(number(r.value!)),
    'rift' => reasonRift,
    'crushExposed' => reasonCrushExposed,
    'noWinner' => reasonNoWinner,
    'crowned' => reasonCrowned(r.name ?? ''),
    'allRight' => reasonAllRight,
    'harmony' => reasonHarmony(number(r.value!)),
    'trust' => reasonTrust(number(r.value!)),
    'beliefsLeft' => reasonBeliefsLeft(r.count!),
    'harmonyOnly' => reasonHarmonyOnly(number(r.value!)),
    'trustOnly' => reasonTrustOnly(number(r.value!)),
    _ => r.english,
  };

  /// "Pip and Mo", "Pip, Mo et June".
  String names(List<String> names) => names.length < 2 ? names.join() : sayAnd(names.sublist(0, names.length - 1).join(', '), names.last);

  /// Where something happens: "at the pond", "연못에서", "à l'étang".
  String at(String place) {
    if (isHut(place)) return sayAt('hut', place.substring(0, place.length - "'s hut".length));
    return sayAt(place == 'berry bushes' ? 'berryBushes' : place, '');
  }

  String _state(String state) {
    final day = RegExp(r'^day (\d+)$').firstMatch(state);
    if (day != null) return sayThreadDay(day.group(1)!);
    return sayThreadState(switch (state) {
      'poem found' => 'poemFound',
      'let down gently' => 'letDownGently',
      'june exposed' => 'juneExposed',
      _ => state,
    });
  }

  String _item(String item) => sayItem(_items[item] ?? item);

  /// A sentence to embed before a full stop of the template's own.
  String _clause(Said? s) => s == null ? '' : say(s).trim().replaceFirst(RegExp(r'[.!。]+$'), '');

  /// A sim sentence in the player's language.
  String say(Said s) {
    String a(String n) => s.str(n);
    String n(String k) => '${s.args[k] ?? ''}';
    String sub(String k) => s.said(k) == null ? '' : say(s.said(k)!);
    String fact() => factLabel(a('fact'), a('short'));
    return switch (s.key) {
      SaidKey.raw => s.english,
      SaidKey.scarfMissingTitle => sayScarfMissingTitle,
      SaidKey.scarfMissingHome => sayScarfMissingHome,
      SaidKey.scarfMissingAway => sayScarfMissingAway,
      SaidKey.scarfFoundTitle => sayScarfFoundTitle,
      SaidKey.scarfFound => sayScarfFound(a('name')),
      SaidKey.scarfReturnedTitle => sayScarfReturnedTitle,
      SaidKey.scarfReturned => sayScarfReturned(a('name')),
      SaidKey.festivalAnnouncedTitle => sayFestivalAnnouncedTitle,
      SaidKey.festivalAnnounced => sayFestivalAnnounced(n('day')),
      SaidKey.pipSignsUpTitle => sayPipSignsUpTitle,
      SaidKey.pipSignsUp => sayPipSignsUp,
      SaidKey.festivalTitle => sayFestivalTitle,
      SaidKey.festivalGathers => sayFestivalGathers(n('count'), names(s.names('names'))),
      SaidKey.festivalNoSingers => sayFestivalNoSingers(n('count')),
      SaidKey.pipSingsTitle => sayPipSingsTitle,
      SaidKey.pipSings => pipSings,
      SaidKey.moFaintsTitle => sayMoFaintsTitle,
      SaidKey.moFaints => moFaints,
      SaidKey.singsTitle => saySingsTitle(a('name')),
      SaidKey.moSings => moSings,
      SaidKey.llamaSings => llamaSings(a('name')),
      SaidKey.goldenBellTitle => sayGoldenBellTitle,
      SaidKey.goldenBell => sayGoldenBell(a('name'), a('scores')),
      SaidKey.goldenBellStory => sayGoldenBellStory(a('name')),
      SaidKey.stormTitle => sayStormTitle,
      SaidKey.storm => sayStorm,
      SaidKey.stormClearsTitle => sayStormClearsTitle,
      SaidKey.stormClears => sayStormClears,
      SaidKey.honeyLoafTitle => sayHoneyLoafTitle,
      SaidKey.honeyLoaf => sayHoneyLoaf,
      SaidKey.rehearsalTitle => sayRehearsalTitle,
      SaidKey.rehearsalEmpty => sayRehearsalEmpty,
      SaidKey.rehearsal => sayRehearsal,
      SaidKey.lanternsTitle => sayLanternsTitle,
      SaidKey.lanterns => sayLanterns,
      SaidKey.logEvent => sayLogEvent(sub('title'), sub('text')),
      SaidKey.logEventSeen => sayLogEventSeen(sub('title'), sub('text'), names(s.names('seen'))),
      SaidKey.talkStarted => sayTalkStarted(a('a'), a('b'), at(a('place'))),
      SaidKey.talkStartedAbout => sayTalkStartedAbout(a('a'), a('b'), at(a('place')), fact()),
      SaidKey.nowKnows => sayNowKnows(a('name'), fact()),
      SaidKey.nowKnowsDoubts => sayNowKnowsDoubts(a('name'), fact()),
      SaidKey.overheard => sayOverheard(a('name'), fact()),
      SaidKey.sawArgue => saySawArgue(names(s.names('names'))),
      SaidKey.dashVisit => [
        reaction(a('name'), s.number('level')).replaceFirst(RegExp(r'[.。]$'), ''),
        ...s.saids('effects').map(say),
      ].join(' · '),
      SaidKey.dashEffect => effectOf(DashEffect.fromArgs(s.args)),
      SaidKey.threadTurn => sayThreadTurn(sayThreadTitle(a('thread')), _state(a('from')), _state(a('to')), _clause(s.said('why'))),
      SaidKey.threadNote => sayThreadNote(sayThreadTitle(a('thread')), sub('text')),
      SaidKey.whyPipNoticed => sayWhyPipNoticed,
      SaidKey.whyPipFoundHerself => sayWhyPipFoundHerself,
      SaidKey.whyFoundIt => sayWhyFoundIt(a('name')),
      SaidKey.whyGaveBack => sayWhyGaveBack(a('name')),
      SaidKey.whyAnnounced => sayWhyAnnounced,
      SaidKey.whyJoinedPip => sayWhyJoinedPip(a('name')),
      SaidKey.whyNoSingers => sayWhyNoSingers,
      SaidKey.whySang => sayWhySang(names(s.names('names'))),
      SaidKey.whyWon => sayWhyWon(a('name'), _clause(s.said('how'))),
      SaidKey.whyNoWinner => sayWhyNoWinner(_clause(s.said('how'))),
      SaidKey.howNobodySang => sayHowNobodySang,
      SaidKey.howDeal => sayHowDeal,
      SaidKey.howDealKnown => sayHowDealKnown(names(s.names('names'))),
      SaidKey.howFair => sayHowFair,
      SaidKey.whyJuneFoundPoem => sayWhyJuneFoundPoem,
      SaidKey.whyJuneSawFlowers => sayWhyJuneSawFlowers,
      SaidKey.whyBrambleTold => sayWhyBrambleTold,
      SaidKey.whyJuneHeard => sayWhyJuneHeard(a('name')),
      SaidKey.whyJuneOverheard => sayWhyJuneOverheard(a('name')),
      SaidKey.whyJuneHeardFlowers => sayWhyJuneHeardFlowers,
      SaidKey.whyCrushConfessed => sayWhyCrushConfessed(a('outcome')),
      SaidKey.whyCrushExposed => sayWhyCrushExposed(a('name'), a('outcome')),
      SaidKey.whyNobodyBelieves => sayWhyNobodyBelieves,
      SaidKey.whyJuneExposed => sayWhyJuneExposed(a('name'), a('from')),
      SaidKey.whyStormArrived => sayWhyStormArrived(n('count')),
      SaidKey.whySkyCleared => sayWhySkyCleared,
      SaidKey.whyDay => countdownFor(s.number('day')),
      SaidKey.confMoTold => sayConfMoTold,
      SaidKey.confPipOverheard => sayConfPipOverheard,
      SaidKey.confPipLearned => sayConfPipLearned(a('from')),
      SaidKey.searchNothing => saySearchNothing(a('name'), at(a('place'))),
      SaidKey.pondNothing => sayPondNothing(a('name')),
      SaidKey.signsUp => saySignsUp(a('name'), _clause(s.said('how'))),
      SaidKey.howToldClover => sayHowToldClover,
      SaidKey.howCloverTalked => sayHowCloverTalked,
      SaidKey.moBraver => sayMoBraver(a('name'), n('pct')),
      SaidKey.moTookBack => sayMoTookBack(n('pct')),
      SaidKey.juneFindsPoem => sayJuneFindsPoem,
      SaidKey.flowersUnseen => sayFlowersUnseen,
      SaidKey.flowersSeen => sayFlowersSeen(names(s.names('names'))),
      SaidKey.sayGoodnight => saySayGoodnight(a('a'), a('b')),
      SaidKey.breakOffFestival => sayBreakOffFestival(a('a'), a('b')),
      SaidKey.morning => sayMorning(n('day')),
      SaidKey.liesAwake => sayLiesAwake(a('name'), a('thought')),
      SaidKey.hearsPip => sayHearsPip(names(s.names('names')), s.names('names').length, at(a('place'))),
      SaidKey.planned => sayPlanned,
      SaidKey.goalFetchScarf => sayGoalFetchScarf,
      SaidKey.goalAskSeen => sayGoalAskSeen(a('name')),
      SaidKey.goalFindScarf => sayGoalFindScarf,
      SaidKey.goalSearchScarf => sayGoalSearchScarf,
      SaidKey.goalMoFish => sayGoalMoFish,
      SaidKey.goalHelpPip => sayGoalHelpPip,
      SaidKey.goalGiveBackMo => sayGoalGiveBackMo,
      SaidKey.goalGiveBack => sayGoalGiveBack,
      SaidKey.goalMoGuilty => sayGoalMoGuilty,
      SaidKey.goalBeAtFestival => sayGoalBeAtFestival,
      SaidKey.goalSetUpStage => sayGoalSetUpStage,
      SaidKey.goalRecruitMo => sayGoalRecruitMo,
      SaidKey.goalTellClover => sayGoalTellClover,
      SaidKey.goalMoScared => sayGoalMoScared,
      SaidKey.goalMoTempted => sayGoalMoTempted,
      SaidKey.goalMoAlmost => sayGoalMoAlmost,
      SaidKey.goalPractise => sayGoalPractise,
      SaidKey.goalWinBell => sayGoalWinBell,
      SaidKey.goalLeaveFlowers => sayGoalLeaveFlowers,
      SaidKey.goalTellJune => sayGoalTellJune,
      SaidKey.goalFindWhoFlowers => sayGoalFindWhoFlowers,
      SaidKey.goalTalkBramble => sayGoalTalkBramble,
      SaidKey.goalFaceJune => sayGoalFaceJune,
      SaidKey.goalSpreadRumour => sayGoalSpreadRumour,
      SaidKey.goalClearName => sayGoalClearName,
      SaidKey.goalSetRecord => sayGoalSetRecord,
      SaidKey.goalWarnToday => sayGoalWarnToday,
      SaidKey.goalWarnDay => sayGoalWarnDay(n('day')),
      SaidKey.goalRunRehearsal => sayGoalRunRehearsal,
      SaidKey.goalGoRehearsal => sayGoalGoRehearsal,
      SaidKey.whyHunger => sayWhyHunger(a('v')),
      SaidKey.whyEnergy => sayWhyEnergy(a('v')),
      SaidKey.whyPlanWork => sayWhyPlanWork,
      SaidKey.whyAtWorkplace => sayWhyAtWorkplace,
      SaidKey.whyNight => sayWhyNight,
      // The plan's activity is the model's English; other languages name the place.
      SaidKey.whyPlan => localeName == 'en' ? s.english : sayWhyPlanAt(placeName(a('place'))),
      SaidKey.whyWaiting => sayWhyWaiting(a('name')),
      SaidKey.whyFood => sayWhyFood,
      SaidKey.whyRest => sayWhyRest,
      SaidKey.whyWork => sayWhyWork,
      SaidKey.whyCompany => sayWhyCompany(a('name')),
      SaidKey.whyBedtime => sayWhyBedtime,
      SaidKey.whyShelter => sayWhyShelter,
      SaidKey.whyNothing => sayWhyNothing,
      SaidKey.storyThread => sayStoryThread(sayThreadTitle(a('thread')), sub('why')),
      SaidKey.storyTalk => sayStoryTalk(a('a'), a('b'), at(a('place')), a('how')),
      SaidKey.storyTalkAbout => sayStoryTalkAbout(a('a'), a('b'), at(a('place')), fact(), a('how')),
      SaidKey.storyConfided => sayStoryConfided(a('name'), _clause(s.said('fact'))),
      SaidKey.storyHeard => sayStoryHeard(a('name'), a('from'), _clause(s.said('fact')), a('overheard'), a('untrue'), a('doubts')),
      SaidKey.storyGossip => sayStoryGossip(a('name'), names(s.names('names')), s.names('names').length, a('reaction')),
      SaidKey.storyDash => sayStoryDash(a('name'), a('intent'), a('about'), _item(a('item')), a('reaction')),
      SaidKey.factPipTune => sayFactPipTune,
      SaidKey.factMoScarf => sayFactMoScarf,
      SaidKey.factScarfWhere => sayFactScarfWhere,
      SaidKey.factJuneRumour => sayFactJuneRumour,
      SaidKey.factBreadRumour => sayFactBreadRumour,
      SaidKey.factBreadTruth => sayFactBreadTruth,
      SaidKey.factBramblePoems => sayFactBramblePoems,
      SaidKey.factWildflowers => sayFactWildflowers,
      SaidKey.factCloverDeal => sayFactCloverDeal,
      SaidKey.factStormForecast => sayFactStormForecast(n('day')),
      SaidKey.factMoVoice => sayFactMoVoice,
      SaidKey.factHoneyLoaf => sayFactHoneyLoaf,
      SaidKey.factRehearsal => sayFactRehearsal(names(s.names('names'))),
      SaidKey.factRehearsalEmpty => sayFactRehearsalEmpty,
      SaidKey.factLanterns => sayFactLanterns,
      SaidKey.factScarfMissing => sayFactScarfMissing,
      SaidKey.factScarfFound => sayFactScarfFound(a('name')),
      SaidKey.factScarfReturned => sayFactScarfReturned(a('name')),
      SaidKey.factFestival => sayFactFestival(n('day')),
      SaidKey.factSigned => sayFactSigned(a('name')),
      SaidKey.factMoFainted => sayFactMoFainted,
      SaidKey.factFestivalWinner => sayFactFestivalWinner(a('name')),
      SaidKey.factAnonPoem => sayFactAnonPoem,
      SaidKey.factBrambleFlowers => sayFactBrambleFlowers,
      SaidKey.factStormHit => sayFactStormHit(n('day')),
      SaidKey.factBrambleRight => sayFactBrambleRight,
      SaidKey.factStormPassed => sayFactStormPassed(n('day')),
      SaidKey.factGift => sayFactGift(a('name'), _item(a('item'))),
      SaidKey.factArgument => sayFactArgument(a('a'), a('b'), at(a('place')), n('day')),
      SaidKey.endWeek => sayEndWeek(endingTitle(a('ending')), endingBlurb(a('ending'))),
      SaidKey.endNoWinner => sayEndNoWinner,
      SaidKey.endRumoursNone => sayEndRumoursNone,
      SaidKey.endRumoursFew => sayEndRumoursFew,
      SaidKey.endRumoursMany => sayEndRumoursMany,
      SaidKey.endFond => sayEndFond,
      SaidKey.endSoured => sayEndSoured,
      SaidKey.endMixed => sayEndMixed,
      SaidKey.endArc => sayEndArc(a('arc')),
      SaidKey.endHappiest => sayEndHappiest(a('a'), a('b')),
      SaidKey.endDashCross => sayEndDashCross,
      SaidKey.endDashFond => sayEndDashFond,
      SaidKey.endDashUnsure => sayEndDashUnsure,
      SaidKey.quietDay => sayQuietDay,
    };
  }

  String saveName(SaveInfo s) => s.isAuto ? autosave : slotN(int.parse(s.slot.substring(4)));

  String saveWhen(SaveInfo s) => s.damaged ? damaged : dayAndTime(s.day!, s.time!);

  String endingName(Ending e) => endingTitle(e.name);
}

String _signed(int v) => v >= 0 ? '+$v' : '$v';

const Map<String, String> _items = {
  'a red ribbon': 'ribbon',
  'a jar of honey': 'honey',
  'a shiny pebble': 'pebble',
  'a bundle of mint': 'mint',
};

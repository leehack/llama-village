import 'package:intl/intl.dart';

import '../game/save_store.dart';
import '../l10n/app_localizations.dart';
import '../sim/cast.dart';
import '../sim/clock.dart';
import '../sim/dash.dart';
import '../sim/endings.dart';
import '../sim/laya_roles.dart';
import '../sim/places.dart';
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

  String saveName(SaveInfo s) => s.isAuto ? autosave : slotN(int.parse(s.slot.substring(4)));

  String saveWhen(SaveInfo s) => s.damaged ? damaged : dayAndTime(s.day!, s.time!);

  String endingName(Ending e) => endingTitle(e.name);
}

String _signed(int v) => v >= 0 ? '+$v' : '$v';

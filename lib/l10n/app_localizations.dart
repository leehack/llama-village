import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('fr'), Locale('ko')];

  /// The game title.
  ///
  /// In en, this message translates to:
  /// **'Llama Village'**
  String get appTitle;

  /// Subtitle on the title screen.
  ///
  /// In en, this message translates to:
  /// **'Festival Week'**
  String get appSubtitle;

  /// Tagline on the title screen.
  ///
  /// In en, this message translates to:
  /// **'Five llamas, five days, one nosy little bird.'**
  String get titleTagline;

  /// Tagline on the loading card.
  ///
  /// In en, this message translates to:
  /// **'Five llamas, their secrets, and one nosy little bird.'**
  String get loadingTagline;

  /// Loading label while the 3D scene builds.
  ///
  /// In en, this message translates to:
  /// **'Building the village…'**
  String get buildingVillage;

  /// The 3D scene could not load.
  ///
  /// In en, this message translates to:
  /// **'The 3D scene failed to load: {error}'**
  String sceneFailed(String error);

  /// No description provided for @modelsNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'The AI models were not found.'**
  String get modelsNotFoundTitle;

  /// No description provided for @modelsMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing: {files}'**
  String modelsMissing(String files);

  /// No description provided for @modelsFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'The models failed to load.'**
  String get modelsFailedTitle;

  /// Quit button.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get quit;

  /// No description provided for @playWithoutAi.
  ///
  /// In en, this message translates to:
  /// **'Play without AI (canned lines)'**
  String get playWithoutAi;

  /// Model status on the title screen.
  ///
  /// In en, this message translates to:
  /// **'Playing with canned lines (no AI).'**
  String get statusCanned;

  /// No description provided for @statusMissing.
  ///
  /// In en, this message translates to:
  /// **'AI models not found ({files}; looked in {dir}). New games use canned lines. See README: VILLAGE_CHAT_MODEL, VILLAGE_EMBED_MODEL.'**
  String statusMissing(String files, String dir);

  /// No description provided for @statusLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading the AI models…'**
  String get statusLoading;

  /// A model loading step and its percentage.
  ///
  /// In en, this message translates to:
  /// **'{stage, select, dialogue{Loading the dialogue model (gemma-4-E2B)…} embedding{Loading the embedding model (EmbeddingGemma)…} laya{Loading Laya for casual topics…} other{Warming up…}} {percent}%'**
  String loadProgress(String stage, int percent);

  /// No description provided for @statusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready: {models}'**
  String statusReady(String models);

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'The AI models failed to load ({error}). New games use canned lines.'**
  String statusFailed(String error);

  /// Shown in the HUD instead of the model name.
  ///
  /// In en, this message translates to:
  /// **'canned lines (no AI)'**
  String get cannedLabel;

  /// No description provided for @busyWaitingModels.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the AI models…'**
  String get busyWaitingModels;

  /// No description provided for @busyPlanning.
  ///
  /// In en, this message translates to:
  /// **'The llamas are planning their day…'**
  String get busyPlanning;

  /// No description provided for @busySkipping.
  ///
  /// In en, this message translates to:
  /// **'Skipping ahead to day {day}…'**
  String busySkipping(int day);

  /// No description provided for @busyLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading {when}…'**
  String busyLoading(String when);

  /// No description provided for @busyTidying.
  ///
  /// In en, this message translates to:
  /// **'Tidying up…'**
  String get busyTidying;

  /// No description provided for @toastCannotLoad.
  ///
  /// In en, this message translates to:
  /// **'That save cannot be loaded: {reason}'**
  String toastCannotLoad(String reason);

  /// slot is "auto" or the slot number.
  ///
  /// In en, this message translates to:
  /// **'{slot, select, auto{Saved to the autosave} other{Saved to slot {slot}}}: day {day}, {time}'**
  String toastSaved(String slot, int day, String time);

  /// No description provided for @toastSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save: {error}'**
  String toastSaveFailed(String error);

  /// No description provided for @noticePlanningTomorrow.
  ///
  /// In en, this message translates to:
  /// **'The llamas are planning tomorrow…'**
  String get noticePlanningTomorrow;

  /// No description provided for @noticePaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get noticePaused;

  /// Top bar clock.
  ///
  /// In en, this message translates to:
  /// **'Day {day}  {time}'**
  String dayClock(int day, String time);

  /// No description provided for @dayAndTime.
  ///
  /// In en, this message translates to:
  /// **'Day {day}, {time}'**
  String dayAndTime(int day, String time);

  /// Days until the festival, lower case in a sentence.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Berry Festival day} =1{the day before the festival} other{{days} days to the festival}}'**
  String countdown(int days);

  /// Days until the festival, as a subtitle.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{The Berry Festival is today at 16:00} =1{The day before the festival} other{{days} days to the festival}}'**
  String countdownTitle(int days);

  /// No description provided for @afterFestival.
  ///
  /// In en, this message translates to:
  /// **'after the festival'**
  String get afterFestival;

  /// No description provided for @planningTomorrowLower.
  ///
  /// In en, this message translates to:
  /// **'the llamas are planning tomorrow…'**
  String get planningTomorrowLower;

  /// The card at dawn.
  ///
  /// In en, this message translates to:
  /// **'Day {day}'**
  String dayTitle(int day);

  /// No description provided for @tipPause.
  ///
  /// In en, this message translates to:
  /// **'Pause (Space)'**
  String get tipPause;

  /// No description provided for @tipOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview (O)'**
  String get tipOverview;

  /// No description provided for @tipFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow the selected llama or Dash (F)'**
  String get tipFollow;

  /// No description provided for @tipSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tipSettings;

  /// No description provided for @fps.
  ///
  /// In en, this message translates to:
  /// **'{fps} fps'**
  String fps(String fps);

  /// What the dialogue model is writing now.
  ///
  /// In en, this message translates to:
  /// **'thinking: {job, select, dialogue{a line} thought{a thought} dash_options{Dash\'s options} dash_reply{a reply} outcome{how it went} schedule{plans} reflection{a dream} storybook{the storybook} epilogue{an epilogue} announcement{an announcement} song{a song} other{…}}'**
  String thinking(String job);

  /// No description provided for @villageLog.
  ///
  /// In en, this message translates to:
  /// **'Village log'**
  String get villageLog;

  /// Controls hint at the bottom of the screen.
  ///
  /// In en, this message translates to:
  /// **'Click a llama: Dash flies over to talk  ·  Right-click: inspect only  ·  Click ground or WASD: fly\nDrag: orbit  ·  Right-drag / two fingers: pan  ·  Scroll / pinch: zoom  ·  Space: pause  ·  F: follow  ·  O: overview'**
  String get helpHint;

  /// No description provided for @dashFlying.
  ///
  /// In en, this message translates to:
  /// **'Dash is flying over to {name}…'**
  String dashFlying(String name);

  /// No description provided for @dashWaiting.
  ///
  /// In en, this message translates to:
  /// **'{name} is busy. Dash waits nearby…'**
  String dashWaiting(String name);

  /// No description provided for @dashThinking.
  ///
  /// In en, this message translates to:
  /// **'Dash is thinking of what to say…'**
  String get dashThinking;

  /// No description provided for @llamaAnswering.
  ///
  /// In en, this message translates to:
  /// **'{name} is answering…'**
  String llamaAnswering(String name);

  /// How the llama took what Dash said.
  ///
  /// In en, this message translates to:
  /// **'{name} is {reaction, select, offended{offended} annoyed{annoyed} indifferent{indifferent} pleased{pleased} delighted{delighted} other{{reaction}}}.'**
  String reactionLine(String name, String reaction);

  /// No description provided for @sayMore.
  ///
  /// In en, this message translates to:
  /// **'Say more'**
  String get sayMore;

  /// No description provided for @flyOff.
  ///
  /// In en, this message translates to:
  /// **'Fly off'**
  String get flyOff;

  /// No description provided for @tipLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave (Esc)'**
  String get tipLeave;

  /// Options panel title.
  ///
  /// In en, this message translates to:
  /// **'Dash and {name}'**
  String dashAnd(String name);

  /// No description provided for @atPlaceMood.
  ///
  /// In en, this message translates to:
  /// **'at {place} · {mood}'**
  String atPlaceMood(String place, String mood);

  /// The kind of thing Dash says.
  ///
  /// In en, this message translates to:
  /// **'{intent, select, compliment{compliment} gossip{gossip} praise{praise} tell{news} gift{gift} help{help} tease{tease} other{{intent}}}'**
  String intent(String intent);

  /// A place, as used after "at" or "to".
  ///
  /// In en, this message translates to:
  /// **'{place, select, pond{the pond} berryBushes{the berry bushes} bakery{the bakery} hilltop{the hilltop} other{{place}}}'**
  String place(String place);

  /// No description provided for @hut.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s hut'**
  String hut(String name);

  /// No description provided for @mood.
  ///
  /// In en, this message translates to:
  /// **'{mood, select, miserable{miserable} grumpy{grumpy} calm{calm} cheerful{cheerful} elated{elated} other{{mood}}}'**
  String mood(String mood);

  /// delta and mood come with their sign.
  ///
  /// In en, this message translates to:
  /// **'{name} toward Dash {delta} (now {now}), mood {mood}'**
  String effectTrust(String name, String delta, int now, String mood);

  /// No description provided for @effectRumourBelieved.
  ///
  /// In en, this message translates to:
  /// **'{name} believes the made-up rumour about {about}'**
  String effectRumourBelieved(String name, String about);

  /// No description provided for @effectRumourDoubted.
  ///
  /// In en, this message translates to:
  /// **'{name} doubts the made-up rumour about {about}'**
  String effectRumourDoubted(String name, String about);

  /// No description provided for @effectWarms.
  ///
  /// In en, this message translates to:
  /// **'{name} warms to {about} (+1)'**
  String effectWarms(String name, String about);

  /// No description provided for @effectShrugs.
  ///
  /// In en, this message translates to:
  /// **'{name} shrugs off the kind words about {about}'**
  String effectShrugs(String name, String about);

  /// No description provided for @effectNowKnows.
  ///
  /// In en, this message translates to:
  /// **'{name} now knows: {fact}'**
  String effectNowKnows(String name, String fact);

  /// No description provided for @effectConfides.
  ///
  /// In en, this message translates to:
  /// **'{name} tells Dash: {fact}'**
  String effectConfides(String name, String fact);

  /// No description provided for @effectWork.
  ///
  /// In en, this message translates to:
  /// **'{name} gets work done faster'**
  String effectWork(String name);

  /// No description provided for @effectCourage.
  ///
  /// In en, this message translates to:
  /// **'Mo courage {percent}%'**
  String effectCourage(int percent);

  /// No description provided for @noticeAsleep.
  ///
  /// In en, this message translates to:
  /// **'{name} is asleep. Try again in the morning.'**
  String noticeAsleep(String name);

  /// No description provided for @noticeRush.
  ///
  /// In en, this message translates to:
  /// **'{name} is hurrying to the festival.'**
  String noticeRush(String name);

  /// No description provided for @noticeCatchUp.
  ///
  /// In en, this message translates to:
  /// **'Catching up with {name}…'**
  String noticeCatchUp(String name);

  /// No description provided for @noticeWaitTalk.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {name} to finish talking…'**
  String noticeWaitTalk(String name);

  /// No description provided for @noticeFellAsleep.
  ///
  /// In en, this message translates to:
  /// **'{name} has fallen asleep.'**
  String noticeFellAsleep(String name);

  /// No description provided for @noticeHurriesOff.
  ///
  /// In en, this message translates to:
  /// **'{name} hurries off to the festival.'**
  String noticeHurriesOff(String name);

  /// No description provided for @factPipTune.
  ///
  /// In en, this message translates to:
  /// **'Pip\'s secret singing'**
  String get factPipTune;

  /// No description provided for @factMoScarf.
  ///
  /// In en, this message translates to:
  /// **'Mo\'s scarf accident'**
  String get factMoScarf;

  /// No description provided for @factScarfWhere.
  ///
  /// In en, this message translates to:
  /// **'where the scarf is'**
  String get factScarfWhere;

  /// No description provided for @factJuneRumour.
  ///
  /// In en, this message translates to:
  /// **'who started the bread rumour'**
  String get factJuneRumour;

  /// No description provided for @factBreadRumour.
  ///
  /// In en, this message translates to:
  /// **'Mo\'s bread rumour'**
  String get factBreadRumour;

  /// No description provided for @factBreadTruth.
  ///
  /// In en, this message translates to:
  /// **'the bread rumour is false'**
  String get factBreadTruth;

  /// No description provided for @factBramblePoems.
  ///
  /// In en, this message translates to:
  /// **'Bramble\'s poems for June'**
  String get factBramblePoems;

  /// No description provided for @factWildflowers.
  ///
  /// In en, this message translates to:
  /// **'the mystery wildflowers'**
  String get factWildflowers;

  /// No description provided for @factCloverDeal.
  ///
  /// In en, this message translates to:
  /// **'Clover\'s Golden Bell deal'**
  String get factCloverDeal;

  /// No description provided for @factStormForecast.
  ///
  /// In en, this message translates to:
  /// **'Bramble\'s storm warning'**
  String get factStormForecast;

  /// No description provided for @factMoVoice.
  ///
  /// In en, this message translates to:
  /// **'Mo\'s singing voice'**
  String get factMoVoice;

  /// No description provided for @factHoneyLoaf.
  ///
  /// In en, this message translates to:
  /// **'Mo\'s honey loaf'**
  String get factHoneyLoaf;

  /// No description provided for @factRehearsal.
  ///
  /// In en, this message translates to:
  /// **'the rehearsal'**
  String get factRehearsal;

  /// No description provided for @factLanterns.
  ///
  /// In en, this message translates to:
  /// **'the lanterns'**
  String get factLanterns;

  /// No description provided for @factScarfMissing.
  ///
  /// In en, this message translates to:
  /// **'the missing scarf'**
  String get factScarfMissing;

  /// No description provided for @factScarfFound.
  ///
  /// In en, this message translates to:
  /// **'the scarf was found'**
  String get factScarfFound;

  /// No description provided for @factScarfReturned.
  ///
  /// In en, this message translates to:
  /// **'the scarf came back'**
  String get factScarfReturned;

  /// No description provided for @factFestival.
  ///
  /// In en, this message translates to:
  /// **'the Berry Festival'**
  String get factFestival;

  /// No description provided for @factMoFainted.
  ///
  /// In en, this message translates to:
  /// **'Mo fainting'**
  String get factMoFainted;

  /// No description provided for @factFestivalWinner.
  ///
  /// In en, this message translates to:
  /// **'the festival winner'**
  String get factFestivalWinner;

  /// No description provided for @factAnonPoem.
  ///
  /// In en, this message translates to:
  /// **'the anonymous love poem'**
  String get factAnonPoem;

  /// No description provided for @factBrambleFlowers.
  ///
  /// In en, this message translates to:
  /// **'Bramble and the wildflowers'**
  String get factBrambleFlowers;

  /// No description provided for @factStormHit.
  ///
  /// In en, this message translates to:
  /// **'the storm'**
  String get factStormHit;

  /// No description provided for @factBrambleRight.
  ///
  /// In en, this message translates to:
  /// **'Bramble being right'**
  String get factBrambleRight;

  /// No description provided for @factStormPassed.
  ///
  /// In en, this message translates to:
  /// **'the rainbow'**
  String get factStormPassed;

  /// No description provided for @factSigned.
  ///
  /// In en, this message translates to:
  /// **'{name} entering the contest'**
  String factSigned(String name);

  /// No description provided for @factArgument.
  ///
  /// In en, this message translates to:
  /// **'{a} and {b} arguing'**
  String factArgument(String a, String b);

  /// No description provided for @factDashGift.
  ///
  /// In en, this message translates to:
  /// **'Dash\'s gift to {name}'**
  String factDashGift(String name);

  /// No description provided for @factDashRumour.
  ///
  /// In en, this message translates to:
  /// **'what Dash said about {name}'**
  String factDashRumour(String name);

  /// No description provided for @llamaRole.
  ///
  /// In en, this message translates to:
  /// **'{name, select, Pip{the scarf knitter} Mo{the baker} June{the berry farmer} Bramble{the weather watcher} Clover{the festival organiser} other{a llama}}'**
  String llamaRole(String name);

  /// No description provided for @llamaTraits.
  ///
  /// In en, this message translates to:
  /// **'{name, select, Pip{vain, dramatic, fashionable, secretly insecure} Mo{shy, kind, anxious, has a golden singing voice} June{nosy, chatty, cheerful, loves a scandal} Bramble{grumpy, old, proud, secretly romantic} Clover{bossy, ambitious, playful, impatient} other{}}'**
  String llamaTraits(String name);

  /// No description provided for @llamaBio.
  ///
  /// In en, this message translates to:
  /// **'{name, select, Pip{Likes her red scarf, ribbons and compliments. Dreams to win the Golden Bell for best singer at the Berry Festival.} Mo{Likes warm bread, quiet mornings and honest praise. Dreams to find the courage to sing at the festival without fainting.} June{Likes gossip, sweet berries and being asked for news. Dreams to be the first llama to know every secret in the village.} Bramble{Likes clouds, poetry and being right. Dreams to be taken seriously when he predicts a storm.} Clover{Likes clipboards, applause and things going to plan. Dreams to run a perfect Berry Festival and be elected village mayor.} other{}}'**
  String llamaBio(String name);

  /// No description provided for @tipTalkAsDash.
  ///
  /// In en, this message translates to:
  /// **'Talk as Dash'**
  String get tipTalkAsDash;

  /// No description provided for @tipCloseEsc.
  ///
  /// In en, this message translates to:
  /// **'Close (Esc)'**
  String get tipCloseEsc;

  /// Inspector section.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get sectionNow;

  /// No description provided for @sectionMoodNeeds.
  ///
  /// In en, this message translates to:
  /// **'Mood and needs'**
  String get sectionMoodNeeds;

  /// No description provided for @sectionFriendships.
  ///
  /// In en, this message translates to:
  /// **'Friendships'**
  String get sectionFriendships;

  /// No description provided for @sectionGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get sectionGoals;

  /// No description provided for @sectionWhy.
  ///
  /// In en, this message translates to:
  /// **'Why this action'**
  String get sectionWhy;

  /// No description provided for @sectionKnows.
  ///
  /// In en, this message translates to:
  /// **'What {name} knows ({count})'**
  String sectionKnows(String name, int count);

  /// No description provided for @barMood.
  ///
  /// In en, this message translates to:
  /// **'Mood: {mood}'**
  String barMood(String mood);

  /// No description provided for @barFed.
  ///
  /// In en, this message translates to:
  /// **'Fed'**
  String get barFed;

  /// No description provided for @barEnergy.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get barEnergy;

  /// No description provided for @barCompany.
  ///
  /// In en, this message translates to:
  /// **'Wants company'**
  String get barCompany;

  /// No description provided for @barCourage.
  ///
  /// In en, this message translates to:
  /// **'Courage'**
  String get barCourage;

  /// No description provided for @noDecision.
  ///
  /// In en, this message translates to:
  /// **'No decision yet.'**
  String get noDecision;

  /// How a llama learned a fact.
  ///
  /// In en, this message translates to:
  /// **'own secret'**
  String get howOwnSecret;

  /// No description provided for @howKnows.
  ///
  /// In en, this message translates to:
  /// **'knows it'**
  String get howKnows;

  /// No description provided for @howSaw.
  ///
  /// In en, this message translates to:
  /// **'saw it'**
  String get howSaw;

  /// No description provided for @howAnnounced.
  ///
  /// In en, this message translates to:
  /// **'announced'**
  String get howAnnounced;

  /// No description provided for @howOverheardDoubt.
  ///
  /// In en, this message translates to:
  /// **'overheard from {name}; does not believe it'**
  String howOverheardDoubt(String name);

  /// No description provided for @howOverheard.
  ///
  /// In en, this message translates to:
  /// **'overheard from {name}; maybe untrue'**
  String howOverheard(String name);

  /// No description provided for @howHeardDoubt.
  ///
  /// In en, this message translates to:
  /// **'heard from {name}; does not believe it'**
  String howHeardDoubt(String name);

  /// No description provided for @howHeard.
  ///
  /// In en, this message translates to:
  /// **'heard from {name}; maybe untrue'**
  String howHeard(String name);

  /// No description provided for @activityWalk.
  ///
  /// In en, this message translates to:
  /// **'walking to {place}'**
  String activityWalk(String place);

  /// No description provided for @activityTalk.
  ///
  /// In en, this message translates to:
  /// **'talking with {name} at {place}'**
  String activityTalk(String name, String place);

  /// No description provided for @activitySleep.
  ///
  /// In en, this message translates to:
  /// **'asleep in {place}'**
  String activitySleep(String place);

  /// No description provided for @activityIdle.
  ///
  /// In en, this message translates to:
  /// **'standing at {place}'**
  String activityIdle(String place);

  /// Doing something somewhere.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, eat{eating} work{working} nap{napping} search{searching} watch{watching} wait{waiting} practise{practising} flowers{leaving flowers} linger{lingering} other{{kind}}} at {place}'**
  String activityAt(String kind, String place);

  /// One option the llama weighed.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, walk{walk} talk{talk} eat{eat} work{work} nap{nap} sleep{sleep} search{search} watch{watch} wait{wait} practise{practise} flowers{leave flowers} linger{linger} idle{stay} other{{kind}}}'**
  String choice(String kind);

  /// No description provided for @choiceTo.
  ///
  /// In en, this message translates to:
  /// **'{kind} to {place}'**
  String choiceTo(String kind, String place);

  /// No description provided for @newGame.
  ///
  /// In en, this message translates to:
  /// **'New game'**
  String get newGame;

  /// No description provided for @continueGame.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueGame;

  /// No description provided for @noSave.
  ///
  /// In en, this message translates to:
  /// **'No saved game yet'**
  String get noSave;

  /// No description provided for @saveDetail.
  ///
  /// In en, this message translates to:
  /// **'{when} · {name}'**
  String saveDetail(String when, String name);

  /// No description provided for @endings.
  ///
  /// In en, this message translates to:
  /// **'Endings'**
  String get endings;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @credits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get credits;

  /// No description provided for @autosave.
  ///
  /// In en, this message translates to:
  /// **'Autosave'**
  String get autosave;

  /// No description provided for @slotN.
  ///
  /// In en, this message translates to:
  /// **'Slot {n}'**
  String slotN(int n);

  /// A save that cannot be loaded.
  ///
  /// In en, this message translates to:
  /// **'damaged'**
  String get damaged;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// Section heading.
  ///
  /// In en, this message translates to:
  /// **'Save game'**
  String get saveGame;

  /// No description provided for @savedMark.
  ///
  /// In en, this message translates to:
  /// **'✓ saved'**
  String get savedMark;

  /// An empty save slot.
  ///
  /// In en, this message translates to:
  /// **'empty'**
  String get empty;

  /// No description provided for @saveAndQuit.
  ///
  /// In en, this message translates to:
  /// **'Save and quit to menu'**
  String get saveAndQuit;

  /// No description provided for @saveAndQuitDetail.
  ///
  /// In en, this message translates to:
  /// **'Saves to the autosave slot'**
  String get saveAndQuitDetail;

  /// No description provided for @quitGame.
  ///
  /// In en, this message translates to:
  /// **'Quit game'**
  String get quitGame;

  /// No description provided for @escResumes.
  ///
  /// In en, this message translates to:
  /// **'Esc resumes'**
  String get escResumes;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @unlockedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} unlocked'**
  String unlockedCount(int count, int total);

  /// No description provided for @lockedTitle.
  ///
  /// In en, this message translates to:
  /// **'? ? ?'**
  String get lockedTitle;

  /// No description provided for @storybooksSection.
  ///
  /// In en, this message translates to:
  /// **'Storybooks'**
  String get storybooksSection;

  /// No description provided for @noStorybooks.
  ///
  /// In en, this message translates to:
  /// **'Finish a week to keep its storybook here.'**
  String get noStorybooks;

  /// No description provided for @endingTitle.
  ///
  /// In en, this message translates to:
  /// **'{ending, select, harmonyFestival{Harmony Festival} dramaLlama{Drama Llama} quietValley{Quiet Valley} other{{ending}}}'**
  String endingTitle(String ending);

  /// No description provided for @endingBlurb.
  ///
  /// In en, this message translates to:
  /// **'{ending, select, harmonyFestival{Every rumour put right, every llama on the hilltop, and the lanterns burn till dawn.} dramaLlama{Whispers, feuds and a festival nobody will forget, for all the wrong reasons.} quietValley{The week passed gently. Dash watched, and the valley mostly minded its own business.} other{}}'**
  String endingBlurb(String ending);

  /// No description provided for @endingHint.
  ///
  /// In en, this message translates to:
  /// **'{ending, select, harmonyFestival{Win the llamas over, set the record straight, and bring them closer.} dramaLlama{A little bird with a loose beak can stir up a lot.} quietValley{Sometimes the valley is happiest left alone.} other{}}'**
  String endingHint(String ending);

  /// No description provided for @creditsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Llama Village: Festival Week'**
  String get creditsSubtitle;

  /// No description provided for @creditsModels.
  ///
  /// In en, this message translates to:
  /// **'Models (all run on this Mac, nothing is downloaded)'**
  String get creditsModels;

  /// No description provided for @creditsGemma.
  ///
  /// In en, this message translates to:
  /// **'Google DeepMind. Dialogue, plans, thoughts, Dash\'s options, epilogues and the storybook. Used under the Gemma 4 licence (Apache License 2.0), ai.google.dev/gemma/docs/gemma_4_license.'**
  String get creditsGemma;

  /// No description provided for @creditsEmbedding.
  ///
  /// In en, this message translates to:
  /// **'Google DeepMind. Checks which facts were actually said. Gemma is provided under and subject to the Gemma Terms of Use found at ai.google.dev/gemma/terms.'**
  String get creditsEmbedding;

  /// No description provided for @creditsLayaName.
  ///
  /// In en, this message translates to:
  /// **'Laya decision model (optional)'**
  String get creditsLayaName;

  /// No description provided for @creditsLaya.
  ///
  /// In en, this message translates to:
  /// **'Picks casual conversation topics when it is installed.'**
  String get creditsLaya;

  /// No description provided for @creditsEngines.
  ///
  /// In en, this message translates to:
  /// **'Engines and libraries'**
  String get creditsEngines;

  /// No description provided for @creditsLlamadart.
  ///
  /// In en, this message translates to:
  /// **'MIT License, © 2024 Jhin Lee. Runs llama.cpp (MIT License, © the ggml authors) on Metal.'**
  String get creditsLlamadart;

  /// No description provided for @creditsScene.
  ///
  /// In en, this message translates to:
  /// **'MIT License, © 2023 Brandon DeRosier. The 3D village, on Flutter GPU.'**
  String get creditsScene;

  /// No description provided for @creditsSoloud.
  ///
  /// In en, this message translates to:
  /// **'MIT License, © 2024 the flutter_soloud authors, with the SoLoud engine (zlib/libpng licence, © Jari Komppa).'**
  String get creditsSoloud;

  /// No description provided for @creditsFlutter.
  ///
  /// In en, this message translates to:
  /// **'BSD 3-Clause License, © the Flutter authors.'**
  String get creditsFlutter;

  /// No description provided for @creditsSound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get creditsSound;

  /// No description provided for @creditsSynth.
  ///
  /// In en, this message translates to:
  /// **'Music and sounds synthesized in code'**
  String get creditsSynth;

  /// No description provided for @creditsSynthNote.
  ///
  /// In en, this message translates to:
  /// **'tool/audio/gen_audio.py: additive synthesis, shaped noise and an FFT reverb. Nothing is sampled or downloaded.'**
  String get creditsSynthNote;

  /// No description provided for @creditsFonts.
  ///
  /// In en, this message translates to:
  /// **'Fonts'**
  String get creditsFonts;

  /// No description provided for @creditsGowunDodum.
  ///
  /// In en, this message translates to:
  /// **'SIL Open Font License 1.1, © 2021 The Gowun Dodum Project Authors (github.com/yangheeryu/Gowun-Dodum). The Korean menus, HUD, inspector, log and settings.'**
  String get creditsGowunDodum;

  /// No description provided for @creditsJua.
  ///
  /// In en, this message translates to:
  /// **'SIL Open Font License 1.1, © 2018 The Jua Project Authors. Korean titles, speech and thought bubbles and Dash\'s options.'**
  String get creditsJua;

  /// No description provided for @creditsGowunBatang.
  ///
  /// In en, this message translates to:
  /// **'SIL Open Font License 1.1, © 2021 The Gowun Batang Project Authors (github.com/yangheeryu/Gowun-Batang). The Korean storybook.'**
  String get creditsGowunBatang;

  /// Epilogue heading.
  ///
  /// In en, this message translates to:
  /// **'After the festival…'**
  String get afterTheFestival;

  /// No description provided for @remembering.
  ///
  /// In en, this message translates to:
  /// **'The llamas are remembering…'**
  String get remembering;

  /// No description provided for @seeWeek.
  ///
  /// In en, this message translates to:
  /// **'See how the week went'**
  String get seeWeek;

  /// No description provided for @endingUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Ending unlocked'**
  String get endingUnlocked;

  /// No description provided for @endingAlready.
  ///
  /// In en, this message translates to:
  /// **'Ending (already unlocked)'**
  String get endingAlready;

  /// No description provided for @why.
  ///
  /// In en, this message translates to:
  /// **'Why: {reasons}.'**
  String why(String reasons);

  /// No description provided for @reasonFalseBeliefs.
  ///
  /// In en, this message translates to:
  /// **'{count} false beliefs still going round'**
  String reasonFalseBeliefs(int count);

  /// No description provided for @reasonSoured.
  ///
  /// In en, this message translates to:
  /// **'friendships soured (harmony {value})'**
  String reasonSoured(String value);

  /// No description provided for @reasonRift.
  ///
  /// In en, this message translates to:
  /// **'Pip and Mo fell out'**
  String get reasonRift;

  /// No description provided for @reasonCrushExposed.
  ///
  /// In en, this message translates to:
  /// **'Bramble\'s crush was aired by someone else, and June said no'**
  String get reasonCrushExposed;

  /// No description provided for @reasonNoWinner.
  ///
  /// In en, this message translates to:
  /// **'the festival had no winner'**
  String get reasonNoWinner;

  /// No description provided for @reasonCrowned.
  ///
  /// In en, this message translates to:
  /// **'the festival crowned {name}'**
  String reasonCrowned(String name);

  /// No description provided for @reasonAllRight.
  ///
  /// In en, this message translates to:
  /// **'every false rumour was put right'**
  String get reasonAllRight;

  /// No description provided for @reasonHarmony.
  ///
  /// In en, this message translates to:
  /// **'harmony {value}'**
  String reasonHarmony(String value);

  /// No description provided for @reasonTrust.
  ///
  /// In en, this message translates to:
  /// **'the llamas trust Dash ({value})'**
  String reasonTrust(String value);

  /// No description provided for @reasonBeliefsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 false belief left} other{{count} false beliefs left}}'**
  String reasonBeliefsLeft(int count);

  /// No description provided for @reasonHarmonyOnly.
  ///
  /// In en, this message translates to:
  /// **'harmony only {value}'**
  String reasonHarmonyOnly(String value);

  /// No description provided for @reasonTrustOnly.
  ///
  /// In en, this message translates to:
  /// **'trust in Dash only {value}'**
  String reasonTrustOnly(String value);

  /// No description provided for @statHarmony.
  ///
  /// In en, this message translates to:
  /// **'Harmony'**
  String get statHarmony;

  /// No description provided for @harmonyValue.
  ///
  /// In en, this message translates to:
  /// **'{value} / 10'**
  String harmonyValue(String value);

  /// No description provided for @harmonyNote.
  ///
  /// In en, this message translates to:
  /// **'mean friendship among the five'**
  String get harmonyNote;

  /// No description provided for @statTruth.
  ///
  /// In en, this message translates to:
  /// **'Truth'**
  String get statTruth;

  /// No description provided for @noFalseBeliefs.
  ///
  /// In en, this message translates to:
  /// **'no false beliefs'**
  String get noFalseBeliefs;

  /// No description provided for @falseBeliefs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 false belief} other{{count} false beliefs}}'**
  String falseBeliefs(int count);

  /// No description provided for @everyRumourRight.
  ///
  /// In en, this message translates to:
  /// **'every rumour was put right'**
  String get everyRumourRight;

  /// No description provided for @moreBeliefs.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String moreBeliefs(int count);

  /// No description provided for @statPipMo.
  ///
  /// In en, this message translates to:
  /// **'Pip and Mo'**
  String get statPipMo;

  /// No description provided for @pipMoArc.
  ///
  /// In en, this message translates to:
  /// **'{arc, select, reconciled{made up} rift{fell out} other{left unsaid}}'**
  String pipMoArc(String arc);

  /// No description provided for @pipMoNote.
  ///
  /// In en, this message translates to:
  /// **'the scarf, the bread rumour and the Golden Bell'**
  String get pipMoNote;

  /// No description provided for @statBramble.
  ///
  /// In en, this message translates to:
  /// **'Bramble\'s poems'**
  String get statBramble;

  /// No description provided for @brambleArc.
  ///
  /// In en, this message translates to:
  /// **'{arc, select, accepted{confessed, and June said yes} declined{confessed; June let him down gently} exposedDeclined{exposed by gossip; June said no} revealed{out in the open, still unanswered} other{still a secret}}'**
  String brambleArc(String arc);

  /// No description provided for @brambleNote.
  ///
  /// In en, this message translates to:
  /// **'his secret crush on June'**
  String get brambleNote;

  /// No description provided for @statFestival.
  ///
  /// In en, this message translates to:
  /// **'Festival'**
  String get statFestival;

  /// No description provided for @noWinner.
  ///
  /// In en, this message translates to:
  /// **'no winner'**
  String get noWinner;

  /// No description provided for @wonBell.
  ///
  /// In en, this message translates to:
  /// **'{name} won the Golden Bell'**
  String wonBell(String name);

  /// No description provided for @statTrust.
  ///
  /// In en, this message translates to:
  /// **'Trust in Dash'**
  String get statTrust;

  /// No description provided for @trustNote.
  ///
  /// In en, this message translates to:
  /// **'how each llama feels about you, -10 to 10'**
  String get trustNote;

  /// No description provided for @backToTitle.
  ///
  /// In en, this message translates to:
  /// **'Back to the title'**
  String get backToTitle;

  /// No description provided for @readStory.
  ///
  /// In en, this message translates to:
  /// **'Read the story'**
  String get readStory;

  /// No description provided for @storyProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} pages written…'**
  String storyProgress(int done, int total);

  /// No description provided for @sectionGraphics.
  ///
  /// In en, this message translates to:
  /// **'Graphics'**
  String get sectionGraphics;

  /// No description provided for @frameRate.
  ///
  /// In en, this message translates to:
  /// **'Frame rate'**
  String get frameRate;

  /// No description provided for @fpsChoice.
  ///
  /// In en, this message translates to:
  /// **'{fps} fps'**
  String fpsChoice(int fps);

  /// No description provided for @promotionNote.
  ///
  /// In en, this message translates to:
  /// **'120 fps needs a ProMotion display.'**
  String get promotionNote;

  /// No description provided for @graphicsQuality.
  ///
  /// In en, this message translates to:
  /// **'Graphics quality'**
  String get graphicsQuality;

  /// No description provided for @quality.
  ///
  /// In en, this message translates to:
  /// **'{quality, select, low{Low} medium{Medium} other{High}}'**
  String quality(String quality);

  /// No description provided for @sectionAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get sectionAudio;

  /// No description provided for @music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get music;

  /// No description provided for @soundEffects.
  ///
  /// In en, this message translates to:
  /// **'Sound effects'**
  String get soundEffects;

  /// No description provided for @muteAll.
  ///
  /// In en, this message translates to:
  /// **'Mute all'**
  String get muteAll;

  /// No description provided for @sectionGameplay.
  ///
  /// In en, this message translates to:
  /// **'Gameplay'**
  String get sectionGameplay;

  /// No description provided for @textSpeed.
  ///
  /// In en, this message translates to:
  /// **'Text speed'**
  String get textSpeed;

  /// No description provided for @speedName.
  ///
  /// In en, this message translates to:
  /// **'{speed, select, slow{Slow} fast{Fast} other{Normal}}'**
  String speedName(String speed);

  /// No description provided for @startingSpeed.
  ///
  /// In en, this message translates to:
  /// **'Starting time speed'**
  String get startingSpeed;

  /// No description provided for @speedChoice.
  ///
  /// In en, this message translates to:
  /// **'{n}×'**
  String speedChoice(int n);

  /// No description provided for @sectionAccessibility.
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get sectionAccessibility;

  /// No description provided for @textSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSize;

  /// No description provided for @sizeName.
  ///
  /// In en, this message translates to:
  /// **'{size, select, large{Large} larger{Larger} other{Normal}}'**
  String sizeName(String size);

  /// No description provided for @reducedMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduced motion'**
  String get reducedMotion;

  /// No description provided for @reducedMotionNote.
  ///
  /// In en, this message translates to:
  /// **'Shorter camera moves in cutscenes, no camera shake, a slower menu flyover, calmer animals and fewer particles.'**
  String get reducedMotionNote;

  /// No description provided for @highContrast.
  ///
  /// In en, this message translates to:
  /// **'High-contrast bubbles'**
  String get highContrast;

  /// No description provided for @sectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get sectionLanguage;

  /// Follow the system language.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageNote.
  ///
  /// In en, this message translates to:
  /// **'Menus, and everything the llamas say and write, switch at once. The sim keeps its facts in English.'**
  String get languageNote;

  /// No description provided for @skipHint.
  ///
  /// In en, this message translates to:
  /// **'Esc / Space / click to skip'**
  String get skipHint;

  /// No description provided for @llamasThinking.
  ///
  /// In en, this message translates to:
  /// **'the llamas are thinking'**
  String get llamasThinking;

  /// No description provided for @dreams.
  ///
  /// In en, this message translates to:
  /// **'{name} dreams…'**
  String dreams(String name);

  /// No description provided for @dreamFallback.
  ///
  /// In en, this message translates to:
  /// **'Zzz…'**
  String get dreamFallback;

  /// No description provided for @announcementFallback.
  ///
  /// In en, this message translates to:
  /// **'Hear ye! The Berry Festival is on day {day} at 16:00 on the hilltop. Best singer wins the Golden Bell!'**
  String announcementFallback(int day);

  /// No description provided for @pipSignsUp.
  ///
  /// In en, this message translates to:
  /// **'Me! Put my name down first. The Golden Bell is mine!'**
  String get pipSignsUp;

  /// No description provided for @berryFestival.
  ///
  /// In en, this message translates to:
  /// **'The Berry Festival'**
  String get berryFestival;

  /// No description provided for @festivalWhen.
  ///
  /// In en, this message translates to:
  /// **'Day {day} · 16:00 · on the hilltop'**
  String festivalWhen(int day);

  /// No description provided for @festivalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Lanterns, berry tarts and a wobbly stage'**
  String get festivalSubtitle;

  /// No description provided for @pipSings.
  ///
  /// In en, this message translates to:
  /// **'Pip sings with enormous feeling and almost no tune.'**
  String get pipSings;

  /// No description provided for @moFaints.
  ///
  /// In en, this message translates to:
  /// **'Mo opens his mouth, sways, and faints into the berry tarts.'**
  String get moFaints;

  /// No description provided for @moSings.
  ///
  /// In en, this message translates to:
  /// **'Mo sings, and the hilltop goes completely silent, then roars.'**
  String get moSings;

  /// No description provided for @llamaSings.
  ///
  /// In en, this message translates to:
  /// **'{name} sings a cheerful berry-picking song.'**
  String llamaSings(String name);

  /// No description provided for @songFallback.
  ///
  /// In en, this message translates to:
  /// **'Oh, the berries on the hill are sweet as summer...'**
  String get songFallback;

  /// No description provided for @laLaLa.
  ///
  /// In en, this message translates to:
  /// **'La la laaa...'**
  String get laLaLa;

  /// No description provided for @nobodyWins.
  ///
  /// In en, this message translates to:
  /// **'Nobody wins the Golden Bell'**
  String get nobodyWins;

  /// No description provided for @winsBell.
  ///
  /// In en, this message translates to:
  /// **'{name} wins the Golden Bell!'**
  String winsBell(String name);

  /// Subtitle under the ending title.
  ///
  /// In en, this message translates to:
  /// **'Ending'**
  String get endingWord;

  /// No description provided for @harmonyLanterns.
  ///
  /// In en, this message translates to:
  /// **'The lanterns came on, one by one, all the way up the hill.'**
  String get harmonyLanterns;

  /// No description provided for @harmonyPipMo.
  ///
  /// In en, this message translates to:
  /// **'Pip and Mo shared the last berry tart, and the scarf, for a while.'**
  String get harmonyPipMo;

  /// No description provided for @harmonyJune.
  ///
  /// In en, this message translates to:
  /// **'June read Bramble\'s poems out loud, and did not mind who heard.'**
  String get harmonyJune;

  /// No description provided for @harmonyNoRumour.
  ///
  /// In en, this message translates to:
  /// **'Not one rumour was left standing. Everyone sang the last song.'**
  String get harmonyNoRumour;

  /// No description provided for @harmonyDash.
  ///
  /// In en, this message translates to:
  /// **'And a small blue bird fell asleep in the bunting.'**
  String get harmonyDash;

  /// No description provided for @dramaSilence.
  ///
  /// In en, this message translates to:
  /// **'By sunset, nobody was speaking to anybody.'**
  String get dramaSilence;

  /// No description provided for @dramaWhistle.
  ///
  /// In en, this message translates to:
  /// **'Somewhere, a little blue bird whistled innocently.'**
  String get dramaWhistle;

  /// No description provided for @quietCame.
  ///
  /// In en, this message translates to:
  /// **'The festival came and went, the way festivals do.'**
  String get quietCame;

  /// No description provided for @quietWork.
  ///
  /// In en, this message translates to:
  /// **'Mo baked. June picked berries. Bramble watched the clouds.'**
  String get quietWork;

  /// No description provided for @quietSecrets.
  ///
  /// In en, this message translates to:
  /// **'The valley kept its secrets, and its peace.'**
  String get quietSecrets;

  /// The storybook title.
  ///
  /// In en, this message translates to:
  /// **'The Week Dash Came to Berry Valley'**
  String get storyTitle;

  /// No description provided for @storySeries.
  ///
  /// In en, this message translates to:
  /// **'A Llama Village storybook'**
  String get storySeries;

  /// No description provided for @storyDayCaption.
  ///
  /// In en, this message translates to:
  /// **'Day {day} · {countdown}'**
  String storyDayCaption(int day, String countdown);

  /// nth is first to fifth.
  ///
  /// In en, this message translates to:
  /// **'{nth, select, first{The First Day} second{The Second Day} third{The Third Day} fourth{The Fourth Day} other{The Fifth Day}}'**
  String storyDayTitle(String nth);

  /// No description provided for @storyEndingTitle.
  ///
  /// In en, this message translates to:
  /// **'Happily Ever After'**
  String get storyEndingTitle;

  /// No description provided for @theEnd.
  ///
  /// In en, this message translates to:
  /// **'The End'**
  String get theEnd;

  /// No description provided for @storyStillWriting.
  ///
  /// In en, this message translates to:
  /// **'The storyteller is still writing… {done} of {total} pages'**
  String storyStillWriting(int done, int total);

  /// No description provided for @storyBegin.
  ///
  /// In en, this message translates to:
  /// **'Turn the page to begin →'**
  String get storyBegin;

  /// No description provided for @storyQuill.
  ///
  /// In en, this message translates to:
  /// **'The storyteller is dipping her quill…'**
  String get storyQuill;

  /// No description provided for @tipPrevPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page (←)'**
  String get tipPrevPage;

  /// No description provided for @tipNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page (→)'**
  String get tipNextPage;

  /// No description provided for @tipCloseBook.
  ///
  /// In en, this message translates to:
  /// **'Close the book (Esc)'**
  String get tipCloseBook;

  /// No description provided for @sayScarfMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'Pip notices her red scarf is missing'**
  String get sayScarfMissingTitle;

  /// No description provided for @sayScarfMissingHome.
  ///
  /// In en, this message translates to:
  /// **'Pip reaches for her red scarf on its hook. The hook is empty. She turns her hut upside down: the scarf is gone.'**
  String get sayScarfMissingHome;

  /// No description provided for @sayScarfMissingAway.
  ///
  /// In en, this message translates to:
  /// **'Pip realises she has not seen her red scarf since yesterday. It is not on its hook: the scarf is gone.'**
  String get sayScarfMissingAway;

  /// No description provided for @sayScarfFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Scarf found'**
  String get sayScarfFoundTitle;

  /// No description provided for @sayScarfFound.
  ///
  /// In en, this message translates to:
  /// **'{name} pulls {name, select, Pip{her} other{Pip\'s}} red scarf, soggy, out of the pond reeds.'**
  String sayScarfFound(String name);

  /// No description provided for @sayScarfReturnedTitle.
  ///
  /// In en, this message translates to:
  /// **'Scarf returned'**
  String get sayScarfReturnedTitle;

  /// No description provided for @sayScarfReturned.
  ///
  /// In en, this message translates to:
  /// **'{name} hands Pip her red scarf.'**
  String sayScarfReturned(String name);

  /// No description provided for @sayFestivalAnnouncedTitle.
  ///
  /// In en, this message translates to:
  /// **'Berry Festival announced'**
  String get sayFestivalAnnouncedTitle;

  /// No description provided for @sayFestivalAnnounced.
  ///
  /// In en, this message translates to:
  /// **'Clover rings her bell: the Berry Festival is on day {day} at 16:00 on the hilltop, and the best singer wins the Golden Bell.'**
  String sayFestivalAnnounced(String day);

  /// No description provided for @sayPipSignsUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Pip signs up'**
  String get sayPipSignsUpTitle;

  /// No description provided for @sayPipSignsUp.
  ///
  /// In en, this message translates to:
  /// **'Pip shouts her name before Clover finishes the sentence.'**
  String get sayPipSignsUp;

  /// No description provided for @sayFestivalTitle.
  ///
  /// In en, this message translates to:
  /// **'The Berry Festival'**
  String get sayFestivalTitle;

  /// No description provided for @sayFestivalGathers.
  ///
  /// In en, this message translates to:
  /// **'Lanterns, berry tarts and a wobbly stage. {count} llamas gather on the hilltop. Singers: {names}.'**
  String sayFestivalGathers(String count, String names);

  /// No description provided for @sayFestivalNoSingers.
  ///
  /// In en, this message translates to:
  /// **'Lanterns, berry tarts and a wobbly stage. {count} llamas gather on the hilltop. Singers: nobody turned up.'**
  String sayFestivalNoSingers(String count);

  /// No description provided for @sayPipSingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pip sings'**
  String get sayPipSingsTitle;

  /// No description provided for @sayMoFaintsTitle.
  ///
  /// In en, this message translates to:
  /// **'Mo faints'**
  String get sayMoFaintsTitle;

  /// No description provided for @saySingsTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} sings'**
  String saySingsTitle(String name);

  /// No description provided for @sayGoldenBellTitle.
  ///
  /// In en, this message translates to:
  /// **'The Golden Bell'**
  String get sayGoldenBellTitle;

  /// No description provided for @sayGoldenBell.
  ///
  /// In en, this message translates to:
  /// **'Clover hands the Golden Bell to {name}. Scores: {scores}.'**
  String sayGoldenBell(String name, String scores);

  /// No description provided for @sayGoldenBellStory.
  ///
  /// In en, this message translates to:
  /// **'Clover hands the Golden Bell to {name}.'**
  String sayGoldenBellStory(String name);

  /// No description provided for @sayStormTitle.
  ///
  /// In en, this message translates to:
  /// **'Storm'**
  String get sayStormTitle;

  /// No description provided for @sayStorm.
  ///
  /// In en, this message translates to:
  /// **'Thunder cracks over the hilltop and sideways rain sweeps the village.'**
  String get sayStorm;

  /// No description provided for @sayStormClearsTitle.
  ///
  /// In en, this message translates to:
  /// **'The storm clears'**
  String get sayStormClearsTitle;

  /// No description provided for @sayStormClears.
  ///
  /// In en, this message translates to:
  /// **'The storm passes. Puddles everywhere, a rainbow over the pond.'**
  String get sayStormClears;

  /// No description provided for @sayHoneyLoafTitle.
  ///
  /// In en, this message translates to:
  /// **'Honey loaf'**
  String get sayHoneyLoafTitle;

  /// No description provided for @sayHoneyLoaf.
  ///
  /// In en, this message translates to:
  /// **'Mo pulls a honey loaf as big as a hay bale out of the bakery oven.'**
  String get sayHoneyLoaf;

  /// No description provided for @sayRehearsalTitle.
  ///
  /// In en, this message translates to:
  /// **'Rehearsal'**
  String get sayRehearsalTitle;

  /// No description provided for @sayRehearsalEmpty.
  ///
  /// In en, this message translates to:
  /// **'Clover blows her whistle at an empty stage and writes something stern on her clipboard.'**
  String get sayRehearsalEmpty;

  /// No description provided for @sayRehearsal.
  ///
  /// In en, this message translates to:
  /// **'Clover runs the singers through their songs; the stage wobbles but holds.'**
  String get sayRehearsal;

  /// No description provided for @sayLanternsTitle.
  ///
  /// In en, this message translates to:
  /// **'Lanterns'**
  String get sayLanternsTitle;

  /// No description provided for @sayLanterns.
  ///
  /// In en, this message translates to:
  /// **'Overnight, Clover has strung lanterns all the way up the hilltop path.'**
  String get sayLanterns;

  /// No description provided for @sayLogEvent.
  ///
  /// In en, this message translates to:
  /// **'{title}. {text}'**
  String sayLogEvent(String title, String text);

  /// No description provided for @sayLogEventSeen.
  ///
  /// In en, this message translates to:
  /// **'{title}. {text} (seen by {seen})'**
  String sayLogEventSeen(String title, String text, String seen);

  /// No description provided for @sayTalkStarted.
  ///
  /// In en, this message translates to:
  /// **'{a} and {b} talk {at}'**
  String sayTalkStarted(String a, String b, String at);

  /// No description provided for @sayTalkStartedAbout.
  ///
  /// In en, this message translates to:
  /// **'{a} and {b} talk {at} about {topic}'**
  String sayTalkStartedAbout(String a, String b, String at, String topic);

  /// No description provided for @sayNowKnows.
  ///
  /// In en, this message translates to:
  /// **'{name} now knows: {fact}'**
  String sayNowKnows(String name, String fact);

  /// No description provided for @sayNowKnowsDoubts.
  ///
  /// In en, this message translates to:
  /// **'{name} now knows: {fact}, but doubts it'**
  String sayNowKnowsDoubts(String name, String fact);

  /// No description provided for @sayOverheard.
  ///
  /// In en, this message translates to:
  /// **'{name} overheard: {fact}'**
  String sayOverheard(String name, String fact);

  /// No description provided for @saySawArgue.
  ///
  /// In en, this message translates to:
  /// **'{names} saw them argue'**
  String saySawArgue(String names);

  /// No description provided for @sayThreadTurn.
  ///
  /// In en, this message translates to:
  /// **'Thread {thread}: {from} → {to} ({why})'**
  String sayThreadTurn(String thread, String from, String to, String why);

  /// No description provided for @sayThreadNote.
  ///
  /// In en, this message translates to:
  /// **'Thread {thread}: {text}'**
  String sayThreadNote(String thread, String text);

  /// No description provided for @sayThreadTitle.
  ///
  /// In en, this message translates to:
  /// **'{thread, select, scarf{The lost red scarf} festival{Berry Festival singing contest} crush{Bramble\'s crush on June} rumour{The bread rumour} storm{Bramble\'s storm warning} week{Festival week} other{{thread}}}'**
  String sayThreadTitle(String thread);

  /// No description provided for @sayThreadState.
  ///
  /// In en, this message translates to:
  /// **'{state, select, unnoticed{unnoticed} missing{missing} found{found} returned{returned} unannounced{unannounced} announced{announced} contest{contest} performed{performed} judged{judged} secret{secret} poemFound{poem found} suspected{suspected} confessed{confessed} exposed{exposed} accepted{accepted} letDownGently{let down gently} spreading{spreading} debunked{debunked} juneExposed{june exposed} forecast{forecast} storm{storm} passed{passed} other{{state}}}'**
  String sayThreadState(String state);

  /// No description provided for @sayThreadDay.
  ///
  /// In en, this message translates to:
  /// **'day {day}'**
  String sayThreadDay(String day);

  /// No description provided for @sayWhyPipNoticed.
  ///
  /// In en, this message translates to:
  /// **'Pip noticed it was gone'**
  String get sayWhyPipNoticed;

  /// No description provided for @sayWhyPipFoundHerself.
  ///
  /// In en, this message translates to:
  /// **'Pip found it herself in the pond reeds'**
  String get sayWhyPipFoundHerself;

  /// No description provided for @sayWhyFoundIt.
  ///
  /// In en, this message translates to:
  /// **'{name} found it in the pond reeds'**
  String sayWhyFoundIt(String name);

  /// No description provided for @sayWhyGaveBack.
  ///
  /// In en, this message translates to:
  /// **'{name} gave it back'**
  String sayWhyGaveBack(String name);

  /// No description provided for @sayWhyAnnounced.
  ///
  /// In en, this message translates to:
  /// **'Clover announced it; Pip signed up at once'**
  String get sayWhyAnnounced;

  /// No description provided for @sayWhyJoinedPip.
  ///
  /// In en, this message translates to:
  /// **'{name} joined Pip in the contest'**
  String sayWhyJoinedPip(String name);

  /// No description provided for @sayWhyNoSingers.
  ///
  /// In en, this message translates to:
  /// **'no singers'**
  String get sayWhyNoSingers;

  /// No description provided for @sayWhySang.
  ///
  /// In en, this message translates to:
  /// **'{names} sang'**
  String sayWhySang(String names);

  /// No description provided for @sayWhyWon.
  ///
  /// In en, this message translates to:
  /// **'{name} won the Golden Bell; {how}.'**
  String sayWhyWon(String name, String how);

  /// No description provided for @sayWhyNoWinner.
  ///
  /// In en, this message translates to:
  /// **'No winner: {how}.'**
  String sayWhyNoWinner(String how);

  /// No description provided for @sayHowNobodySang.
  ///
  /// In en, this message translates to:
  /// **'nobody sang'**
  String get sayHowNobodySang;

  /// No description provided for @sayHowDeal.
  ///
  /// In en, this message translates to:
  /// **'Clover quietly honoured her secret deal with Pip'**
  String get sayHowDeal;

  /// No description provided for @sayHowDealKnown.
  ///
  /// In en, this message translates to:
  /// **'the deal was known to {names}, so Clover judged fairly'**
  String sayHowDealKnown(String names);

  /// No description provided for @sayHowFair.
  ///
  /// In en, this message translates to:
  /// **'judged on voice and the crowd'**
  String get sayHowFair;

  /// No description provided for @sayWhyJuneFoundPoem.
  ///
  /// In en, this message translates to:
  /// **'June found an anonymous love poem'**
  String get sayWhyJuneFoundPoem;

  /// No description provided for @sayWhyJuneSawFlowers.
  ///
  /// In en, this message translates to:
  /// **'June saw Bramble leave the flowers'**
  String get sayWhyJuneSawFlowers;

  /// No description provided for @sayWhyBrambleTold.
  ///
  /// In en, this message translates to:
  /// **'Bramble told June himself'**
  String get sayWhyBrambleTold;

  /// No description provided for @sayWhyJuneHeard.
  ///
  /// In en, this message translates to:
  /// **'June heard it from {name}'**
  String sayWhyJuneHeard(String name);

  /// No description provided for @sayWhyJuneOverheard.
  ///
  /// In en, this message translates to:
  /// **'June overheard it from {name}'**
  String sayWhyJuneOverheard(String name);

  /// No description provided for @sayWhyJuneHeardFlowers.
  ///
  /// In en, this message translates to:
  /// **'June heard Bramble leaves the flowers'**
  String get sayWhyJuneHeardFlowers;

  /// No description provided for @sayWhyCrushConfessed.
  ///
  /// In en, this message translates to:
  /// **'Bramble confessed; June {outcome, select, accepted{accepted him} other{let him down gently}}.'**
  String sayWhyCrushConfessed(String outcome);

  /// No description provided for @sayWhyCrushExposed.
  ///
  /// In en, this message translates to:
  /// **'Bramble was exposed by {name}; June {outcome, select, accepted{accepted him} other{let him down gently}}.'**
  String sayWhyCrushExposed(String name, String outcome);

  /// No description provided for @sayWhyNobodyBelieves.
  ///
  /// In en, this message translates to:
  /// **'nobody believes it any more'**
  String get sayWhyNobodyBelieves;

  /// No description provided for @sayWhyJuneExposed.
  ///
  /// In en, this message translates to:
  /// **'{name} learned June made it up (from {from})'**
  String sayWhyJuneExposed(String name, String from);

  /// No description provided for @sayWhyStormArrived.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{it arrived on time, but nobody had believed him} =1{it arrived on time; one llama had been warned} other{it arrived on time; {count} llamas had been warned}}'**
  String sayWhyStormArrived(int count);

  /// No description provided for @sayWhySkyCleared.
  ///
  /// In en, this message translates to:
  /// **'the sky cleared'**
  String get sayWhySkyCleared;

  /// No description provided for @sayConfMoTold.
  ///
  /// In en, this message translates to:
  /// **'Mo confessed to Pip'**
  String get sayConfMoTold;

  /// No description provided for @sayConfPipOverheard.
  ///
  /// In en, this message translates to:
  /// **'Pip overheard Mo confessing to someone else'**
  String get sayConfPipOverheard;

  /// No description provided for @sayConfPipLearned.
  ///
  /// In en, this message translates to:
  /// **'Pip learned it from {from}'**
  String sayConfPipLearned(String from);

  /// No description provided for @saySearchNothing.
  ///
  /// In en, this message translates to:
  /// **'{name} searches for the scarf {at} and finds nothing.'**
  String saySearchNothing(String name, String at);

  /// No description provided for @sayPondNothing.
  ///
  /// In en, this message translates to:
  /// **'{name} pokes around the pond reeds but finds nothing.'**
  String sayPondNothing(String name);

  /// No description provided for @saySignsUp.
  ///
  /// In en, this message translates to:
  /// **'{name} signs up for the singing contest ({how}).'**
  String saySignsUp(String name, String how);

  /// No description provided for @sayHowToldClover.
  ///
  /// In en, this message translates to:
  /// **'he told Clover yes'**
  String get sayHowToldClover;

  /// No description provided for @sayHowCloverTalked.
  ///
  /// In en, this message translates to:
  /// **'Clover talked her into it'**
  String get sayHowCloverTalked;

  /// No description provided for @sayMoBraver.
  ///
  /// In en, this message translates to:
  /// **'Mo feels braver after talking with {name} (courage {pct}%).'**
  String sayMoBraver(String name, String pct);

  /// No description provided for @sayMoTookBack.
  ///
  /// In en, this message translates to:
  /// **'Mo said yes, then went pale and took it back (courage {pct}%).'**
  String sayMoTookBack(String pct);

  /// No description provided for @sayJuneFindsPoem.
  ///
  /// In en, this message translates to:
  /// **'June finds an unsigned love poem tucked into the wildflowers. She reads it twice.'**
  String get sayJuneFindsPoem;

  /// No description provided for @sayFlowersUnseen.
  ///
  /// In en, this message translates to:
  /// **'Bramble tucks wildflowers into the berry bushes unseen.'**
  String get sayFlowersUnseen;

  /// No description provided for @sayFlowersSeen.
  ///
  /// In en, this message translates to:
  /// **'Bramble tucks wildflowers into the berry bushes, but {names} sees him.'**
  String sayFlowersSeen(String names);

  /// No description provided for @saySayGoodnight.
  ///
  /// In en, this message translates to:
  /// **'{a} and {b} say goodnight.'**
  String saySayGoodnight(String a, String b);

  /// No description provided for @sayBreakOffFestival.
  ///
  /// In en, this message translates to:
  /// **'{a} and {b} break off to hurry to the festival.'**
  String sayBreakOffFestival(String a, String b);

  /// No description provided for @sayMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning of day {day}. The village wakes up.'**
  String sayMorning(String day);

  /// No description provided for @sayLiesAwake.
  ///
  /// In en, this message translates to:
  /// **'{name} lies awake thinking: \"{thought}\"'**
  String sayLiesAwake(String name, String thought);

  /// No description provided for @sayHearsPip.
  ///
  /// In en, this message translates to:
  /// **'{names} {count, plural, =1{hears} other{hear}} Pip croaking scales {at}.'**
  String sayHearsPip(String names, int count, String at);

  /// No description provided for @sayPlanned.
  ///
  /// In en, this message translates to:
  /// **'The llamas have planned their day.'**
  String get sayPlanned;

  /// No description provided for @sayGoalFetchScarf.
  ///
  /// In en, this message translates to:
  /// **'fetch your red scarf from your hut to look your best'**
  String get sayGoalFetchScarf;

  /// No description provided for @sayGoalAskSeen.
  ///
  /// In en, this message translates to:
  /// **'ask {name} whether they have seen your red scarf'**
  String sayGoalAskSeen(String name);

  /// No description provided for @sayGoalFindScarf.
  ///
  /// In en, this message translates to:
  /// **'find your red scarf and find out who took it'**
  String get sayGoalFindScarf;

  /// No description provided for @sayGoalSearchScarf.
  ///
  /// In en, this message translates to:
  /// **'search for your red scarf'**
  String get sayGoalSearchScarf;

  /// No description provided for @sayGoalMoFish.
  ///
  /// In en, this message translates to:
  /// **'quietly fish Pip\'s scarf out of the pond reeds before anyone learns what you did'**
  String get sayGoalMoFish;

  /// No description provided for @sayGoalHelpPip.
  ///
  /// In en, this message translates to:
  /// **'help Pip look for her red scarf'**
  String get sayGoalHelpPip;

  /// No description provided for @sayGoalGiveBackMo.
  ///
  /// In en, this message translates to:
  /// **'give Pip back her red scarf, and decide whether to confess you knocked it into the pond'**
  String get sayGoalGiveBackMo;

  /// No description provided for @sayGoalGiveBack.
  ///
  /// In en, this message translates to:
  /// **'give Pip back her red scarf (you found it in the pond reeds)'**
  String get sayGoalGiveBack;

  /// No description provided for @sayGoalMoGuilty.
  ///
  /// In en, this message translates to:
  /// **'you still feel guilty: maybe confess to Pip that you knocked her scarf into the pond'**
  String get sayGoalMoGuilty;

  /// No description provided for @sayGoalBeAtFestival.
  ///
  /// In en, this message translates to:
  /// **'be at the hilltop for the Berry Festival at 16:00'**
  String get sayGoalBeAtFestival;

  /// No description provided for @sayGoalSetUpStage.
  ///
  /// In en, this message translates to:
  /// **'set up the festival stage on the hilltop'**
  String get sayGoalSetUpStage;

  /// No description provided for @sayGoalRecruitMo.
  ///
  /// In en, this message translates to:
  /// **'recruit Mo to sing at the festival (he has the best voice)'**
  String get sayGoalRecruitMo;

  /// No description provided for @sayGoalTellClover.
  ///
  /// In en, this message translates to:
  /// **'tell Clover you will sing at the festival after all'**
  String get sayGoalTellClover;

  /// No description provided for @sayGoalMoScared.
  ///
  /// In en, this message translates to:
  /// **'you are far too scared to sing at the festival; you would faint'**
  String get sayGoalMoScared;

  /// No description provided for @sayGoalMoTempted.
  ///
  /// In en, this message translates to:
  /// **'you are tempted to sing at the festival but scared of fainting'**
  String get sayGoalMoTempted;

  /// No description provided for @sayGoalMoAlmost.
  ///
  /// In en, this message translates to:
  /// **'you are almost brave enough to say yes to singing at the festival'**
  String get sayGoalMoAlmost;

  /// No description provided for @sayGoalPractise.
  ///
  /// In en, this message translates to:
  /// **'practise singing at the pond at dawn, where nobody can hear'**
  String get sayGoalPractise;

  /// No description provided for @sayGoalWinBell.
  ///
  /// In en, this message translates to:
  /// **'win the Golden Bell; outshine Mo'**
  String get sayGoalWinBell;

  /// No description provided for @sayGoalLeaveFlowers.
  ///
  /// In en, this message translates to:
  /// **'leave wildflowers for June at the berry bushes before anyone sees'**
  String get sayGoalLeaveFlowers;

  /// No description provided for @sayGoalTellJune.
  ///
  /// In en, this message translates to:
  /// **'work up the courage to tell June that you are the one writing her love poems'**
  String get sayGoalTellJune;

  /// No description provided for @sayGoalFindWhoFlowers.
  ///
  /// In en, this message translates to:
  /// **'find out who leaves you wildflowers and love poems'**
  String get sayGoalFindWhoFlowers;

  /// No description provided for @sayGoalTalkBramble.
  ///
  /// In en, this message translates to:
  /// **'talk to Bramble about the love poems'**
  String get sayGoalTalkBramble;

  /// No description provided for @sayGoalFaceJune.
  ///
  /// In en, this message translates to:
  /// **'face June about the poems'**
  String get sayGoalFaceJune;

  /// No description provided for @sayGoalSpreadRumour.
  ///
  /// In en, this message translates to:
  /// **'spread the juicy story about Mo\'s bread'**
  String get sayGoalSpreadRumour;

  /// No description provided for @sayGoalClearName.
  ///
  /// In en, this message translates to:
  /// **'clear your name: your bread never made anyone sick'**
  String get sayGoalClearName;

  /// No description provided for @sayGoalSetRecord.
  ///
  /// In en, this message translates to:
  /// **'set the record straight: Mo\'s bread never made you sick'**
  String get sayGoalSetRecord;

  /// No description provided for @sayGoalWarnToday.
  ///
  /// In en, this message translates to:
  /// **'warn everyone that a storm will hit this afternoon; be taken seriously'**
  String get sayGoalWarnToday;

  /// No description provided for @sayGoalWarnDay.
  ///
  /// In en, this message translates to:
  /// **'warn everyone that a storm will hit on the afternoon of day {day}; be taken seriously'**
  String sayGoalWarnDay(String day);

  /// No description provided for @sayGoalRunRehearsal.
  ///
  /// In en, this message translates to:
  /// **'run the festival rehearsal on the hilltop at 11:00'**
  String get sayGoalRunRehearsal;

  /// No description provided for @sayGoalGoRehearsal.
  ///
  /// In en, this message translates to:
  /// **'go to Clover\'s rehearsal on the hilltop at 11:00'**
  String get sayGoalGoRehearsal;

  /// No description provided for @sayWhyHunger.
  ///
  /// In en, this message translates to:
  /// **'hunger {v}'**
  String sayWhyHunger(String v);

  /// No description provided for @sayWhyEnergy.
  ///
  /// In en, this message translates to:
  /// **'energy {v}'**
  String sayWhyEnergy(String v);

  /// No description provided for @sayWhyPlanWork.
  ///
  /// In en, this message translates to:
  /// **'plan says work'**
  String get sayWhyPlanWork;

  /// No description provided for @sayWhyAtWorkplace.
  ///
  /// In en, this message translates to:
  /// **'at workplace'**
  String get sayWhyAtWorkplace;

  /// No description provided for @sayWhyNight.
  ///
  /// In en, this message translates to:
  /// **'night'**
  String get sayWhyNight;

  /// No description provided for @sayWhyPlanAt.
  ///
  /// In en, this message translates to:
  /// **'plan: {place}'**
  String sayWhyPlanAt(String place);

  /// No description provided for @sayWhyWaiting.
  ///
  /// In en, this message translates to:
  /// **'waiting for {name}'**
  String sayWhyWaiting(String name);

  /// No description provided for @sayWhyFood.
  ///
  /// In en, this message translates to:
  /// **'food'**
  String get sayWhyFood;

  /// No description provided for @sayWhyRest.
  ///
  /// In en, this message translates to:
  /// **'rest'**
  String get sayWhyRest;

  /// No description provided for @sayWhyWork.
  ///
  /// In en, this message translates to:
  /// **'work'**
  String get sayWhyWork;

  /// No description provided for @sayWhyCompany.
  ///
  /// In en, this message translates to:
  /// **'company: {name}'**
  String sayWhyCompany(String name);

  /// No description provided for @sayWhyBedtime.
  ///
  /// In en, this message translates to:
  /// **'bedtime'**
  String get sayWhyBedtime;

  /// No description provided for @sayWhyShelter.
  ///
  /// In en, this message translates to:
  /// **'shelter from the storm'**
  String get sayWhyShelter;

  /// No description provided for @sayWhyNothing.
  ///
  /// In en, this message translates to:
  /// **'nothing better'**
  String get sayWhyNothing;

  /// No description provided for @sayStoryThread.
  ///
  /// In en, this message translates to:
  /// **'{thread}: {why}'**
  String sayStoryThread(String thread, String why);

  /// No description provided for @sayStoryTalk.
  ///
  /// In en, this message translates to:
  /// **'{a} and {b} talked {at}{how, select, quarrel{, and it ended in a quarrel} warm{, and they parted warmly} other{}}.'**
  String sayStoryTalk(String a, String b, String at, String how);

  /// No description provided for @sayStoryTalkAbout.
  ///
  /// In en, this message translates to:
  /// **'{a} and {b} talked {at} about {topic}{how, select, quarrel{, and it ended in a quarrel} warm{, and they parted warmly} other{}}.'**
  String sayStoryTalkAbout(String a, String b, String at, String topic, String how);

  /// No description provided for @sayStoryConfided.
  ///
  /// In en, this message translates to:
  /// **'{name} confided in Dash: {fact}.'**
  String sayStoryConfided(String name, String fact);

  /// No description provided for @sayStoryHeard.
  ///
  /// In en, this message translates to:
  /// **'{name} {overheard, select, yes{overheard {from} say} other{heard from {from}}}: {fact}{untrue, select, yes{ (it was not true)} other{}}{doubts, select, yes{, but did not believe it} other{}}.'**
  String sayStoryHeard(String name, String from, String fact, String overheard, String untrue, String doubts);

  /// No description provided for @sayStoryGossip.
  ///
  /// In en, this message translates to:
  /// **'Dash whispered {count, plural, =1{a made-up rumour} other{made-up rumours}} about {names} to {name}, and {name} was {reaction, select, offended{offended} annoyed{annoyed} indifferent{indifferent} pleased{pleased} delighted{delighted} other{{reaction}}}.'**
  String sayStoryGossip(String name, String names, int count, String reaction);

  /// No description provided for @sayStoryDash.
  ///
  /// In en, this message translates to:
  /// **'Dash {intent, select, praise{told {name} something kind about {about}} tell{passed on some news to {name}} gift{gave {name} {item}} help{offered to help {name}} compliment{paid {name} a compliment} tease{teased {name}} other{spoke with {name}}}, and {name} was {reaction, select, offended{offended} annoyed{annoyed} indifferent{indifferent} pleased{pleased} delighted{delighted} other{{reaction}}}.'**
  String sayStoryDash(String name, String intent, String about, String item, String reaction);

  /// No description provided for @sayItem.
  ///
  /// In en, this message translates to:
  /// **'{item, select, ribbon{a red ribbon} honey{a jar of honey} pebble{a shiny pebble} mint{a bundle of mint} other{{item}}}'**
  String sayItem(String item);

  /// No description provided for @sayAt.
  ///
  /// In en, this message translates to:
  /// **'{place, select, pond{at the pond} berryBushes{at the berry bushes} bakery{at the bakery} hilltop{on the hilltop} hut{at {name}\'s hut} other{at {place}}}'**
  String sayAt(String place, String name);

  /// No description provided for @sayAnd.
  ///
  /// In en, this message translates to:
  /// **'{first} and {last}'**
  String sayAnd(String first, String last);

  /// No description provided for @sayFactPipTune.
  ///
  /// In en, this message translates to:
  /// **'Pip cannot hold a tune and practises singing in secret at the pond at dawn.'**
  String get sayFactPipTune;

  /// No description provided for @sayFactMoScarf.
  ///
  /// In en, this message translates to:
  /// **'Mo knocked Pip\'s red scarf into the pond reeds by accident and never told her.'**
  String get sayFactMoScarf;

  /// No description provided for @sayFactScarfWhere.
  ///
  /// In en, this message translates to:
  /// **'Pip\'s red scarf is lying in the pond reeds.'**
  String get sayFactScarfWhere;

  /// No description provided for @sayFactJuneRumour.
  ///
  /// In en, this message translates to:
  /// **'June made up the rumour that Mo\'s bread made Bramble sick.'**
  String get sayFactJuneRumour;

  /// No description provided for @sayFactBreadRumour.
  ///
  /// In en, this message translates to:
  /// **'Mo\'s bread made Bramble sick.'**
  String get sayFactBreadRumour;

  /// No description provided for @sayFactBreadTruth.
  ///
  /// In en, this message translates to:
  /// **'Bramble was never sick from Mo\'s bread; the bread rumour is false.'**
  String get sayFactBreadTruth;

  /// No description provided for @sayFactBramblePoems.
  ///
  /// In en, this message translates to:
  /// **'Bramble writes anonymous love poems to June.'**
  String get sayFactBramblePoems;

  /// No description provided for @sayFactWildflowers.
  ///
  /// In en, this message translates to:
  /// **'Someone keeps leaving wildflowers at the berry bushes for June.'**
  String get sayFactWildflowers;

  /// No description provided for @sayFactCloverDeal.
  ///
  /// In en, this message translates to:
  /// **'Clover secretly promised Pip the Golden Bell in exchange for a free scarf.'**
  String get sayFactCloverDeal;

  /// No description provided for @sayFactStormForecast.
  ///
  /// In en, this message translates to:
  /// **'Bramble predicts a big storm will hit the village on the afternoon of day {day}.'**
  String sayFactStormForecast(String day);

  /// No description provided for @sayFactMoVoice.
  ///
  /// In en, this message translates to:
  /// **'Mo sang beautifully at last year\'s festival and got the loudest applause.'**
  String get sayFactMoVoice;

  /// No description provided for @sayFactHoneyLoaf.
  ///
  /// In en, this message translates to:
  /// **'Mo baked a giant honey loaf for the Berry Festival on day 2.'**
  String get sayFactHoneyLoaf;

  /// No description provided for @sayFactRehearsal.
  ///
  /// In en, this message translates to:
  /// **'Clover held a festival rehearsal on the hilltop on day 4; {names} practised.'**
  String sayFactRehearsal(String names);

  /// No description provided for @sayFactRehearsalEmpty.
  ///
  /// In en, this message translates to:
  /// **'Clover held a festival rehearsal on the hilltop on day 4; no singer came.'**
  String get sayFactRehearsalEmpty;

  /// No description provided for @sayFactLanterns.
  ///
  /// In en, this message translates to:
  /// **'Clover strung lanterns all the way up the hilltop path for the festival.'**
  String get sayFactLanterns;

  /// No description provided for @sayFactScarfMissing.
  ///
  /// In en, this message translates to:
  /// **'Pip\'s red scarf has gone missing from her hut.'**
  String get sayFactScarfMissing;

  /// No description provided for @sayFactScarfFound.
  ///
  /// In en, this message translates to:
  /// **'{name} found Pip\'s red scarf in the pond reeds.'**
  String sayFactScarfFound(String name);

  /// No description provided for @sayFactScarfReturned.
  ///
  /// In en, this message translates to:
  /// **'{name} gave Pip back her red scarf.'**
  String sayFactScarfReturned(String name);

  /// No description provided for @sayFactFestival.
  ///
  /// In en, this message translates to:
  /// **'Clover announced the Berry Festival for day {day} at 16:00 on the hilltop; the best singer wins the Golden Bell.'**
  String sayFactFestival(String day);

  /// No description provided for @sayFactSigned.
  ///
  /// In en, this message translates to:
  /// **'{name} signed up to sing at the Berry Festival.'**
  String sayFactSigned(String name);

  /// No description provided for @sayFactMoFainted.
  ///
  /// In en, this message translates to:
  /// **'Mo fainted on stage at the Berry Festival before singing a note.'**
  String get sayFactMoFainted;

  /// No description provided for @sayFactFestivalWinner.
  ///
  /// In en, this message translates to:
  /// **'{name} won the Golden Bell at the Berry Festival.'**
  String sayFactFestivalWinner(String name);

  /// No description provided for @sayFactAnonPoem.
  ///
  /// In en, this message translates to:
  /// **'June found an unsigned love poem tucked into the wildflowers at the berry bushes.'**
  String get sayFactAnonPoem;

  /// No description provided for @sayFactBrambleFlowers.
  ///
  /// In en, this message translates to:
  /// **'Bramble was seen leaving wildflowers at the berry bushes at dawn.'**
  String get sayFactBrambleFlowers;

  /// No description provided for @sayFactStormHit.
  ///
  /// In en, this message translates to:
  /// **'A storm hit the village on day {day} at 15:00: thunder, sideways rain, the festival bunting blew away.'**
  String sayFactStormHit(String day);

  /// No description provided for @sayFactBrambleRight.
  ///
  /// In en, this message translates to:
  /// **'Bramble\'s storm prediction came true.'**
  String get sayFactBrambleRight;

  /// No description provided for @sayFactStormPassed.
  ///
  /// In en, this message translates to:
  /// **'The storm passed in the evening of day {day}, leaving puddles and a rainbow over the pond.'**
  String sayFactStormPassed(String day);

  /// No description provided for @sayFactGift.
  ///
  /// In en, this message translates to:
  /// **'Dash gave {name} {item}.'**
  String sayFactGift(String name, String item);

  /// No description provided for @sayFactArgument.
  ///
  /// In en, this message translates to:
  /// **'{a} and {b} had a heated argument {at} (day {day}).'**
  String sayFactArgument(String a, String b, String at, String day);

  /// No description provided for @sayEndWeek.
  ///
  /// In en, this message translates to:
  /// **'The week ended as \"{title}\": {blurb}'**
  String sayEndWeek(String title, String blurb);

  /// No description provided for @sayEndNoWinner.
  ///
  /// In en, this message translates to:
  /// **'Nobody won the Golden Bell.'**
  String get sayEndNoWinner;

  /// No description provided for @sayEndRumoursNone.
  ///
  /// In en, this message translates to:
  /// **'Every untrue rumour had been put right.'**
  String get sayEndRumoursNone;

  /// No description provided for @sayEndRumoursFew.
  ///
  /// In en, this message translates to:
  /// **'A few untrue rumours were still going round.'**
  String get sayEndRumoursFew;

  /// No description provided for @sayEndRumoursMany.
  ///
  /// In en, this message translates to:
  /// **'Many untrue rumours were still going round.'**
  String get sayEndRumoursMany;

  /// No description provided for @sayEndFond.
  ///
  /// In en, this message translates to:
  /// **'The llamas were fond of one another.'**
  String get sayEndFond;

  /// No description provided for @sayEndSoured.
  ///
  /// In en, this message translates to:
  /// **'Many friendships had soured.'**
  String get sayEndSoured;

  /// No description provided for @sayEndMixed.
  ///
  /// In en, this message translates to:
  /// **'Some friendships were warm and some were cool.'**
  String get sayEndMixed;

  /// No description provided for @sayEndArc.
  ///
  /// In en, this message translates to:
  /// **'{arc, select, reconciled{Pip and Mo made up.} rift{Pip and Mo fell out.} unresolved{Things between Pip and Mo were left unsaid.} accepted{June said yes to Bramble.} declined{June let Bramble down gently.} revealed{Everyone knows Bramble writes June\'s poems.} secret{Nobody learned who writes June\'s poems.} other{}}'**
  String sayEndArc(String arc);

  /// No description provided for @sayEndHappiest.
  ///
  /// In en, this message translates to:
  /// **'{a} ended the week happiest, and {b} the gloomiest.'**
  String sayEndHappiest(String a, String b);

  /// No description provided for @sayEndDashCross.
  ///
  /// In en, this message translates to:
  /// **'Most llamas were cross with Dash.'**
  String get sayEndDashCross;

  /// No description provided for @sayEndDashFond.
  ///
  /// In en, this message translates to:
  /// **'Most llamas had grown fond of Dash.'**
  String get sayEndDashFond;

  /// No description provided for @sayEndDashUnsure.
  ///
  /// In en, this message translates to:
  /// **'The llamas were not sure what to make of Dash.'**
  String get sayEndDashUnsure;

  /// No description provided for @sayQuietDay.
  ///
  /// In en, this message translates to:
  /// **'A quiet day: the llamas went about their work.'**
  String get sayQuietDay;

  /// No description provided for @pickSave.
  ///
  /// In en, this message translates to:
  /// **'Pick a save to load.'**
  String get pickSave;

  /// Real time played in a saved game, under an hour.
  ///
  /// In en, this message translates to:
  /// **'Played {minutes} min'**
  String playtimeMinutes(int minutes);

  /// Real time played in a saved game.
  ///
  /// In en, this message translates to:
  /// **'Played {hours} h {minutes} min'**
  String playtimeHours(int hours, int minutes);

  /// When a save was written; date is a short date and time.
  ///
  /// In en, this message translates to:
  /// **'Saved {date}'**
  String savedOn(String date);

  /// No description provided for @saveCannotLoad.
  ///
  /// In en, this message translates to:
  /// **'This save cannot be loaded.'**
  String get saveCannotLoad;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'fr', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return L10nEn();
    case 'fr':
      return L10nFr();
    case 'ko':
      return L10nKo();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Llama Village';

  @override
  String get appSubtitle => 'Festival Week';

  @override
  String get titleTagline => 'Five llamas, five days, one nosy little bird.';

  @override
  String get loadingTagline => 'Five llamas, their secrets, and one nosy little bird.';

  @override
  String get buildingVillage => 'Building the village…';

  @override
  String sceneFailed(String error) {
    return 'The 3D scene failed to load: $error';
  }

  @override
  String get modelsNotFoundTitle => 'The AI models were not found.';

  @override
  String modelsMissing(String files) {
    return 'Missing: $files';
  }

  @override
  String get modelsFailedTitle => 'The models failed to load.';

  @override
  String get quit => 'Quit';

  @override
  String get playWithoutAi => 'Play without AI (canned lines)';

  @override
  String get statusCanned => 'Playing with canned lines (no AI).';

  @override
  String statusMissing(String files, String dir) {
    return 'AI models not found ($files; looked in $dir). New games use canned lines. See README: VILLAGE_CHAT_MODEL, VILLAGE_EMBED_MODEL.';
  }

  @override
  String get statusLoading => 'Loading the AI models…';

  @override
  String loadProgress(String stage, int percent) {
    String _temp0 = intl.Intl.selectLogic(stage, {
      'dialogue': 'Loading the dialogue model (gemma-4-E2B)…',
      'embedding': 'Loading the embedding model (EmbeddingGemma)…',
      'laya': 'Loading Laya for casual topics…',
      'other': 'Warming up…',
    });
    return '$_temp0 $percent%';
  }

  @override
  String statusReady(String models) {
    return 'Ready: $models';
  }

  @override
  String statusFailed(String error) {
    return 'The AI models failed to load ($error). New games use canned lines.';
  }

  @override
  String get cannedLabel => 'canned lines (no AI)';

  @override
  String get busyWaitingModels => 'Waiting for the AI models…';

  @override
  String get busyPlanning => 'The llamas are planning their day…';

  @override
  String busySkipping(int day) {
    return 'Skipping ahead to day $day…';
  }

  @override
  String busyLoading(String when) {
    return 'Loading $when…';
  }

  @override
  String get busyTidying => 'Tidying up…';

  @override
  String toastCannotLoad(String reason) {
    return 'That save cannot be loaded: $reason';
  }

  @override
  String toastSaved(String slot, int day, String time) {
    String _temp0 = intl.Intl.selectLogic(slot, {'auto': 'Saved to the autosave', 'other': 'Saved to slot $slot'});
    return '$_temp0: day $day, $time';
  }

  @override
  String toastSaveFailed(String error) {
    return 'Could not save: $error';
  }

  @override
  String get noticePlanningTomorrow => 'The llamas are planning tomorrow…';

  @override
  String get noticePaused => 'Paused';

  @override
  String dayClock(int day, String time) {
    return 'Day $day  $time';
  }

  @override
  String dayAndTime(int day, String time) {
    return 'Day $day, $time';
  }

  @override
  String countdown(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days to the festival',
      one: 'the day before the festival',
      zero: 'Berry Festival day',
    );
    return '$_temp0';
  }

  @override
  String countdownTitle(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days to the festival',
      one: 'The day before the festival',
      zero: 'The Berry Festival is today at 16:00',
    );
    return '$_temp0';
  }

  @override
  String get afterFestival => 'after the festival';

  @override
  String get planningTomorrowLower => 'the llamas are planning tomorrow…';

  @override
  String dayTitle(int day) {
    return 'Day $day';
  }

  @override
  String get tipPause => 'Pause (Space)';

  @override
  String get tipOverview => 'Overview (O)';

  @override
  String get tipFollow => 'Follow the selected llama or Dash (F)';

  @override
  String get tipSettings => 'Settings';

  @override
  String fps(String fps) {
    return '$fps fps';
  }

  @override
  String thinking(String job) {
    String _temp0 = intl.Intl.selectLogic(job, {
      'dialogue': 'a line',
      'thought': 'a thought',
      'dash_options': 'Dash\'s options',
      'dash_reply': 'a reply',
      'outcome': 'how it went',
      'schedule': 'plans',
      'reflection': 'a dream',
      'storybook': 'the storybook',
      'epilogue': 'an epilogue',
      'announcement': 'an announcement',
      'song': 'a song',
      'other': '…',
    });
    return 'thinking: $_temp0';
  }

  @override
  String get villageLog => 'Village log';

  @override
  String get helpHint =>
      'Click a llama: Dash flies over to talk  ·  Right-click: inspect only  ·  Click ground or WASD: fly\nDrag: orbit  ·  Right-drag / two fingers: pan  ·  Scroll / pinch: zoom  ·  Space: pause  ·  F: follow  ·  O: overview';

  @override
  String dashFlying(String name) {
    return 'Dash is flying over to $name…';
  }

  @override
  String dashWaiting(String name) {
    return '$name is busy. Dash waits nearby…';
  }

  @override
  String get dashThinking => 'Dash is thinking of what to say…';

  @override
  String llamaAnswering(String name) {
    return '$name is answering…';
  }

  @override
  String reactionLine(String name, String reaction) {
    String _temp0 = intl.Intl.selectLogic(reaction, {
      'offended': 'offended',
      'annoyed': 'annoyed',
      'indifferent': 'indifferent',
      'pleased': 'pleased',
      'delighted': 'delighted',
      'other': '$reaction',
    });
    return '$name is $_temp0.';
  }

  @override
  String get sayMore => 'Say more';

  @override
  String get flyOff => 'Fly off';

  @override
  String get tipLeave => 'Leave (Esc)';

  @override
  String dashAnd(String name) {
    return 'Dash and $name';
  }

  @override
  String atPlaceMood(String place, String mood) {
    return 'at $place · $mood';
  }

  @override
  String intent(String intent) {
    String _temp0 = intl.Intl.selectLogic(intent, {
      'compliment': 'compliment',
      'gossip': 'gossip',
      'praise': 'praise',
      'tell': 'news',
      'gift': 'gift',
      'help': 'help',
      'tease': 'tease',
      'other': '$intent',
    });
    return '$_temp0';
  }

  @override
  String place(String place) {
    String _temp0 = intl.Intl.selectLogic(place, {
      'pond': 'the pond',
      'berryBushes': 'the berry bushes',
      'bakery': 'the bakery',
      'hilltop': 'the hilltop',
      'other': '$place',
    });
    return '$_temp0';
  }

  @override
  String hut(String name) {
    return '$name\'s hut';
  }

  @override
  String mood(String mood) {
    String _temp0 = intl.Intl.selectLogic(mood, {
      'miserable': 'miserable',
      'grumpy': 'grumpy',
      'calm': 'calm',
      'cheerful': 'cheerful',
      'elated': 'elated',
      'other': '$mood',
    });
    return '$_temp0';
  }

  @override
  String effectTrust(String name, String delta, int now, String mood) {
    return '$name toward Dash $delta (now $now), mood $mood';
  }

  @override
  String effectRumourBelieved(String name, String about) {
    return '$name believes the made-up rumour about $about';
  }

  @override
  String effectRumourDoubted(String name, String about) {
    return '$name doubts the made-up rumour about $about';
  }

  @override
  String effectWarms(String name, String about) {
    return '$name warms to $about (+1)';
  }

  @override
  String effectShrugs(String name, String about) {
    return '$name shrugs off the kind words about $about';
  }

  @override
  String effectNowKnows(String name, String fact) {
    return '$name now knows: $fact';
  }

  @override
  String effectConfides(String name, String fact) {
    return '$name tells Dash: $fact';
  }

  @override
  String effectWork(String name) {
    return '$name gets work done faster';
  }

  @override
  String effectCourage(int percent) {
    return 'Mo courage $percent%';
  }

  @override
  String noticeAsleep(String name) {
    return '$name is asleep. Try again in the morning.';
  }

  @override
  String noticeRush(String name) {
    return '$name is hurrying to the festival.';
  }

  @override
  String noticeCatchUp(String name) {
    return 'Catching up with $name…';
  }

  @override
  String noticeWaitTalk(String name) {
    return 'Waiting for $name to finish talking…';
  }

  @override
  String noticeFellAsleep(String name) {
    return '$name has fallen asleep.';
  }

  @override
  String noticeHurriesOff(String name) {
    return '$name hurries off to the festival.';
  }

  @override
  String get factPipTune => 'Pip\'s secret singing';

  @override
  String get factMoScarf => 'Mo\'s scarf accident';

  @override
  String get factScarfWhere => 'where the scarf is';

  @override
  String get factJuneRumour => 'who started the bread rumour';

  @override
  String get factBreadRumour => 'Mo\'s bread rumour';

  @override
  String get factBreadTruth => 'the bread rumour is false';

  @override
  String get factBramblePoems => 'Bramble\'s poems for June';

  @override
  String get factWildflowers => 'the mystery wildflowers';

  @override
  String get factCloverDeal => 'Clover\'s Golden Bell deal';

  @override
  String get factStormForecast => 'Bramble\'s storm warning';

  @override
  String get factMoVoice => 'Mo\'s singing voice';

  @override
  String get factHoneyLoaf => 'Mo\'s honey loaf';

  @override
  String get factRehearsal => 'the rehearsal';

  @override
  String get factLanterns => 'the lanterns';

  @override
  String get factScarfMissing => 'the missing scarf';

  @override
  String get factScarfFound => 'the scarf was found';

  @override
  String get factScarfReturned => 'the scarf came back';

  @override
  String get factFestival => 'the Berry Festival';

  @override
  String get factMoFainted => 'Mo fainting';

  @override
  String get factFestivalWinner => 'the festival winner';

  @override
  String get factAnonPoem => 'the anonymous love poem';

  @override
  String get factBrambleFlowers => 'Bramble and the wildflowers';

  @override
  String get factStormHit => 'the storm';

  @override
  String get factBrambleRight => 'Bramble being right';

  @override
  String get factStormPassed => 'the rainbow';

  @override
  String factSigned(String name) {
    return '$name entering the contest';
  }

  @override
  String factArgument(String a, String b) {
    return '$a and $b arguing';
  }

  @override
  String factDashGift(String name) {
    return 'Dash\'s gift to $name';
  }

  @override
  String factDashRumour(String name) {
    return 'what Dash said about $name';
  }

  @override
  String llamaRole(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'Pip': 'the scarf knitter',
      'Mo': 'the baker',
      'June': 'the berry farmer',
      'Bramble': 'the weather watcher',
      'Clover': 'the festival organiser',
      'other': 'a llama',
    });
    return '$_temp0';
  }

  @override
  String llamaTraits(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'Pip': 'vain, dramatic, fashionable, secretly insecure',
      'Mo': 'shy, kind, anxious, has a golden singing voice',
      'June': 'nosy, chatty, cheerful, loves a scandal',
      'Bramble': 'grumpy, old, proud, secretly romantic',
      'Clover': 'bossy, ambitious, playful, impatient',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String llamaBio(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'Pip': 'Likes her red scarf, ribbons and compliments. Dreams to win the Golden Bell for best singer at the Berry Festival.',
      'Mo': 'Likes warm bread, quiet mornings and honest praise. Dreams to find the courage to sing at the festival without fainting.',
      'June': 'Likes gossip, sweet berries and being asked for news. Dreams to be the first llama to know every secret in the village.',
      'Bramble': 'Likes clouds, poetry and being right. Dreams to be taken seriously when he predicts a storm.',
      'Clover': 'Likes clipboards, applause and things going to plan. Dreams to run a perfect Berry Festival and be elected village mayor.',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get tipTalkAsDash => 'Talk as Dash';

  @override
  String get tipCloseEsc => 'Close (Esc)';

  @override
  String get sectionNow => 'Now';

  @override
  String get sectionMoodNeeds => 'Mood and needs';

  @override
  String get sectionFriendships => 'Friendships';

  @override
  String get sectionGoals => 'Goals';

  @override
  String get sectionWhy => 'Why this action';

  @override
  String sectionKnows(String name, int count) {
    return 'What $name knows ($count)';
  }

  @override
  String barMood(String mood) {
    return 'Mood: $mood';
  }

  @override
  String get barFed => 'Fed';

  @override
  String get barEnergy => 'Energy';

  @override
  String get barCompany => 'Wants company';

  @override
  String get barCourage => 'Courage';

  @override
  String get noDecision => 'No decision yet.';

  @override
  String get howOwnSecret => 'own secret';

  @override
  String get howKnows => 'knows it';

  @override
  String get howSaw => 'saw it';

  @override
  String get howAnnounced => 'announced';

  @override
  String howOverheardDoubt(String name) {
    return 'overheard from $name; does not believe it';
  }

  @override
  String howOverheard(String name) {
    return 'overheard from $name; maybe untrue';
  }

  @override
  String howHeardDoubt(String name) {
    return 'heard from $name; does not believe it';
  }

  @override
  String howHeard(String name) {
    return 'heard from $name; maybe untrue';
  }

  @override
  String activityWalk(String place) {
    return 'walking to $place';
  }

  @override
  String activityTalk(String name, String place) {
    return 'talking with $name at $place';
  }

  @override
  String activitySleep(String place) {
    return 'asleep in $place';
  }

  @override
  String activityIdle(String place) {
    return 'standing at $place';
  }

  @override
  String activityAt(String kind, String place) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'eat': 'eating',
      'work': 'working',
      'nap': 'napping',
      'search': 'searching',
      'watch': 'watching',
      'wait': 'waiting',
      'practise': 'practising',
      'flowers': 'leaving flowers',
      'linger': 'lingering',
      'other': '$kind',
    });
    return '$_temp0 at $place';
  }

  @override
  String choice(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'walk',
      'talk': 'talk',
      'eat': 'eat',
      'work': 'work',
      'nap': 'nap',
      'sleep': 'sleep',
      'search': 'search',
      'watch': 'watch',
      'wait': 'wait',
      'practise': 'practise',
      'flowers': 'leave flowers',
      'linger': 'linger',
      'idle': 'stay',
      'other': '$kind',
    });
    return '$_temp0';
  }

  @override
  String choiceTo(String kind, String place) {
    return '$kind to $place';
  }

  @override
  String get newGame => 'New game';

  @override
  String get continueGame => 'Continue';

  @override
  String get noSave => 'No saved game yet';

  @override
  String saveDetail(String when, String name) {
    return '$when · $name';
  }

  @override
  String get endings => 'Endings';

  @override
  String get settings => 'Settings';

  @override
  String get credits => 'Credits';

  @override
  String get autosave => 'Autosave';

  @override
  String slotN(int n) {
    return 'Slot $n';
  }

  @override
  String get damaged => 'damaged';

  @override
  String get paused => 'Paused';

  @override
  String get resume => 'Resume';

  @override
  String get saveGame => 'Save game';

  @override
  String get savedMark => '✓ saved';

  @override
  String get empty => 'empty';

  @override
  String get saveAndQuit => 'Save and quit to menu';

  @override
  String get saveAndQuitDetail => 'Saves to the autosave slot';

  @override
  String get quitGame => 'Quit game';

  @override
  String get escResumes => 'Esc resumes';

  @override
  String get close => 'Close';

  @override
  String unlockedCount(int count, int total) {
    return '$count of $total unlocked';
  }

  @override
  String get lockedTitle => '? ? ?';

  @override
  String get storybooksSection => 'Storybooks';

  @override
  String get noStorybooks => 'Finish a week to keep its storybook here.';

  @override
  String endingTitle(String ending) {
    String _temp0 = intl.Intl.selectLogic(ending, {
      'harmonyFestival': 'Harmony Festival',
      'dramaLlama': 'Drama Llama',
      'quietValley': 'Quiet Valley',
      'other': '$ending',
    });
    return '$_temp0';
  }

  @override
  String endingBlurb(String ending) {
    String _temp0 = intl.Intl.selectLogic(ending, {
      'harmonyFestival': 'Every rumour put right, every llama on the hilltop, and the lanterns burn till dawn.',
      'dramaLlama': 'Whispers, feuds and a festival nobody will forget, for all the wrong reasons.',
      'quietValley': 'The week passed gently. Dash watched, and the valley mostly minded its own business.',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String endingHint(String ending) {
    String _temp0 = intl.Intl.selectLogic(ending, {
      'harmonyFestival': 'Win the llamas over, set the record straight, and bring them closer.',
      'dramaLlama': 'A little bird with a loose beak can stir up a lot.',
      'quietValley': 'Sometimes the valley is happiest left alone.',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get creditsSubtitle => 'Llama Village: Festival Week';

  @override
  String get creditsModels => 'Models (all run on this Mac, nothing is downloaded)';

  @override
  String get creditsGemma =>
      'Google DeepMind. Dialogue, plans, thoughts, Dash\'s options, epilogues and the storybook. Used under the Gemma 4 licence (Apache License 2.0), ai.google.dev/gemma/docs/gemma_4_license.';

  @override
  String get creditsEmbedding =>
      'Google DeepMind. Checks which facts were actually said. Gemma is provided under and subject to the Gemma Terms of Use found at ai.google.dev/gemma/terms.';

  @override
  String get creditsLayaName => 'Laya decision model (optional)';

  @override
  String get creditsLaya => 'Picks casual conversation topics when it is installed.';

  @override
  String get creditsEngines => 'Engines and libraries';

  @override
  String get creditsLlamadart => 'MIT License, © 2024 Jhin Lee. Runs llama.cpp (MIT License, © the ggml authors) on Metal.';

  @override
  String get creditsScene => 'MIT License, © 2023 Brandon DeRosier. The 3D village, on Flutter GPU.';

  @override
  String get creditsSoloud =>
      'MIT License, © 2024 the flutter_soloud authors, with the SoLoud engine (zlib/libpng licence, © Jari Komppa).';

  @override
  String get creditsFlutter => 'BSD 3-Clause License, © the Flutter authors.';

  @override
  String get creditsSound => 'Sound';

  @override
  String get creditsSynth => 'Music and sounds synthesized in code';

  @override
  String get creditsSynthNote =>
      'tool/audio/gen_audio.py: additive synthesis, shaped noise and an FFT reverb. Nothing is sampled or downloaded.';

  @override
  String get afterTheFestival => 'After the festival…';

  @override
  String get remembering => 'The llamas are remembering…';

  @override
  String get seeWeek => 'See how the week went';

  @override
  String get endingUnlocked => 'Ending unlocked';

  @override
  String get endingAlready => 'Ending (already unlocked)';

  @override
  String why(String reasons) {
    return 'Why: $reasons.';
  }

  @override
  String reasonFalseBeliefs(int count) {
    return '$count false beliefs still going round';
  }

  @override
  String reasonSoured(String value) {
    return 'friendships soured (harmony $value)';
  }

  @override
  String get reasonRift => 'Pip and Mo fell out';

  @override
  String get reasonCrushExposed => 'Bramble\'s crush was aired by someone else, and June said no';

  @override
  String get reasonNoWinner => 'the festival had no winner';

  @override
  String reasonCrowned(String name) {
    return 'the festival crowned $name';
  }

  @override
  String get reasonAllRight => 'every false rumour was put right';

  @override
  String reasonHarmony(String value) {
    return 'harmony $value';
  }

  @override
  String reasonTrust(String value) {
    return 'the llamas trust Dash ($value)';
  }

  @override
  String reasonBeliefsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count false beliefs left', one: '1 false belief left');
    return '$_temp0';
  }

  @override
  String reasonHarmonyOnly(String value) {
    return 'harmony only $value';
  }

  @override
  String reasonTrustOnly(String value) {
    return 'trust in Dash only $value';
  }

  @override
  String get statHarmony => 'Harmony';

  @override
  String harmonyValue(String value) {
    return '$value / 10';
  }

  @override
  String get harmonyNote => 'mean friendship among the five';

  @override
  String get statTruth => 'Truth';

  @override
  String get noFalseBeliefs => 'no false beliefs';

  @override
  String falseBeliefs(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count false beliefs', one: '1 false belief');
    return '$_temp0';
  }

  @override
  String get everyRumourRight => 'every rumour was put right';

  @override
  String moreBeliefs(int count) {
    return '+$count more';
  }

  @override
  String get statPipMo => 'Pip and Mo';

  @override
  String pipMoArc(String arc) {
    String _temp0 = intl.Intl.selectLogic(arc, {'reconciled': 'made up', 'rift': 'fell out', 'other': 'left unsaid'});
    return '$_temp0';
  }

  @override
  String get pipMoNote => 'the scarf, the bread rumour and the Golden Bell';

  @override
  String get statBramble => 'Bramble\'s poems';

  @override
  String brambleArc(String arc) {
    String _temp0 = intl.Intl.selectLogic(arc, {
      'accepted': 'confessed, and June said yes',
      'declined': 'confessed; June let him down gently',
      'exposedDeclined': 'exposed by gossip; June said no',
      'revealed': 'out in the open, still unanswered',
      'other': 'still a secret',
    });
    return '$_temp0';
  }

  @override
  String get brambleNote => 'his secret crush on June';

  @override
  String get statFestival => 'Festival';

  @override
  String get noWinner => 'no winner';

  @override
  String wonBell(String name) {
    return '$name won the Golden Bell';
  }

  @override
  String get statTrust => 'Trust in Dash';

  @override
  String get trustNote => 'how each llama feels about you, -10 to 10';

  @override
  String get backToTitle => 'Back to the title';

  @override
  String get readStory => 'Read the story';

  @override
  String storyProgress(int done, int total) {
    return '$done of $total pages written…';
  }

  @override
  String get sectionGraphics => 'Graphics';

  @override
  String get frameRate => 'Frame rate';

  @override
  String fpsChoice(int fps) {
    return '$fps fps';
  }

  @override
  String get promotionNote => '120 fps needs a ProMotion display.';

  @override
  String get graphicsQuality => 'Graphics quality';

  @override
  String quality(String quality) {
    String _temp0 = intl.Intl.selectLogic(quality, {'low': 'Low', 'medium': 'Medium', 'other': 'High'});
    return '$_temp0';
  }

  @override
  String get sectionAudio => 'Audio';

  @override
  String get music => 'Music';

  @override
  String get soundEffects => 'Sound effects';

  @override
  String get muteAll => 'Mute all';

  @override
  String get sectionGameplay => 'Gameplay';

  @override
  String get textSpeed => 'Text speed';

  @override
  String speedName(String speed) {
    String _temp0 = intl.Intl.selectLogic(speed, {'slow': 'Slow', 'fast': 'Fast', 'other': 'Normal'});
    return '$_temp0';
  }

  @override
  String get startingSpeed => 'Starting time speed';

  @override
  String speedChoice(int n) {
    return '$n×';
  }

  @override
  String get sectionAccessibility => 'Accessibility';

  @override
  String get textSize => 'Text size';

  @override
  String sizeName(String size) {
    String _temp0 = intl.Intl.selectLogic(size, {'large': 'Large', 'larger': 'Larger', 'other': 'Normal'});
    return '$_temp0';
  }

  @override
  String get reducedMotion => 'Reduced motion';

  @override
  String get reducedMotionNote =>
      'Shorter camera moves in cutscenes, no camera shake, a slower menu flyover, calmer animals and fewer particles.';

  @override
  String get highContrast => 'High-contrast bubbles';

  @override
  String get sectionLanguage => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageNote => 'Menus, and everything the llamas say and write, switch at once. The sim keeps its facts in English.';

  @override
  String get skipHint => 'Esc / Space / click to skip';

  @override
  String get llamasThinking => 'the llamas are thinking';

  @override
  String dreams(String name) {
    return '$name dreams…';
  }

  @override
  String get dreamFallback => 'Zzz…';

  @override
  String announcementFallback(int day) {
    return 'Hear ye! The Berry Festival is on day $day at 16:00 on the hilltop. Best singer wins the Golden Bell!';
  }

  @override
  String get pipSignsUp => 'Me! Put my name down first. The Golden Bell is mine!';

  @override
  String get berryFestival => 'The Berry Festival';

  @override
  String festivalWhen(int day) {
    return 'Day $day · 16:00 · on the hilltop';
  }

  @override
  String get festivalSubtitle => 'Lanterns, berry tarts and a wobbly stage';

  @override
  String get pipSings => 'Pip sings with enormous feeling and almost no tune.';

  @override
  String get moFaints => 'Mo opens his mouth, sways, and faints into the berry tarts.';

  @override
  String get moSings => 'Mo sings, and the hilltop goes completely silent, then roars.';

  @override
  String llamaSings(String name) {
    return '$name sings a cheerful berry-picking song.';
  }

  @override
  String get songFallback => 'Oh, the berries on the hill are sweet as summer...';

  @override
  String get laLaLa => 'La la laaa...';

  @override
  String get nobodyWins => 'Nobody wins the Golden Bell';

  @override
  String winsBell(String name) {
    return '$name wins the Golden Bell!';
  }

  @override
  String get endingWord => 'Ending';

  @override
  String get harmonyLanterns => 'The lanterns came on, one by one, all the way up the hill.';

  @override
  String get harmonyPipMo => 'Pip and Mo shared the last berry tart, and the scarf, for a while.';

  @override
  String get harmonyJune => 'June read Bramble\'s poems out loud, and did not mind who heard.';

  @override
  String get harmonyNoRumour => 'Not one rumour was left standing. Everyone sang the last song.';

  @override
  String get harmonyDash => 'And a small blue bird fell asleep in the bunting.';

  @override
  String get dramaSilence => 'By sunset, nobody was speaking to anybody.';

  @override
  String get dramaWhistle => 'Somewhere, a little blue bird whistled innocently.';

  @override
  String get quietCame => 'The festival came and went, the way festivals do.';

  @override
  String get quietWork => 'Mo baked. June picked berries. Bramble watched the clouds.';

  @override
  String get quietSecrets => 'The valley kept its secrets, and its peace.';

  @override
  String get storyTitle => 'The Week Dash Came to Berry Valley';

  @override
  String get storySeries => 'A Llama Village storybook';

  @override
  String storyDayCaption(int day, String countdown) {
    return 'Day $day · $countdown';
  }

  @override
  String storyDayTitle(String nth) {
    String _temp0 = intl.Intl.selectLogic(nth, {
      'first': 'The First Day',
      'second': 'The Second Day',
      'third': 'The Third Day',
      'fourth': 'The Fourth Day',
      'other': 'The Fifth Day',
    });
    return '$_temp0';
  }

  @override
  String get storyEndingTitle => 'Happily Ever After';

  @override
  String get theEnd => 'The End';

  @override
  String storyStillWriting(int done, int total) {
    return 'The storyteller is still writing… $done of $total pages';
  }

  @override
  String get storyBegin => 'Turn the page to begin →';

  @override
  String get storyQuill => 'The storyteller is dipping her quill…';

  @override
  String get tipPrevPage => 'Previous page (←)';

  @override
  String get tipNextPage => 'Next page (→)';

  @override
  String get tipCloseBook => 'Close the book (Esc)';
}

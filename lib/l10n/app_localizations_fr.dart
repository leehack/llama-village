// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class L10nFr extends L10n {
  L10nFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Le Village des Lamas';

  @override
  String get appSubtitle => 'La semaine de la fête';

  @override
  String get titleTagline => 'Cinq lamas, cinq jours, un petit oiseau curieux.';

  @override
  String get loadingTagline => 'Cinq lamas, leurs secrets, et un petit oiseau curieux.';

  @override
  String get buildingVillage => 'Construction du village…';

  @override
  String sceneFailed(String error) {
    return 'Impossible de charger la scène 3D : $error';
  }

  @override
  String get modelsNotFoundTitle => 'Modèles d\'IA introuvables.';

  @override
  String modelsMissing(String files) {
    return 'Manquant : $files';
  }

  @override
  String get modelsFailedTitle => 'Échec du chargement des modèles.';

  @override
  String get quit => 'Quitter';

  @override
  String get playWithoutAi => 'Jouer sans IA (répliques toutes faites)';

  @override
  String get statusCanned => 'Partie avec des répliques toutes faites (sans IA).';

  @override
  String statusMissing(String files, String dir) {
    return 'Modèles d\'IA introuvables ($files ; cherchés dans $dir). Les nouvelles parties utilisent des répliques toutes faites. Voir le README : VILLAGE_CHAT_MODEL, VILLAGE_EMBED_MODEL.';
  }

  @override
  String get statusLoading => 'Chargement des modèles d\'IA…';

  @override
  String loadProgress(String stage, int percent) {
    String _temp0 = intl.Intl.selectLogic(stage, {
      'dialogue': 'Chargement du modèle de dialogue (gemma-4-E2B)…',
      'embedding': 'Chargement du modèle d\'embeddings (EmbeddingGemma)…',
      'laya': 'Chargement de Laya pour les sujets de conversation…',
      'other': 'Mise en route…',
    });
    return '$_temp0 $percent %';
  }

  @override
  String statusReady(String models) {
    return 'Prêt : $models';
  }

  @override
  String statusFailed(String error) {
    return 'Échec du chargement des modèles d\'IA ($error). Les nouvelles parties utilisent des répliques toutes faites.';
  }

  @override
  String get cannedLabel => 'répliques toutes faites (sans IA)';

  @override
  String get busyWaitingModels => 'En attente des modèles d\'IA…';

  @override
  String get busyPlanning => 'Les lamas préparent leur journée…';

  @override
  String busySkipping(int day) {
    return 'On saute au jour $day…';
  }

  @override
  String busyLoading(String when) {
    return 'Chargement : $when…';
  }

  @override
  String get busyTidying => 'Rangement…';

  @override
  String toastCannotLoad(String reason) {
    return 'Impossible de charger cette sauvegarde : $reason';
  }

  @override
  String toastSaved(String slot, int day, String time) {
    String _temp0 = intl.Intl.selectLogic(slot, {
      'auto': 'Sauvegardé dans la sauvegarde auto',
      'other': 'Sauvegardé dans l\'emplacement $slot',
    });
    return '$_temp0 : jour $day, $time';
  }

  @override
  String toastSaveFailed(String error) {
    return 'Impossible de sauvegarder : $error';
  }

  @override
  String get noticePlanningTomorrow => 'Les lamas préparent demain…';

  @override
  String get noticePaused => 'En pause';

  @override
  String dayClock(int day, String time) {
    return 'Jour $day  $time';
  }

  @override
  String dayAndTime(int day, String time) {
    return 'Jour $day, $time';
  }

  @override
  String countdown(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours avant la fête',
      one: 'la veille de la fête',
      zero: 'jour de la fête des Baies',
    );
    return '$_temp0';
  }

  @override
  String countdownTitle(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours avant la fête',
      one: 'La veille de la fête',
      zero: 'La fête des Baies, c\'est aujourd\'hui à 16 h',
    );
    return '$_temp0';
  }

  @override
  String get afterFestival => 'après la fête';

  @override
  String get planningTomorrowLower => 'les lamas préparent demain…';

  @override
  String dayTitle(int day) {
    return 'Jour $day';
  }

  @override
  String get tipPause => 'Pause (Espace)';

  @override
  String get tipOverview => 'Vue d\'ensemble (O)';

  @override
  String get tipFollow => 'Suivre le lama choisi ou Dash (F)';

  @override
  String get tipSettings => 'Réglages';

  @override
  String fps(String fps) {
    return '$fps i/s';
  }

  @override
  String thinking(String job) {
    String _temp0 = intl.Intl.selectLogic(job, {
      'dialogue': 'une réplique',
      'thought': 'une pensée',
      'dash_options': 'les choix de Dash',
      'dash_reply': 'une réponse',
      'outcome': 'le bilan',
      'schedule': 'les projets',
      'reflection': 'un rêve',
      'storybook': 'le livre',
      'epilogue': 'un épilogue',
      'announcement': 'une annonce',
      'song': 'une chanson',
      'other': '…',
    });
    return 'réflexion : $_temp0';
  }

  @override
  String get villageLog => 'Journal du village';

  @override
  String get helpHint =>
      'Clic sur un lama : Dash vole lui parler  ·  Clic droit : observer  ·  Clic au sol ou ZQSD/WASD : voler\nGlisser : pivoter  ·  Glisser clic droit / deux doigts : déplacer  ·  Molette / pincer : zoom  ·  Espace : pause  ·  F : suivre  ·  O : vue d\'ensemble';

  @override
  String dashFlying(String name) {
    return 'Dash vole vers $name…';
  }

  @override
  String dashWaiting(String name) {
    return '$name n\'est pas disponible. Dash attend tout près…';
  }

  @override
  String get dashThinking => 'Dash réfléchit à ce qu\'il va dire…';

  @override
  String llamaAnswering(String name) {
    return '$name répond…';
  }

  @override
  String reactionLine(String name, String reaction) {
    String _temp0 = intl.Intl.selectLogic(reaction, {
      'offended': 'vexation',
      'annoyed': 'agacement',
      'indifferent': 'indifférence',
      'pleased': 'plaisir',
      'delighted': 'joie',
      'other': '$reaction',
    });
    return 'Réaction de $name : $_temp0.';
  }

  @override
  String get sayMore => 'Dire autre chose';

  @override
  String get flyOff => 'S\'envoler';

  @override
  String get tipLeave => 'Partir (Échap)';

  @override
  String dashAnd(String name) {
    return 'Dash et $name';
  }

  @override
  String atPlaceMood(String place, String mood) {
    return '$place · $mood';
  }

  @override
  String intent(String intent) {
    String _temp0 = intl.Intl.selectLogic(intent, {
      'compliment': 'compliment',
      'gossip': 'ragot',
      'praise': 'éloge',
      'tell': 'nouvelle',
      'gift': 'cadeau',
      'help': 'aide',
      'tease': 'taquinerie',
      'other': '$intent',
    });
    return '$_temp0';
  }

  @override
  String place(String place) {
    String _temp0 = intl.Intl.selectLogic(place, {
      'pond': 'l\'étang',
      'berryBushes': 'les buissons de baies',
      'bakery': 'la boulangerie',
      'hilltop': 'la colline',
      'other': '$place',
    });
    return '$_temp0';
  }

  @override
  String hut(String name) {
    return 'la hutte de $name';
  }

  @override
  String mood(String mood) {
    String _temp0 = intl.Intl.selectLogic(mood, {
      'miserable': 'au plus bas',
      'grumpy': 'grognon',
      'calm': 'calme',
      'cheerful': 'de bonne humeur',
      'elated': 'aux anges',
      'other': '$mood',
    });
    return '$_temp0';
  }

  @override
  String effectTrust(String name, String delta, int now, String mood) {
    return '$name envers Dash $delta (maintenant $now), humeur $mood';
  }

  @override
  String effectRumourBelieved(String name, String about) {
    return '$name croit la rumeur inventée sur $about';
  }

  @override
  String effectRumourDoubted(String name, String about) {
    return '$name doute de la rumeur inventée sur $about';
  }

  @override
  String effectWarms(String name, String about) {
    return '$name se radoucit envers $about (+1)';
  }

  @override
  String effectShrugs(String name, String about) {
    return '$name ignore les mots gentils sur $about';
  }

  @override
  String effectNowKnows(String name, String fact) {
    return '$name sait maintenant : $fact';
  }

  @override
  String effectConfides(String name, String fact) {
    return '$name confie à Dash : $fact';
  }

  @override
  String effectWork(String name) {
    return '$name avance plus vite dans son travail';
  }

  @override
  String effectCourage(int percent) {
    return 'Courage de Mo : $percent %';
  }

  @override
  String noticeAsleep(String name) {
    return '$name dort. Reviens demain matin.';
  }

  @override
  String noticeRush(String name) {
    return '$name file à la fête.';
  }

  @override
  String noticeCatchUp(String name) {
    return 'Dash rattrape $name…';
  }

  @override
  String noticeWaitTalk(String name) {
    return 'Dash attend que $name finisse de parler…';
  }

  @override
  String noticeFellAsleep(String name) {
    return '$name dort déjà.';
  }

  @override
  String noticeHurriesOff(String name) {
    return '$name part en vitesse pour la fête.';
  }

  @override
  String get factPipTune => 'le chant secret de Pip';

  @override
  String get factMoScarf => 'l\'accident de l\'écharpe de Mo';

  @override
  String get factScarfWhere => 'où est l\'écharpe';

  @override
  String get factJuneRumour => 'qui a lancé la rumeur du pain';

  @override
  String get factBreadRumour => 'la rumeur sur le pain de Mo';

  @override
  String get factBreadTruth => 'la rumeur du pain est fausse';

  @override
  String get factBramblePoems => 'les poèmes de Bramble pour June';

  @override
  String get factWildflowers => 'les fleurs mystérieuses';

  @override
  String get factCloverDeal => 'le marché de Clover pour la Cloche d\'or';

  @override
  String get factStormForecast => 'l\'alerte à l\'orage de Bramble';

  @override
  String get factMoVoice => 'la voix de Mo';

  @override
  String get factHoneyLoaf => 'la miche au miel de Mo';

  @override
  String get factRehearsal => 'la répétition';

  @override
  String get factLanterns => 'les lanternes';

  @override
  String get factScarfMissing => 'l\'écharpe disparue';

  @override
  String get factScarfFound => 'l\'écharpe retrouvée';

  @override
  String get factScarfReturned => 'l\'écharpe rendue';

  @override
  String get factFestival => 'la fête des Baies';

  @override
  String get factMoFainted => 'l\'évanouissement de Mo';

  @override
  String get factFestivalWinner => 'le gagnant de la fête';

  @override
  String get factAnonPoem => 'le poème d\'amour anonyme';

  @override
  String get factBrambleFlowers => 'Bramble et les fleurs sauvages';

  @override
  String get factStormHit => 'l\'orage';

  @override
  String get factBrambleRight => 'Bramble avait raison';

  @override
  String get factStormPassed => 'l\'arc-en-ciel';

  @override
  String factSigned(String name) {
    return 'l\'inscription de $name au concours';
  }

  @override
  String factArgument(String a, String b) {
    return 'la dispute entre $a et $b';
  }

  @override
  String factDashGift(String name) {
    return 'le cadeau de Dash à $name';
  }

  @override
  String factDashRumour(String name) {
    return 'ce que Dash a dit de $name';
  }

  @override
  String llamaRole(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'Pip': 'la tricoteuse d\'écharpes',
      'Mo': 'le boulanger',
      'June': 'la cueilleuse de baies',
      'Bramble': 'l\'observateur du temps',
      'Clover': 'l\'organisatrice de la fête',
      'other': 'un lama',
    });
    return '$_temp0';
  }

  @override
  String llamaTraits(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'Pip': 'vaniteuse, théâtrale, élégante, secrètement peu sûre d\'elle',
      'Mo': 'timide, gentil, anxieux, une voix en or',
      'June': 'curieuse, bavarde, joyeuse, adore les scandales',
      'Bramble': 'grognon, vieux, fier, secrètement romantique',
      'Clover': 'autoritaire, ambitieuse, espiègle, impatiente',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String llamaBio(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'Pip': 'Aime son écharpe rouge, les rubans et les compliments. Rêve de gagner la Cloche d\'or du meilleur chant à la fête des Baies.',
      'Mo':
          'Aime le pain chaud, les matins calmes et les éloges sincères. Rêve de trouver le courage de chanter à la fête sans s\'évanouir.',
      'June': 'Aime les ragots, les baies sucrées et qu\'on lui demande les nouvelles. Rêve d\'être la première à connaître tous les secrets du village.',
      'Bramble': 'Aime les nuages, la poésie et avoir raison. Rêve d\'être pris au sérieux quand il annonce un orage.',
      'Clover': 'Aime les porte-bloc, les applaudissements et les plans qui marchent. Rêve d\'organiser une fête des Baies parfaite et d\'être élue maire.',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get tipTalkAsDash => 'Parler en tant que Dash';

  @override
  String get tipCloseEsc => 'Fermer (Échap)';

  @override
  String get sectionNow => 'Maintenant';

  @override
  String get sectionMoodNeeds => 'Humeur et besoins';

  @override
  String get sectionFriendships => 'Amitiés';

  @override
  String get sectionGoals => 'Objectifs';

  @override
  String get sectionWhy => 'Pourquoi cette action';

  @override
  String sectionKnows(String name, int count) {
    return 'Ce que sait $name ($count)';
  }

  @override
  String barMood(String mood) {
    return 'Humeur : $mood';
  }

  @override
  String get barFed => 'Rassasié';

  @override
  String get barEnergy => 'Énergie';

  @override
  String get barCompany => 'Envie de compagnie';

  @override
  String get barCourage => 'Courage';

  @override
  String get noDecision => 'Pas encore de décision.';

  @override
  String get howOwnSecret => 'son secret';

  @override
  String get howKnows => 'le sait';

  @override
  String get howSaw => 'l\'a vu';

  @override
  String get howAnnounced => 'annoncé';

  @override
  String howOverheardDoubt(String name) {
    return 'entendu de $name ; n\'y croit pas';
  }

  @override
  String howOverheard(String name) {
    return 'entendu de $name ; peut-être faux';
  }

  @override
  String howHeardDoubt(String name) {
    return 'appris de $name ; n\'y croit pas';
  }

  @override
  String howHeard(String name) {
    return 'appris de $name ; peut-être faux';
  }

  @override
  String activityWalk(String place) {
    return 'marche vers $place';
  }

  @override
  String activityTalk(String name, String place) {
    return 'parle avec $name · $place';
  }

  @override
  String activitySleep(String place) {
    return 'dort · $place';
  }

  @override
  String activityIdle(String place) {
    return 'attend · $place';
  }

  @override
  String activityAt(String kind, String place) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'eat': 'mange',
      'work': 'travaille',
      'nap': 'fait la sieste',
      'search': 'cherche',
      'watch': 'regarde',
      'wait': 'attend',
      'practise': 's\'exerce',
      'flowers': 'dépose des fleurs',
      'linger': 'flâne',
      'other': '$kind',
    });
    return '$_temp0 · $place';
  }

  @override
  String choice(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': 'marcher',
      'talk': 'parler',
      'eat': 'manger',
      'work': 'travailler',
      'nap': 'sieste',
      'sleep': 'dormir',
      'search': 'chercher',
      'watch': 'regarder',
      'wait': 'attendre',
      'practise': 's\'exercer',
      'flowers': 'déposer des fleurs',
      'linger': 'flâner',
      'idle': 'rester',
      'other': '$kind',
    });
    return '$_temp0';
  }

  @override
  String choiceTo(String kind, String place) {
    return '$kind vers $place';
  }

  @override
  String get newGame => 'Nouvelle partie';

  @override
  String get continueGame => 'Continuer';

  @override
  String get noSave => 'Aucune partie sauvegardée';

  @override
  String saveDetail(String when, String name) {
    return '$when · $name';
  }

  @override
  String get endings => 'Fins';

  @override
  String get settings => 'Réglages';

  @override
  String get credits => 'Crédits';

  @override
  String get autosave => 'Sauvegarde auto';

  @override
  String slotN(int n) {
    return 'Emplacement $n';
  }

  @override
  String get damaged => 'endommagée';

  @override
  String get paused => 'Pause';

  @override
  String get resume => 'Reprendre';

  @override
  String get saveGame => 'Sauvegarder';

  @override
  String get savedMark => '✓ sauvegardé';

  @override
  String get empty => 'vide';

  @override
  String get saveAndQuit => 'Sauvegarder et revenir au menu';

  @override
  String get saveAndQuitDetail => 'Sauvegarde dans l\'emplacement auto';

  @override
  String get quitGame => 'Quitter le jeu';

  @override
  String get escResumes => 'Échap pour reprendre';

  @override
  String get close => 'Fermer';

  @override
  String unlockedCount(int count, int total) {
    return '$count sur $total débloquées';
  }

  @override
  String get lockedTitle => '? ? ?';

  @override
  String get storybooksSection => 'Livres d\'histoires';

  @override
  String get noStorybooks => 'Termine une semaine pour ranger son livre ici.';

  @override
  String endingTitle(String ending) {
    String _temp0 = intl.Intl.selectLogic(ending, {
      'harmonyFestival': 'La Fête de l\'harmonie',
      'dramaLlama': 'Lama Drama',
      'quietValley': 'La Vallée tranquille',
      'other': '$ending',
    });
    return '$_temp0';
  }

  @override
  String endingBlurb(String ending) {
    String _temp0 = intl.Intl.selectLogic(ending, {
      'harmonyFestival': 'Toutes les rumeurs corrigées, tous les lamas sur la colline, et les lanternes brillent jusqu\'à l\'aube.',
      'dramaLlama': 'Des messes basses, des brouilles, et une fête que personne n\'oubliera, pour de mauvaises raisons.',
      'quietValley': 'La semaine a passé doucement. Dash a observé, et la vallée s\'est surtout occupée de ses affaires.',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String endingHint(String ending) {
    String _temp0 = intl.Intl.selectLogic(ending, {
      'harmonyFestival': 'Gagne le cœur des lamas, rétablis la vérité et rapproche-les.',
      'dramaLlama': 'Un petit oiseau trop bavard peut semer la zizanie.',
      'quietValley': 'Parfois, la vallée est plus heureuse qu\'on la laisse tranquille.',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get creditsSubtitle => 'Le Village des Lamas : la semaine de la fête';

  @override
  String get creditsModels => 'Modèles (tout tourne sur ce Mac, rien n\'est téléchargé)';

  @override
  String get creditsGemma =>
      'Google DeepMind. Dialogues, projets, pensées, choix de Dash, épilogues et livre d\'histoires. Utilisé sous la licence Gemma 4 (Apache License 2.0), ai.google.dev/gemma/docs/gemma_4_license.';

  @override
  String get creditsEmbedding =>
      'Google DeepMind. Vérifie quels faits ont vraiment été dits. Gemma est fourni selon les conditions d\'utilisation de Gemma, ai.google.dev/gemma/terms.';

  @override
  String get creditsLayaName => 'Modèle de décision Laya (facultatif)';

  @override
  String get creditsLaya => 'Choisit les sujets de conversation légers quand il est installé.';

  @override
  String get creditsEngines => 'Moteurs et bibliothèques';

  @override
  String get creditsLlamadart => 'MIT License, © 2024 Jhin Lee. Fait tourner llama.cpp (MIT License, © the ggml authors) sur Metal.';

  @override
  String get creditsScene => 'MIT License, © 2023 Brandon DeRosier. Le village en 3D, sur Flutter GPU.';

  @override
  String get creditsSoloud => 'MIT License, © 2024 the flutter_soloud authors, avec le moteur SoLoud (licence zlib/libpng, © Jari Komppa).';

  @override
  String get creditsFlutter => 'BSD 3-Clause License, © the Flutter authors.';

  @override
  String get creditsSound => 'Son';

  @override
  String get creditsSynth => 'Musique et sons synthétisés par le code';

  @override
  String get creditsSynthNote =>
      'tool/audio/gen_audio.py : synthèse additive, bruit filtré et réverbération FFT. Rien n\'est échantillonné ni téléchargé.';

  @override
  String get afterTheFestival => 'Après la fête…';

  @override
  String get remembering => 'Les lamas se souviennent…';

  @override
  String get seeWeek => 'Voir le bilan de la semaine';

  @override
  String get endingUnlocked => 'Fin débloquée';

  @override
  String get endingAlready => 'Fin (déjà débloquée)';

  @override
  String why(String reasons) {
    return 'Pourquoi : $reasons.';
  }

  @override
  String reasonFalseBeliefs(int count) {
    return '$count fausses croyances circulent encore';
  }

  @override
  String reasonSoured(String value) {
    return 'amitiés gâchées (harmonie $value)';
  }

  @override
  String get reasonRift => 'Pip et Mo se sont brouillés';

  @override
  String get reasonCrushExposed => 'le béguin de Bramble a été ébruité par quelqu\'un d\'autre, et June a dit non';

  @override
  String get reasonNoWinner => 'la fête n\'a pas eu de gagnant';

  @override
  String reasonCrowned(String name) {
    return 'la fête a couronné $name';
  }

  @override
  String get reasonAllRight => 'toutes les fausses rumeurs ont été corrigées';

  @override
  String reasonHarmony(String value) {
    return 'harmonie $value';
  }

  @override
  String reasonTrust(String value) {
    return 'les lamas font confiance à Dash ($value)';
  }

  @override
  String reasonBeliefsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fausses croyances restantes',
      one: '1 fausse croyance restante',
    );
    return '$_temp0';
  }

  @override
  String reasonHarmonyOnly(String value) {
    return 'harmonie de seulement $value';
  }

  @override
  String reasonTrustOnly(String value) {
    return 'confiance en Dash de seulement $value';
  }

  @override
  String get statHarmony => 'Harmonie';

  @override
  String harmonyValue(String value) {
    return '$value / 10';
  }

  @override
  String get harmonyNote => 'amitié moyenne entre les cinq';

  @override
  String get statTruth => 'Vérité';

  @override
  String get noFalseBeliefs => 'aucune fausse croyance';

  @override
  String falseBeliefs(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count fausses croyances', one: '1 fausse croyance');
    return '$_temp0';
  }

  @override
  String get everyRumourRight => 'toutes les rumeurs ont été corrigées';

  @override
  String moreBeliefs(int count) {
    return '+$count autres';
  }

  @override
  String get statPipMo => 'Pip et Mo';

  @override
  String pipMoArc(String arc) {
    String _temp0 = intl.Intl.selectLogic(arc, {'reconciled': 'réconciliés', 'rift': 'brouillés', 'other': 'des non-dits'});
    return '$_temp0';
  }

  @override
  String get pipMoNote => 'l\'écharpe, la rumeur du pain et la Cloche d\'or';

  @override
  String get statBramble => 'Les poèmes de Bramble';

  @override
  String brambleArc(String arc) {
    String _temp0 = intl.Intl.selectLogic(arc, {
      'accepted': 'il s\'est déclaré, et June a dit oui',
      'declined': 'il s\'est déclaré ; June l\'a gentiment éconduit',
      'exposedDeclined': 'dévoilé par les ragots ; June a dit non',
      'revealed': 'au grand jour, toujours sans réponse',
      'other': 'toujours un secret',
    });
    return '$_temp0';
  }

  @override
  String get brambleNote => 'son béguin secret pour June';

  @override
  String get statFestival => 'Fête';

  @override
  String get noWinner => 'pas de gagnant';

  @override
  String wonBell(String name) {
    return '$name a gagné la Cloche d\'or';
  }

  @override
  String get statTrust => 'Confiance en Dash';

  @override
  String get trustNote => 'ce que chaque lama pense de toi, de -10 à 10';

  @override
  String get backToTitle => 'Retour à l\'écran titre';

  @override
  String get readStory => 'Lire l\'histoire';

  @override
  String storyProgress(int done, int total) {
    return '$done pages sur $total écrites…';
  }

  @override
  String get sectionGraphics => 'Graphismes';

  @override
  String get frameRate => 'Fréquence d\'images';

  @override
  String fpsChoice(int fps) {
    return '$fps i/s';
  }

  @override
  String get promotionNote => '120 i/s nécessite un écran ProMotion.';

  @override
  String get graphicsQuality => 'Qualité graphique';

  @override
  String quality(String quality) {
    String _temp0 = intl.Intl.selectLogic(quality, {'low': 'Basse', 'medium': 'Moyenne', 'other': 'Haute'});
    return '$_temp0';
  }

  @override
  String get sectionAudio => 'Audio';

  @override
  String get music => 'Musique';

  @override
  String get soundEffects => 'Effets sonores';

  @override
  String get muteAll => 'Tout couper';

  @override
  String get sectionGameplay => 'Jeu';

  @override
  String get textSpeed => 'Vitesse du texte';

  @override
  String speedName(String speed) {
    String _temp0 = intl.Intl.selectLogic(speed, {'slow': 'Lente', 'fast': 'Rapide', 'other': 'Normale'});
    return '$_temp0';
  }

  @override
  String get startingSpeed => 'Vitesse du temps au départ';

  @override
  String speedChoice(int n) {
    return '$n×';
  }

  @override
  String get sectionAccessibility => 'Accessibilité';

  @override
  String get textSize => 'Taille du texte';

  @override
  String sizeName(String size) {
    String _temp0 = intl.Intl.selectLogic(size, {'large': 'Grande', 'larger': 'Très grande', 'other': 'Normale'});
    return '$_temp0';
  }

  @override
  String get reducedMotion => 'Animations réduites';

  @override
  String get reducedMotionNote =>
      'Mouvements de caméra plus courts, pas de tremblement, survol du menu plus lent, animaux plus calmes et moins de particules.';

  @override
  String get highContrast => 'Bulles à fort contraste';

  @override
  String get sectionLanguage => 'Langue';

  @override
  String get languageSystem => 'Langue du système';

  @override
  String get languageNote =>
      'Les menus, et tout ce que disent et écrivent les lamas, changent tout de suite. La simulation garde ses faits en anglais.';

  @override
  String get skipHint => 'Échap / Espace / clic pour passer';

  @override
  String get llamasThinking => 'les lamas réfléchissent';

  @override
  String dreams(String name) {
    return '$name rêve…';
  }

  @override
  String get dreamFallback => 'Zzz…';

  @override
  String announcementFallback(int day) {
    return 'Oyez, oyez ! La fête des Baies, c\'est le jour $day à 16 h sur la colline. Le meilleur chant gagne la Cloche d\'or !';
  }

  @override
  String get pipSignsUp => 'Moi ! Inscris-moi en premier. La Cloche d\'or est à moi !';

  @override
  String get berryFestival => 'La fête des Baies';

  @override
  String festivalWhen(int day) {
    return 'Jour $day · 16 h · sur la colline';
  }

  @override
  String get festivalSubtitle => 'Des lanternes, des tartes aux baies et une scène bancale';

  @override
  String get pipSings => 'Pip chante avec une émotion immense et presque aucune justesse.';

  @override
  String get moFaints => 'Mo ouvre la bouche, vacille et s\'évanouit dans les tartes aux baies.';

  @override
  String get moSings => 'Mo chante, la colline se tait complètement, puis rugit.';

  @override
  String llamaSings(String name) {
    return '$name chante une joyeuse chanson de cueillette.';
  }

  @override
  String get songFallback => 'Oh, les baies de la colline sont douces comme l\'été...';

  @override
  String get laLaLa => 'La la laaa...';

  @override
  String get nobodyWins => 'Personne ne gagne la Cloche d\'or';

  @override
  String winsBell(String name) {
    return '$name gagne la Cloche d\'or !';
  }

  @override
  String get endingWord => 'Fin';

  @override
  String get harmonyLanterns => 'Les lanternes s\'allumèrent une à une, jusqu\'en haut de la colline.';

  @override
  String get harmonyPipMo => 'Pip et Mo partagèrent la dernière tarte aux baies, et l\'écharpe, un moment.';

  @override
  String get harmonyJune => 'June lut à voix haute les poèmes de Bramble, sans se soucier de qui écoutait.';

  @override
  String get harmonyNoRumour => 'Plus une seule rumeur ne tenait debout. Tout le monde chanta la dernière chanson.';

  @override
  String get harmonyDash => 'Et un petit oiseau bleu s\'endormit dans les guirlandes.';

  @override
  String get dramaSilence => 'Au coucher du soleil, plus personne ne se parlait.';

  @override
  String get dramaWhistle => 'Quelque part, un petit oiseau bleu sifflotait innocemment.';

  @override
  String get quietCame => 'La fête vint et passa, comme les fêtes le font.';

  @override
  String get quietWork => 'Mo fit du pain. June cueillit des baies. Bramble regarda les nuages.';

  @override
  String get quietSecrets => 'La vallée garda ses secrets, et sa paix.';

  @override
  String get storyTitle => 'La semaine où Dash vint à la Vallée des Baies';

  @override
  String get storySeries => 'Un livre du Village des Lamas';

  @override
  String storyDayCaption(int day, String countdown) {
    return 'Jour $day · $countdown';
  }

  @override
  String storyDayTitle(String nth) {
    String _temp0 = intl.Intl.selectLogic(nth, {
      'first': 'Le premier jour',
      'second': 'Le deuxième jour',
      'third': 'Le troisième jour',
      'fourth': 'Le quatrième jour',
      'other': 'Le cinquième jour',
    });
    return '$_temp0';
  }

  @override
  String get storyEndingTitle => 'Et ils vécurent heureux';

  @override
  String get theEnd => 'Fin';

  @override
  String storyStillWriting(int done, int total) {
    return 'Le conteur écrit encore… $done pages sur $total';
  }

  @override
  String get storyBegin => 'Tourne la page pour commencer →';

  @override
  String get storyQuill => 'La conteuse trempe sa plume…';

  @override
  String get tipPrevPage => 'Page précédente (←)';

  @override
  String get tipNextPage => 'Page suivante (→)';

  @override
  String get tipCloseBook => 'Fermer le livre (Échap)';
}

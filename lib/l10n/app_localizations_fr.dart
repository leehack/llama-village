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

  @override
  String get sayScarfMissingTitle => 'Pip remarque que son écharpe rouge a disparu';

  @override
  String get sayScarfMissingHome =>
      'Pip tend la main vers son écharpe rouge sur son crochet. Le crochet est vide. Elle retourne toute sa hutte : l\'écharpe a disparu.';

  @override
  String get sayScarfMissingAway =>
      'Pip se rend compte qu\'elle n\'a pas vu son écharpe rouge depuis hier. Elle n\'est pas sur son crochet : l\'écharpe a disparu.';

  @override
  String get sayScarfFoundTitle => 'L\'écharpe est retrouvée';

  @override
  String sayScarfFound(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': 'son écharpe rouge', 'other': 'l\'écharpe rouge de Pip'});
    return '$name sort des roseaux de l\'étang $_temp0, toute trempée.';
  }

  @override
  String get sayScarfReturnedTitle => 'L\'écharpe est rendue';

  @override
  String sayScarfReturned(String name) {
    return '$name rend à Pip son écharpe rouge.';
  }

  @override
  String get sayFestivalAnnouncedTitle => 'La fête des Baies est annoncée';

  @override
  String sayFestivalAnnounced(String day) {
    return 'Clover sonne sa cloche : la fête des Baies aura lieu le jour $day à 16 h sur la colline, et le meilleur chanteur gagnera la Cloche d\'or.';
  }

  @override
  String get sayPipSignsUpTitle => 'Pip s\'inscrit';

  @override
  String get sayPipSignsUp => 'Pip crie son nom avant même que Clover ait fini sa phrase.';

  @override
  String get sayFestivalTitle => 'La fête des Baies';

  @override
  String sayFestivalGathers(String count, String names) {
    return 'Des lanternes, des tartes aux baies et une scène bancale. $count lamas se rassemblent sur la colline. Chanteurs : $names.';
  }

  @override
  String sayFestivalNoSingers(String count) {
    return 'Des lanternes, des tartes aux baies et une scène bancale. $count lamas se rassemblent sur la colline. Chanteurs : personne n\'est venu.';
  }

  @override
  String get sayPipSingsTitle => 'Pip chante';

  @override
  String get sayMoFaintsTitle => 'Mo s\'évanouit';

  @override
  String saySingsTitle(String name) {
    return '$name chante';
  }

  @override
  String get sayGoldenBellTitle => 'La Cloche d\'or';

  @override
  String sayGoldenBell(String name, String scores) {
    return 'Clover remet la Cloche d\'or à $name. Scores : $scores.';
  }

  @override
  String sayGoldenBellStory(String name) {
    return 'Clover remet la Cloche d\'or à $name.';
  }

  @override
  String get sayStormTitle => 'L\'orage';

  @override
  String get sayStorm => 'Le tonnerre gronde sur la colline et une pluie battante balaie le village.';

  @override
  String get sayStormClearsTitle => 'L\'orage se dissipe';

  @override
  String get sayStormClears => 'L\'orage passe. Des flaques partout, un arc-en-ciel au-dessus de l\'étang.';

  @override
  String get sayHoneyLoafTitle => 'La miche au miel';

  @override
  String get sayHoneyLoaf => 'Mo sort du four de la boulangerie une miche au miel grosse comme une botte de foin.';

  @override
  String get sayRehearsalTitle => 'La répétition';

  @override
  String get sayRehearsalEmpty => 'Clover siffle devant une scène vide et note quelque chose de sévère sur son bloc-notes.';

  @override
  String get sayRehearsal => 'Clover fait répéter les chanteurs ; la scène tangue mais tient bon.';

  @override
  String get sayLanternsTitle => 'Les lanternes';

  @override
  String get sayLanterns => 'Pendant la nuit, Clover a suspendu des lanternes tout le long du chemin de la colline.';

  @override
  String sayLogEvent(String title, String text) {
    return '$title. $text';
  }

  @override
  String sayLogEventSeen(String title, String text, String seen) {
    return '$title. $text (vu par $seen)';
  }

  @override
  String sayTalkStarted(String a, String b, String at) {
    return '$a et $b discutent $at';
  }

  @override
  String sayTalkStartedAbout(String a, String b, String at, String topic) {
    return '$a et $b discutent $at ; sujet : $topic';
  }

  @override
  String sayNowKnows(String name, String fact) {
    return '$name sait maintenant : $fact';
  }

  @override
  String sayNowKnowsDoubts(String name, String fact) {
    return '$name sait maintenant : $fact, mais en doute';
  }

  @override
  String sayOverheard(String name, String fact) {
    return '$name a surpris : $fact';
  }

  @override
  String saySawArgue(String names) {
    return 'Témoins de la dispute : $names';
  }

  @override
  String sayThreadTurn(String thread, String from, String to, String why) {
    return 'Fil « $thread » : $from → $to ($why)';
  }

  @override
  String sayThreadNote(String thread, String text) {
    return 'Fil « $thread » : $text';
  }

  @override
  String sayThreadTitle(String thread) {
    String _temp0 = intl.Intl.selectLogic(thread, {
      'scarf': 'L\'écharpe rouge perdue',
      'festival': 'Le concours de chant de la fête des Baies',
      'crush': 'Le béguin de Bramble pour June',
      'rumour': 'La rumeur du pain',
      'storm': 'L\'alerte à l\'orage de Bramble',
      'week': 'La semaine de la fête',
      'other': '$thread',
    });
    return '$_temp0';
  }

  @override
  String sayThreadState(String state) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'unnoticed': 'inaperçue',
      'missing': 'disparue',
      'found': 'retrouvée',
      'returned': 'rendue',
      'unannounced': 'pas annoncée',
      'announced': 'annoncée',
      'contest': 'concours ouvert',
      'performed': 'chants finis',
      'judged': 'jugé',
      'secret': 'secret',
      'poemFound': 'poème trouvé',
      'suspected': 'soupçons',
      'confessed': 'aveu',
      'exposed': 'démasqué',
      'accepted': 'accepté',
      'letDownGently': 'refus en douceur',
      'spreading': 'se répand',
      'debunked': 'démentie',
      'juneExposed': 'June démasquée',
      'forecast': 'prévu',
      'storm': 'orage',
      'passed': 'passé',
      'other': '$state',
    });
    return '$_temp0';
  }

  @override
  String sayThreadDay(String day) {
    return 'jour $day';
  }

  @override
  String get sayWhyPipNoticed => 'Pip a remarqué sa disparition';

  @override
  String get sayWhyPipFoundHerself => 'Pip l\'a retrouvée elle-même dans les roseaux de l\'étang';

  @override
  String sayWhyFoundIt(String name) {
    return '$name l\'a retrouvée dans les roseaux de l\'étang';
  }

  @override
  String sayWhyGaveBack(String name) {
    return '$name l\'a rendue';
  }

  @override
  String get sayWhyAnnounced => 'Clover l\'a annoncée ; Pip s\'est inscrite aussitôt';

  @override
  String sayWhyJoinedPip(String name) {
    return '$name a rejoint Pip au concours';
  }

  @override
  String get sayWhyNoSingers => 'aucun chanteur';

  @override
  String sayWhySang(String names) {
    return 'ont chanté : $names';
  }

  @override
  String sayWhyWon(String name, String how) {
    return '$name a gagné la Cloche d\'or ; $how.';
  }

  @override
  String sayWhyNoWinner(String how) {
    return 'Pas de gagnant : $how.';
  }

  @override
  String get sayHowNobodySang => 'personne n\'a chanté';

  @override
  String get sayHowDeal => 'Clover a discrètement tenu son marché secret avec Pip';

  @override
  String sayHowDealKnown(String names) {
    return 'le marché était connu de $names, alors Clover a jugé équitablement';
  }

  @override
  String get sayHowFair => 'jugé sur la voix et le public';

  @override
  String get sayWhyJuneFoundPoem => 'June a trouvé un poème d\'amour anonyme';

  @override
  String get sayWhyJuneSawFlowers => 'June a vu Bramble déposer les fleurs';

  @override
  String get sayWhyBrambleTold => 'Bramble l\'a dit lui-même à June';

  @override
  String sayWhyJuneHeard(String name) {
    return 'June l\'a appris de $name';
  }

  @override
  String sayWhyJuneOverheard(String name) {
    return 'June l\'a surpris de la bouche de $name';
  }

  @override
  String get sayWhyJuneHeardFlowers => 'June a appris que Bramble dépose les fleurs';

  @override
  String sayWhyCrushConfessed(String outcome) {
    String _temp0 = intl.Intl.selectLogic(outcome, {'accepted': 'l\'a accepté', 'other': 'l\'a éconduit en douceur'});
    return 'Bramble a avoué ; June $_temp0.';
  }

  @override
  String sayWhyCrushExposed(String name, String outcome) {
    String _temp0 = intl.Intl.selectLogic(outcome, {'accepted': 'l\'a accepté', 'other': 'l\'a éconduit en douceur'});
    return 'Bramble a été démasqué par $name ; June $_temp0.';
  }

  @override
  String get sayWhyNobodyBelieves => 'plus personne n\'y croit';

  @override
  String sayWhyJuneExposed(String name, String from) {
    return '$name a appris que June l\'avait inventée (par $from)';
  }

  @override
  String sayWhyStormArrived(String count) {
    return 'il est arrivé à l\'heure ; $count lamas avaient été prévenus';
  }

  @override
  String get sayWhySkyCleared => 'le ciel s\'est dégagé';

  @override
  String get sayConfMoTold => 'Mo a tout avoué à Pip';

  @override
  String get sayConfPipOverheard => 'Pip a surpris Mo en train de tout avouer à quelqu\'un d\'autre';

  @override
  String sayConfPipLearned(String from) {
    return 'Pip l\'a appris par $from';
  }

  @override
  String saySearchNothing(String name, String at) {
    return '$name cherche l\'écharpe $at mais ne trouve rien.';
  }

  @override
  String sayPondNothing(String name) {
    return '$name fouille les roseaux de l\'étang mais ne trouve rien.';
  }

  @override
  String saySignsUp(String name, String how) {
    return '$name s\'inscrit au concours de chant ($how).';
  }

  @override
  String get sayHowToldClover => 'il a dit oui à Clover';

  @override
  String get sayHowCloverTalked => 'Clover l\'a convaincue';

  @override
  String sayMoBraver(String name, String pct) {
    return 'Mo se sent plus courageux après avoir parlé avec $name (courage $pct %).';
  }

  @override
  String sayMoTookBack(String pct) {
    return 'Mo a dit oui, puis a pâli et s\'est rétracté (courage $pct %).';
  }

  @override
  String get sayJuneFindsPoem => 'June trouve un poème d\'amour non signé glissé dans les fleurs sauvages. Elle le lit deux fois.';

  @override
  String get sayFlowersUnseen => 'Bramble glisse des fleurs sauvages dans les buissons de baies sans être vu.';

  @override
  String sayFlowersSeen(String names) {
    return 'Bramble glisse des fleurs sauvages dans les buissons de baies, mais il est vu par $names.';
  }

  @override
  String saySayGoodnight(String a, String b) {
    return '$a et $b se souhaitent bonne nuit.';
  }

  @override
  String sayBreakOffFestival(String a, String b) {
    return '$a et $b s\'interrompent pour filer à la fête.';
  }

  @override
  String sayMorning(String day) {
    return 'Matin du jour $day. Le village s\'éveille.';
  }

  @override
  String sayLiesAwake(String name, String thought) {
    return '$name ne dort pas et pense : « $thought »';
  }

  @override
  String sayHearsPip(String names, int count, String at) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'entendent', one: 'entend');
    return '$names $_temp0 Pip massacrer ses gammes $at.';
  }

  @override
  String get sayPlanned => 'Les lamas ont planifié leur journée.';

  @override
  String get sayGoalFetchScarf => 'aller chercher son écharpe rouge à la hutte pour être à son avantage';

  @override
  String sayGoalAskSeen(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {'June': 'si elle', 'Clover': 'si elle', 'other': 's\'il'});
    return 'demander à $name $_temp0 a vu son écharpe rouge';
  }

  @override
  String get sayGoalFindScarf => 'retrouver son écharpe rouge et découvrir qui l\'a prise';

  @override
  String get sayGoalSearchScarf => 'chercher son écharpe rouge';

  @override
  String get sayGoalMoFish => 'repêcher discrètement l\'écharpe de Pip dans les roseaux avant que quiconque apprenne ce qu\'il a fait';

  @override
  String get sayGoalHelpPip => 'aider Pip à chercher son écharpe rouge';

  @override
  String get sayGoalGiveBackMo => 'rendre son écharpe rouge à Pip, et décider s\'il avoue l\'avoir fait tomber dans l\'étang';

  @override
  String get sayGoalGiveBack => 'rendre son écharpe rouge à Pip (trouvée dans les roseaux de l\'étang)';

  @override
  String get sayGoalMoGuilty => 'il culpabilise encore : peut-être avouer à Pip qu\'il a fait tomber son écharpe dans l\'étang';

  @override
  String get sayGoalBeAtFestival => 'être sur la colline pour la fête des Baies à 16 h';

  @override
  String get sayGoalSetUpStage => 'monter la scène de la fête sur la colline';

  @override
  String get sayGoalRecruitMo => 'convaincre Mo de chanter à la fête (il a la plus belle voix)';

  @override
  String get sayGoalTellClover => 'dire à Clover qu\'il chantera à la fête, finalement';

  @override
  String get sayGoalMoScared => 'il a bien trop peur de chanter à la fête ; il s\'évanouirait';

  @override
  String get sayGoalMoTempted => 'il a envie de chanter à la fête mais a peur de s\'évanouir';

  @override
  String get sayGoalMoAlmost => 'il est presque assez courageux pour accepter de chanter à la fête';

  @override
  String get sayGoalPractise => 's\'entraîner à chanter à l\'étang à l\'aube, là où personne n\'entend';

  @override
  String get sayGoalWinBell => 'gagner la Cloche d\'or ; éclipser Mo';

  @override
  String get sayGoalLeaveFlowers => 'déposer des fleurs sauvages pour June aux buissons de baies avant que quiconque le voie';

  @override
  String get sayGoalTellJune => 'trouver le courage de dire à June que c\'est lui qui écrit ses poèmes d\'amour';

  @override
  String get sayGoalFindWhoFlowers => 'découvrir qui lui laisse des fleurs sauvages et des poèmes d\'amour';

  @override
  String get sayGoalTalkBramble => 'parler des poèmes d\'amour avec Bramble';

  @override
  String get sayGoalFaceJune => 'affronter June au sujet des poèmes';

  @override
  String get sayGoalSpreadRumour => 'répandre la croustillante histoire du pain de Mo';

  @override
  String get sayGoalClearName => 'laver son nom : son pain n\'a jamais rendu personne malade';

  @override
  String get sayGoalSetRecord => 'rétablir la vérité : le pain de Mo ne l\'a jamais rendu malade';

  @override
  String get sayGoalWarnToday => 'prévenir tout le monde qu\'un orage frappera cet après-midi ; être pris au sérieux';

  @override
  String sayGoalWarnDay(String day) {
    return 'prévenir tout le monde qu\'un orage frappera l\'après-midi du jour $day ; être pris au sérieux';
  }

  @override
  String get sayGoalRunRehearsal => 'diriger la répétition de la fête sur la colline à 11 h';

  @override
  String get sayGoalGoRehearsal => 'aller à la répétition de Clover sur la colline à 11 h';

  @override
  String sayWhyHunger(String v) {
    return 'faim $v';
  }

  @override
  String sayWhyEnergy(String v) {
    return 'énergie $v';
  }

  @override
  String get sayWhyPlanWork => 'le plan dit : travail';

  @override
  String get sayWhyAtWorkplace => 'sur son lieu de travail';

  @override
  String get sayWhyNight => 'la nuit';

  @override
  String sayWhyPlanAt(String place) {
    return 'plan : $place';
  }

  @override
  String sayWhyWaiting(String name) {
    return 'attend $name';
  }

  @override
  String get sayWhyFood => 'à manger';

  @override
  String get sayWhyRest => 'repos';

  @override
  String get sayWhyWork => 'travail';

  @override
  String sayWhyCompany(String name) {
    return 'compagnie : $name';
  }

  @override
  String get sayWhyBedtime => 'l\'heure du coucher';

  @override
  String get sayWhyShelter => 's\'abriter de l\'orage';

  @override
  String get sayWhyNothing => 'rien de mieux';

  @override
  String sayStoryThread(String thread, String why) {
    return '$thread : $why';
  }

  @override
  String sayStoryTalk(String a, String b, String at, String how) {
    String _temp0 = intl.Intl.selectLogic(how, {
      'quarrel': ', et cela a fini en dispute',
      'warm': ', et ils se sont quittés bons amis',
      'other': '',
    });
    return '$a et $b ont discuté $at$_temp0.';
  }

  @override
  String sayStoryTalkAbout(String a, String b, String at, String topic, String how) {
    String _temp0 = intl.Intl.selectLogic(how, {
      'quarrel': ', et cela a fini en dispute',
      'warm': ', et ils se sont quittés bons amis',
      'other': '',
    });
    return '$a et $b ont discuté $at ; il était question de : $topic$_temp0.';
  }

  @override
  String sayStoryConfided(String name, String fact) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': 'e', 'June': 'e', 'Clover': 'e', 'other': ''});
    return '$name s\'est confié$_temp0 à Dash : $fact.';
  }

  @override
  String sayStoryHeard(String name, String from, String fact, String overheard, String untrue, String doubts) {
    String _temp0 = intl.Intl.selectLogic(overheard, {'yes': 'a surpris $from dire', 'other': 'a appris de $from'});
    String _temp1 = intl.Intl.selectLogic(untrue, {'yes': ' (ce n\'était pas vrai)', 'other': ''});
    String _temp2 = intl.Intl.selectLogic(doubts, {'yes': ', mais n\'y a pas cru', 'other': ''});
    return '$name $_temp0 : $fact$_temp1$_temp2.';
  }

  @override
  String sayStoryGossip(String name, String names, int count, String reaction) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'des rumeurs inventées', one: 'une rumeur inventée');
    String _temp1 = intl.Intl.selectLogic(reaction, {
      'offended': 'l\'a mal pris',
      'annoyed': 'a levé les yeux au ciel',
      'indifferent': 'a haussé les épaules',
      'pleased': 'a souri',
      'delighted': 'était aux anges',
      'other': '$reaction',
    });
    return 'Dash a chuchoté à $name $_temp0 sur $names, et $name $_temp1.';
  }

  @override
  String sayStoryDash(String name, String intent, String about, String item, String reaction) {
    String _temp0 = intl.Intl.selectLogic(intent, {
      'praise': 'a dit du bien de $about à $name',
      'tell': 'a transmis une nouvelle à $name',
      'gift': 'a offert $item à $name',
      'help': 'a proposé son aide à $name',
      'compliment': 'a fait un compliment à $name',
      'tease': 'a taquiné $name',
      'other': 'a parlé avec $name',
    });
    String _temp1 = intl.Intl.selectLogic(reaction, {
      'offended': 'l\'a mal pris',
      'annoyed': 'a levé les yeux au ciel',
      'indifferent': 'a haussé les épaules',
      'pleased': 'a souri',
      'delighted': 'était aux anges',
      'other': '$reaction',
    });
    return 'Dash $_temp0, et $name $_temp1.';
  }

  @override
  String sayItem(String item) {
    String _temp0 = intl.Intl.selectLogic(item, {
      'ribbon': 'un ruban rouge',
      'honey': 'un pot de miel',
      'pebble': 'un caillou brillant',
      'mint': 'un bouquet de menthe',
      'other': '$item',
    });
    return '$_temp0';
  }

  @override
  String sayAt(String place, String name) {
    String _temp0 = intl.Intl.selectLogic(place, {
      'pond': 'à l\'étang',
      'berryBushes': 'aux buissons de baies',
      'bakery': 'à la boulangerie',
      'hilltop': 'sur la colline',
      'hut': 'dans la hutte de $name',
      'other': 'à $place',
    });
    return '$_temp0';
  }

  @override
  String sayAnd(String first, String last) {
    return '$first et $last';
  }

  @override
  String get sayFactPipTune => 'Pip chante faux et s\'entraîne en secret à l\'étang à l\'aube.';

  @override
  String get sayFactMoScarf =>
      'Mo a fait tomber par accident l\'écharpe rouge de Pip dans les roseaux de l\'étang et ne le lui a jamais dit.';

  @override
  String get sayFactScarfWhere => 'L\'écharpe rouge de Pip est dans les roseaux de l\'étang.';

  @override
  String get sayFactJuneRumour => 'June a inventé la rumeur selon laquelle le pain de Mo a rendu Bramble malade.';

  @override
  String get sayFactBreadRumour => 'Le pain de Mo a rendu Bramble malade.';

  @override
  String get sayFactBreadTruth => 'Bramble n\'a jamais été malade à cause du pain de Mo ; la rumeur est fausse.';

  @override
  String get sayFactBramblePoems => 'Bramble écrit des poèmes d\'amour anonymes à June.';

  @override
  String get sayFactWildflowers => 'Quelqu\'un dépose sans cesse des fleurs sauvages aux buissons de baies pour June.';

  @override
  String get sayFactCloverDeal => 'Clover a promis en secret la Cloche d\'or à Pip en échange d\'une écharpe gratuite.';

  @override
  String sayFactStormForecast(String day) {
    return 'Bramble prédit qu\'un gros orage frappera le village l\'après-midi du jour $day.';
  }

  @override
  String get sayFactMoVoice => 'Mo a chanté magnifiquement à la fête de l\'an dernier et a reçu les plus forts applaudissements.';

  @override
  String get sayFactHoneyLoaf => 'Mo a cuit une énorme miche au miel pour la fête des Baies le jour 2.';

  @override
  String sayFactRehearsal(String names) {
    return 'Clover a organisé une répétition sur la colline le jour 4 ; $names ont répété.';
  }

  @override
  String get sayFactRehearsalEmpty => 'Clover a organisé une répétition sur la colline le jour 4 ; aucun chanteur n\'est venu.';

  @override
  String get sayFactLanterns => 'Clover a suspendu des lanternes tout le long du chemin de la colline pour la fête.';

  @override
  String get sayFactScarfMissing => 'L\'écharpe rouge de Pip a disparu de sa hutte.';

  @override
  String sayFactScarfFound(String name) {
    return '$name a retrouvé l\'écharpe rouge de Pip dans les roseaux de l\'étang.';
  }

  @override
  String sayFactScarfReturned(String name) {
    return '$name a rendu son écharpe rouge à Pip.';
  }

  @override
  String sayFactFestival(String day) {
    return 'Clover a annoncé la fête des Baies pour le jour $day à 16 h sur la colline ; le meilleur chanteur gagne la Cloche d\'or.';
  }

  @override
  String sayFactSigned(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': 'e', 'June': 'e', 'Clover': 'e', 'other': ''});
    return '$name s\'est inscrit$_temp0 pour chanter à la fête des Baies.';
  }

  @override
  String get sayFactMoFainted => 'Mo s\'est évanoui sur la scène de la fête des Baies avant de chanter une seule note.';

  @override
  String sayFactFestivalWinner(String name) {
    return '$name a gagné la Cloche d\'or à la fête des Baies.';
  }

  @override
  String get sayFactAnonPoem => 'June a trouvé un poème d\'amour non signé glissé dans les fleurs sauvages des buissons de baies.';

  @override
  String get sayFactBrambleFlowers => 'On a vu Bramble déposer des fleurs sauvages aux buissons de baies à l\'aube.';

  @override
  String sayFactStormHit(String day) {
    return 'Un orage a frappé le village le jour $day à 15 h : tonnerre, pluie battante, et les guirlandes de la fête se sont envolées.';
  }

  @override
  String get sayFactBrambleRight => 'La prédiction d\'orage de Bramble s\'est réalisée.';

  @override
  String sayFactStormPassed(String day) {
    return 'L\'orage est passé le soir du jour $day, laissant des flaques et un arc-en-ciel au-dessus de l\'étang.';
  }

  @override
  String sayFactGift(String name, String item) {
    return 'Dash a offert $item à $name.';
  }

  @override
  String sayFactArgument(String a, String b, String at, String day) {
    return '$a et $b se sont violemment disputés $at (jour $day).';
  }

  @override
  String sayEndWeek(String title, String blurb) {
    return 'La semaine s\'est terminée en « $title ». $blurb';
  }

  @override
  String get sayEndNoWinner => 'Personne n\'a gagné la Cloche d\'or.';

  @override
  String get sayEndRumoursNone => 'Toutes les fausses rumeurs avaient été démenties.';

  @override
  String get sayEndRumoursFew => 'Quelques fausses rumeurs couraient encore.';

  @override
  String get sayEndRumoursMany => 'Beaucoup de fausses rumeurs couraient encore.';

  @override
  String get sayEndFond => 'Les lamas s\'aimaient bien les uns les autres.';

  @override
  String get sayEndSoured => 'Bien des amitiés avaient tourné au vinaigre.';

  @override
  String get sayEndMixed => 'Certaines amitiés étaient chaleureuses, d\'autres froides.';

  @override
  String sayEndArc(String arc) {
    String _temp0 = intl.Intl.selectLogic(arc, {
      'reconciled': 'Pip et Mo se sont réconciliés.',
      'rift': 'Pip et Mo se sont brouillés.',
      'unresolved': 'Entre Pip et Mo, bien des choses sont restées non dites.',
      'accepted': 'June a dit oui à Bramble.',
      'declined': 'June a éconduit Bramble en douceur.',
      'revealed': 'Tout le monde sait que Bramble écrit les poèmes de June.',
      'secret': 'Personne n\'a su qui écrit les poèmes de June.',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String sayEndHappiest(String a, String b) {
    return 'C\'est $a qui a fini la semaine le cœur le plus léger, et $b le plus lourd.';
  }

  @override
  String get sayEndDashCross => 'La plupart des lamas en voulaient à Dash.';

  @override
  String get sayEndDashFond => 'La plupart des lamas s\'étaient attachés à Dash.';

  @override
  String get sayEndDashUnsure => 'Les lamas ne savaient pas trop quoi penser de Dash.';

  @override
  String get sayQuietDay => 'Une journée tranquille : les lamas vaquaient à leurs occupations.';
}

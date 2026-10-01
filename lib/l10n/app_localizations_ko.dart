// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class L10nKo extends L10n {
  L10nKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '라마 마을';

  @override
  String get appSubtitle => '축제 주간';

  @override
  String get titleTagline => '라마 다섯, 닷새, 그리고 참견쟁이 작은 새 한 마리.';

  @override
  String get loadingTagline => '라마 다섯 마리와 그들의 비밀, 그리고 참견쟁이 작은 새 한 마리.';

  @override
  String get buildingVillage => '마을을 짓는 중…';

  @override
  String sceneFailed(String error) {
    return '3D 장면을 불러오지 못했어요: $error';
  }

  @override
  String get modelsNotFoundTitle => 'AI 모델을 찾지 못했어요.';

  @override
  String modelsMissing(String files) {
    return '없는 파일: $files';
  }

  @override
  String get modelsFailedTitle => '모델을 불러오지 못했어요.';

  @override
  String get quit => '종료';

  @override
  String get playWithoutAi => 'AI 없이 플레이 (미리 쓴 대사)';

  @override
  String get statusCanned => '미리 쓴 대사로 플레이 중이에요 (AI 없음).';

  @override
  String statusMissing(String files, String dir) {
    return 'AI 모델이 없어요 ($files, 찾아본 곳: $dir). 새 게임은 미리 쓴 대사로 진행돼요. README의 VILLAGE_CHAT_MODEL, VILLAGE_EMBED_MODEL을 참고하세요.';
  }

  @override
  String get statusLoading => 'AI 모델을 불러오는 중…';

  @override
  String loadProgress(String stage, int percent) {
    String _temp0 = intl.Intl.selectLogic(stage, {
      'dialogue': '대화 모델(gemma-4-E2B)을 불러오는 중…',
      'embedding': '임베딩 모델(EmbeddingGemma)을 불러오는 중…',
      'laya': '가벼운 화제를 고르는 Laya를 불러오는 중…',
      'other': '예열하는 중…',
    });
    return '$_temp0 $percent%';
  }

  @override
  String statusReady(String models) {
    return '준비 완료: $models';
  }

  @override
  String statusFailed(String error) {
    return 'AI 모델을 불러오지 못했어요 ($error). 새 게임은 미리 쓴 대사로 진행돼요.';
  }

  @override
  String get cannedLabel => '미리 쓴 대사 (AI 없음)';

  @override
  String get busyWaitingModels => 'AI 모델을 기다리는 중…';

  @override
  String get busyPlanning => '라마들이 하루 계획을 세우는 중…';

  @override
  String busySkipping(int day) {
    return '$day일째로 건너뛰는 중…';
  }

  @override
  String busyLoading(String when) {
    return '$when 불러오는 중…';
  }

  @override
  String get busyTidying => '정리하는 중…';

  @override
  String toastCannotLoad(String reason) {
    return '이 저장 파일은 불러올 수 없어요: $reason';
  }

  @override
  String toastSaved(String slot, int day, String time) {
    String _temp0 = intl.Intl.selectLogic(slot, {'auto': '자동 저장에 저장했어요', 'other': '슬롯 $slot에 저장했어요'});
    return '$_temp0: $day일째, $time';
  }

  @override
  String toastSaveFailed(String error) {
    return '저장하지 못했어요: $error';
  }

  @override
  String get noticePlanningTomorrow => '라마들이 내일 계획을 세우는 중…';

  @override
  String get noticePaused => '일시 정지';

  @override
  String dayClock(int day, String time) {
    return '$day일째  $time';
  }

  @override
  String dayAndTime(int day, String time) {
    return '$day일째, $time';
  }

  @override
  String countdown(int days) {
    String _temp0 = intl.Intl.pluralLogic(days, locale: localeName, other: '축제까지 $days일', one: '축제 전날', zero: '베리 축제 날');
    return '$_temp0';
  }

  @override
  String countdownTitle(int days) {
    String _temp0 = intl.Intl.pluralLogic(days, locale: localeName, other: '축제까지 $days일', one: '축제 전날', zero: '오늘 16:00, 베리 축제가 열려요');
    return '$_temp0';
  }

  @override
  String get afterFestival => '축제가 끝난 뒤';

  @override
  String get planningTomorrowLower => '라마들이 내일 계획을 세우는 중…';

  @override
  String dayTitle(int day) {
    return '$day일째';
  }

  @override
  String get tipPause => '일시 정지 (Space)';

  @override
  String get tipOverview => '전체 보기 (O)';

  @override
  String get tipFollow => '선택한 라마나 Dash 따라가기 (F)';

  @override
  String get tipSettings => '설정';

  @override
  String fps(String fps) {
    return '$fps fps';
  }

  @override
  String thinking(String job) {
    String _temp0 = intl.Intl.selectLogic(job, {
      'dialogue': '대사',
      'thought': '속마음',
      'dash_options': 'Dash의 선택지',
      'dash_reply': '대답',
      'outcome': '대화 결과',
      'schedule': '하루 계획',
      'reflection': '꿈',
      'storybook': '그림책',
      'epilogue': '에필로그',
      'announcement': '발표',
      'song': '노래',
      'other': '…',
    });
    return '생각 중: $_temp0';
  }

  @override
  String get villageLog => '마을 일지';

  @override
  String get helpHint =>
      '라마 클릭: Dash가 날아가 말 걸기  ·  오른쪽 클릭: 살펴보기만  ·  땅 클릭 또는 WASD: 날기\n드래그: 회전  ·  오른쪽 드래그 / 두 손가락: 이동  ·  스크롤 / 핀치: 확대  ·  Space: 일시 정지  ·  F: 따라가기  ·  O: 전체 보기';

  @override
  String dashFlying(String name) {
    return 'Dash가 $name에게 날아가는 중…';
  }

  @override
  String dashWaiting(String name) {
    return '$name의 볼일이 끝날 때까지 Dash가 근처에서 기다려요…';
  }

  @override
  String get dashThinking => 'Dash가 무슨 말을 할지 고민하는 중…';

  @override
  String llamaAnswering(String name) {
    return '$name의 대답을 기다리는 중…';
  }

  @override
  String reactionLine(String name, String reaction) {
    String _temp0 = intl.Intl.selectLogic(reaction, {
      'offended': '기분이 상했어요',
      'annoyed': '짜증이 났어요',
      'indifferent': '시큰둥해요',
      'pleased': '기뻐해요',
      'delighted': '아주 기뻐해요',
      'other': '$reaction',
    });
    return '$name의 반응: $_temp0';
  }

  @override
  String get sayMore => '더 말하기';

  @override
  String get flyOff => '날아가기';

  @override
  String get tipLeave => '떠나기 (Esc)';

  @override
  String dashAnd(String name) {
    return 'Dash와 $name';
  }

  @override
  String atPlaceMood(String place, String mood) {
    return '$place에서 · $mood';
  }

  @override
  String intent(String intent) {
    String _temp0 = intl.Intl.selectLogic(intent, {
      'compliment': '칭찬',
      'gossip': '뒷소문',
      'praise': '좋은 말 전하기',
      'tell': '소식',
      'gift': '선물',
      'help': '돕기',
      'tease': '놀리기',
      'other': '$intent',
    });
    return '$_temp0';
  }

  @override
  String place(String place) {
    String _temp0 = intl.Intl.selectLogic(place, {
      'pond': '연못',
      'berryBushes': '베리 덤불',
      'bakery': '빵집',
      'hilltop': '언덕 위',
      'other': '$place',
    });
    return '$_temp0';
  }

  @override
  String hut(String name) {
    return '$name의 오두막';
  }

  @override
  String mood(String mood) {
    String _temp0 = intl.Intl.selectLogic(mood, {
      'miserable': '비참함',
      'grumpy': '뾰로통함',
      'calm': '차분함',
      'cheerful': '명랑함',
      'elated': '신바람 남',
      'other': '$mood',
    });
    return '$_temp0';
  }

  @override
  String effectTrust(String name, String delta, int now, String mood) {
    return '$name의 Dash 호감도 $delta (현재 $now), 기분 $mood';
  }

  @override
  String effectRumourBelieved(String name, String about) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '은', 'June': '은', 'Bramble': '은', 'other': '는'});
    return '$name$_temp0 $about에 대한 지어낸 소문을 믿어요';
  }

  @override
  String effectRumourDoubted(String name, String about) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '은', 'June': '은', 'Bramble': '은', 'other': '는'});
    return '$name$_temp0 $about에 대한 지어낸 소문을 믿지 않아요';
  }

  @override
  String effectWarms(String name, String about) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '은', 'June': '은', 'Bramble': '은', 'other': '는'});
    return '$name$_temp0 $about에게 마음이 조금 열렸어요 (+1)';
  }

  @override
  String effectShrugs(String name, String about) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '은', 'June': '은', 'Bramble': '은', 'other': '는'});
    return '$name$_temp0 $about에 대한 좋은 말을 흘려들었어요';
  }

  @override
  String effectNowKnows(String name, String fact) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    return '$name$_temp0 이제 알아요: $fact';
  }

  @override
  String effectConfides(String name, String fact) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    return '$name$_temp0 Dash에게 털어놓았어요: $fact';
  }

  @override
  String effectWork(String name) {
    return '$name의 일이 더 빨리 끝나요';
  }

  @override
  String effectCourage(int percent) {
    return 'Mo의 용기 $percent%';
  }

  @override
  String noticeAsleep(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '은', 'June': '은', 'Bramble': '은', 'other': '는'});
    return '$name$_temp0 자고 있어요. 아침에 다시 와 보세요.';
  }

  @override
  String noticeRush(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '은', 'June': '은', 'Bramble': '은', 'other': '는'});
    return '$name$_temp0 축제에 가느라 바빠요.';
  }

  @override
  String noticeCatchUp(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '을', 'June': '을', 'Bramble': '을', 'other': '를'});
    return '$name$_temp0 따라가는 중…';
  }

  @override
  String noticeWaitTalk(String name) {
    return '$name의 이야기가 끝나기를 기다리는 중…';
  }

  @override
  String noticeFellAsleep(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '은', 'June': '은', 'Bramble': '은', 'other': '는'});
    return '$name$_temp0 잠들어 버렸어요.';
  }

  @override
  String noticeHurriesOff(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '은', 'June': '은', 'Bramble': '은', 'other': '는'});
    return '$name$_temp0 서둘러 축제에 갔어요.';
  }

  @override
  String get factPipTune => 'Pip의 비밀 노래 연습';

  @override
  String get factMoScarf => 'Mo의 목도리 사고';

  @override
  String get factScarfWhere => '목도리가 있는 곳';

  @override
  String get factJuneRumour => '빵 소문을 퍼뜨린 사람';

  @override
  String get factBreadRumour => 'Mo의 빵 소문';

  @override
  String get factBreadTruth => '빵 소문은 거짓';

  @override
  String get factBramblePoems => 'Bramble이 June에게 쓴 시';

  @override
  String get factWildflowers => '수수께끼의 들꽃';

  @override
  String get factCloverDeal => 'Clover의 황금 종 거래';

  @override
  String get factStormForecast => 'Bramble의 폭풍 경고';

  @override
  String get factMoVoice => 'Mo의 노랫소리';

  @override
  String get factHoneyLoaf => 'Mo의 꿀빵';

  @override
  String get factRehearsal => '리허설';

  @override
  String get factLanterns => '등불';

  @override
  String get factScarfMissing => '사라진 목도리';

  @override
  String get factScarfFound => '목도리를 찾았다';

  @override
  String get factScarfReturned => '목도리가 돌아왔다';

  @override
  String get factFestival => '베리 축제';

  @override
  String get factMoFainted => 'Mo가 기절한 일';

  @override
  String get factFestivalWinner => '축제 우승자';

  @override
  String get factAnonPoem => '이름 없는 연애시';

  @override
  String get factBrambleFlowers => 'Bramble과 들꽃';

  @override
  String get factStormHit => '폭풍';

  @override
  String get factBrambleRight => 'Bramble의 예보가 맞은 일';

  @override
  String get factStormPassed => '무지개';

  @override
  String factSigned(String name) {
    return '$name의 노래 대회 참가';
  }

  @override
  String factArgument(String a, String b) {
    String _temp0 = intl.Intl.selectLogic(a, {'Pip': '과', 'June': '과', 'Bramble': '과', 'other': '와'});
    return '$a$_temp0 $b의 말다툼';
  }

  @override
  String factDashGift(String name) {
    return 'Dash가 $name에게 준 선물';
  }

  @override
  String factDashRumour(String name) {
    return 'Dash가 $name에 대해 한 말';
  }

  @override
  String llamaRole(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'Pip': '목도리 뜨개질꾼',
      'Mo': '빵집 주인',
      'June': '베리 농부',
      'Bramble': '날씨 관찰꾼',
      'Clover': '축제 준비 위원장',
      'other': '라마',
    });
    return '$_temp0';
  }

  @override
  String llamaTraits(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'Pip': '허영심 많고, 극적이고, 멋쟁이지만, 속으로는 자신이 없어요',
      'Mo': '수줍고, 다정하고, 걱정이 많고, 황금 같은 목소리를 지녔어요',
      'June': '참견쟁이에 수다쟁이, 명랑하고, 스캔들을 사랑해요',
      'Bramble': '투덜거리고, 나이 들었고, 자존심이 세지만, 속은 낭만적이에요',
      'Clover': '대장 노릇을 좋아하고, 야심차고, 장난스럽고, 성미가 급해요',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String llamaBio(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'Pip': '빨간 목도리와 리본, 칭찬을 좋아해요. 베리 축제에서 최고의 가수로 황금 종을 받는 게 꿈이에요.',
      'Mo': '따끈한 빵과 조용한 아침, 진심 어린 칭찬을 좋아해요. 기절하지 않고 축제에서 노래할 용기를 찾는 게 꿈이에요.',
      'June': '뒷소문과 달콤한 베리, 소식을 물어봐 주는 걸 좋아해요. 마을의 비밀을 누구보다 먼저 다 아는 게 꿈이에요.',
      'Bramble': '구름과 시, 그리고 자기가 옳은 걸 좋아해요. 폭풍을 예보할 때 다들 진지하게 들어 주는 게 꿈이에요.',
      'Clover': '클립보드와 박수, 계획대로 되는 일을 좋아해요. 완벽한 베리 축제를 치르고 마을 이장으로 뽑히는 게 꿈이에요.',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get tipTalkAsDash => 'Dash로 말 걸기';

  @override
  String get tipCloseEsc => '닫기 (Esc)';

  @override
  String get sectionNow => '지금';

  @override
  String get sectionMoodNeeds => '기분과 욕구';

  @override
  String get sectionFriendships => '우정';

  @override
  String get sectionGoals => '목표';

  @override
  String get sectionWhy => '이 행동을 고른 이유';

  @override
  String sectionKnows(String name, int count) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '은', 'June': '은', 'Bramble': '은', 'other': '는'});
    return '$name$_temp0 알고 있는 것 ($count)';
  }

  @override
  String barMood(String mood) {
    return '기분: $mood';
  }

  @override
  String get barFed => '배부름';

  @override
  String get barEnergy => '기운';

  @override
  String get barCompany => '어울리고 싶음';

  @override
  String get barCourage => '용기';

  @override
  String get noDecision => '아직 정한 게 없어요.';

  @override
  String get howOwnSecret => '자기 비밀';

  @override
  String get howKnows => '알고 있음';

  @override
  String get howSaw => '직접 봄';

  @override
  String get howAnnounced => '모두에게 알려짐';

  @override
  String howOverheardDoubt(String name) {
    return '$name에게서 엿들음, 믿지 않음';
  }

  @override
  String howOverheard(String name) {
    return '$name에게서 엿들음, 사실이 아닐 수도';
  }

  @override
  String howHeardDoubt(String name) {
    return '$name에게서 들음, 믿지 않음';
  }

  @override
  String howHeard(String name) {
    return '$name에게서 들음, 사실이 아닐 수도';
  }

  @override
  String activityWalk(String place) {
    return '$place 쪽으로 걸어가는 중';
  }

  @override
  String activityTalk(String name, String place) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '과', 'June': '과', 'Bramble': '과', 'other': '와'});
    return '$place에서 $name$_temp0 이야기하는 중';
  }

  @override
  String activitySleep(String place) {
    return '$place에서 자는 중';
  }

  @override
  String activityIdle(String place) {
    return '$place에 서 있음';
  }

  @override
  String activityAt(String kind, String place) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'eat': '먹는 중',
      'work': '일하는 중',
      'nap': '낮잠 자는 중',
      'search': '찾는 중',
      'watch': '구경하는 중',
      'wait': '기다리는 중',
      'practise': '연습하는 중',
      'flowers': '꽃을 두는 중',
      'linger': '어슬렁거리는 중',
      'other': '$kind',
    });
    return '$place에서 $_temp0';
  }

  @override
  String choice(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'walk': '걷기',
      'talk': '이야기',
      'eat': '먹기',
      'work': '일하기',
      'nap': '낮잠',
      'sleep': '잠자기',
      'search': '찾기',
      'watch': '구경',
      'wait': '기다리기',
      'practise': '연습',
      'flowers': '꽃 두기',
      'linger': '어슬렁거리기',
      'idle': '그대로 있기',
      'other': '$kind',
    });
    return '$_temp0';
  }

  @override
  String choiceTo(String kind, String place) {
    return '$place 쪽으로 $kind';
  }

  @override
  String get newGame => '새 게임';

  @override
  String get continueGame => '이어 하기';

  @override
  String get noSave => '저장된 게임이 없어요';

  @override
  String saveDetail(String when, String name) {
    return '$when · $name';
  }

  @override
  String get endings => '엔딩';

  @override
  String get settings => '설정';

  @override
  String get credits => '만든 사람들';

  @override
  String get autosave => '자동 저장';

  @override
  String slotN(int n) {
    return '슬롯 $n';
  }

  @override
  String get damaged => '손상됨';

  @override
  String get paused => '일시 정지';

  @override
  String get resume => '계속하기';

  @override
  String get saveGame => '게임 저장';

  @override
  String get savedMark => '✓ 저장됨';

  @override
  String get empty => '비어 있음';

  @override
  String get saveAndQuit => '저장하고 메뉴로';

  @override
  String get saveAndQuitDetail => '자동 저장 슬롯에 저장해요';

  @override
  String get quitGame => '게임 종료';

  @override
  String get escResumes => 'Esc로 계속하기';

  @override
  String get close => '닫기';

  @override
  String unlockedCount(int count, int total) {
    return '$total개 중 $count개 달성';
  }

  @override
  String get lockedTitle => '? ? ?';

  @override
  String get storybooksSection => '그림책';

  @override
  String get noStorybooks => '한 주를 끝까지 마치면 그 주의 그림책이 여기에 꽂혀요.';

  @override
  String endingTitle(String ending) {
    String _temp0 = intl.Intl.selectLogic(ending, {
      'harmonyFestival': '화합의 축제',
      'dramaLlama': '드라마 라마',
      'quietValley': '고요한 골짜기',
      'other': '$ending',
    });
    return '$_temp0';
  }

  @override
  String endingBlurb(String ending) {
    String _temp0 = intl.Intl.selectLogic(ending, {
      'harmonyFestival': '헛소문은 모두 바로잡히고, 라마들은 모두 언덕 위에 모였고, 등불은 새벽까지 타올랐어요.',
      'dramaLlama': '속닥임과 다툼, 그리고 아무도 잊지 못할 축제. 안 좋은 쪽으로요.',
      'quietValley': '한 주가 잔잔하게 흘러갔어요. Dash는 지켜보았고, 골짜기는 대체로 제 일만 했어요.',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String endingHint(String ending) {
    String _temp0 = intl.Intl.selectLogic(ending, {
      'harmonyFestival': '라마들의 마음을 얻고, 오해를 풀고, 서로 가까워지게 해 주세요.',
      'dramaLlama': '입이 가벼운 작은 새는 큰 소동을 일으킬 수 있어요.',
      'quietValley': '가끔은 그냥 내버려 두는 게 골짜기에 가장 좋아요.',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get creditsSubtitle => '라마 마을: 축제 주간';

  @override
  String get creditsModels => '모델 (모두 이 Mac에서 실행되며, 아무것도 내려받지 않아요)';

  @override
  String get creditsGemma =>
      'Google DeepMind. 대사, 하루 계획, 속마음, Dash의 선택지, 에필로그, 그림책. Gemma 4 라이선스(Apache License 2.0)에 따라 사용, ai.google.dev/gemma/docs/gemma_4_license.';

  @override
  String get creditsEmbedding => 'Google DeepMind. 어떤 사실이 실제로 말해졌는지 확인해요. Gemma는 ai.google.dev/gemma/terms의 Gemma 이용 약관에 따라 제공돼요.';

  @override
  String get creditsLayaName => 'Laya 결정 모델 (선택)';

  @override
  String get creditsLaya => '설치되어 있으면 가벼운 대화 화제를 골라요.';

  @override
  String get creditsEngines => '엔진과 라이브러리';

  @override
  String get creditsLlamadart => 'MIT License, © 2024 Jhin Lee. Metal에서 llama.cpp(MIT License, © the ggml authors)를 실행해요.';

  @override
  String get creditsScene => 'MIT License, © 2023 Brandon DeRosier. Flutter GPU로 그린 3D 마을.';

  @override
  String get creditsSoloud => 'MIT License, © 2024 the flutter_soloud authors, SoLoud 엔진 포함 (zlib/libpng licence, © Jari Komppa).';

  @override
  String get creditsFlutter => 'BSD 3-Clause License, © the Flutter authors.';

  @override
  String get creditsSound => '소리';

  @override
  String get creditsSynth => '코드로 합성한 음악과 효과음';

  @override
  String get creditsSynthNote => 'tool/audio/gen_audio.py: 가산 합성, 다듬은 잡음, FFT 리버브. 샘플도, 내려받은 것도 없어요.';

  @override
  String get afterTheFestival => '축제가 끝나고…';

  @override
  String get remembering => '라마들이 추억하는 중…';

  @override
  String get seeWeek => '이번 주 결과 보기';

  @override
  String get endingUnlocked => '엔딩 달성';

  @override
  String get endingAlready => '엔딩 (이미 달성)';

  @override
  String why(String reasons) {
    return '이유: $reasons.';
  }

  @override
  String reasonFalseBeliefs(int count) {
    return '아직 퍼져 있는 잘못된 믿음 $count개';
  }

  @override
  String reasonSoured(String value) {
    return '우정이 틀어졌어요 (화합 $value)';
  }

  @override
  String get reasonRift => 'Pip과 Mo가 사이가 틀어졌어요';

  @override
  String get reasonCrushExposed => 'Bramble의 짝사랑이 남의 입으로 퍼졌고, June은 거절했어요';

  @override
  String get reasonNoWinner => '축제에 우승자가 없었어요';

  @override
  String reasonCrowned(String name) {
    return '축제 우승자는 $name';
  }

  @override
  String get reasonAllRight => '헛소문이 모두 바로잡혔어요';

  @override
  String reasonHarmony(String value) {
    return '화합 $value';
  }

  @override
  String reasonTrust(String value) {
    return '라마들이 Dash를 믿어요 ($value)';
  }

  @override
  String reasonBeliefsLeft(int count) {
    return '남은 잘못된 믿음 $count개';
  }

  @override
  String reasonHarmonyOnly(String value) {
    return '화합이 $value밖에 안 돼요';
  }

  @override
  String reasonTrustOnly(String value) {
    return 'Dash에 대한 믿음이 $value밖에 안 돼요';
  }

  @override
  String get statHarmony => '화합';

  @override
  String harmonyValue(String value) {
    return '$value / 10';
  }

  @override
  String get harmonyNote => '다섯 라마 사이의 평균 우정';

  @override
  String get statTruth => '진실';

  @override
  String get noFalseBeliefs => '잘못된 믿음 없음';

  @override
  String falseBeliefs(int count) {
    return '잘못된 믿음 $count개';
  }

  @override
  String get everyRumourRight => '모든 소문이 바로잡혔어요';

  @override
  String moreBeliefs(int count) {
    return '외 $count개';
  }

  @override
  String get statPipMo => 'Pip과 Mo';

  @override
  String pipMoArc(String arc) {
    String _temp0 = intl.Intl.selectLogic(arc, {'reconciled': '화해했어요', 'rift': '사이가 틀어졌어요', 'other': '하지 못한 말이 남았어요'});
    return '$_temp0';
  }

  @override
  String get pipMoNote => '목도리, 빵 소문, 그리고 황금 종';

  @override
  String get statBramble => 'Bramble의 시';

  @override
  String brambleArc(String arc) {
    String _temp0 = intl.Intl.selectLogic(arc, {
      'accepted': '고백했고, June이 받아 주었어요',
      'declined': '고백했지만, June이 다정하게 거절했어요',
      'exposedDeclined': '소문으로 드러났고, June은 거절했어요',
      'revealed': '다 알려졌지만, 아직 답을 듣지 못했어요',
      'other': '아직 비밀이에요',
    });
    return '$_temp0';
  }

  @override
  String get brambleNote => 'June을 향한 그의 남몰래 한 사랑';

  @override
  String get statFestival => '축제';

  @override
  String get noWinner => '우승자 없음';

  @override
  String wonBell(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    return '$name$_temp0 황금 종을 받았어요';
  }

  @override
  String get statTrust => 'Dash에 대한 믿음';

  @override
  String get trustNote => '라마마다 나를 어떻게 생각하는지, -10에서 10까지';

  @override
  String get backToTitle => '타이틀로 돌아가기';

  @override
  String get readStory => '이야기 읽기';

  @override
  String storyProgress(int done, int total) {
    return '$total쪽 중 $done쪽 썼어요…';
  }

  @override
  String get sectionGraphics => '그래픽';

  @override
  String get frameRate => '프레임 레이트';

  @override
  String fpsChoice(int fps) {
    return '$fps fps';
  }

  @override
  String get promotionNote => '120 fps는 ProMotion 디스플레이에서만 의미가 있어요.';

  @override
  String get graphicsQuality => '그래픽 품질';

  @override
  String quality(String quality) {
    String _temp0 = intl.Intl.selectLogic(quality, {'low': '낮음', 'medium': '보통', 'other': '높음'});
    return '$_temp0';
  }

  @override
  String get sectionAudio => '오디오';

  @override
  String get music => '음악';

  @override
  String get soundEffects => '효과음';

  @override
  String get muteAll => '모두 음소거';

  @override
  String get sectionGameplay => '게임 진행';

  @override
  String get textSpeed => '대사 속도';

  @override
  String speedName(String speed) {
    String _temp0 = intl.Intl.selectLogic(speed, {'slow': '느리게', 'fast': '빠르게', 'other': '보통'});
    return '$_temp0';
  }

  @override
  String get startingSpeed => '시작할 때 시간 속도';

  @override
  String speedChoice(int n) {
    return '$n×';
  }

  @override
  String get sectionAccessibility => '접근성';

  @override
  String get textSize => '글자 크기';

  @override
  String sizeName(String size) {
    String _temp0 = intl.Intl.selectLogic(size, {'large': '크게', 'larger': '더 크게', 'other': '보통'});
    return '$_temp0';
  }

  @override
  String get reducedMotion => '움직임 줄이기';

  @override
  String get reducedMotionNote => '컷신의 카메라 이동을 줄이고, 화면 흔들림을 없애고, 메뉴 비행을 느리게 하고, 동물을 차분하게, 입자를 적게 해요.';

  @override
  String get highContrast => '고대비 말풍선';

  @override
  String get sectionLanguage => '언어';

  @override
  String get languageSystem => '시스템 설정';

  @override
  String get languageNote => '메뉴와 라마들이 하는 말, 쓰는 글이 바로 바뀌어요. 시뮬레이션 속 사실 기록은 영어로 남아요.';

  @override
  String get skipHint => 'Esc / Space / 클릭으로 건너뛰기';

  @override
  String get llamasThinking => '라마들이 생각하는 중';

  @override
  String dreams(String name) {
    return '$name의 꿈…';
  }

  @override
  String get dreamFallback => '쿨쿨…';

  @override
  String announcementFallback(int day) {
    return '들어라, 여러분! 베리 축제는 $day일째 16:00에 언덕 위에서 열려요. 노래를 제일 잘하는 라마가 황금 종을 가져가요!';
  }

  @override
  String get pipSignsUp => '나! 내 이름부터 적어 줘. 황금 종은 내 거야!';

  @override
  String get berryFestival => '베리 축제';

  @override
  String festivalWhen(int day) {
    return '$day일째 · 16:00 · 언덕 위';
  }

  @override
  String get festivalSubtitle => '등불과 베리 타르트, 그리고 삐걱대는 무대';

  @override
  String get pipSings => 'Pip이 감정은 가득, 음정은 거의 없이 노래해요.';

  @override
  String get moFaints => 'Mo가 입을 열더니, 휘청하다가, 베리 타르트 위로 기절해요.';

  @override
  String get moSings => 'Mo가 노래하자 언덕이 쥐 죽은 듯 조용해졌다가, 환호성이 터져요.';

  @override
  String llamaSings(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    return '$name$_temp0 신나는 베리 따기 노래를 불러요.';
  }

  @override
  String get songFallback => '언덕 위의 베리는 여름처럼 달콤해...';

  @override
  String get laLaLa => '랄라라~...';

  @override
  String get nobodyWins => '황금 종의 주인은 없었어요';

  @override
  String winsBell(String name) {
    return '황금 종은 $name에게!';
  }

  @override
  String get endingWord => '엔딩';

  @override
  String get harmonyLanterns => '등불이 하나둘 켜져 언덕 꼭대기까지 이어졌어요.';

  @override
  String get harmonyPipMo => 'Pip과 Mo는 마지막 베리 타르트를 나눠 먹고, 한동안 목도리도 나눠 둘렀어요.';

  @override
  String get harmonyJune => 'June은 Bramble의 시를 소리 내어 읽었고, 누가 듣든 개의치 않았어요.';

  @override
  String get harmonyNoRumour => '헛소문은 하나도 남지 않았어요. 모두가 마지막 노래를 함께 불렀어요.';

  @override
  String get harmonyDash => '그리고 작은 파랑새 한 마리가 깃발 장식 속에서 잠이 들었어요.';

  @override
  String get dramaSilence => '해 질 무렵, 아무도 서로 말을 하지 않았어요.';

  @override
  String get dramaWhistle => '어딘가에서 작은 파랑새 한 마리가 시치미를 떼고 휘파람을 불었어요.';

  @override
  String get quietCame => '축제는 여느 축제처럼 왔다가 지나갔어요.';

  @override
  String get quietWork => 'Mo는 빵을 구웠어요. June은 베리를 땄어요. Bramble은 구름을 바라보았어요.';

  @override
  String get quietSecrets => '골짜기는 비밀도, 평화도 그대로 간직했어요.';

  @override
  String get storyTitle => 'Dash가 베리 골짜기에 온 일주일';

  @override
  String get storySeries => '라마 마을 그림책';

  @override
  String storyDayCaption(int day, String countdown) {
    return '$day일째 · $countdown';
  }

  @override
  String storyDayTitle(String nth) {
    String _temp0 = intl.Intl.selectLogic(nth, {'first': '첫째 날', 'second': '둘째 날', 'third': '셋째 날', 'fourth': '넷째 날', 'other': '다섯째 날'});
    return '$_temp0';
  }

  @override
  String get storyEndingTitle => '그 후로 오래오래';

  @override
  String get theEnd => '끝';

  @override
  String storyStillWriting(int done, int total) {
    return '이야기꾼이 아직 쓰고 있어요… $total쪽 중 $done쪽';
  }

  @override
  String get storyBegin => '책장을 넘겨 시작하세요 →';

  @override
  String get storyQuill => '이야기꾼이 깃펜에 잉크를 묻히는 중…';

  @override
  String get tipPrevPage => '이전 쪽 (←)';

  @override
  String get tipNextPage => '다음 쪽 (→)';

  @override
  String get tipCloseBook => '책 덮기 (Esc)';
}

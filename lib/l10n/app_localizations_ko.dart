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
  String get creditsFonts => '글꼴';

  @override
  String get creditsGowunDodum =>
      'SIL Open Font License 1.1, © 2021 The Gowun Dodum Project Authors (github.com/yangheeryu/Gowun-Dodum). 한국어 메뉴, HUD, 살펴보기 창, 마을 일지, 설정.';

  @override
  String get creditsJua => 'SIL Open Font License 1.1, © 2018 The Jua Project Authors. 한국어 제목, 말풍선과 생각 풍선, Dash의 선택지.';

  @override
  String get creditsGowunBatang =>
      'SIL Open Font License 1.1, © 2021 The Gowun Batang Project Authors (github.com/yangheeryu/Gowun-Batang). 한국어 그림책.';

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

  @override
  String get sayScarfMissingTitle => 'Pip이 빨간 목도리가 없어진 걸 알아챘어요';

  @override
  String get sayScarfMissingHome => 'Pip이 고리에 걸린 빨간 목도리를 집으려는데 고리가 비어 있어요. 오두막을 샅샅이 뒤져 봐도 목도리는 없어요.';

  @override
  String get sayScarfMissingAway => 'Pip은 어제부터 빨간 목도리를 못 봤다는 걸 깨달아요. 고리에도 없어요. 목도리가 사라졌어요.';

  @override
  String get sayScarfFoundTitle => '목도리를 찾았어요';

  @override
  String sayScarfFound(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    String _temp1 = intl.Intl.selectLogic(name, {'Pip': '자기', 'other': 'Pip의'});
    return '$name$_temp0 연못 갈대숲에서 흠뻑 젖은 $_temp1 빨간 목도리를 건져 내요.';
  }

  @override
  String get sayScarfReturnedTitle => '목도리를 돌려줬어요';

  @override
  String sayScarfReturned(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    return '$name$_temp0 Pip에게 빨간 목도리를 건네줘요.';
  }

  @override
  String get sayFestivalAnnouncedTitle => '베리 축제 발표';

  @override
  String sayFestivalAnnounced(String day) {
    return 'Clover가 종을 울려요. 베리 축제는 $day일째 16:00에 언덕 위에서 열리고, 노래를 가장 잘하는 라마가 황금 종을 받아요.';
  }

  @override
  String get sayPipSignsUpTitle => 'Pip의 참가 신청';

  @override
  String get sayPipSignsUp => 'Clover가 말을 끝내기도 전에 Pip이 자기 이름을 외쳐요.';

  @override
  String get sayFestivalTitle => '베리 축제';

  @override
  String sayFestivalGathers(String count, String names) {
    return '등불과 베리 타르트, 흔들거리는 무대. 라마 $count마리가 언덕 위에 모였어요. 노래할 라마: $names.';
  }

  @override
  String sayFestivalNoSingers(String count) {
    return '등불과 베리 타르트, 흔들거리는 무대. 라마 $count마리가 언덕 위에 모였어요. 노래하러 나온 라마는 아무도 없어요.';
  }

  @override
  String get sayPipSingsTitle => 'Pip의 노래';

  @override
  String get sayMoFaintsTitle => 'Mo가 기절해요';

  @override
  String saySingsTitle(String name) {
    return '$name의 노래';
  }

  @override
  String get sayGoldenBellTitle => '황금 종';

  @override
  String sayGoldenBell(String name, String scores) {
    return 'Clover가 $name에게 황금 종을 건네요. 점수: $scores.';
  }

  @override
  String sayGoldenBellStory(String name) {
    return 'Clover가 $name에게 황금 종을 건네요.';
  }

  @override
  String get sayStormTitle => '폭풍';

  @override
  String get sayStorm => '언덕 위로 천둥이 울리고, 옆으로 들이치는 비가 마을을 휩쓸어요.';

  @override
  String get sayStormClearsTitle => '폭풍이 걷혔어요';

  @override
  String get sayStormClears => '폭풍이 지나가요. 여기저기 물웅덩이가 생기고, 연못 위에 무지개가 떴어요.';

  @override
  String get sayHoneyLoafTitle => '꿀빵';

  @override
  String get sayHoneyLoaf => 'Mo가 빵집 오븐에서 건초 더미만 한 꿀빵을 꺼내요.';

  @override
  String get sayRehearsalTitle => '리허설';

  @override
  String get sayRehearsalEmpty => 'Clover가 텅 빈 무대를 향해 호루라기를 불고, 클립보드에 뭔가 엄하게 적어요.';

  @override
  String get sayRehearsal => 'Clover가 가수들에게 노래를 한 번씩 불러 보게 해요. 무대가 흔들리지만 버텨요.';

  @override
  String get sayLanternsTitle => '등불';

  @override
  String get sayLanterns => '밤사이 Clover가 언덕길을 따라 꼭대기까지 등불을 달아 놓았어요.';

  @override
  String sayLogEvent(String title, String text) {
    return '$title. $text';
  }

  @override
  String sayLogEventSeen(String title, String text, String seen) {
    return '$title. $text (본 라마: $seen)';
  }

  @override
  String sayTalkStarted(String a, String b, String at) {
    String _temp0 = intl.Intl.selectLogic(a, {'Pip': '과', 'June': '과', 'Bramble': '과', 'other': '와'});
    String _temp1 = intl.Intl.selectLogic(b, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    return '$a$_temp0 $b$_temp1 $at 이야기해요';
  }

  @override
  String sayTalkStartedAbout(String a, String b, String at, String topic) {
    String _temp0 = intl.Intl.selectLogic(a, {'Pip': '과', 'June': '과', 'Bramble': '과', 'other': '와'});
    String _temp1 = intl.Intl.selectLogic(b, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    return '$a$_temp0 $b$_temp1 $at 이야기해요. 주제: $topic';
  }

  @override
  String sayNowKnows(String name, String fact) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    return '$name$_temp0 이제 알아요: $fact';
  }

  @override
  String sayNowKnowsDoubts(String name, String fact) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    return '$name$_temp0 이제 알아요: $fact (하지만 믿지 않아요)';
  }

  @override
  String sayOverheard(String name, String fact) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    return '$name$_temp0 엿들었어요: $fact';
  }

  @override
  String saySawArgue(String names) {
    return '둘이 다투는 걸 본 라마: $names';
  }

  @override
  String sayThreadTurn(String thread, String from, String to, String why) {
    return '이야기 「$thread」: $from → $to ($why)';
  }

  @override
  String sayThreadNote(String thread, String text) {
    return '이야기 「$thread」: $text';
  }

  @override
  String sayThreadTitle(String thread) {
    String _temp0 = intl.Intl.selectLogic(thread, {
      'scarf': '잃어버린 빨간 목도리',
      'festival': '베리 축제 노래 대회',
      'crush': 'Bramble의 June 짝사랑',
      'rumour': '빵 소문',
      'storm': 'Bramble의 폭풍 경고',
      'week': '축제 주간',
      'other': '$thread',
    });
    return '$_temp0';
  }

  @override
  String sayThreadState(String state) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'unnoticed': '모름',
      'missing': '사라짐',
      'found': '찾음',
      'returned': '돌려줌',
      'unannounced': '발표 전',
      'announced': '발표됨',
      'contest': '대회 진행',
      'performed': '공연 끝',
      'judged': '심사 끝',
      'secret': '비밀',
      'poemFound': '시 발견',
      'suspected': '의심',
      'confessed': '고백',
      'exposed': '들통',
      'accepted': '받아들임',
      'letDownGently': '정중한 거절',
      'spreading': '퍼지는 중',
      'debunked': '바로잡힘',
      'juneExposed': 'June 들통',
      'forecast': '예보',
      'storm': '폭풍',
      'passed': '지나감',
      'other': '$state',
    });
    return '$_temp0';
  }

  @override
  String sayThreadDay(String day) {
    return '$day일째';
  }

  @override
  String get sayWhyPipNoticed => 'Pip이 없어진 걸 알아챘어요';

  @override
  String get sayWhyPipFoundHerself => 'Pip이 연못 갈대숲에서 직접 찾았어요';

  @override
  String sayWhyFoundIt(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    return '$name$_temp0 연못 갈대숲에서 찾았어요';
  }

  @override
  String sayWhyGaveBack(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    return '$name$_temp0 돌려줬어요';
  }

  @override
  String get sayWhyAnnounced => 'Clover가 발표하자 Pip이 바로 신청했어요';

  @override
  String sayWhyJoinedPip(String name) {
    return '$name도 Pip과 함께 대회에 나가요';
  }

  @override
  String get sayWhyNoSingers => '노래한 라마 없음';

  @override
  String sayWhySang(String names) {
    return '노래한 라마: $names';
  }

  @override
  String sayWhyWon(String name, String how) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    return '$name$_temp0 황금 종을 받았어요. $how';
  }

  @override
  String sayWhyNoWinner(String how) {
    return '우승자 없음: $how';
  }

  @override
  String get sayHowNobodySang => '아무도 노래하지 않았어요.';

  @override
  String get sayHowDeal => 'Clover가 Pip과의 비밀 약속을 조용히 지켰어요.';

  @override
  String sayHowDealKnown(String names) {
    return '약속을 아는 라마($names)가 있어서 Clover가 공정하게 심사했어요.';
  }

  @override
  String get sayHowFair => '목소리와 관객 반응으로 심사했어요.';

  @override
  String get sayWhyJuneFoundPoem => 'June이 이름 없는 연애시를 발견했어요';

  @override
  String get sayWhyJuneSawFlowers => 'June이 Bramble이 꽃을 두고 가는 걸 봤어요';

  @override
  String get sayWhyBrambleTold => 'Bramble이 June에게 직접 말했어요';

  @override
  String sayWhyJuneHeard(String name) {
    return 'June이 $name에게서 들었어요';
  }

  @override
  String sayWhyJuneOverheard(String name) {
    return 'June이 $name의 말을 엿들었어요';
  }

  @override
  String get sayWhyJuneHeardFlowers => 'June이 Bramble이 꽃을 두고 간다는 얘기를 들었어요';

  @override
  String sayWhyCrushConfessed(String outcome) {
    String _temp0 = intl.Intl.selectLogic(outcome, {'accepted': '마음을 받아 주었어요', 'other': '정중히 거절했어요'});
    return 'Bramble이 고백했어요. June은 $_temp0.';
  }

  @override
  String sayWhyCrushExposed(String name, String outcome) {
    String _temp0 = intl.Intl.selectLogic(outcome, {'accepted': '마음을 받아 주었어요', 'other': '정중히 거절했어요'});
    return '$name 때문에 Bramble의 마음이 들통났어요. June은 $_temp0.';
  }

  @override
  String get sayWhyNobodyBelieves => '이제 아무도 믿지 않아요';

  @override
  String sayWhyJuneExposed(String name, String from) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    return '$name$_temp0 June이 지어낸 얘기라는 걸 알았어요 ($from에게서)';
  }

  @override
  String sayWhyStormArrived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '예보대로 왔어요. 미리 경고를 들은 라마는 $count마리였어요',
      zero: '예보대로 왔지만, 아무도 Bramble의 말을 믿지 않았어요',
    );
    return '$_temp0';
  }

  @override
  String get sayWhySkyCleared => '하늘이 개었어요';

  @override
  String get sayConfMoTold => 'Mo가 Pip에게 털어놓았어요';

  @override
  String get sayConfPipOverheard => 'Pip이 Mo가 다른 라마에게 털어놓는 걸 엿들었어요';

  @override
  String sayConfPipLearned(String from) {
    return 'Pip이 $from에게서 알게 됐어요';
  }

  @override
  String saySearchNothing(String name, String at) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    return '$name$_temp0 $at 목도리를 찾아보지만 아무것도 없어요.';
  }

  @override
  String sayPondNothing(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    return '$name$_temp0 연못 갈대숲을 뒤져 보지만 아무것도 못 찾아요.';
  }

  @override
  String saySignsUp(String name, String how) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    return '$name$_temp0 노래 대회에 참가 신청을 해요 ($how).';
  }

  @override
  String get sayHowToldClover => 'Clover에게 하겠다고 했어요';

  @override
  String get sayHowCloverTalked => 'Clover가 설득했어요';

  @override
  String sayMoBraver(String name, String pct) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '과', 'June': '과', 'Bramble': '과', 'other': '와'});
    return 'Mo는 $name$_temp0 이야기하고 나서 용기가 조금 났어요 (용기 $pct%).';
  }

  @override
  String sayMoTookBack(String pct) {
    return 'Mo가 하겠다고 했다가 하얗게 질려서 취소했어요 (용기 $pct%).';
  }

  @override
  String get sayJuneFindsPoem => 'June이 들꽃 사이에 끼워진 이름 없는 연애시를 발견해요. 두 번이나 읽어요.';

  @override
  String get sayFlowersUnseen => 'Bramble이 아무도 모르게 베리 덤불에 들꽃을 꽂아 둬요.';

  @override
  String sayFlowersSeen(String names) {
    return 'Bramble이 베리 덤불에 들꽃을 꽂아 두는데, 들키고 말아요. 본 라마: $names.';
  }

  @override
  String saySayGoodnight(String a, String b) {
    String _temp0 = intl.Intl.selectLogic(a, {'Pip': '과', 'June': '과', 'Bramble': '과', 'other': '와'});
    String _temp1 = intl.Intl.selectLogic(b, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    return '$a$_temp0 $b$_temp1 잘 자라고 인사해요.';
  }

  @override
  String sayBreakOffFestival(String a, String b) {
    String _temp0 = intl.Intl.selectLogic(a, {'Pip': '과', 'June': '과', 'Bramble': '과', 'other': '와'});
    String _temp1 = intl.Intl.selectLogic(b, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    return '$a$_temp0 $b$_temp1 이야기를 멈추고 축제로 서둘러 가요.';
  }

  @override
  String sayMorning(String day) {
    return '$day일째 아침. 마을이 깨어나요.';
  }

  @override
  String sayLiesAwake(String name, String thought) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    return '$name$_temp0 잠 못 들고 생각해요: \"$thought\"';
  }

  @override
  String sayHearsPip(String names, int count, String at) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '');
    return '$at Pip이 음계를 꽥꽥대며 연습하는 소리가 들려요. 들은 라마: $names$_temp0.';
  }

  @override
  String get sayPlanned => '라마들이 하루 계획을 세웠어요.';

  @override
  String get sayGoalFetchScarf => '멋져 보이게 오두막에서 빨간 목도리 가져오기';

  @override
  String sayGoalAskSeen(String name) {
    return '$name에게 빨간 목도리를 봤는지 물어보기';
  }

  @override
  String get sayGoalFindScarf => '빨간 목도리를 찾고 누가 가져갔는지 알아내기';

  @override
  String get sayGoalSearchScarf => '빨간 목도리 찾아다니기';

  @override
  String get sayGoalMoFish => '아무도 모르게 연못 갈대숲에서 Pip의 목도리 건져 오기';

  @override
  String get sayGoalHelpPip => 'Pip이 빨간 목도리 찾는 걸 돕기';

  @override
  String get sayGoalGiveBackMo => 'Pip에게 빨간 목도리를 돌려주고, 연못에 빠뜨린 게 자기라고 고백할지 정하기';

  @override
  String get sayGoalGiveBack => 'Pip에게 빨간 목도리 돌려주기 (연못 갈대숲에서 찾았어요)';

  @override
  String get sayGoalMoGuilty => '아직 마음이 무거워요. 목도리를 연못에 빠뜨린 게 자기라고 Pip에게 털어놓을지도 몰라요';

  @override
  String get sayGoalBeAtFestival => '16:00 베리 축제에 맞춰 언덕 위에 가기';

  @override
  String get sayGoalSetUpStage => '언덕 위에 축제 무대 세우기';

  @override
  String get sayGoalRecruitMo => 'Mo에게 축제에서 노래해 달라고 설득하기 (목소리가 제일 좋으니까)';

  @override
  String get sayGoalTellClover => 'Clover에게 축제에서 노래하겠다고 말하기';

  @override
  String get sayGoalMoScared => '축제에서 노래하기엔 너무 무서워요. 기절할지도 몰라요';

  @override
  String get sayGoalMoTempted => '축제에서 노래하고 싶지만 기절할까 봐 무서워요';

  @override
  String get sayGoalMoAlmost => '축제에서 노래하겠다고 말할 용기가 거의 생겼어요';

  @override
  String get sayGoalPractise => '아무도 못 듣는 새벽 연못에서 노래 연습하기';

  @override
  String get sayGoalWinBell => '황금 종 받기, Mo보다 빛나기';

  @override
  String get sayGoalLeaveFlowers => '아무도 보기 전에 베리 덤불에 June을 위한 들꽃 두고 오기';

  @override
  String get sayGoalTellJune => 'June에게 연애시를 쓴 게 자기라고 말할 용기 내기';

  @override
  String get sayGoalFindWhoFlowers => '누가 들꽃과 연애시를 두고 가는지 알아내기';

  @override
  String get sayGoalTalkBramble => '연애시에 대해 Bramble과 이야기하기';

  @override
  String get sayGoalFaceJune => '시 문제로 June과 마주하기';

  @override
  String get sayGoalSpreadRumour => 'Mo의 빵에 대한 솔깃한 이야기 퍼뜨리기';

  @override
  String get sayGoalClearName => '누명 벗기: 내 빵 때문에 아픈 라마는 없었어요';

  @override
  String get sayGoalSetRecord => '바로잡기: Mo의 빵 때문에 아팠던 게 아니에요';

  @override
  String get sayGoalWarnToday => '오늘 오후에 폭풍이 온다고 모두에게 알리고, 진지하게 받아들여지기';

  @override
  String sayGoalWarnDay(String day) {
    return '$day일째 오후에 폭풍이 온다고 모두에게 알리고, 진지하게 받아들여지기';
  }

  @override
  String get sayGoalRunRehearsal => '11:00에 언덕 위에서 축제 리허설 진행하기';

  @override
  String get sayGoalGoRehearsal => '11:00에 언덕 위 Clover의 리허설에 가기';

  @override
  String sayWhyHunger(String v) {
    return '배고픔 $v';
  }

  @override
  String sayWhyEnergy(String v) {
    return '기운 $v';
  }

  @override
  String get sayWhyPlanWork => '계획: 일하기';

  @override
  String get sayWhyAtWorkplace => '일터에 있음';

  @override
  String get sayWhyNight => '밤';

  @override
  String sayWhyPlanAt(String place) {
    return '계획: $place';
  }

  @override
  String sayWhyWaiting(String name) {
    return '$name 기다리는 중';
  }

  @override
  String get sayWhyFood => '먹을 것';

  @override
  String get sayWhyRest => '휴식';

  @override
  String get sayWhyWork => '일';

  @override
  String sayWhyCompany(String name) {
    return '함께 있고 싶음: $name';
  }

  @override
  String get sayWhyBedtime => '잘 시간';

  @override
  String get sayWhyShelter => '폭풍 피하기';

  @override
  String get sayWhyNothing => '할 일 없음';

  @override
  String sayStoryThread(String thread, String why) {
    return '$thread: $why';
  }

  @override
  String sayStoryTalk(String a, String b, String at, String how) {
    String _temp0 = intl.Intl.selectLogic(a, {'Pip': '과', 'June': '과', 'Bramble': '과', 'other': '와'});
    String _temp1 = intl.Intl.selectLogic(b, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    String _temp2 = intl.Intl.selectLogic(how, {'quarrel': '. 결국 말다툼으로 끝났어요', 'warm': '. 다정하게 헤어졌어요', 'other': ''});
    return '$a$_temp0 $b$_temp1 $at 이야기를 나눴어요$_temp2.';
  }

  @override
  String sayStoryTalkAbout(String a, String b, String at, String topic, String how) {
    String _temp0 = intl.Intl.selectLogic(a, {'Pip': '과', 'June': '과', 'Bramble': '과', 'other': '와'});
    String _temp1 = intl.Intl.selectLogic(b, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    String _temp2 = intl.Intl.selectLogic(how, {'quarrel': '. 결국 말다툼으로 끝났어요', 'warm': '. 다정하게 헤어졌어요', 'other': ''});
    return '$a$_temp0 $b$_temp1 $at $topic에 대해 이야기를 나눴어요$_temp2.';
  }

  @override
  String sayStoryConfided(String name, String fact) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    return '$name$_temp0 Dash에게 털어놓았어요. $fact.';
  }

  @override
  String sayStoryHeard(String name, String from, String fact, String overheard, String untrue, String doubts) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    String _temp1 = intl.Intl.selectLogic(overheard, {'yes': '$from의 말을 엿들었어요', 'other': '$from에게서 들었어요'});
    String _temp2 = intl.Intl.selectLogic(untrue, {'yes': ' (사실이 아니었어요)', 'other': ''});
    String _temp3 = intl.Intl.selectLogic(doubts, {'yes': '. 하지만 믿지 않았어요', 'other': ''});
    return '$name$_temp0 $_temp1. $fact$_temp2$_temp3.';
  }

  @override
  String sayStoryGossip(String name, String names, int count, String reaction) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '');
    String _temp1 = intl.Intl.selectLogic(name, {'Pip': '은', 'June': '은', 'Bramble': '은', 'other': '는'});
    String _temp2 = intl.Intl.selectLogic(reaction, {
      'offended': '기분이 상했어요',
      'annoyed': '짜증을 냈어요',
      'indifferent': '시큰둥했어요',
      'pleased': '기뻐했어요',
      'delighted': '무척 기뻐했어요',
      'other': '$reaction',
    });
    return 'Dash가 $name에게 $names에 대한 지어낸 소문을 속삭였어요$_temp0. $name$_temp1 $_temp2.';
  }

  @override
  String sayStoryDash(String name, String intent, String about, String item, String reaction) {
    String _temp0 = intl.Intl.selectLogic(intent, {
      'praise': '$name에게 $about에 대해 좋은 말을 했어요',
      'tell': '$name에게 소식을 전했어요',
      'gift': '$name에게 $item을 선물했어요',
      'help': '$name에게 도와주겠다고 했어요',
      'compliment': '$name에게 칭찬을 했어요',
      'tease': '$name에게 장난을 쳤어요',
      'other': '$name에게 말을 걸었어요',
    });
    String _temp1 = intl.Intl.selectLogic(name, {'Pip': '은', 'June': '은', 'Bramble': '은', 'other': '는'});
    String _temp2 = intl.Intl.selectLogic(reaction, {
      'offended': '기분이 상했어요',
      'annoyed': '짜증을 냈어요',
      'indifferent': '시큰둥했어요',
      'pleased': '기뻐했어요',
      'delighted': '무척 기뻐했어요',
      'other': '$reaction',
    });
    return 'Dash가 $_temp0. $name$_temp1 $_temp2.';
  }

  @override
  String sayItem(String item) {
    String _temp0 = intl.Intl.selectLogic(item, {
      'ribbon': '빨간 리본',
      'honey': '꿀 한 병',
      'pebble': '반짝이는 조약돌',
      'mint': '박하 한 다발',
      'other': '$item',
    });
    return '$_temp0';
  }

  @override
  String sayAt(String place, String name) {
    String _temp0 = intl.Intl.selectLogic(place, {
      'pond': '연못에서',
      'berryBushes': '베리 덤불에서',
      'bakery': '빵집에서',
      'hilltop': '언덕 위에서',
      'hut': '$name의 오두막에서',
      'other': '$place에서',
    });
    return '$_temp0';
  }

  @override
  String sayAnd(String first, String last) {
    return '$first, $last';
  }

  @override
  String get sayFactPipTune => 'Pip은 음치라서 새벽마다 연못에서 몰래 노래 연습을 해요.';

  @override
  String get sayFactMoScarf => 'Mo가 실수로 Pip의 빨간 목도리를 연못 갈대숲에 빠뜨리고는 말하지 않았어요.';

  @override
  String get sayFactScarfWhere => 'Pip의 빨간 목도리는 연못 갈대숲에 있어요.';

  @override
  String get sayFactJuneRumour => 'Mo의 빵 때문에 Bramble이 아팠다는 소문은 June이 지어낸 거예요.';

  @override
  String get sayFactBreadRumour => 'Mo의 빵 때문에 Bramble이 아팠대요.';

  @override
  String get sayFactBreadTruth => 'Bramble은 Mo의 빵 때문에 아픈 적이 없어요. 빵 소문은 거짓이에요.';

  @override
  String get sayFactBramblePoems => 'Bramble이 June에게 이름 없는 연애시를 써요.';

  @override
  String get sayFactWildflowers => '누군가 베리 덤불에 June을 위한 들꽃을 자꾸 두고 가요.';

  @override
  String get sayFactCloverDeal => 'Clover가 공짜 목도리를 받는 대신 Pip에게 황금 종을 몰래 약속했어요.';

  @override
  String sayFactStormForecast(String day) {
    return 'Bramble은 $day일째 오후에 큰 폭풍이 마을을 덮칠 거라고 예측해요.';
  }

  @override
  String get sayFactMoVoice => 'Mo는 작년 축제에서 아름답게 노래해서 가장 큰 박수를 받았어요.';

  @override
  String get sayFactHoneyLoaf => 'Mo가 2일째에 베리 축제를 위해 커다란 꿀빵을 구웠어요.';

  @override
  String sayFactRehearsal(String names) {
    return 'Clover가 4일째에 언덕 위에서 축제 리허설을 열었어요. 연습한 라마: $names.';
  }

  @override
  String get sayFactRehearsalEmpty => 'Clover가 4일째에 언덕 위에서 축제 리허설을 열었지만 노래할 라마가 아무도 오지 않았어요.';

  @override
  String get sayFactLanterns => 'Clover가 축제를 위해 언덕길 꼭대기까지 등불을 달았어요.';

  @override
  String get sayFactScarfMissing => 'Pip의 오두막에서 빨간 목도리가 사라졌어요.';

  @override
  String sayFactScarfFound(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    return '$name$_temp0 연못 갈대숲에서 Pip의 빨간 목도리를 찾았어요.';
  }

  @override
  String sayFactScarfReturned(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    return '$name$_temp0 Pip에게 빨간 목도리를 돌려줬어요.';
  }

  @override
  String sayFactFestival(String day) {
    return 'Clover가 $day일째 16:00 언덕 위에서 베리 축제를 연다고 발표했어요. 노래를 가장 잘하는 라마가 황금 종을 받아요.';
  }

  @override
  String sayFactSigned(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    return '$name$_temp0 베리 축제 노래 대회에 참가 신청을 했어요.';
  }

  @override
  String get sayFactMoFainted => 'Mo가 베리 축제 무대에서 한 소절도 부르기 전에 기절했어요.';

  @override
  String sayFactFestivalWinner(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    return '$name$_temp0 베리 축제에서 황금 종을 받았어요.';
  }

  @override
  String get sayFactAnonPoem => 'June이 베리 덤불의 들꽃 사이에서 이름 없는 연애시를 발견했어요.';

  @override
  String get sayFactBrambleFlowers => 'Bramble이 새벽에 베리 덤불에 들꽃을 두고 가는 모습이 눈에 띄었어요.';

  @override
  String sayFactStormHit(String day) {
    return '$day일째 15:00에 폭풍이 마을을 덮쳤어요. 천둥이 치고 비가 옆으로 들이치고, 축제 깃발이 날아갔어요.';
  }

  @override
  String get sayFactBrambleRight => 'Bramble의 폭풍 예측이 맞았어요.';

  @override
  String sayFactStormPassed(String day) {
    return '$day일째 저녁에 폭풍이 지나가고, 물웅덩이와 연못 위 무지개가 남았어요.';
  }

  @override
  String sayFactGift(String name, String item) {
    return 'Dash가 $name에게 $item을 줬어요.';
  }

  @override
  String sayFactArgument(String a, String b, String at, String day) {
    String _temp0 = intl.Intl.selectLogic(a, {'Pip': '과', 'June': '과', 'Bramble': '과', 'other': '와'});
    String _temp1 = intl.Intl.selectLogic(b, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    return '$a$_temp0 $b$_temp1 $at 크게 말다툼했어요 ($day일째).';
  }

  @override
  String sayEndWeek(String title, String blurb) {
    return '이번 주의 결말: \"$title\". $blurb';
  }

  @override
  String get sayEndNoWinner => '아무도 황금 종을 받지 못했어요.';

  @override
  String get sayEndRumoursNone => '거짓 소문은 모두 바로잡혔어요.';

  @override
  String get sayEndRumoursFew => '거짓 소문 몇 개가 아직 돌고 있었어요.';

  @override
  String get sayEndRumoursMany => '거짓 소문이 아직 많이 돌고 있었어요.';

  @override
  String get sayEndFond => '라마들은 서로를 아꼈어요.';

  @override
  String get sayEndSoured => '많은 우정이 틀어졌어요.';

  @override
  String get sayEndMixed => '어떤 우정은 따뜻했고, 어떤 우정은 서먹했어요.';

  @override
  String sayEndArc(String arc) {
    String _temp0 = intl.Intl.selectLogic(arc, {
      'reconciled': 'Pip과 Mo는 화해했어요.',
      'rift': 'Pip과 Mo는 사이가 틀어졌어요.',
      'unresolved': 'Pip과 Mo 사이엔 못다 한 말이 남았어요.',
      'accepted': 'June이 Bramble의 마음을 받아 주었어요.',
      'declined': 'June이 Bramble을 정중히 거절했어요.',
      'revealed': 'June의 시를 Bramble이 쓴다는 걸 모두가 알게 됐어요.',
      'secret': 'June의 시를 누가 쓰는지 아무도 몰랐어요.',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String sayEndHappiest(String a, String b) {
    String _temp0 = intl.Intl.selectLogic(a, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    String _temp1 = intl.Intl.selectLogic(b, {'Pip': '이', 'June': '이', 'Bramble': '이', 'other': '가'});
    return '$a$_temp0 가장 행복하게 한 주를 마쳤고, $b$_temp1 가장 시무룩했어요.';
  }

  @override
  String get sayEndDashCross => '대부분의 라마가 Dash에게 화가 나 있었어요.';

  @override
  String get sayEndDashFond => '대부분의 라마가 Dash를 좋아하게 됐어요.';

  @override
  String get sayEndDashUnsure => '라마들은 Dash를 어떻게 생각해야 할지 몰랐어요.';

  @override
  String get sayQuietDay => '조용한 하루였어요. 라마들은 저마다 할 일을 했어요.';
}

/// The language the llamas speak and the storybook is written in. The sim's
/// facts, goals and intents stay in English, and so do the prompts; every
/// prompt whose output the player reads ends with a short instruction in
/// the target language. Plans, outcomes and topic choices stay English.
enum Lang {
  en,
  ko,
  fr;

  static Lang fromCode(String? code) => values.firstWhere((l) => l.name == code, orElse: () => en);
}

const String _names = 'Pip, Mo, June, Bramble, Clover, Dash';

/// Each llama's pronoun, for prompts (French agreement depends on it).
String pronounOf(String name) =>
    const {'Pip': 'she', 'Mo': 'he', 'June': 'she', 'Bramble': 'he', 'Clover': 'she', 'Dash': 'he'}[name] ?? 'they';

/// The English instruction naming the language, for the system prompt and
/// the end of each prompt.
String writeIn(Lang lang) => switch (lang) {
  Lang.en => '',
  Lang.ko => 'Write everything you say in natural Korean (한국어), never in English, keeping the names $_names in English letters.',
  Lang.fr => 'Write everything you say in natural French (français), never in English, keeping the names $_names as they are.',
};

/// The closing instruction for a prompt in [lang], in English and then in
/// the language itself, with the game's names for its places and things;
/// empty for English. [json]: the output is a JSON object whose keys must
/// stay English. [story]: a storybook page, which wants the fairy-tale
/// register.
String speakIn(Lang lang, {bool json = false, bool story = false}) => switch (lang) {
  Lang.en => '',
  Lang.ko => [
    json ? 'Keep the JSON keys in English and write every value in Korean.' : writeIn(lang),
    if (json) 'JSON 키는 영어 그대로 두고, 값(대사)은 모두 자연스러운 한국어로 쓰세요.' else '반드시 자연스러운 한국어로만 쓰세요.',
    if (story) '"옛날 옛적에"처럼 다정한 동화 말투(…했어요, …했답니다)로 쓰세요.',
    '이름은 $_names처럼 영어 철자 그대로 쓰세요(피프, 모, 준처럼 한글로 옮기지 마세요).',
    '용어: Berry Festival은 베리 축제, Golden Bell은 황금 종, Berry Valley는 베리 골짜기, lantern은 등불, llama는 라마.',
  ].join(' '),
  Lang.fr => [
    json ? 'Keep the JSON keys in English and write every value in French.' : writeIn(lang),
    if (json)
      'Garde les clés JSON en anglais ; écris toutes les valeurs (les répliques) en français naturel.'
    else
      'Écris uniquement en français naturel.',
    if (story) 'Prends le ton doux d\'un conte (« Il était une fois… »), au passé simple.',
    'Garde les noms ($_names) tels quels.',
    'Vocabulaire : Berry Festival = la fête des Baies, Golden Bell = la Cloche d\'or, Berry Valley = la Vallée des Baies, lantern = lanterne, llama = lama.',
  ].join(' '),
};

/// Whether [text] is written in [lang], to reject an answer the model gave
/// in English anyway: Korean needs Hangul; French must not read as English.
bool speaksIn(String text, Lang lang) => switch (lang) {
  Lang.en => true,
  Lang.ko => RegExp('[가-힣]').hasMatch(text),
  Lang.fr => !RegExp(r'\b(the|and|was|were|with|you|your|is|are)\b', caseSensitive: false).hasMatch(text),
};

/// [prompt] with [lang]'s closing instruction.
String inLang(String prompt, Lang lang, {bool json = false, bool story = false}) =>
    lang == Lang.en ? prompt : '$prompt\n\n${speakIn(lang, json: json, story: story)}';

/// Lines a llama says when the model fails.
List<String> fallbackLinesIn(Lang lang) => switch (lang) {
  Lang.en => const ['Hmm. Well, I suppose so.', 'I have a lot on my mind today.', 'Let us talk about it later.', 'Oh! Is that so?'],
  Lang.ko => const ['음. 뭐, 그런가 보네.', '오늘은 생각할 게 많아.', '그 얘기는 나중에 하자.', '어머! 정말이야?'],
  Lang.fr => const [
    'Hum. Bon, si tu le dis.',
    'J\'ai beaucoup de choses en tête aujourd\'hui.',
    'On en reparlera plus tard.',
    'Oh ! Vraiment ?',
  ],
};

/// The evening reflection when the model fails.
String quietEveningIn(Lang lang) => switch (lang) {
  Lang.en => 'What a day.',
  Lang.ko => '정말 긴 하루였어.',
  Lang.fr => 'Quelle journée.',
};

/// A llama's answer to Dash when the model fails.
String replyFallbackIn(Lang lang, {required bool pleased}) => switch ((lang, pleased)) {
  (Lang.en, true) => 'Oh! Well, thank you, Dash.',
  (Lang.en, false) => 'Hmph. If you say so, Dash.',
  (Lang.ko, true) => '어머! 고마워, Dash.',
  (Lang.ko, false) => '흥. 네가 그렇다면 그렇겠지, Dash.',
  (Lang.fr, true) => 'Oh ! Eh bien, merci, Dash.',
  (Lang.fr, false) => 'Pff. Si tu le dis, Dash.',
};

/// What Dash offers to say when the model fails; [tell] is the news text.
String cannedOptionIn(Lang lang, String intent, {required String name, String? about, String? praiseAbout, String? item, String? tell}) =>
    switch (lang) {
      Lang.en => switch (intent) {
        'compliment' => 'You look wonderful today, $name.',
        'gossip' => 'I heard $about has been acting very strange lately.',
        'praise' => '$praiseAbout said such kind things about you yesterday.',
        'tell' => 'Did you hear? $tell',
        'gift' => 'I brought you $item.',
        'help' => 'Can I help you with anything?',
        _ => 'Is that a frown or your normal face?',
      },
      Lang.ko => switch (intent) {
        'compliment' => '$name, 오늘 정말 멋져 보여.',
        'gossip' => '요즘 $about 좀 이상하게 군다던데.',
        'praise' => '어제 ${koSubject(praiseAbout ?? '')} 네 칭찬을 엄청 하더라.',
        'tell' => '그 얘기 들었어? $tell',
        'gift' => '${itemIn(lang, item ?? '')} 가져왔어.',
        'help' => '내가 뭐 도와줄 거 없어?',
        _ => '그거 찡그린 거야, 원래 얼굴이야?',
      },
      Lang.fr => switch (intent) {
        'compliment' => 'Tu es magnifique aujourd\'hui, $name.',
        'gossip' => 'Il paraît que $about se comporte bizarrement ces temps-ci.',
        'praise' => '$praiseAbout a dit des choses si gentilles sur toi hier.',
        'tell' => 'Tu as entendu ? $tell',
        'gift' => 'Je t\'ai apporté ${itemIn(lang, item ?? '')}.',
        'help' => 'Je peux t\'aider à quelque chose ?',
        _ => 'C\'est une grimace ou ta tête normale ?',
      },
    };

/// Whether a cast name ends in a consonant when said in Korean (핍, 준,
/// 브램블), which picks the particle after it.
bool _koBatchim(String name) => const {'Pip', 'June', 'Bramble'}.contains(name);

/// [name] with the Korean subject particle: "Pip이", "Mo가".
String koSubject(String name) => '$name${_koBatchim(name) ? '이' : '가'}';

/// [name] with the Korean topic particle: "Pip은", "Mo는".
String koTopic(String name) => '$name${_koBatchim(name) ? '은' : '는'}';

/// Dash's gifts, as the player reads them.
String itemIn(Lang lang, String item) => switch (lang) {
  Lang.en => item,
  Lang.ko =>
    const {'a red ribbon': '빨간 리본', 'a jar of honey': '꿀 한 병', 'a shiny pebble': '반짝이는 조약돌', 'a bundle of mint': '박하 한 다발'}[item] ?? item,
  Lang.fr =>
    const {
          'a red ribbon': 'un ruban rouge',
          'a jar of honey': 'un pot de miel',
          'a shiny pebble': 'un caillou brillant',
          'a bundle of mint': 'un bouquet de menthe',
        }[item] ??
        item,
};

/// A token budget for [lang]: Korean and French spend more tokens on the
/// same sentence than English.
int tokensFor(Lang lang, int english) => switch (lang) {
  Lang.en => english,
  Lang.ko => (english * 1.7).round(),
  Lang.fr => (english * 1.3).round(),
};

/// Korean and French words for the facts' English keywords, so a fact told
/// in either language is still recognised as told. Matched lowercase, as
/// substrings, like the English ones; Korean stems leave the particle off.
const Map<String, List<String>> keywordTranslations = {
  'tune': ['음치', '음정', 'chante faux', 'chanter faux', 'fausse note', 'fausses notes'],
  'off-key': ['음이 틀', '음 이탈', 'faux'],
  'croak': ['꽥꽥', 'croass'],
  'screech': ['끽끽', 'grinc'],
  'flat': ['음이 낮', 'trop bas'],
  'sing badly': ['노래를 못', 'chante mal'],
  "can't sing": ['노래를 못', 'sait pas chanter'],
  'secret practi': ['몰래 연습', 'en cachette', 'en secret'],
  'scarf': ['스카프', '목도리', 'écharpe'],
  'knock': ['떨어뜨', '쳐서', 'fait tomber', 'renvers'],
  'accident': ['실수로', '사고'],
  'my fault': ['내 잘못', 'ma faute'],
  'his fault': ['그의 잘못', 'mo 잘못', 'sa faute'],
  'your fault': ['네 잘못', 'ta faute'],
  'mo did': ['mo가 그랬', "c'est mo"],
  'pushed': ['밀어', 'poussé'],
  'i did it': ['내가 그랬', "c'est moi"],
  'clumsy': ['덜렁', '서툴', 'maladroit'],
  'reed': ['갈대', 'roseau'],
  'pond': ['연못', 'étang', 'mare '],
  'water': ['물속', "dans l'eau"],
  'rumou': ['소문', 'rumeur'],
  'story': ['이야기', 'histoire'],
  'tale': ['얘기', 'racontar', 'ragot'],
  'lie': ['거짓말', 'mensonge'],
  'made up': ['지어낸', '꾸며낸', 'inventé'],
  'started': ['시작했', 'lancé'],
  'spread it': ['퍼뜨렸', '퍼뜨린', 'répandu'],
  'your doing': ['네가 한', 'ton œuvre'],
  'bread': ['빵', 'pain'],
  'loaf': ['빵 한 덩이', 'miche'],
  'sick': ['아팠', '아프', '배탈', 'malade'],
  'ill': ['앓았', 'malade'],
  'poison': ['식중독', 'empoisonn'],
  'stomach': ['배가', 'estomac', 'ventre'],
  'never': ['절대', '한 번도', 'jamais'],
  'not sick': ['안 아팠', 'pas malade'],
  'false': ['거짓', '사실이 아니', 'faux'],
  'untrue': ['사실이 아니', 'pas vrai'],
  'nonsense': ['말도 안', "n'importe quoi", 'absurde'],
  'wasn': ['아니었', "n'était pas"],
  'poem': ['시를', '시가', '연애시', '편지', 'poème'],
  'poet': ['시인', 'poète'],
  'verse': ['구절', 'vers '],
  'love': ['사랑', 'amour', 'amoureu'],
  'crush': ['짝사랑', '반했', 'béguin'],
  'sweet on': ['좋아하', 'craque pour'],
  'admire': ['동경', '흠모', 'admir'],
  'wildflower': ['들꽃', 'fleurs sauvages'],
  'flowers': ['꽃', 'fleurs'],
  'flower': ['꽃', 'fleur'],
  'bell': ['황금 종', '종을', 'cloche'],
  'prize': ['상품', '상을', 'prix'],
  'win': ['우승', '이기', 'gagn'],
  'promis': ['약속', 'promesse'],
  'deal': ['거래', 'marché', 'accord'],
  'rig': ['조작', 'truqu'],
  'fix': ['짜고', 'arrang'],
  'bribe': ['뇌물', 'soudoy', 'pot-de-vin'],
  'free scarf': ['공짜 목도리', 'écharpe gratuite'],
  'in exchange': ['대가로', 'en échange'],
  'bought': ['샀', 'acheté'],
  'storm': ['폭풍', 'orage', 'tempête'],
  'thunder': ['천둥', 'tonnerre'],
  'rain': ['비가', '빗', 'pluie'],
  'weather': ['날씨', 'météo'],
  'predict': ['예보', '예측', 'prévoi', 'prédi'],
  'warn': ['경고', '조심', 'prévien', 'averti'],
  'coming': ['온다', '올 거', 'arrive'],
  'will hit': ['몰아칠', 'va frapper', 'va éclater'],
  'brewing': ['몰려오', 'se prépare'],
  'on its way': ['다가오', 'en route'],
  'this afternoon': ['오늘 오후', 'cet après-midi'],
  'missing': ['없어졌', '사라졌', 'disparu'],
  'gone': ['없어', 'partie'],
  'lost': ['잃어', 'perdu'],
  'vanish': ['사라', 'volatilis'],
  'stolen': ['훔쳐', 'volé'],
  'took': ['가져갔', 'pris'],
  'find': ['찾', 'trouv'],
  'where': ['어디', 'où'],
  'seen': ['봤', 'vu'],
  'found': ['찾았', '발견', 'trouvé'],
  'reeds': ['갈대', 'roseaux'],
  'fished': ['건져', 'repêch'],
  'gave': ['줬', '돌려', 'donné'],
  'back': ['돌려받', 'rendu'],
  'returned': ['돌려', 'rendu'],
  'festival': ['축제', 'fête', 'festival'],
  'golden bell': ['황금 종', "cloche d'or"],
  'contest': ['대회', 'concours'],
  'unsigned': ['이름 없는', '서명 없는', 'sans signature', 'non signé'],
  'anonymous': ['익명', 'anonyme'],
  'someone': ['누군가', "quelqu'un"],
  'he ': ['그가', 'il '],
  'him': ['그를', 'lui'],
  'old': ['영감', 'vieux'],
  'right': ['맞았', '옳았', 'raison'],
  'warned': ['경고했', 'prévenu', 'averti'],
  'told us': ['말했잖', "nous l'avait dit"],
  'said it': ['그랬잖', "l'avait dit"],
  'honey': ['꿀', 'miel'],
  'rehears': ['리허설', '예행연습', 'répétition'],
};

const Map<String, String> _koNames = {'피프': 'Pip', '핍': 'Pip', '브램블': 'Bramble', '클로버': 'Clover', '대시': 'Dash', '데시': 'Dash'};
const String _koParticles = '은|는|이|가|을|를|의|에게서|에게|한테서|한테|과|와|도|만|아|야|이랑|랑|이나|나|에|로|으로|처럼|보다|부터|까지|라고|이라고';
final RegExp _koName = RegExp('(?<![가-힣])(${_koNames.keys.join('|')})(?=($_koParticles)?(?![가-힣]))');
// 준 and 모 are also common syllables (준비, 모두), so only a lone word or
// one followed by a particle counts as the name.
final RegExp _koShortName = RegExp('(?<![가-힣])(준|모)(?=($_koParticles)(?![가-힣])|(?![가-힣]))');
final RegExp _koAfterConsonant = RegExp('(Pip|June|Bramble)(가|는|를|와|랑)(?![가-힣])');
final RegExp _koAfterVowel = RegExp('(Mo|Clover|Dash)(이|은|을|과|이랑)(?![가-힣])');

/// Fixes what the model reliably gets wrong in [lang]: Korean output often
/// spells the names in Hangul (피프, 준) and picks the particle for the
/// wrong ending; both sometimes leave the festival's English names in; French
/// writes "llama" for "lama".
String polish(String text, Lang lang) => switch (lang) {
  Lang.en => text,
  Lang.ko =>
    text
        .replaceAll(RegExp('(the )?Berry Festival', caseSensitive: false), '베리 축제')
        .replaceAll(RegExp('(the )?Golden Bell', caseSensitive: false), '황금 종')
        .replaceAllMapped(_koName, (m) => _koNames[m.group(1)]!)
        .replaceAllMapped(_koShortName, (m) => m.group(1) == '준' ? 'June' : 'Mo')
        .replaceAllMapped(_koAfterConsonant, (m) => '${m.group(1)}${const {'가': '이', '는': '은', '를': '을', '와': '과', '랑': '이랑'}[m.group(2)]}')
        .replaceAllMapped(_koAfterVowel, (m) => '${m.group(1)}${const {'이': '가', '은': '는', '을': '를', '과': '와', '이랑': '랑'}[m.group(2)]}'),
  Lang.fr =>
    text
        .replaceAll(RegExp('(the )?Berry Festival', caseSensitive: false), 'fête des Baies')
        .replaceAll(RegExp('(the )?Golden Bell', caseSensitive: false), "Cloche d'or")
        .replaceAllMapped(RegExp(r'\b([Ll])lama'), (m) => '${m.group(1)}ama'),
};

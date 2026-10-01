import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show AppExitResponse, AppExitType;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:vector_math/vector_math.dart' as vm;

import 'ai/models.dart';
import 'ambient/animal_sounds.dart';
import 'audio/soloud_out.dart';
import 'audio/soundscape.dart';
import 'autoplay.dart';
import 'cutscene/overlay.dart';
import 'frame_throttle.dart';
import 'game/bot.dart';
import 'game/director.dart';
import 'game/mem_probe.dart';
import 'game/save_store.dart';
import 'game/story_camera.dart';
import 'game/week_autoplay.dart';
import 'l10n/app_localizations.dart';
import 'render_tour.dart';
import 'render/stage.dart';
import 'self_test.dart';
import 'settings.dart';
import 'sim/canned.dart';
import 'sim/clock.dart';
import 'sim/dash.dart';
import 'sim/endings.dart';
import 'sim/epilogue.dart';
import 'sim/geo.dart';
import 'sim/influence.dart';
import 'sim/lang.dart';
import 'sim/snapshot.dart';
import 'sim/storybook.dart';
import 'sim/village.dart';
import 'ui/bubbles.dart';
import 'ui/fonts.dart';
import 'ui/game_keys.dart';
import 'ui/menus/credits.dart';
import 'ui/menus/gallery.dart';
import 'ui/menus/menu_kit.dart';
import 'ui/menus/pause_menu.dart';
import 'ui/menus/save_picker.dart';
import 'ui/menus/start_menu.dart';
import 'ui/menus/storybook.dart';
import 'ui/menus/week_end.dart';
import 'ui/panels.dart';
import 'ui/settings_panel.dart';
import 'ui/strings.dart';

class VillageApp extends StatelessWidget {
  const VillageApp({super.key, required this.test, required this.settings});
  final SelfTest test;
  final VillageSettings settings;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppLanguage>(
    valueListenable: settings.languageListenable,
    builder: (context, language, _) => MaterialApp(
      onGenerateTitle: (context) => L10n.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: language.code == null ? null : Locale(language.code!),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: villageTheme(korean: false),
      // The resolved locale (a system default may be Korean) picks the face.
      builder: (context, child) => koreanUi(context) ? Theme(data: villageTheme(korean: true), child: child!) : child!,
      home: VillageHome(test: test, settings: settings),
    ),
  );
}

/// loading: the 3D scene is being built. menu: the title screen over the
/// flyover. playing: a game (cutscenes included). epilogue and results:
/// the end of the week. failed: the scene could not load.
enum Phase { loading, menu, playing, epilogue, results, failed }

/// Pages over the title screen.
enum MenuPage { none, settings, credits, endings, saves }

class VillageHome extends StatefulWidget {
  const VillageHome({super.key, required this.test, required this.settings});
  final SelfTest test;
  final VillageSettings settings;

  @override
  State<VillageHome> createState() => VillageHomeState();
}

class VillageHomeState extends State<VillageHome> with SingleTickerProviderStateMixin {
  final VillageStage stage = VillageStage();
  final ValueNotifier<int> frame = ValueNotifier(0);
  final ValueNotifier<int> slow = ValueNotifier(0);
  final FocusNode focus = FocusNode();
  late final AppLifecycleListener _lifecycle;
  late final Ticker _vsync;
  final FrameThrottle _throttle = FrameThrottle(VillageSettings.defaultFps);
  final GlobalKey _sceneKey = GlobalKey();

  /// The 3D view alone (no HUD), for the storybook's pictures.
  final GlobalKey _sceneShotKey = GlobalKey();
  RenderObject? _scenePaint;
  VillageSettings get settings => widget.settings;
  bool showSettings = false;
  final SoloudOut _audio = SoloudOut();
  late final Soundscape sound = Soundscape(_audio, onPlay: (name, volume) => test.log('AUDIO $name vol=${volume.toStringAsFixed(2)}'));
  late final _StageView _view = _StageView(this);
  late final AnimalSounds animalSounds = AnimalSounds(
    _audio,
    onPlay: (name, volume) => test.log('AUDIO $name vol=${volume.toStringAsFixed(2)}'),
  );
  RenderTour? _tour;

  Phase phase = Phase.loading;
  MenuPage page = MenuPage.none;
  String Function(L10n l) label = (l) => l.buildingVillage;
  double progress = 0.02;
  String? error;

  /// The models' state for the title screen.
  String Function(L10n l) modelStatus = (_) => '';
  ModelConfig? config;
  VillageModels? models;
  bool _modelsFailed = false;

  /// The background village of the title screen (canned, no bubbles).
  Village? attract;

  /// The game being played, if any.
  Village? village;
  Director? director;
  PlayerBot? bot;
  SaveStore? store;

  /// The newest save that loads, for the title screen's Continue.
  SaveInfo? continueSave;
  Set<Ending> unlocked = {};

  /// Set while a game is starting, for the title screen.
  String Function(L10n l)? busy;
  bool pauseMenu = false;
  bool _pausedBefore = false;

  /// Every save slot, empty ones as null.
  Map<String, SaveInfo?> slots = {};
  String? toast;
  double _toastUntil = 0;

  final Map<String, String?> epilogue = {};

  /// This week's storybook, written from the ending scene on.
  Storybook? book;
  StoryWriter? _writer;
  StoryCamera? _camera;
  bool _bookSaved = false;
  final Set<int> _pagesLogged = {};

  /// Ticks as storybook pages stream in.
  final ValueNotifier<int> storyTick = ValueNotifier(0);

  /// The storybook on screen: this week's or one from the gallery.
  Storybook? reading;
  final GlobalKey<StorybookViewState> storyKey = GlobalKey();
  List<Storybook> books = [];
  EndingVerdict? verdict;
  Influence? influence;
  bool newlyUnlocked = false;

  bool _sceneReady = false;

  /// The models' description for the HUD; null with canned lines.
  String? modelLabel;

  /// The language the llamas speak, from the app's locale.
  Lang lang = Lang.en;
  double _wall = 0;
  double _slowAcc = 0;
  double? fps;
  int _fpsFrames = 0;
  double _fpsTime = 0;
  Size _size = Size.zero;
  Future<void>? _shutdown;
  Future<VillageModels>? _loading;
  Autoplay? _autoplay;
  WeekAutoplay? _week;
  late final MemProbe? _mem = test.memLogSeconds == null ? null : MemProbe(this, test.memLogSeconds!);

  /// Audio voices alive, for the memory log.
  int get audioVoices => _audio.voices;

  /// Seconds since the phase last changed.
  double phaseTime = 0;

  // Pointer state.
  Offset? _downAt;
  int _downButtons = 0;
  bool _dragging = false;

  SelfTest get test => widget.test;

  /// The village on screen: the game, or the title screen's.
  Village? get shown => village ?? attract;
  bool get inCutscene => director?.player != null;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onExitRequested: _onExitRequested);
    test.start();
    _vsync = createTicker(_onVsync)..start();
    if (test.keepTicking) _keepTicking = Timer.periodic(const Duration(milliseconds: 50), (_) => _tickWithoutVsync());
    unawaited(_boot());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final now = Lang.fromCode(Localizations.localeOf(context).languageCode);
    if (now == lang) return;
    lang = now;
    village?.lang = now;
    test.log('LANGUAGE ${now.name}');
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _vsync.dispose();
    _keepTicking?.cancel();
    frame.dispose();
    slow.dispose();
    storyTick.dispose();
    focus.dispose();
    unawaited(shutdown());
    super.dispose();
  }

  // ------------------------------------------------------------ boot

  Future<void> _boot() async {
    _applySettings();
    settings.addListener(_applySettings);
    unawaited(
      _audio.init().then((ok) {
        _applySettings();
        test.log('AUDIO ready=$ok loops ${_audio.loopLengths().map((k, s) => MapEntry(k, s.toStringAsFixed(4)))}');
      }),
    );
    try {
      await stage.load(const ['Pip', 'Mo', 'June', 'Bramble', 'Clover']);
      _sceneReady = true;
    } catch (e, st) {
      debugPrint('SCENE FAILED: $e\n$st');
      setState(() {
        phase = Phase.failed;
        error = '$e';
      });
      return;
    }
    try {
      final dir = test.saveDir;
      store = dir != null ? SaveStore(Directory(dir)) : await SaveStore.open();
      test.log('SAVES ${store!.dir.path}');
    } catch (e) {
      debugPrint('Llama Village: saves unavailable: $e');
    }
    await _refreshSaves();
    await _startAttract();
    _loadModels();
    if (!mounted) return;
    setState(() {
      phase = Phase.menu;
      phaseTime = 0;
    });
    test.log('MENU shown');
    if (test.autoplay) _autoplay = Autoplay(this)..start();
    if (test.weekScript) _week = WeekAutoplay(this)..start();
    final tour = RenderTour.requested;
    if (tour != null) _tour = RenderTour(this, tour);
  }

  void _loadModels() {
    final cfg = config = ModelConfig.resolve();
    if (test.canned) {
      modelStatus = (l) => l.statusCanned;
      return;
    }
    if (!cfg.hasRequired) {
      test.log('MODELS missing ${cfg.missing.join(', ')}');
      final files = cfg.missing.join(', '), dir = cfg.searched.first;
      modelStatus = (l) => l.statusMissing(files, dir);
      return;
    }
    modelStatus = (l) => l.statusLoading;
    final watch = Stopwatch()..start();
    final loading = _loading = VillageModels.load(
      cfg,
      onProgress: (stage, f) {
        if (!mounted) return;
        setState(() {
          modelStatus = (l) => l.loadProgress(stage, (f * 100).round());
          progress = f;
        });
      },
    );
    loading.then(
      (m) async {
        if (_shutdown != null) return;
        models = m;
        modelLabel = m.description;
        test.log('MODELS loaded in ${watch.elapsedMilliseconds} ms: ${m.description}');
        if (mounted) setState(() => modelStatus = (l) => l.statusReady(m.description));
      },
      onError: (Object e, StackTrace st) {
        debugPrint('MODELS FAILED: $e\n$st');
        _modelsFailed = true;
        if (mounted) setState(() => modelStatus = (l) => l.statusFailed('$e'));
      },
    );
  }

  bool _attractStarting = false;

  Future<void> _startAttract() async {
    if (_attractStarting) return;
    _attractStarting = true;
    final a = Village(
      chat: CannedChat(delay: const Duration(milliseconds: 250)),
      embed: HashEmbed(),
      seed: 7,
      msPerMinute: 500,
      autoAck: true,
    )..now = const GameTime(1, 9 * 60);
    await a.begin();
    attract?.close();
    attract = a;
    _attractStarting = false;
  }

  Future<void> _refreshSaves() async {
    final s = store;
    if (s == null) return;
    final all = await s.list();
    final have = await s.unlocked();
    if (!mounted) return;
    setState(() {
      continueSave = SaveStore.newest(all.values);
      unlocked = have;
      slots = all;
    });
  }

  void _applySettings() {
    _throttle.fps = settings.fps;
    stage
      ..quality = settings.quality
      ..reducedMotion = settings.reducedMotion;
    animalSounds.sfxVolume = settings.sfxVolume;
    sound
      ..musicVolume = settings.musicVolume
      ..sfxVolume = settings.sfxVolume;
    _audio.muted = settings.muted;
    village?.textPace = settings.textSpeed.pace;
  }

  // ------------------------------------------------------------ games

  Village _newVillage(int seed) {
    final m = models;
    final pace = test.msPerMinute ?? 500;
    final v = m != null
        ? Village(chat: m, embed: m, laya: m.hasLaya ? m : null, seed: seed, msPerMinute: pace)
        : Village(
            chat: CannedChat(delay: const Duration(milliseconds: 250)),
            embed: HashEmbed(),
            seed: seed,
            msPerMinute: pace,
          );
    return v..lang = lang;
  }

  /// Waits for a model load in progress, so a game does not start on canned
  /// lines by accident.
  Future<void> _awaitModels() async {
    final loading = _loading;
    if (loading == null || models != null || _modelsFailed) return;
    setState(() => busy = (l) => l.busyWaitingModels);
    try {
      await loading;
    } catch (_) {
      // The status line says what failed; the game uses canned lines.
    }
  }

  Future<void> newGame() async {
    if (busy != null || phase != Phase.menu) return;
    sound.click();
    await _awaitModels();
    if (!mounted || _shutdown != null) return;
    modelLabel = models?.description;
    final v = _newVillage(test.seed ?? DateTime.now().millisecondsSinceEpoch);
    setState(() => busy = (l) => l.busyPlanning);
    final watch = Stopwatch()..start();
    await v.begin();
    test.log('PLANS ready in ${watch.elapsedMilliseconds} ms');
    final jump = test.jumpDay;
    if (jump != null && jump > 1) {
      setState(() => busy = (l) => l.busySkipping(jump));
      await v.jumpTo(jump);
      test.log('JUMP to ${v.now}');
    }
    if (!mounted || _shutdown != null) {
      v.close();
      return;
    }
    _enterGame(v);
  }

  /// Loads the save in [info]'s slot, picked in the save picker.
  Future<void> continueGame(SaveInfo info) async {
    final s = store;
    if (s == null || busy != null || phase != Phase.menu) return;
    sound.click();
    setState(() {
      page = MenuPage.none;
      busy = (l) => l.busyLoading(l.saveWhen(info));
    });
    final Map<String, Object?> json;
    try {
      json = await s.read(info.slot);
    } on SaveException catch (e) {
      _toast((l) => l.toastCannotLoad(e.message));
      setState(() => busy = null);
      await _refreshSaves();
      return;
    }
    await _awaitModels();
    if (!mounted || _shutdown != null) return;
    modelLabel = models?.description;
    final v = _newVillage(1);
    try {
      restoreVillage(v, json);
    } on SaveException catch (e) {
      v.close();
      _toast((l) => l.toastCannotLoad(e.message));
      setState(() => busy = null);
      return;
    }
    test.log('LOADED ${info.slot} at ${v.now}');
    _enterGame(v);
  }

  void _enterGame(Village v) {
    v
      ..timeScale = test.timeScale ?? settings.defaultSpeed.toDouble()
      ..textPace = settings.textSpeed.pace
      ..paused = false;
    test.generating = () => v.chat.queue.busy;
    test.running = () => [?v.chat.queue.runningType, ?v.embed.queue.runningType].join('+');
    final preset = botPresetFrom(test.bot);
    final camera = _camera = StoryCamera(stage: stage, boundary: _sceneShotKey, log: test.log);
    v.events.listeners.add((e) => camera.onEvent(v, e));
    book = null;
    _writer = null;
    _bookSaved = false;
    _pagesLogged.clear();
    setState(() {
      busy = null;
      village = v;
      director = _tour != null
          ? null
          : Director(
              v: v,
              stage: stage,
              settings: settings,
              log: test.log,
              onDawn: (day) => unawaited(_autosave(day)),
              onWeekOver: _weekOver,
              onEnding: _startStory,
              strings: () => L10n.of(context),
            );
      bot = preset == null ? null : (PlayerBot(preset)..thinkMs = test.capture ? 1500 : 0);
      phase = Phase.playing;
      page = MenuPage.none;
      pauseMenu = false;
      phaseTime = 0;
      stage.rig
        ..override = null
        ..overview();
    });
    focus.requestFocus();
    test.log('GAME start ${v.now} scale=${v.timeScale} bot=${preset?.name}');
  }

  Future<void> _autosave(int day) async {
    await saveTo(SaveStore.autoSlot, quiet: true);
    test.log('AUTOSAVE day $day');
  }

  /// Saves the game to [slot]; [quiet] skips the confirmation (the morning
  /// autosave lands mid-cutscene).
  Future<void> saveTo(String slot, {bool quiet = false}) async {
    final s = store, v = village;
    if (s == null || v == null) return;
    try {
      // The sim keeps running while the picture is taken; save this moment.
      final save = snapshotVillage(v);
      await s.write(slot, save, thumbnail: await _thumbnail());
      if (!quiet) {
        _toast((l) => l.toastSaved(slot == SaveStore.autoSlot ? 'auto' : slot.substring(4), v.now.day, v.now.hhmm));
      }
    } catch (e) {
      _toast((l) => l.toastSaveFailed('$e'));
    }
    await _refreshSaves();
  }

  /// The save list's picture of the 3D view; a save without one still
  /// loads.
  Future<Uint8List?> _thumbnail() async {
    try {
      return await captureScene(_sceneShotKey, 320);
    } catch (e) {
      test.log('THUMBNAIL failed: $e');
      return null;
    }
  }

  void _toast(String Function(L10n l) say) {
    if (!mounted) return;
    final text = say(L10n.of(context));
    toast = text;
    _toastUntil = _wall + 3;
    test.log('TOAST $text');
    if (mounted) setState(() {});
  }

  /// Starts writing this week's storybook in the background, page by page,
  /// while the ending scene, the epilogue and the results play.
  void _startStory(EndingVerdict verdict, Influence i) {
    final v = village;
    if (v == null) return;
    final b = book = newStorybook(v, verdict, id: 'week-${DateTime.now().millisecondsSinceEpoch}', title: L10n.of(context).storyTitle);
    _bookSaved = false;
    final writer = _writer = StoryWriter(v, b, verdict: verdict, influence: i, onChange: () => _storyChanged(b), say: L10n.of(context).say);
    test.log('STORYBOOK start (${v.journal.beats.length} beats, ${v.album.shots.length} pictures)');
    unawaited(writer.start());
  }

  void _storyChanged(Storybook b) {
    storyTick.value++;
    for (final (n, p) in b.pages.indexed) {
      if (p.text != null && _pagesLogged.add(n)) test.log('STORYPAGE $n fallback=${p.fallback} ${p.text}');
    }
    if (b.complete && !_bookSaved && b == book) unawaited(_saveBook(b));
  }

  /// Keeps the finished book in the gallery, once.
  Future<void> _saveBook(Storybook b) async {
    if (_bookSaved) return;
    _bookSaved = true;
    final v = village;
    if (v != null) illustrate(b, v.album);
    try {
      await store?.writeStorybook(b);
      test.log('STORYBOOK saved ${b.id} (${b.pages.where((p) => p.shot != null).length} pictures)');
    } catch (e) {
      debugPrint('Llama Village: storybook not saved: $e');
    }
  }

  /// Finishes an unfinished book from the rules and keeps it, for a game
  /// being left or quit while pages are still being written.
  Future<void> _keepBook() async {
    final b = book;
    if (b == null || _bookSaved) return;
    if (!b.complete) _writer?.finishWithFallbacks();
    await _saveBook(b);
  }

  void openStory([Storybook? b]) {
    final open = b ?? book;
    if (open == null) return;
    sound.click();
    setState(() => reading = open);
    test.log('STORYBOOK open ${open.id}');
  }

  void closeStory() {
    sound.click();
    setState(() => reading = null);
    focus.requestFocus();
  }

  Future<void> _refreshBooks() async {
    final list = await store?.storybooks() ?? const <Storybook>[];
    if (mounted) setState(() => books = list);
  }

  void _weekOver(EndingVerdict v, Influence i) {
    final game = village!;
    final b = book;
    if (b != null) illustrate(b, game.album);
    setState(() {
      phase = Phase.epilogue;
      phaseTime = 0;
      verdict = v;
      influence = i;
      epilogue
        ..clear()
        ..addAll({for (final l in game.cast) l.name: null});
    });
    unawaited(_unlock(v.ending));
    for (final l in game.cast) {
      epilogueLine(game, l, i, verdict: v).then((line) {
        if (!mounted || village != game) return;
        setState(() => epilogue[l.name] = line);
        test.log('EPILOGUE ${l.name}: $line');
      });
    }
  }

  Future<void> _unlock(Ending e) async {
    final s = store;
    newlyUnlocked = s == null ? !unlocked.contains(e) : await s.unlock(e);
    test.log('UNLOCK ${e.name} new=$newlyUnlocked');
    await _refreshSaves();
  }

  void showResults() {
    final game = village, i = influence;
    if (game != null && i != null) {
      for (final l in game.cast) {
        epilogue[l.name] ??= fallbackEpilogue(game, l, i);
      }
    }
    sound.click();
    setState(() {
      phase = Phase.results;
      phaseTime = 0;
    });
  }

  /// Leaves the game for the title screen, saving first if asked.
  Future<void> toMenu({bool save = false}) async {
    final v = village;
    if (v == null) return;
    if (save) await saveTo(SaveStore.autoSlot);
    await _keepBook();
    director?.dispose();
    v.close();
    models?.cancel();
    setState(() {
      village = null;
      director = null;
      bot = null;
      reading = null;
      _camera = null;
      pauseMenu = false;
      showSettings = false;
      stage.selected = null;
      phase = Phase.menu;
      page = MenuPage.none;
      busy = (l) => l.busyTidying;
      phaseTime = 0;
    });
    await _quiesce(v);
    if (!mounted) return;
    setState(() => busy = null);
    await _refreshSaves();
    focus.requestFocus();
    test.log('MENU back from the game');
  }

  /// Waits until a closed village's last model job has stopped, so the next
  /// game never shares an engine with it.
  Future<void> _quiesce(Village v) async {
    final watch = Stopwatch()..start();
    while ((v.chat.queue.busy || v.embed.queue.busy) && watch.elapsed < const Duration(seconds: 15)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  // ------------------------------------------------------------ exit

  Future<AppExitResponse> _onExitRequested() async {
    test.log('EXIT requested');
    await shutdown();
    return AppExitResponse.exit;
  }

  /// Stops the sim and frees every model engine; the app must not exit
  /// with models loaded (ggml's Metal teardown would crash).
  Future<void> shutdown() => _shutdown ??= _doShutdown();

  Future<void> _doShutdown() async {
    final watch = Stopwatch()..start();
    try {
      await _keepBook().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Quitting must not wait on the gallery.
    }
    _audio.dispose();
    village?.close();
    attract?.close();
    // A quit during loading waits for the engines, then frees them too.
    final loading = _loading;
    if (models == null && loading != null) {
      try {
        models = await loading.timeout(const Duration(seconds: 60));
      } catch (_) {
        // Loading failed, so nothing is left to free.
      }
    }
    await models?.dispose();
    models = null;
    test.log('SHUTDOWN models disposed in ${watch.elapsedMilliseconds} ms');
    debugPrint('Llama Village: models disposed in ${watch.elapsedMilliseconds} ms');
  }

  Future<void> quit() async {
    await shutdown();
    await ServicesBinding.instance.exitApplication(AppExitType.required);
  }

  // ------------------------------------------------------------ loop

  Timer? _keepTicking;
  final Stopwatch _sinceVsync = Stopwatch()..start();

  /// VILLAGE_KEEP_TICKING: a locked screen or a sleeping display sends no
  /// vsync, so a soak run steps the game and pumps frames itself meanwhile.
  void _tickWithoutVsync() {
    if (_sinceVsync.elapsedMilliseconds < 250 || _shutdown != null) return;
    _tick(0.05);
    SchedulerBinding.instance.scheduleWarmUpFrame();
  }

  void _onVsync(Duration elapsed) {
    _sinceVsync.reset();
    final dt = _throttle.onVsync(elapsed);
    if (dt == null) return;
    _tick(dt);
    _repaintScene();
  }

  /// The SceneView runs without its own ticker (which would render on every
  /// vsync), so a rendered frame marks its painter dirty directly.
  void _repaintScene() {
    var paint = _scenePaint;
    if (paint == null || !paint.attached) {
      paint = _scenePaint = _findCustomPaint(_sceneKey.currentContext?.findRenderObject());
    }
    paint?.markNeedsPaint();
  }

  static RenderCustomPaint? _findCustomPaint(RenderObject? root) {
    if (root == null) return null;
    if (root is RenderCustomPaint) return root;
    RenderCustomPaint? found;
    root.visitChildren((child) => found ??= _findCustomPaint(child));
    return found;
  }

  void _tick(double dt) {
    _wall += dt;
    phaseTime += dt;
    _fpsFrames++;
    _fpsTime += dt;
    if (_fpsTime >= 1) {
      fps = _fpsFrames / _fpsTime;
      _fpsFrames = 0;
      _fpsTime = 0;
    }
    if (toast != null && _wall > _toastUntil) setState(() => toast = null);
    final v = shown;
    if (v == null || !_sceneReady || _shutdown != null) return;
    final step = math.min(dt, 0.1);
    final watch = Stopwatch()..start();
    final game = village;
    if (game != null && phase == Phase.playing) {
      // A stall longer than a second (a sleeping Mac) is not play.
      if (!pauseMenu) game.playtime += math.min(dt, 1);
      if (!inCutscene && !pauseMenu) _steer(game);
      game.advance(step * 1000);
      director?.tick(step);
      _camera?.tick(game, step, player: director?.player);
      if (inCutscene != _wasCutscene) setState(() => _wasCutscene = inCutscene);
      if (!inCutscene && !pauseMenu) bot?.tick(game);
    } else if (game == null) {
      attract!.advance(step * 1000);
      if (attract!.now.minute >= 18 * 60 && busy == null) unawaited(_startAttract());
    }
    if (phase != Phase.playing) _drone();
    final simDone = watch.elapsedMicroseconds;
    stage.update(v, step);
    if (game != null && phase == Phase.playing) {
      sound.update(game, _view, step);
    } else {
      sound.ambience(v, step);
    }
    animalSounds.update(stage.life.calls, _view, step, groundAt: groundHeight);
    if (test.capture) {
      test.simMs.add(simDone / 1000);
      test.sceneMs.add((watch.elapsedMicroseconds - simDone) / 1000);
    }
    test.frame(dt);
    _autoplay?.tick(dt);
    _week?.tick(dt);
    _mem?.tick(dt);
    _quitTest();
    _tour?.tick(dt);
    frame.value++;
    _slowAcc += dt;
    if (_slowAcc > 0.25) {
      _slowAcc = 0;
      slow.value++;
    }
  }

  /// The slow flyover behind the title screen and the end of the week.
  void _drone() {
    final speed = settings.reducedMotion ? 0.012 : 0.035;
    final a = _wall * speed + 0.6;
    final centre = vm.Vector3(1, 1.5, -6);
    stage.rig.override = PerspectiveCamera(
      position: centre + vm.Vector3(math.sin(a) * 64, 27 + math.sin(_wall * 0.05) * 3, math.cos(a) * 64),
      target: centre,
      fovRadiansY: CameraRig.fov * 1.15,
      fovNear: 0.5,
      fovFar: 400,
    );
  }

  bool _quitStarted = false;
  bool _wasCutscene = false;

  /// VILLAGE_QUIT_AT: quits from the title screen (its Quit button), mid
  /// cutscene, mid generation or while the storybook is being written (the
  /// last three through the system exit request, as Cmd-Q does).
  void _quitTest() {
    final at = test.quitAt;
    if (at == null || _quitStarted) return;
    final game = village;
    final due = switch (at) {
      'menu' => phase == Phase.menu && busy == null && phaseTime > 3,
      'cutscene' => (director?.player?.time ?? 0) > 2,
      'generation' => game != null && phase == Phase.playing && !inCutscene && phaseTime > 4 && game.chat.queue.busy,
      'story' => book != null && !book!.complete && book!.pages.any((p) => p.draft.isNotEmpty),
      _ => false,
    };
    if (!due) return;
    _quitStarted = true;
    test.log('QUIT_AT $at (generating=${game?.chat.queue.busy}, cutscene=${director?.player?.scene.name})');
    if (at == 'menu') {
      unawaited(quit());
    } else {
      unawaited(ServicesBinding.instance.exitApplication(AppExitType.cancelable));
    }
  }

  void _steer(Village v) {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    var f = 0.0, r = 0.0;
    if (keys.contains(LogicalKeyboardKey.keyW) || keys.contains(LogicalKeyboardKey.arrowUp)) f += 1;
    if (keys.contains(LogicalKeyboardKey.keyS) || keys.contains(LogicalKeyboardKey.arrowDown)) f -= 1;
    if (keys.contains(LogicalKeyboardKey.keyD) || keys.contains(LogicalKeyboardKey.arrowRight)) r += 1;
    if (keys.contains(LogicalKeyboardKey.keyA) || keys.contains(LogicalKeyboardKey.arrowLeft)) r -= 1;
    if (f == 0 && r == 0) {
      if (v.dash.steer.$1 != 0 || v.dash.steer.$2 != 0) v.dash.steerBy(0, 0);
      return;
    }
    final yaw = stage.rig.yaw;
    final forward = vm.Vector2(-math.sin(yaw), -math.cos(yaw));
    // flutter_scene's view puts world -x on screen right at yaw 0.
    final right = vm.Vector2(-math.cos(yaw), math.sin(yaw));
    final d = forward * f + right * r;
    v.dash.steerBy(d.x, d.y);
  }

  // ------------------------------------------------------------ commands

  void select(String? name) {
    setState(() => stage.selected = name);
    slow.value++;
  }

  void talkTo(String name) {
    final v = village;
    if (v == null) return;
    select(name);
    unawaited(v.dash.talk(v.byName(name)));
  }

  void choose(int i) {
    sound.click();
    village?.dash.choose(i);
  }

  void togglePause() {
    final v = village;
    if (v == null) return;
    setState(() => v.paused = !v.paused);
  }

  void setSpeed(double s) {
    final v = village;
    if (v == null) return;
    setState(() {
      v.timeScale = s;
      v.paused = false;
    });
  }

  void openPause() {
    final v = village;
    // Not while a night skip is still finishing: a save then would lose
    // the plans being written.
    if (v == null || pauseMenu || (director?.busy ?? false) || phase != Phase.playing) return;
    sound.click();
    _pausedBefore = v.paused;
    v.paused = true;
    v.dash.steerBy(0, 0);
    setState(() {
      pauseMenu = true;
      showSettings = false;
    });
    unawaited(_refreshSaves());
    test.log('PAUSE open at ${v.now}');
  }

  void closePause() {
    final v = village;
    if (!pauseMenu) return;
    sound.click();
    if (v != null && !(director?.busy ?? false)) v.paused = _pausedBefore;
    setState(() {
      pauseMenu = false;
      showSettings = false;
    });
    focus.requestFocus();
  }

  void openPage(MenuPage p) {
    sound.click();
    setState(() => page = p);
    if (p == MenuPage.endings) {
      unawaited(_refreshSaves());
      unawaited(_refreshBooks());
    }
    if (p == MenuPage.saves) unawaited(_refreshSaves());
  }

  void closePage() {
    sound.click();
    setState(() => page = MenuPage.none);
    focus.requestFocus();
  }

  void follow() {
    final rig = stage.rig;
    final name = stage.selected ?? 'Dash';
    if (rig.followName == name) {
      rig.follow = null;
      rig.followName = null;
    } else {
      rig
        ..followName = name
        ..follow = (() => name == 'Dash' ? stage.dash.position.clone() : stage.llamas[name]!.position.clone())
        ..distance = math.min(rig.distance, 34);
    }
    setState(() {});
  }

  void _click(Offset at, {required bool secondary}) {
    final v = village;
    if (v == null || phase != Phase.playing || inCutscene || pauseMenu) return;
    final hit = stage.pickLlama(at, _size);
    if (hit != null) {
      if (secondary) {
        select(hit);
      } else {
        talkTo(hit);
      }
      return;
    }
    if (secondary) return;
    final ground = stage.pickGround(at, _size);
    if (ground != null) v.dash.flyTo(ground);
  }

  void _onPress(LogicalKeyboardKey k) {
    final escape = k == LogicalKeyboardKey.escape;
    if (reading != null) {
      if (escape) closeStory();
      return;
    }
    if (inCutscene) {
      if (escape || k == LogicalKeyboardKey.space) director!.skip();
      return;
    }
    if (phase == Phase.menu) {
      if (escape && page != MenuPage.none) closePage();
      return;
    }
    final v = village;
    if (v == null || phase != Phase.playing) return;
    if (pauseMenu) {
      if (!escape) return;
      if (showSettings) {
        setState(() => showSettings = false);
      } else {
        closePause();
      }
      return;
    }
    final visit = v.dash.visit;
    if (k == LogicalKeyboardKey.space) {
      togglePause();
    } else if (escape) {
      if (visit != null) {
        v.dash.leave();
      } else if (stage.selected != null) {
        select(null);
      } else if (showSettings) {
        setState(() => showSettings = false);
      } else {
        openPause();
      }
    } else if (k == LogicalKeyboardKey.keyF) {
      follow();
    } else if (k == LogicalKeyboardKey.keyO) {
      stage.rig.overview();
      setState(() {});
    } else if (k == LogicalKeyboardKey.keyQ || k == LogicalKeyboardKey.keyE) {
      stage.rig.yaw += k == LogicalKeyboardKey.keyQ ? 0.35 : -0.35;
    } else {
      final digit = switch (k) {
        LogicalKeyboardKey.digit1 => 1,
        LogicalKeyboardKey.digit2 => 2,
        LogicalKeyboardKey.digit3 => 3,
        LogicalKeyboardKey.digit4 => 4,
        _ => 0,
      };
      if (digit > 0 && visit?.stage == VisitStage.choosing) choose(digit - 1);
    }
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2B3A67),
      child: GameKeys(
        focusNode: focus,
        onPress: _onPress,
        child: RepaintBoundary(
          key: test.boundaryKey,
          child: LayoutBuilder(
            builder: (context, box) {
              _size = box.biggest;
              final game = village;
              return Stack(
                fit: StackFit.expand,
                children: [
                  _sceneLayer(),
                  if (phase == Phase.playing && game != null) ..._overlay(game),
                  if (phase == Phase.menu) ..._menu(),
                  if (phase == Phase.epilogue) Scrim(opacity: 0.35, child: _epilogue()),
                  if (phase == Phase.results && verdict != null)
                    Scrim(
                      child: ValueListenableBuilder<int>(
                        valueListenable: storyTick,
                        builder: (context, _, _) {
                          final b = book;
                          return ResultsView(
                            verdict: verdict!,
                            influence: influence!,
                            newlyUnlocked: newlyUnlocked,
                            onMenu: () => unawaited(toMenu()),
                            onStory: b == null ? null : openStory,
                            storyStatus: b == null || b.complete ? null : L10n.of(context).storyProgress(b.writtenCount, b.textPages),
                          );
                        },
                      ),
                    ),
                  if (reading != null)
                    Positioned.fill(
                      child: StorybookView(
                        key: storyKey,
                        book: reading!,
                        changes: storyTick,
                        reducedMotion: settings.reducedMotion,
                        onClick: sound.click,
                        onClose: closeStory,
                      ),
                    ),
                  if (phase == Phase.loading || phase == Phase.failed)
                    LoadingCard(
                      label: label(L10n.of(context)),
                      progress: progress,
                      error: phase == Phase.failed && error != null ? L10n.of(context).sceneFailed(error!) : null,
                      onQuit: phase == Phase.failed ? quit : null,
                    ),
                  if (toast != null)
                    Positioned(
                      top: 24,
                      left: 0,
                      right: 0,
                      child: Center(child: Toast(text: toast!)),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _epilogue() => ValueListenableBuilder<int>(
    valueListenable: slow,
    builder: (context, _, _) {
      final ready = epilogue.values.every((l) => l != null) || phaseTime > 40;
      return EpilogueView(lines: epilogue, wall: _wall, textScale: settings.textSize.scale, onContinue: ready ? showResults : null);
    },
  );

  List<Widget> _menu() => [
    StartMenu(
      save: continueSave,
      status: modelStatus(L10n.of(context)),
      busy: busy?.call(L10n.of(context)),
      onNew: () => unawaited(newGame()),
      onContinue: () => openPage(MenuPage.saves),
      onEndings: () => openPage(MenuPage.endings),
      onSettings: () => openPage(MenuPage.settings),
      onCredits: () => openPage(MenuPage.credits),
      onQuit: () {
        sound.click();
        unawaited(quit());
      },
    ),
    if (page != MenuPage.none)
      Scrim(
        child: switch (page) {
          MenuPage.settings => SettingsPanel(settings: settings, onClick: sound.click, onClose: closePage, maxHeight: _panelHeight),
          MenuPage.credits => CreditsView(onClose: closePage),
          MenuPage.endings => EndingsGallery(unlocked: unlocked, onClose: closePage, books: books, onOpenBook: openStory),
          MenuPage.saves => SavePicker(slots: slots, onPick: (info) => unawaited(continueGame(info)), onClose: closePage),
          MenuPage.none => const SizedBox.shrink(),
        },
      ),
  ];

  Widget _sceneLayer() => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: (e) {
      _downAt = e.localPosition;
      _downButtons = e.buttons;
      _dragging = false;
      focus.requestFocus();
    },
    onPointerMove: (e) {
      final start = _downAt;
      if (start == null || phase != Phase.playing || inCutscene) return;
      if (!_dragging && (e.localPosition - start).distance > 5) _dragging = true;
      if (!_dragging) return;
      final pan = _downButtons & kSecondaryMouseButton != 0 || HardwareKeyboard.instance.isShiftPressed;
      if (pan) {
        stage.rig.pan(e.delta.dx, e.delta.dy);
      } else {
        stage.rig.orbit(e.delta.dx, e.delta.dy);
      }
    },
    onPointerUp: (e) {
      final start = _downAt;
      _downAt = null;
      if (start != null && !_dragging) _click(e.localPosition, secondary: _downButtons & kSecondaryMouseButton != 0);
      _dragging = false;
    },
    onPointerSignal: (e) {
      if (e is PointerScrollEvent && phase == Phase.playing) stage.rig.zoom(math.pow(1.0015, e.scrollDelta.dy).toDouble());
    },
    onPointerPanZoomUpdate: (e) {
      if (phase != Phase.playing) return;
      stage.rig.pan(e.panDelta.dx, e.panDelta.dy);
      if (e.scale != 1) stage.rig.zoom(1 / math.pow(e.scale, 0.08).toDouble());
    },
    child: RepaintBoundary(
      key: _sceneShotKey,
      child: SceneView(stage.scene, key: _sceneKey, autoTick: false, cameraBuilder: (_) => stage.rig.camera()),
    ),
  );

  /// Tall enough for every setting in a full-size window; it scrolls below.
  double get _panelHeight => math.max(240, _size.height - 100);

  VoidCallback _clicky(VoidCallback action) => () {
    sound.click();
    action();
  };

  List<Widget> _overlay(Village v) {
    final d = director;
    if (d != null && d.player != null) {
      return [
        ValueListenableBuilder<int>(
          valueListenable: frame,
          builder: (context, _, _) {
            final p = d.player;
            if (p == null) return const SizedBox.shrink();
            return CutsceneOverlay(
              player: p,
              stage: stage,
              size: _size,
              onSkip: d.skip,
              textScale: settings.textSize.scale,
              highContrast: settings.highContrast,
              wall: _wall,
            );
          },
        ),
      ];
    }
    return [
      ValueListenableBuilder<int>(
        valueListenable: frame,
        builder: (context, _, _) => BubbleLayer(
          village: v,
          stage: stage,
          size: _size,
          wall: _wall,
          textScale: settings.textSize.scale,
          highContrast: settings.highContrast,
        ),
      ),
      Positioned(
        top: 14,
        left: 14,
        child: ValueListenableBuilder<int>(
          valueListenable: slow,
          builder: (context, _, _) => TopBar(
            village: v,
            fps: fps,
            onPause: _clicky(togglePause),
            onSpeed: (s) {
              sound.click();
              setSpeed(s);
            },
            onOverview: _clicky(() => setState(stage.rig.overview)),
            onFollow: _clicky(follow),
            followName: stage.rig.followName,
            modelLabel: modelLabel ?? L10n.of(context).cannedLabel,
            onSettings: _clicky(() => setState(() => showSettings = !showSettings)),
          ),
        ),
      ),
      if (showSettings && !pauseMenu)
        Positioned(
          top: 80,
          left: 14,
          child: SettingsPanel(
            settings: settings,
            maxHeight: _panelHeight,
            onClick: sound.click,
            onClose: _clicky(() => setState(() => showSettings = false)),
          ),
        ),
      Positioned(
        left: 14,
        bottom: 14,
        child: ValueListenableBuilder<int>(
          valueListenable: slow,
          builder: (context, _, _) => VillageLog(entries: v.log.entries, count: v.log.entries.length),
        ),
      ),
      if (stage.selected != null)
        Positioned(
          top: 14,
          right: 14,
          bottom: 14,
          child: ValueListenableBuilder<int>(
            valueListenable: slow,
            builder: (context, _, _) => Inspector(
              data: v.inspect(stage.selected!),
              village: v,
              cast: v.cast,
              onClose: _clicky(() => select(null)),
              onTalk: _clicky(() => talkTo(stage.selected!)),
            ),
          ),
        ),
      // Between the log (left) and the inspector (right).
      Positioned(
        left: 420,
        right: stage.selected == null ? 14 : 388,
        bottom: 16,
        child: Center(
          child: ValueListenableBuilder<int>(
            valueListenable: frame,
            builder: (context, _, _) {
              final visit = v.dash.visit;
              if (visit == null) return const HelpHint();
              return OptionsPanel(visit: visit, onChoose: choose, onMore: _clicky(v.dash.sayMore), onLeave: _clicky(v.dash.leave));
            },
          ),
        ),
      ),
      Positioned(
        top: 80,
        left: 0,
        right: 0,
        child: Center(
          child: ValueListenableBuilder<int>(
            valueListenable: slow,
            builder: (context, _, _) {
              final l = L10n.of(context);
              final notice = v.dash.notice;
              final n = notice != null
                  ? l.noticeOf(notice)
                  : (d?.waitingForDawn ?? false)
                  ? l.noticePlanningTomorrow
                  : v.paused && !pauseMenu
                  ? l.noticePaused
                  : null;
              return n == null ? const SizedBox.shrink() : Notice(text: n);
            },
          ),
        ),
      ),
      if (pauseMenu)
        Scrim(
          child: showSettings
              ? SettingsPanel(
                  settings: settings,
                  onClick: sound.click,
                  onClose: _clicky(() => setState(() => showSettings = false)),
                  maxHeight: _panelHeight,
                )
              : PauseMenu(
                  when: L10n.of(context).dayAndTime(v.now.day, v.now.hhmm),
                  slots: {for (final slot in SaveStore.manualSlots) slot: slots[slot]},
                  onResume: closePause,
                  onSave: saveTo,
                  onSettings: _clicky(() => setState(() => showSettings = true)),
                  onSaveAndQuit: () => unawaited(toMenu(save: true)),
                  onQuit: () {
                    sound.click();
                    unawaited(quit());
                  },
                ),
        ),
    ];
  }
}

class _StageView implements SoundView {
  _StageView(this.home);
  final VillageHomeState home;

  @override
  vm.Vector3 get eye => home.stage.rig.eye;

  @override
  vm.Vector3 get dash => home.stage.dash.position;

  @override
  vm.Vector3? llama(String name) {
    final a = home.stage.llamas[name];
    return a == null || !a.visible ? null : a.position;
  }

  @override
  double panOf(vm.Vector3 p) {
    final size = home._size;
    final at = home.stage.toScreen(p, size);
    if (at == null || size.width <= 0) return 0;
    return ((at.dx / size.width) * 2 - 1).clamp(-1.0, 1.0) * 0.6;
  }
}

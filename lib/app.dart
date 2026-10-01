import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show AppExitResponse, AppExitType;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:vector_math/vector_math.dart' as vm;

import 'ai/models.dart';
import 'autoplay.dart';
import 'render/stage.dart';
import 'self_test.dart';
import 'sim/canned.dart';
import 'sim/dash.dart';
import 'sim/village.dart';
import 'ui/bubbles.dart';
import 'ui/panels.dart';

class VillageApp extends StatelessWidget {
  const VillageApp({super.key, required this.test});
  final SelfTest test;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Llama Village',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF3E8EF0)),
    home: VillageHome(test: test),
  );
}

enum Phase { loading, missing, failed, planning, playing }

class VillageHome extends StatefulWidget {
  const VillageHome({super.key, required this.test});
  final SelfTest test;

  @override
  State<VillageHome> createState() => VillageHomeState();
}

class VillageHomeState extends State<VillageHome> {
  final VillageStage stage = VillageStage();
  final ValueNotifier<int> frame = ValueNotifier(0);
  final ValueNotifier<int> slow = ValueNotifier(0);
  final FocusNode focus = FocusNode();
  late final AppLifecycleListener _lifecycle;

  Phase phase = Phase.loading;
  String label = 'Building the village…';
  double progress = 0.02;
  String? error;
  List<String>? missing;
  ModelConfig? config;
  VillageModels? models;
  Village? village;
  bool _sceneReady = false;
  String modelLabel = '';
  double _wall = 0;
  double _slowAcc = 0;
  double? fps;
  int _fpsFrames = 0;
  double _fpsTime = 0;
  Size _size = Size.zero;
  Future<void>? _shutdown;
  Autoplay? _autoplay;

  // Pointer state.
  Offset? _downAt;
  int _downButtons = 0;
  bool _dragging = false;

  SelfTest get test => widget.test;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onExitRequested: _onExitRequested);
    test.start();
    unawaited(_boot());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    frame.dispose();
    slow.dispose();
    focus.dispose();
    unawaited(shutdown());
    super.dispose();
  }

  // ------------------------------------------------------------ boot

  Future<void> _boot() async {
    final scene = stage.load(const ['Pip', 'Mo', 'June', 'Bramble', 'Clover']).then((_) => _sceneReady = true);
    final cfg = ModelConfig.resolve();
    config = cfg;
    try {
      await scene;
    } catch (e, st) {
      debugPrint('SCENE FAILED: $e\n$st');
      setState(() {
        phase = Phase.failed;
        error = 'The 3D scene failed to load: $e';
      });
      return;
    }
    if (test.canned) {
      await startCanned();
      return;
    }
    if (!cfg.hasRequired) {
      test.log('MODELS missing ${cfg.missing.join(', ')}');
      setState(() {
        phase = Phase.missing;
        missing = cfg.missing;
        label =
            'Looked in ${cfg.searched.first}. Set VILLAGE_CHAT_MODEL and VILLAGE_EMBED_MODEL (or VILLAGE_MODELS_DIR), '
            'or put the same keys in ${ModelConfig.configPath}.';
      });
      return;
    }
    try {
      final watch = Stopwatch()..start();
      final m = await VillageModels.load(
        cfg,
        onProgress: (l, f) {
          if (mounted) {
            setState(() {
              label = l;
              progress = f;
            });
          }
        },
      );
      if (_shutdown != null) {
        await m.dispose();
        return;
      }
      models = m;
      modelLabel = m.description;
      test.log('MODELS loaded in ${watch.elapsedMilliseconds} ms: ${m.description}');
      await _start(
        Village(
          chat: m,
          embed: m,
          laya: m.hasLaya ? m : null,
          seed: test.seed ?? DateTime.now().millisecondsSinceEpoch,
          msPerMinute: test.msPerMinute ?? 500,
        ),
      );
    } catch (e, st) {
      debugPrint('MODELS FAILED: $e\n$st');
      if (mounted) {
        setState(() {
          phase = Phase.failed;
          error = '$e';
        });
      }
    }
  }

  Future<void> startCanned() async {
    modelLabel = 'canned lines (no AI)';
    await _start(
      Village(
        chat: CannedChat(delay: const Duration(milliseconds: 250)),
        embed: HashEmbed(),
        seed: test.seed ?? 11,
        msPerMinute: test.msPerMinute ?? 500,
      ),
    );
  }

  Future<void> _start(Village v) async {
    setState(() {
      village = v;
      phase = Phase.planning;
      label = 'The llamas are planning their day…';
      progress = 0.92;
    });
    test.generating = () => v.chat.queue.busy;
    final watch = Stopwatch()..start();
    await v.begin();
    test.log('PLANS ready in ${watch.elapsedMilliseconds} ms');
    if (!mounted) return;
    setState(() => phase = Phase.playing);
    focus.requestFocus();
    if (test.autoplay) _autoplay = Autoplay(this)..start();
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
    village?.close();
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

  void _tick(double dt) {
    final v = village;
    _wall += dt;
    _fpsFrames++;
    _fpsTime += dt;
    if (_fpsTime >= 1) {
      fps = _fpsFrames / _fpsTime;
      _fpsFrames = 0;
      _fpsTime = 0;
    }
    if (v == null || !_sceneReady) return;
    final step = math.min(dt, 0.1);
    final watch = Stopwatch()..start();
    if (phase == Phase.playing) {
      _steer(v);
      v.advance(step * 1000);
    }
    final simDone = watch.elapsedMicroseconds;
    stage.update(v, step);
    if (test.capture) {
      test.simMs.add(simDone / 1000);
      test.sceneMs.add((watch.elapsedMicroseconds - simDone) / 1000);
    }
    test.frame();
    _autoplay?.tick(dt);
    frame.value++;
    _slowAcc += dt;
    if (_slowAcc > 0.25) {
      _slowAcc = 0;
      slow.value++;
    }
  }

  void _steer(Village v) {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    var f = 0.0, r = 0.0;
    if (keys.contains(LogicalKeyboardKey.keyW)) f += 1;
    if (keys.contains(LogicalKeyboardKey.keyS)) f -= 1;
    if (keys.contains(LogicalKeyboardKey.keyD)) r += 1;
    if (keys.contains(LogicalKeyboardKey.keyA)) r -= 1;
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
    if (v == null || phase != Phase.playing) return;
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

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final v = village;
    if (v == null) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final visit = v.dash.visit;
    if (k == LogicalKeyboardKey.space) {
      togglePause();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      if (visit != null) {
        v.dash.leave();
      } else {
        select(null);
      }
      return KeyEventResult.handled;
    }
    final digit = switch (k) {
      LogicalKeyboardKey.digit1 => 1,
      LogicalKeyboardKey.digit2 => 2,
      LogicalKeyboardKey.digit3 => 3,
      LogicalKeyboardKey.digit4 => 4,
      _ => 0,
    };
    if (digit > 0 && visit?.stage == VisitStage.choosing) {
      choose(digit - 1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyF) {
      follow();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyO) {
      stage.rig.overview();
      setState(() {});
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyQ || k == LogicalKeyboardKey.keyE) {
      stage.rig.yaw += k == LogicalKeyboardKey.keyQ ? 0.35 : -0.35;
      return KeyEventResult.handled;
    }
    if ({LogicalKeyboardKey.keyW, LogicalKeyboardKey.keyA, LogicalKeyboardKey.keyS, LogicalKeyboardKey.keyD}.contains(k)) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2B3A67),
      child: Focus(
        focusNode: focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: RepaintBoundary(
          key: test.boundaryKey,
          child: LayoutBuilder(
            builder: (context, box) {
              _size = box.biggest;
              return Stack(
                fit: StackFit.expand,
                children: [
                  _sceneLayer(),
                  if (phase == Phase.playing && village != null) ..._overlay(village!),
                  if (phase != Phase.playing)
                    LoadingCard(
                      label: label,
                      progress: progress,
                      missing: phase == Phase.missing ? missing : null,
                      error: phase == Phase.failed ? error : null,
                      onCanned: phase == Phase.missing || phase == Phase.failed && _sceneReady ? startCanned : null,
                      onQuit: phase == Phase.missing || phase == Phase.failed ? quit : null,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

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
      if (start == null) return;
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
      if (e is PointerScrollEvent) stage.rig.zoom(math.pow(1.0015, e.scrollDelta.dy).toDouble());
    },
    onPointerPanZoomUpdate: (e) {
      stage.rig.pan(e.panDelta.dx, e.panDelta.dy);
      if (e.scale != 1) stage.rig.zoom(1 / math.pow(e.scale, 0.08).toDouble());
    },
    child: SceneView(stage.scene, onTick: (elapsed, dt) => _tick(dt), cameraBuilder: (_) => stage.rig.camera()),
  );

  List<Widget> _overlay(Village v) => [
    ValueListenableBuilder<int>(
      valueListenable: frame,
      builder: (context, _, _) => BubbleLayer(village: v, stage: stage, size: _size, wall: _wall),
    ),
    Positioned(
      top: 14,
      left: 14,
      child: ValueListenableBuilder<int>(
        valueListenable: slow,
        builder: (context, _, _) => TopBar(
          village: v,
          fps: fps,
          onPause: togglePause,
          onSpeed: setSpeed,
          onOverview: () => setState(stage.rig.overview),
          onFollow: follow,
          followName: stage.rig.followName,
          modelLabel: modelLabel,
        ),
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
          builder: (context, _, _) =>
              Inspector(data: v.inspect(stage.selected!), cast: v.cast, onClose: () => select(null), onTalk: () => talkTo(stage.selected!)),
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
            return OptionsPanel(visit: visit, onChoose: choose, onMore: v.dash.sayMore, onLeave: v.dash.leave);
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
            final n = v.dash.notice ?? (v.paused ? 'Paused' : null);
            return n == null ? const SizedBox.shrink() : Notice(text: n);
          },
        ),
      ),
    ),
  ];
}

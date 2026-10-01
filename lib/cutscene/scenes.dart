import 'dart:math' as math;

import 'package:vector_math/vector_math.dart' as vm;

import '../render/stage.dart';
import '../sim/cast.dart';
import '../sim/clock.dart';
import '../sim/endings.dart';
import '../sim/geo.dart';
import '../sim/influence.dart';
import '../sim/model.dart';
import '../sim/places.dart';
import '../sim/village.dart';
import '../sim/week.dart';
import 'timeline.dart';

/// Positions and poses the scene scripts need from the village and stage.
class SceneContext {
  SceneContext(this.v, this.stage);
  final Village v;
  final VillageStage stage;

  /// Where the camera is now, so a scene starts from the player's view.
  CameraPose get current {
    final o = stage.rig.override;
    return o != null
        ? CameraPose(o.position.clone(), o.target.clone(), fov: o.fovRadiansY)
        : CameraPose(stage.rig.orbitEye.clone(), stage.rig.orbitTarget.clone(), fov: CameraRig.fov);
  }

  vm.Vector3 ground(P2 p) => vm.Vector3(p.$1, groundHeight(p.$1, p.$2), p.$2);
  vm.Vector3 place(String name) => ground(placeAnchor(name));
  vm.Vector3 llama(String name) => stage.llamas[name]?.position.clone() ?? place(hutOf(name));

  vm.Vector3 facing(String name) {
    final (x, z) = placeFacing(name);
    return vm.Vector3(x, 0, z);
  }

  /// A shot of [subject] from [dir] (horizontal), [dist] metres back and
  /// [up] metres higher, looking [aim] metres above it.
  CameraPose shot(vm.Vector3 subject, vm.Vector3 dir, {double dist = 9, double up = 3, double aim = 1.4, double fov = defaultFov}) {
    final d = vm.Vector3(dir.x, 0, dir.z)..normalize();
    return CameraPose(subject + d * dist + vm.Vector3(0, up, 0), subject + vm.Vector3(0, aim, 0), fov: fov);
  }

  /// The direction from the village square toward [p], for shots from outside.
  vm.Vector3 outward(vm.Vector3 p) {
    final d = vm.Vector3(p.x, 0, p.z + 5);
    return d.length2 < 1e-6 ? vm.Vector3(0, 0, 1) : d.normalized();
  }

  Future<String> line(String type, String prompt, {required String fallback, int maxTokens = 48}) => v.chat.text<String>(
    type,
    Priority.dashReply,
    prompt,
    parse: (raw) {
      final l = raw.split('\n').map((s) => cleanLine(s)).firstWhere((s) => s.split(' ').length >= 3, orElse: () => '');
      return l.isEmpty || l.length > 160 ? null : l;
    },
    fallback: () => fallback,
    maxTokens: maxTokens,
    seed: v.rng.nextInt(1 << 30),
  );
}

const List<Ramp> _barsIn = [Ramp(0, 0.8, 0, 1)];

List<Ramp> _bars(double end) => [..._barsIn, Ramp(end - 1, 0.8, 1, 0)];

/// The night skip: sunset, hut lights going out one by one, the moon
/// crossing, each llama's evening reflection as a dream bubble over its hut,
/// then dawn and a "Day N" card. [startNight] runs the sim clock through
/// the night underneath; [startDawn] takes it to 06:00 (it may wait for
/// the plans), and the dawn shot holds on [dawnReady].
Cutscene nightSkipScene(
  SceneContext c, {
  required int nextDay,
  required void Function() startNight,
  required void Function() startDawn,
  required bool Function() dawnReady,
  required Future<String> Function(Llama l) dream,
}) {
  final v = c.v;
  // The sky starts from sunset whatever the clock says, so the sun is seen to go down.
  final start = (v.now.minute < 6 * 60 ? v.now.minute + 1440 : v.now.minute) / 60;
  final fromHour = math.min(start, 19.9);
  const per = 3.4, dreams = 7.0;
  final dawn = dreams + v.cast.length * per;
  final end = dawn + 8.5;
  final centre = vm.Vector3(0, 0, -5);
  double hourAt(double t) {
    if (t < 4) return fromHour + (21.0 - fromHour) * applyEase(Ease.inOut, t / 4);
    if (t < 6.5) return 21.0 + 2.3 * applyEase(Ease.inOut, (t - 4) / 2.5);
    if (t < dawn) return (23.3 + (24 + 4.9 - 23.3) * ((t - 6.5) / (dawn - 6.5))) % 24;
    return 4.9 + (6.7 - 4.9) * applyEase(Ease.inOut, (t - dawn) / 4);
  }

  final keys = <CameraKey>[
    CameraKey(0, c.current),
    // Low and looking west, so the setting sun is in frame over the village.
    CameraKey(2.5, CameraPose(vm.Vector3(40, 9, 14), vm.Vector3(-20, 8, -4), fov: 0.66)),
    CameraKey(5.8, CameraPose(vm.Vector3(36, 10, 12), vm.Vector3(-20, 7, -4), fov: 0.66), ease: Ease.linear),
  ];
  final texts = <TextCue>[];
  final cues = <Cue>[Cue(0, startNight, label: 'night'), Cue(dawn, startDawn, label: 'dawn')];
  for (var i = 0; i < v.cast.length; i++) {
    final l = v.cast[i];
    final hut = c.place(l.home);
    cues.add(Cue(4.4 + i * 0.4, () => c.stage.lightsOut.add(l.name), label: 'lights ${l.name}'));
    final t = dreams + i * per;
    keys
      ..add(CameraKey(t, c.shot(hut, c.outward(hut) + vm.Vector3(0.4, 0, 0), dist: 19, up: 6, aim: 4.6)))
      ..add(CameraKey(t + per - 0.6, c.shot(hut, c.outward(hut) + vm.Vector3(0.2, 0, 0), dist: 17, up: 5.5, aim: 4.8), ease: Ease.linear));
    texts.add(
      TextCue(
        t + 0.3,
        per - 0.5,
        kind: TextKind.dream,
        speaker: l.name,
        anchor: hut + vm.Vector3(0, 5.6, 0),
        future: dream(l),
        hold: true,
        maxWait: 8,
        fallback: 'Zzz…',
      ),
    );
  }
  keys
    ..add(CameraKey(dawn + 1.5, CameraPose(vm.Vector3(-44, 16, 12), centre + vm.Vector3(16, 4, -2), fov: 0.6)))
    ..add(CameraKey(end, CameraPose(vm.Vector3(-36, 13, 9), centre + vm.Vector3(16, 5, -2), fov: 0.6), ease: Ease.linear));
  texts.add(TextCue(dawn + 3, 4.5, kind: TextKind.title, text: 'Day $nextDay', subtitle: _dayLine(nextDay)));
  return Cutscene(
    name: 'night',
    duration: end,
    camera: keys,
    letterbox: _bars(end),
    texts: texts,
    cues: cues,
    holds: [Hold(dawn + 2, dawnReady, maxWait: 60, label: 'plans')],
    onFrame: (t) => c.stage.hourOverride = hourAt(t),
  );
}

String _dayLine(int day) => day == festivalDay ? 'The Berry Festival is today at 16:00' : dayLabel(day).replaceFirst('the day', 'The day');

/// Day 1, 07:00: Clover rings her bell and announces the festival.
Cutscene announcementScene(SceneContext c) {
  final clover = c.llama('Clover'), pip = c.llama('Pip');
  final side = c.outward(clover) + vm.Vector3(0.5, 0, 0.3);
  final prompt = [
    'You are Clover, the festival organiser (bossy, ambitious, playful). It is the morning of day 1 of festival week.',
    'Ring your bell and announce to the whole village: the Berry Festival is on day $festivalDay at 16:00 on the hilltop, '
        'and the best singer wins the Golden Bell.',
    'Write only what Clover shouts: one or two short sentences, under 30 words. No quotes, no name prefix.',
  ].join('\n');
  const end = 15.0;
  return Cutscene(
    name: 'announcement',
    duration: end,
    camera: [
      CameraKey(0, c.current),
      CameraKey(2.2, c.shot(clover, side, dist: 8, up: 2.2)),
      CameraKey(6.8, c.shot(clover, side, dist: 6.5, up: 1.8), ease: Ease.linear),
      CameraKey(8, c.shot(pip, c.outward(pip), dist: 7, up: 2)),
      CameraKey(10.6, c.shot(pip, c.outward(pip), dist: 6, up: 1.8), ease: Ease.linear),
      CameraKey(12.5, CameraPose(vm.Vector3(1, 42, 46), vm.Vector3(2, 2, -14), fov: 0.5)),
    ],
    letterbox: _bars(end),
    texts: [
      TextCue(
        2.4,
        4.4,
        speaker: 'Clover',
        future: c.line(
          'announcement',
          prompt,
          fallback: 'Hear ye! The Berry Festival is on day $festivalDay at 16:00 on the hilltop. Best singer wins the Golden Bell!',
        ),
        hold: true,
        maxWait: 10,
      ),
      TextCue(8.2, 2.6, speaker: 'Pip', text: 'Me! Put my name down first. The Golden Bell is mine!'),
      TextCue(11.2, 3.4, kind: TextKind.title, text: 'The Berry Festival', subtitle: 'Day $festivalDay · 16:00 · on the hilltop'),
    ],
  );
}

/// Day 5, 16:00: the stage, each contestant's turn, and the winner.
/// [judge] runs the sim on to the judging; the winner is read after it.
Cutscene festivalScene(SceneContext c, {required void Function() judge}) {
  final v = c.v;
  final hill = c.place('hilltop');
  final front = c.facing('hilltop');
  final performances = [...v.festival.performances];
  const per = 4.6;
  final judgeAt = 4.5 + performances.length * per;
  final end = judgeAt + 6;
  final winnerTitle = TextCue(judgeAt + 1.2, 4.2, kind: TextKind.title, text: '…');
  final keys = <CameraKey>[
    CameraKey(0, c.current),
    CameraKey(2.5, c.shot(hill + front * 3, front + vm.Vector3(0.5, 0, 0), dist: 17, up: 6, aim: 2)),
    CameraKey(4.2, c.shot(hill + front * 3, front + vm.Vector3(0.3, 0, 0), dist: 15, up: 5, aim: 2), ease: Ease.linear),
  ];
  final texts = <TextCue>[
    TextCue(0.8, 3.2, kind: TextKind.title, text: 'The Berry Festival', subtitle: 'Lanterns, berry tarts and a wobbly stage'),
  ];
  final shakes = <Shake>[];
  for (var i = 0; i < performances.length; i++) {
    final (name, what) = performances[i];
    final at = 4.5 + i * per;
    final p = c.llama(name);
    keys
      ..add(CameraKey(at + 0.6, c.shot(p, front + vm.Vector3(0.6, 0, 0), dist: 6.5, up: 1.6)))
      ..add(CameraKey(at + per - 0.2, c.shot(p, front + vm.Vector3(0.3, 0, 0), dist: 5.5, up: 1.4), ease: Ease.linear));
    texts.add(TextCue(at + 0.6, per - 0.8, speaker: name, text: what));
    if (what.contains('faints')) shakes.add(Shake(at + 1.6, 1.2, 0.25));
    if (!what.contains('faints')) {
      texts.add(
        TextCue(
          at + 1.2,
          per - 1.6,
          kind: TextKind.song,
          speaker: name,
          anchor: p + vm.Vector3(0, 3.1, 0),
          future: c.line(
            'song',
            'Write one line of the song ${name == 'Pip' ? 'Pip sings (very off-key)' : '$name sings'} at the Berry Festival, '
                'about berries or the valley. Under 12 words, no quotes.',
            fallback: 'Oh, the berries on the hill are sweet as summer...',
            maxTokens: 24,
          ),
          fallback: 'La la laaa...',
        ),
      );
    }
  }
  keys.add(
    CameraKey.lazy(judgeAt + 1, () {
      final w = v.festival.winner;
      return w == null
          ? c.shot(hill + front * 3, front, dist: 12, up: 4, aim: 2)
          : c.shot(c.llama(w), front + vm.Vector3(-0.4, 0, 0), dist: 6, up: 1.5, aim: 1.6);
    }),
  );
  keys.add(
    CameraKey.lazy(end, () {
      final w = v.festival.winner;
      return w == null
          ? c.shot(hill + front * 3, front, dist: 14, up: 6, aim: 2)
          : c.shot(c.llama(w), front + vm.Vector3(-0.2, 0, 0), dist: 7.5, up: 2.4, aim: 1.6);
    }, ease: Ease.linear),
  );
  texts.add(winnerTitle);
  return Cutscene(
    name: 'festival',
    duration: end,
    camera: keys,
    letterbox: _bars(end + 1),
    texts: texts,
    shakes: shakes,
    cues: [
      Cue(judgeAt, () {
        judge();
        final w = v.festival.winner;
        winnerTitle.text = w == null ? 'Nobody wins the Golden Bell' : '$w wins the Golden Bell!';
      }, label: 'judge'),
    ],
  );
}

/// The closing scene for [verdict], over the hilltop, the village or the pond.
Cutscene endingScene(SceneContext c, EndingVerdict verdict, Influence i) {
  final v = c.v;
  final info = endingInfo[verdict.ending]!;
  const end = 17.0;
  final hill = c.place('hilltop'), front = c.facing('hilltop');
  final pond = c.place('pond');
  switch (verdict.ending) {
    case Ending.harmonyFestival:
      final lines = [
        'The lanterns came on, one by one, all the way up the hill.',
        if (i.pipMo == PipMoArc.reconciled) 'Pip and Mo shared the last berry tart, and the scarf, for a while.',
        if (i.bramble == BrambleArc.accepted) 'June read Bramble\'s poems out loud, and did not mind who heard.',
        if (i.pipMo != PipMoArc.reconciled && i.bramble != BrambleArc.accepted)
          'Not one rumour was left standing. Everyone sang the last song.',
        'And a small blue bird fell asleep in the bunting.',
      ];
      return Cutscene(
        name: 'ending',
        duration: end,
        camera: [
          CameraKey(0, c.current),
          CameraKey(2, c.shot(hill + front * 3, front + vm.Vector3(0.4, 0, 0), dist: 9, up: 2.2, aim: 1.8)),
          CameraKey(end - 3, c.shot(hill, front + vm.Vector3(0.9, 0, 0), dist: 46, up: 30, aim: 0, fov: 0.6), ease: Ease.inOut),
          CameraKey(end, c.shot(hill, front + vm.Vector3(1, 0, 0), dist: 50, up: 33, aim: 0, fov: 0.6), ease: Ease.linear),
        ],
        letterbox: _bars(end + 1),
        texts: [
          for (var k = 0; k < lines.length; k++) TextCue(1.6 + k * 3.2, 3.0, text: lines[k]),
          TextCue(end - 3.6, 3.6, kind: TextKind.title, text: info.title, subtitle: 'Ending'),
        ],
        onFrame: (t) => c.stage.hourOverride = 17.5 + (20.9 - 17.5) * applyEase(Ease.inOut, t / 6),
      );
    case Ending.dramaLlama:
      final names = llamaNames;
      final lines = [
        'By sunset, nobody was speaking to anybody.',
        ...verdict.reasons.take(2).map((r) => '${r[0].toUpperCase()}${r.substring(1)}.'),
        'Somewhere, a little blue bird whistled innocently.',
      ];
      final keys = <CameraKey>[CameraKey(0, c.current)];
      for (var k = 0; k < names.length; k++) {
        final p = c.llama(names[k]);
        // Quick close-ups from the audience side, alternating left and right.
        final side = vm.Vector3(k.isEven ? 0.55 : -0.55, 0, 0);
        keys
          ..add(CameraKey(1.2 + k * 2.4, c.shot(p, front + side, dist: 6.8, up: 1.7, aim: 1.6, fov: 0.48), ease: Ease.out))
          ..add(CameraKey(3.2 + k * 2.4, c.shot(p, front + side * 0.8, dist: 6.0, up: 1.5, aim: 1.6, fov: 0.46), ease: Ease.linear));
      }
      keys.add(CameraKey(end, c.shot(hill, front + vm.Vector3(0.8, 0, 0), dist: 34, up: 20, aim: 1, fov: 0.6)));
      return Cutscene(
        name: 'ending',
        duration: end,
        camera: keys,
        letterbox: _bars(end + 1),
        shakes: const [Shake(1.4, 0.6, 0.18), Shake(6.2, 0.6, 0.18), Shake(11, 0.8, 0.25)],
        texts: [
          for (var k = 0; k < lines.length; k++) TextCue(1.4 + k * 3.2, 3.0, text: lines[k]),
          TextCue(end - 3.6, 3.6, kind: TextKind.title, text: info.title, subtitle: 'Ending'),
        ],
        cues: [Cue(0.2, () => v.storm = true, label: 'thunder')],
        onFrame: (t) => c.stage.hourOverride = 18.4 + 1.4 * (t / end),
      );
    case Ending.quietValley:
      final lines = [
        'The festival came and went, the way festivals do.',
        'Mo baked. June picked berries. Bramble watched the clouds.',
        'The valley kept its secrets, and its peace.',
      ];
      final across = c.facing('pond');
      return Cutscene(
        name: 'ending',
        duration: end,
        camera: [
          CameraKey(0, c.current),
          // From the far shore, the pond in front and the village beyond.
          CameraKey(3, c.shot(pond, -across + vm.Vector3(0.3, 0, 0.3), dist: 15, up: 4.5, aim: 1.5, fov: 0.6)),
          CameraKey(end, c.shot(pond, -across + vm.Vector3(-0.3, 0, 0.3), dist: 17, up: 6, aim: 1.5, fov: 0.6), ease: Ease.linear),
        ],
        letterbox: _bars(end + 1),
        texts: [
          for (var k = 0; k < lines.length; k++) TextCue(2 + k * 3.6, 3.4, text: lines[k]),
          TextCue(end - 3.6, 3.6, kind: TextKind.title, text: info.title, subtitle: 'Ending'),
        ],
        onFrame: (t) => c.stage.hourOverride = 18.2 + 1.2 * (t / end),
      );
  }
}

/// [l]'s reflection on the evening of [day], written at 22:00 on the model
/// queue. Polls until it lands; gives up (empty) after [timeout].
Future<String> reflectionOf(Llama l, int day, {Duration timeout = const Duration(seconds: 40)}) async {
  final watch = Stopwatch()..start();
  while (l.reflectedDay < day) {
    if (watch.elapsed > timeout) return '';
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return l.reflections.last;
}

/// The night skip is due: night, and everyone asleep or past 22:00.
bool nightDue(Village v) =>
    v.started &&
    !v.paused &&
    !v.weekOver &&
    v.isNight &&
    (v.cast.every((l) => l.asleep) || v.now.minute >= 22 * 60 || v.now.minute < 6 * 60);

/// The morning after the current night.
GameTime dawnAfter(GameTime now) => GameTime(now.minute < 6 * 60 ? now.day : now.day + 1, 6 * 60);

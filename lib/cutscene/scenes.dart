import 'dart:math' as math;

import 'package:vector_math/vector_math.dart' as vm;

import '../l10n/app_localizations.dart';
import '../render/stage.dart';
import '../sim/cast.dart';
import '../sim/clock.dart';
import '../sim/endings.dart';
import '../sim/geo.dart';
import '../sim/influence.dart';
import '../sim/lang.dart';
import '../sim/model.dart';
import '../sim/places.dart';
import '../sim/village.dart';
import '../sim/week.dart';
import '../ui/strings.dart';
import 'festival_show.dart';
import 'timeline.dart';

/// Positions and poses the scene scripts need from the village and stage.
class SceneContext {
  SceneContext(this.v, this.stage, this._strings);
  final Village v;
  final VillageStage stage;
  final L10n Function() _strings;

  /// The words for captions and titles, in the player's language now.
  L10n get l => _strings();

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
    maxTokens: tokensFor(v.lang, maxTokens),
    seed: v.rng.nextInt(1 << 30),
    lang: v.lang,
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
        fallback: c.l.dreamFallback,
      ),
    );
  }
  keys
    ..add(CameraKey(dawn + 1.5, CameraPose(vm.Vector3(-44, 16, 12), centre + vm.Vector3(16, 4, -2), fov: 0.6)))
    ..add(CameraKey(end, CameraPose(vm.Vector3(-36, 13, 9), centre + vm.Vector3(16, 5, -2), fov: 0.6), ease: Ease.linear));
  texts.add(TextCue(dawn + 3, 4.5, kind: TextKind.title, text: c.l.dayTitle(nextDay), subtitle: c.l.dayCardLine(nextDay)));
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

/// Day 1, 07:00: Clover rings her bell and announces the festival.
Cutscene announcementScene(SceneContext c) {
  final clover = c.llama('Clover'), pip = c.llama('Pip');
  final side = c.outward(clover) + vm.Vector3(0.5, 0, 0.3);
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
        future: c.line('announcement', announcementPrompt(c.v.lang), fallback: c.l.announcementFallback(festivalDay)),
        hold: true,
        maxWait: 10,
      ),
      TextCue(8.2, 2.6, speaker: 'Pip', text: c.l.pipSignsUp),
      TextCue(11.2, 3.4, kind: TextKind.title, text: c.l.berryFestival, subtitle: c.l.festivalWhen(festivalDay)),
    ],
  );
}

/// The festival show on the llamas and the stage props: everyone posed
/// for a moment of [show], the winner once the judging names one.
class FestivalStaging {
  FestivalStaging(this.c)
    : show = FestivalShow(
        singers: [for (final (name, what) in c.v.festival.performances) (name, what.contains('faints'))],
        present: [
          for (final l in c.v.cast)
            if (l.place == 'hilltop' && c.stage.llamas.containsKey(l.name)) l.name,
        ],
        paces: {for (final l in c.v.cast) l.name: l.walkPace},
      );

  final SceneContext c;
  final FestivalShow show;
  String? winner;
  bool _placed = false;

  /// Where the Golden Bell hangs: above and beside the winner's head.
  vm.Vector3 _bellAt(String name) {
    final a = c.stage.llamas[name]!;
    return a.position + FestivalShow.right * 0.5 + vm.Vector3(0, a.headHeight + 0.62 + 0.05 * math.sin(c.stage.wall * 2.1), 0);
  }

  /// Poses everyone for [t]; the first call puts them in place at once.
  /// With [turnAway] they all turn their backs on the stage, quietly.
  void apply(double t, {bool turnAway = false}) {
    final llamas = c.stage.llamas;
    for (final name in show.cast) {
      final a = llamas[name]!;
      final p = show.pose(name, t, winner: winner);
      final look = p.look == null ? null : llamas[p.look]?.headWorld;
      final yaw = turnAway ? math.atan2(-FestivalShow.front.x, -FestivalShow.front.z) : p.yaw;
      a
        ..staged = (x: p.at.$1, z: p.at.$2, yaw: yaw, look: turnAway ? null : look)
        ..lift = p.lift
        ..singing = p.sing
        ..cheering = turnAway ? 0 : p.cheer
        ..fainted = p.faint;
      if (!_placed) a.snap();
    }
    _placed = true;
    final props = c.stage.festival;
    props.spotlight(show.spotlight(t, winner), FestivalShow.centre, FestivalShow.front);
    final w = winner;
    final bell = show.bell(t, w);
    // Pops in a little past full size and settles (an ease-out-back).
    final scale = bell <= 0 ? 0.0 : 1 + 2.7 * math.pow(bell - 1, 3) + 1.7 * math.pow(bell - 1, 2);
    props.bell(w == null ? 0 : scale, w == null ? FestivalShow.centre : _bellAt(w), FestivalShow.front, 0.2 * math.sin(c.stage.wall * 2.6));
  }
}

/// Day 5, 16:00: the festival as a staged show (see [FestivalShow]): the
/// singers' turns at centre stage, the judging, and the winner stepping
/// into the spotlight for the Golden Bell. [judge] runs the sim on to the
/// judging; the winner is read after it. The sky drifts toward the golden
/// hour, and the festival theme takes over the music with the title.
Cutscene festivalScene(SceneContext c, FestivalStaging staging, {required void Function() judge}) {
  final v = c.v;
  final show = staging.show;
  final end = show.end;
  final centre = FestivalShow.centre, front = FestivalShow.front;
  final fromHour = (v.now.minute + v.minuteFrac) / 60;
  const stage = FestivalShow.shot;
  final reverse = FestivalShow.crowdShot;
  final winnerTitle = TextCue(show.judgeAt + 0.3, FestivalShow.verdictSeconds, kind: TextKind.title, text: '…');
  final keys = <CameraKey>[
    CameraKey(0, c.current),
    CameraKey(2.5, stage(0.5, 17, 6, aim: 1)),
    CameraKey(FestivalShow.audienceIn - 0.1, stage(0.4, 15, 5.2, aim: 1.1), ease: Ease.linear),
  ];
  final texts = <TextCue>[TextCue(0.8, 3.2, kind: TextKind.title, text: c.l.berryFestival, subtitle: c.l.festivalSubtitle)];
  final notes = <NoteCue>[];
  final shakes = <Shake>[];
  final cues = <Cue>[];
  // The first song ends on the crowd's faces as they cheer.
  final crowd = show.turns.firstOrNull?.faints == false ? show.turns.first : null;
  var cameraFree = 0.0;
  for (final (i, turn) in show.turns.indexed) {
    final name = turn.name;
    final side = FestivalShow.sideOf(i);
    final close = FestivalShow.closeUp(i), closer = FestivalShow.closeUp(i, closer: true);
    // Watching the next singer step up, unless the crowd shot still has the camera.
    if (turn.walkOn + 0.5 > cameraFree) keys.add(CameraKey(turn.walkOn + 0.5, stage(0.45 * side, 10, 3.2)));
    if (turn.arrive - 0.1 > cameraFree) keys.add(CameraKey(turn.arrive - 0.1, stage(0.42 * side, 9.2, 3), ease: Ease.linear));
    keys.add(CameraKey(math.max(turn.arrive + 0.6, cameraFree + 0.6), close));
    if (turn == crowd) {
      final cut = turn.singFrom + 2.6, back = turn.singTo + 0.9;
      cameraFree = back + 0.1;
      keys
        ..add(CameraKey(cut, close.lerp(closer, (cut - turn.arrive - 0.6) / (turn.singTo - turn.arrive - 0.6)), ease: Ease.linear))
        ..add(CameraKey(cut + 0.02, reverse, ease: Ease.linear))
        ..add(CameraKey(back, CameraPose(reverse.eye + front * 0.5, reverse.target, fov: reverse.fov), ease: Ease.linear))
        ..add(CameraKey(back + 0.02, stage(0.4 * side, 10.5, 3.4), ease: Ease.linear));
    } else {
      keys.add(
        CameraKey(turn.singTo, turn.faints ? stage(0.35 * side, 6.4, 2.6, aim: 1.1) : closer, ease: turn.faints ? Ease.inOut : Ease.linear),
      );
    }
    final shown = name == 'Pip'
        ? c.l.pipSings
        : turn.faints
        ? c.l.moFaints
        : name == 'Mo'
        ? c.l.moSings
        : c.l.llamaSings(name);
    texts.add(TextCue(turn.singFrom - 0.3, FestivalShow.singSeconds + 0.1, speaker: name, text: shown));
    final head = c.stage.llamas[name]?.headHeight ?? 2;
    notes.add(
      NoteCue(
        turn.singFrom + 0.1,
        turn.faints ? FestivalShow.faintFall * 0.45 : FestivalShow.singSeconds - 0.4,
        anchor: () => (c.stage.llamas[name]?.headWorld ?? centre) + vm.Vector3(0, 0.3, 0),
        speaker: name,
      ),
    );
    if (turn.faints) {
      shakes.add(Shake(turn.faintAt - 0.05, 1.0, 0.22));
      cues.add(
        Cue(turn.faintAt, () {
          for (final n in show.cast) {
            if (n != name) c.stage.llamas[n]?.react('surprise');
          }
        }, label: 'gasp'),
      );
      continue;
    }
    // Beside the singer's head, on the far side from the camera, and off
    // screen while the camera looks at the crowd.
    final from = turn.singFrom + 0.3, to = turn == crowd ? turn.singFrom + 2.5 : turn.singTo - 0.3;
    texts.add(
      TextCue(
        from,
        to - from,
        kind: TextKind.song,
        speaker: name,
        anchor: centre - FestivalShow.right * (1.25 * side) + vm.Vector3(0, head + 0.35, 0),
        future: c.line('song', songPrompt(name, v.lang), fallback: c.l.songFallback, maxTokens: 24),
        fallback: c.l.laLaLa,
      ),
    );
  }
  final last = show.turns.lastOrNull;
  keys.add(
    CameraKey((last?.singTo ?? FestivalShow.audienceIn) + (last != null && last == crowd ? 1.5 : 0.9), stage(-0.3, 11, 3.6, aim: 1.2)),
  );
  keys.add(
    CameraKey.lazy(show.winnerAt - 0.4, () => staging.winner == null ? stage(-0.25, 12, 4, aim: 1.2) : stage(-0.32, 6.6, 3.3, aim: 1.6)),
  );
  keys.add(
    CameraKey.lazy(
      end,
      () => staging.winner == null ? stage(-0.2, 13, 4.5, aim: 1.2) : stage(-0.26, 5.8, 3.0, aim: 1.75),
      ease: Ease.linear,
    ),
  );
  texts.add(winnerTitle);
  cues.add(
    Cue(show.judgeAt, () {
      judge();
      final w = staging.winner = v.festival.winner;
      winnerTitle.text = w == null ? c.l.nobodyWins : c.l.winsBell(w);
    }, label: 'judge'),
  );
  return Cutscene(
    name: 'festival',
    duration: end,
    camera: keys,
    letterbox: _bars(end + 1),
    texts: texts,
    notes: notes,
    shakes: shakes,
    cues: cues,
    music: festivalMusic,
    onFrame: (t) {
      c.stage.hourOverride = fromHour + (festivalSkyHour - fromHour) * (t / end);
      staging.apply(t);
    },
  );
}

/// Where the festival's sky has got to as it ends, and the ending's starts.
const double festivalSkyHour = 17.5;

/// The closing scene for [verdict], over the hilltop, the village or the
/// pond. The festival's last tableau holds on the hilltop ([festival]),
/// and the ending theme takes over the music as the sky goes to dusk.
Cutscene endingScene(SceneContext c, EndingVerdict verdict, Influence i, {FestivalStaging? festival}) {
  final v = c.v;
  final l = c.l;
  final title = l.endingName(verdict.ending);
  const end = 17.0;
  final hill = c.place('hilltop'), front = c.facing('hilltop');
  final pond = c.place('pond');
  switch (verdict.ending) {
    case Ending.harmonyFestival:
      final lines = [
        l.harmonyLanterns,
        if (i.pipMo == PipMoArc.reconciled) l.harmonyPipMo,
        if (i.bramble == BrambleArc.accepted) l.harmonyJune,
        if (i.pipMo != PipMoArc.reconciled && i.bramble != BrambleArc.accepted) l.harmonyNoRumour,
        l.harmonyDash,
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
          TextCue(end - 3.6, 3.6, kind: TextKind.title, text: title, subtitle: l.endingWord),
        ],
        music: endingMusic,
        onFrame: (t) {
          c.stage.hourOverride = festivalSkyHour + (20.9 - festivalSkyHour) * applyEase(Ease.inOut, t / 6);
          festival?.apply(festival.show.end);
        },
      );
    case Ending.dramaLlama:
      final names = llamaNames;
      final lines = [l.dramaSilence, ...verdict.why.take(2).map((r) => _sentence(l.reasonOf(r))), l.dramaWhistle];
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
          TextCue(end - 3.6, 3.6, kind: TextKind.title, text: title, subtitle: l.endingWord),
        ],
        cues: [Cue(0.2, () => v.storm = true, label: 'thunder')],
        music: endingMusic,
        onFrame: (t) {
          c.stage.hourOverride = 18.4 + 1.4 * (t / end);
          festival?.apply(festival.show.end, turnAway: true);
        },
      );
    case Ending.quietValley:
      final lines = [l.quietCame, l.quietWork, l.quietSecrets];
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
          TextCue(end - 3.6, 3.6, kind: TextKind.title, text: title, subtitle: l.endingWord),
        ],
        music: endingMusic,
        onFrame: (t) {
          c.stage.hourOverride = 18.2 + 1.2 * (t / end);
          festival?.apply(festival.show.end);
        },
      );
  }
}

/// The festival loop takes over from the day loop as the title comes up.
const Map<String, List<Ramp>> festivalMusic = {
  'music_festival': [Ramp(0.6, 2.6, 0, 1)],
};

/// The ending theme fades in over the first six seconds, as the harmony
/// ending's sky goes from the golden hour to dusk.
const Map<String, List<Ramp>> endingMusic = {
  'music_ending': [Ramp(0, 6, 0, 1)],
};

/// [s] as a caption: a capital first letter and a full stop.
String _sentence(String s) {
  if (s.isEmpty) return s;
  final t = '${s[0].toUpperCase()}${s.substring(1)}';
  return RegExp(r'[.!?。]$').hasMatch(t) ? t : '$t.';
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

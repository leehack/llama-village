import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../app.dart';
import '../sim/session.dart';

/// Drives a recorded (`VILLAGE_RECORD`) or replayed (`VILLAGE_PLAYBACK`)
/// game from the title screen to the end of the week and out: a new game
/// at once, then the epilogue, the results, every storybook page and the
/// Endings gallery, each on a fixed number of 60 Hz steps so a replay
/// reaches them on the same steps. The bot plays Dash meanwhile. At the
/// end it writes the recording (or logs how faithful the replay was) and
/// quits, unless a cinematic render is still using the app.
class SessionDriver {
  SessionDriver(this.home);
  final VillageHomeState home;

  bool _started = false, _weekLeft = false, _finished = false;
  int _page = 0;
  double _since = 0;

  /// The phase of the post-week tour, for the cinematic shot anchors:
  /// epilogue, results, story, gallery or done.
  String stage = 'play';

  /// Seconds since [stage] last changed.
  double stageTime = 0;

  static const double epilogueHold = 9, resultsHold = 5, pageHold = 4.5, galleryHold = 6;

  void _to(String s) {
    stage = s;
    stageTime = 0;
    _since = 0;
    home.test.log('SESSION stage $s at tick ${home.ticks}');
  }

  void tick(double dt) {
    if (_finished) return;
    _since += dt;
    stageTime += dt;
    switch (home.phase) {
      case Phase.menu:
        if (!_started) {
          if (home.busy == null && home.phaseTime > 0.5) {
            _started = true;
            unawaited(home.newGame());
          }
        } else if (_weekLeft && home.busy == null) {
          if (stage != 'gallery') {
            home.openPage(MenuPage.endings);
            _to('gallery');
          } else if (_since > galleryHold) {
            home.closePage();
            unawaited(_finish());
          }
        }
      case Phase.epilogue:
        if (stage != 'epilogue') _to('epilogue');
        if (home.epilogue.values.every((l) => l != null) && _since > epilogueHold) home.showResults();
      case Phase.results:
        final book = home.book;
        if (home.reading == null) {
          if (stage != 'results' && stage != 'story') _to('results');
          if (stage == 'results' && _since > resultsHold && book != null && book.complete) {
            home.openStory();
            _page = 0;
            _to('story');
          } else if (stage == 'story' && _since > 1) {
            _weekLeft = true;
            unawaited(home.toMenu());
          }
        } else if (_since > pageHold) {
          final view = home.storyKey.currentState;
          if (view == null) return;
          _since = 0;
          if (_page + 1 < view.count) {
            view.turnTo(++_page);
          } else {
            home.closeStory();
          }
        }
      case Phase.playing || Phase.loading || Phase.failed:
        break;
    }
  }

  Future<void> _finish() async {
    _finished = true;
    _to('done');
    await home.saveRecording();
    final r = home.replay;
    if (r != null) {
      home.test.log('REPLAY done: ${r.summary}');
    }
    if (home.cinematicActive) return;
    unawaited(home.quit());
  }
}

/// Writes [recorder]'s session to [path] in one atomic rename.
Future<void> writeSession(SessionRecorder recorder, String path) async {
  final tmp = File('$path.tmp');
  await tmp.writeAsString(jsonEncode(recorder.toJson()));
  await tmp.rename(path);
}

/// Reads a session file written by [writeSession].
SessionReplay readSession(String path) => SessionReplay((jsonDecode(File(path).readAsStringSync()) as Map).cast<String, Object?>());

import 'dart:async';

import '../app.dart';
import '../autoplay.dart';
import '../cutscene/timeline.dart';

/// The env-gated Festival Week script (`VILLAGE_AUTOPLAY=week`): the title
/// screen and gallery, a new game, the pause menu and a manual save, the
/// first night skip watched to the day card (later ones skipped), the
/// festival, the ending, the epilogue and results, the storybook (cover,
/// a page turning, two pages and the ending), then the gallery again.
/// It takes a PNG at each stop; a bot (`VILLAGE_BOT`) plays Dash meanwhile.
class WeekAutoplay {
  WeekAutoplay(this.home);
  final VillageHomeState home;

  int _step = 0;
  double _since = 0;
  double _t = 0;
  int _nights = 0;
  String? _scene;
  bool _paused = false;
  Future<void>? _shooting;

  void start() => home.test.log('WEEK autoplay start');

  bool _taken(String name) => home.test.taken.contains(name);

  void _shot(String name) {
    if (_taken(name)) return;
    _shooting = home.test.shot(name).whenComplete(() => _shooting = null);
  }

  void _next() {
    _step++;
    _since = 0;
  }

  void tick(double dt) {
    _t += dt;
    if (_shooting != null) return;
    _since += dt;
    switch (_step) {
      case 0:
        if (home.phase == Phase.menu && home.busy == null && _since > 4) {
          _shot('01_start_menu');
          _next();
        }
      case 1:
        if (_since > 0.5) {
          home.openPage(MenuPage.endings);
          _next();
        }
      case 2:
        if (_since > 1.2) {
          _shot('02_gallery_before');
          _next();
        }
      case 3:
        if (_since > 0.5) {
          home.openPage(MenuPage.credits);
          _next();
        }
      case 4:
        if (_since > 1.2) {
          _shot('03_credits');
          _next();
        }
      case 5:
        if (_since > 0.5) {
          home.openPage(MenuPage.settings);
          _next();
        }
      case 6:
        if (_since > 1.2) {
          _shot('04_settings');
          _next();
        }
      case 7:
        if (_since > 0.5) {
          home.closePage();
          unawaited(home.newGame());
          _next();
        }
      case 8:
        if (home.phase == Phase.playing) _play();
        if (home.phase == Phase.epilogue) _next();
      case 9:
        final ready = home.epilogue.values.every((l) => l != null);
        if ((ready && _since > 2) || _since > 45) {
          if (!_taken('40_epilogue')) {
            _shot('40_epilogue');
            return;
          }
          final v = home.village;
          if (v != null) logCalls(home.test, v);
          home.showResults();
          _next();
        }
      case 10:
        if (_since > 2) {
          _shot('41_results');
          _next();
        }
      case 11:
        if (_since > 1) {
          home.openStory();
          _next();
        }
      case 12:
        final book = home.book;
        if ((book != null && book.complete && _since > 2) || _since > 180) {
          home.test.log('STORYBOOK ${book?.writtenCount}/${book?.textPages} written after ${_since.toStringAsFixed(0)} s');
          _shot('43_storybook_cover');
          _next();
        }
      case 13:
        if (_since > 0.5) {
          home.storyKey.currentState?.turnTo(1);
          _next();
        }
      case 14:
        if (_since > 0.3) _shot('44a_storybook_turning');
        if (_since > 1.4) {
          _shot('44_storybook_day1');
          _next();
        }
      case 15:
        if (_since > 0.5) {
          home.storyKey.currentState?.turnTo(3);
          _next();
        }
      case 16:
        if (_since > 1.4) {
          _shot('45_storybook_day3');
          _next();
        }
      case 17:
        if (_since > 0.5) {
          final s = home.storyKey.currentState;
          s?.turnTo(s.count - 1);
          _next();
        }
      case 18:
        if (_since > 1.4) {
          _shot('46_storybook_ending');
          _next();
        }
      case 19:
        if (_since > 0.5) {
          home.closeStory();
          _next();
        }
      case 20:
        if (_since > 1) {
          unawaited(home.toMenu());
          _next();
        }
      case 21:
        if (home.phase == Phase.menu && home.busy == null && _since > 1) {
          home.openPage(MenuPage.endings);
          _next();
        }
      case 22:
        if (_since > 1.5) {
          _shot('42_gallery_after');
          _next();
        }
      case 23:
        if (_since > 0.5) {
          home.test.log('WEEK autoplay done in ${_t.toStringAsFixed(0)} s');
          _next();
          if (home.test.exitWhenDone) unawaited(home.quit());
        }
    }
  }

  void _play() {
    final v = home.village;
    final d = home.director;
    if (v == null || d == null) return;
    final p = d.player;
    if (p != null) {
      _cutscene(p);
      return;
    }
    _scene = null;
    if (!_paused && v.now.day == 1 && v.now.minute >= 9 * 60 && v.now.minute < 20 * 60) {
      _paused = true;
      home.openPause();
      unawaited(_pauseShots());
      return;
    }
    if (v.now.day == 2 && v.now.minute >= 11 * 60) _shot('10_day2_play');
  }

  Future<void> _pauseShots() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    await home.test.shot('05_pause_menu');
    await home.saveTo('slot1');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    home.closePause();
  }

  void _cutscene(CutscenePlayer p) {
    final name = p.scene.name;
    if (_scene != name) {
      _scene = name;
      if (name == 'night') _nights++;
    }
    final texts = p.texts;
    bool showing(TextKind kind, {double alpha = 0.95}) => texts.any((t) => t.$1.kind == kind && t.$1.text != null && t.$2 >= alpha);
    switch (name) {
      case 'announcement':
        if (showing(TextKind.subtitle)) _shot('06_announcement');
      case 'night' when _nights == 1:
        if (p.time > 3.2 && p.time < 4.2) _shot('11_night_sunset');
        if (p.time > 5.9 && p.time < 6.6) _shot('11b_night_lights_out');
        if (showing(TextKind.dream) && p.time > 10) _shot('12_night_dream');
        if (showing(TextKind.title)) _shot('13_day_title');
      case 'night':
        if (p.time > 1.5) p.skip();
      case 'festival':
        if (p.time > 6 && showing(TextKind.subtitle) && showing(TextKind.song, alpha: 0.9)) _shot('20_festival');
        if (p.time > 14 && showing(TextKind.subtitle)) _shot('20_festival');
        if (showing(TextKind.title) && home.village!.festival.state == 'judged') _shot('21_festival_winner');
      case 'ending':
        final e = home.director!.verdict!.ending.name;
        if (p.time > 5 && showing(TextKind.subtitle)) _shot('30_ending_$e');
        if (showing(TextKind.title)) _shot('31_ending_${e}_title');
    }
  }
}

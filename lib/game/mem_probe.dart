import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_scene/scene.dart';

import '../app.dart';
import '../sim/village.dart';

/// The env-gated memory log for soak runs (`VILLAGE_MEMLOG=<seconds>`):
/// every few seconds, one `VILLAGE MEM` line with the resident set size and
/// the length of every collection a long session could grow.
class MemProbe {
  MemProbe(this.home, this.every);
  final VillageHomeState home;
  final double every;
  double _acc = 0;
  double _t = 0;

  /// Villages seen by the probe, weakly, to count the ones still alive.
  final List<WeakReference<Village>> _villages = [];

  void tick(double dt) {
    _t += dt;
    _acc += dt;
    if (_acc < every) return;
    _acc = 0;
    home.test.log('MEM ${report().entries.map((e) => '${e.key}=${e.value}').join(' ')}');
  }

  void _see(Village? v) {
    if (v == null || _villages.any((w) => identical(w.target, v))) return;
    _villages.add(WeakReference(v));
  }

  Map<String, Object> report() {
    final v = home.village;
    _see(v);
    _see(home.attract);
    _villages.removeWhere((w) => w.target == null);
    final images = PaintingBinding.instance.imageCache;
    final shots = v?.album.shots ?? const [];
    int pngBytes(Iterable<List<int>?> pngs) => pngs.fold(0, (a, p) => a + (p?.length ?? 0));
    final bookShots = home.books.expand((b) => b.pages.map((p) => p.shot));
    return {
      'epochMs': DateTime.now().millisecondsSinceEpoch,
      't': _t.round(),
      'phase': home.phase.name,
      'game': v == null ? '-' : '${v.now.day}/${v.now.hhmm}',
      'rssMB': ProcessInfo.currentRss >> 20,
      'maxRssMB': ProcessInfo.maxRss >> 20,
      'villagesAlive': _villages.length,
      'journal': v?.journal.beats.length ?? 0,
      'shots': shots.length,
      'shotsKB': pngBytes(shots.map((s) => s.png)) >> 10,
      'bookShotsKB': pngBytes(home.book?.pages.map((p) => p.shot) ?? const []) >> 10,
      'galleryBooks': home.books.length,
      'galleryKB': pngBytes(bookShots) >> 10,
      'diary': v?.cast.fold<int>(0, (a, l) => a + l.diary.length) ?? 0,
      'thoughts': v?.cast.fold<int>(0, (a, l) => a + l.thoughts.length + l.reflections.length) ?? 0,
      'facts': v?.kb.facts.length ?? 0,
      'transfers': v?.kb.transfers.length ?? 0,
      'convActive': v?.active.length ?? 0,
      'convDone': v?.done.length ?? 0,
      'lines': v?.lines.length ?? 0,
      'logEntries': v?.log.entries.length ?? 0,
      'transcriptKB': (v?.log.out.length ?? 0) >> 10,
      'events': v?.events.events.length ?? 0,
      'listeners': v?.events.listeners.length ?? 0,
      'calls': v?.metrics.calls.length ?? 0,
      'embedCache': v?.embed.cache.length ?? 0,
      'speech': v?.speech.length ?? 0,
      'sceneNodes': _count(home.stage.scene.root),
      'imageCache': images.currentSize,
      'imageCacheKB': images.currentSizeBytes >> 10,
      'liveImages': images.liveImageCount,
      'voices': home.audioVoices,
      'models': home.models == null ? 0 : 1,
    };
  }

  static int _count(Node n) => 1 + n.children.fold<int>(0, (a, c) => a + _count(c));
}

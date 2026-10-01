import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../ambient/animal_sounds.dart';
import 'soundscape.dart';

/// [SoundOut] on flutter_soloud: every clip is decoded into memory at
/// start, so loops are sample-exact and effects start with low latency.
class SoloudOut implements SoundOut {
  static const List<String> effects = [
    'flap',
    'chirp',
    'step1',
    'step2',
    'hum',
    'pop',
    'click',
    'sparkle',
    'birds1',
    'birds2',
    'crickets',
    ...AnimalSounds.sounds,
  ];

  final Map<String, AudioSource> _sources = {};
  final Map<String, SoundHandle> _loops = {};
  final Map<String, double> _loopVolume = {};
  bool _ready = false;
  bool _closed = false;

  bool get ready => _ready;

  /// Voices playing in the mixer, plus handles the Dart side still tracks.
  int get voices {
    final soloud = SoLoud.instance;
    if (!_ready || !soloud.isInitialized) return 0;
    return soloud.getActiveVoiceCount() + _sources.values.fold<int>(0, (a, s) => a + s.handles.length);
  }

  /// Starts the engine, loads every clip and starts the loops silent.
  /// Returns false (and stays silent) when there is no audio device.
  Future<bool> init() async {
    final soloud = SoLoud.instance;
    try {
      await soloud.init(sampleRate: 48000, bufferSize: 1024);
      for (final name in [...Soundscape.loops, ...effects]) {
        if (_closed) break;
        _sources[name] = await soloud.loadAsset('assets/audio/$name.ogg');
      }
      // A quit while loading has already run dispose.
      if (_closed) {
        if (soloud.isInitialized) soloud.deinit();
        return false;
      }
      for (final name in Soundscape.loops) {
        _loops[name] = soloud.play(_sources[name]!, volume: 0, looping: true);
      }
      _ready = true;
      return true;
    } catch (e) {
      debugPrint('Llama Village: audio unavailable: $e');
      return false;
    }
  }

  /// Seconds of each loaded loop, to check the decoder kept them sample-exact.
  Map<String, double> loopLengths() => {
    for (final name in Soundscape.loops)
      if (_sources[name] != null) name: SoLoud.instance.getLength(_sources[name]!).inMicroseconds / 1e6,
  };

  set muted(bool value) {
    if (_ready) SoLoud.instance.setGlobalVolume(value ? 0 : 1);
  }

  @override
  void play(String name, {double volume = 1, double speed = 1, double pan = 0}) {
    final source = _sources[name];
    if (!_ready || source == null) return;
    final soloud = SoLoud.instance;
    final handle = soloud.play(source, volume: volume, pan: pan);
    if (speed != 1) soloud.setRelativePlaySpeed(handle, speed);
  }

  @override
  void setLoopVolume(String name, double volume) {
    final handle = _loops[name];
    if (!_ready || handle == null) return;
    if (((_loopVolume[name] ?? -1) - volume).abs() < 0.002) return;
    _loopVolume[name] = volume;
    SoLoud.instance.setVolume(handle, volume);
  }

  /// Stops every voice and shuts the engine down; safe to call twice.
  void dispose() {
    _closed = true;
    _ready = false;
    final soloud = SoLoud.instance;
    if (soloud.isInitialized) soloud.deinit();
  }
}

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Player settings, persisted with shared_preferences.
class VillageSettings extends ChangeNotifier {
  VillageSettings._(this._prefs);

  /// Settings that are never saved, for tests and self-test runs.
  VillageSettings.ephemeral() : _prefs = null;

  static const List<int> fpsChoices = [30, 60, 120];
  static const int defaultFps = 60;
  static const double defaultMusicVolume = 0.5;
  static const double defaultSfxVolume = 0.7;

  final SharedPreferences? _prefs;
  int _fps = defaultFps;
  double _music = defaultMusicVolume;
  double _sfx = defaultSfxVolume;
  bool _muted = false;

  static Future<VillageSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = VillageSettings._(prefs);
    final fps = prefs.getInt('fps');
    if (fps != null && fpsChoices.contains(fps)) s._fps = fps;
    s._music = (prefs.getDouble('musicVolume') ?? defaultMusicVolume).clamp(0.0, 1.0);
    s._sfx = (prefs.getDouble('sfxVolume') ?? defaultSfxVolume).clamp(0.0, 1.0);
    s._muted = prefs.getBool('muted') ?? false;
    return s;
  }

  int get fps => _fps;
  set fps(int value) {
    if (!fpsChoices.contains(value) || value == _fps) return;
    _fps = value;
    _prefs?.setInt('fps', value);
    notifyListeners();
  }

  double get musicVolume => _music;
  set musicVolume(double value) {
    value = value.clamp(0.0, 1.0);
    if (value == _music) return;
    _music = value;
    _prefs?.setDouble('musicVolume', value);
    notifyListeners();
  }

  double get sfxVolume => _sfx;
  set sfxVolume(double value) {
    value = value.clamp(0.0, 1.0);
    if (value == _sfx) return;
    _sfx = value;
    _prefs?.setDouble('sfxVolume', value);
    notifyListeners();
  }

  bool get muted => _muted;
  set muted(bool value) {
    if (value == _muted) return;
    _muted = value;
    _prefs?.setBool('muted', value);
    notifyListeners();
  }
}

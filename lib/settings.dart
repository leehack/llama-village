import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'render/quality.dart';

/// How long speech stays up: [pace] multiplies each bubble's display time.
enum TextSpeed {
  slow(1.5),
  normal(1.0),
  fast(0.7);

  const TextSpeed(this.pace);
  final double pace;
}

/// UI text scale for bubbles, subtitles and cards.
enum TextSize {
  normal(1.0),
  large(1.2),
  larger(1.4);

  const TextSize(this.scale);
  final double scale;
}

/// Player settings, persisted with shared_preferences.
class VillageSettings extends ChangeNotifier {
  VillageSettings._(this._prefs);

  /// Settings that are never saved, for tests and self-test runs.
  VillageSettings.ephemeral() : _prefs = null;

  static const List<int> fpsChoices = [30, 60, 120];
  static const int defaultFps = 60;
  static const double defaultMusicVolume = 0.5;
  static const double defaultSfxVolume = 0.7;
  static const List<int> speedChoices = [1, 2, 4];

  final SharedPreferences? _prefs;
  int _fps = defaultFps;
  double _music = defaultMusicVolume;
  double _sfx = defaultSfxVolume;
  bool _muted = false;
  TextSpeed _textSpeed = TextSpeed.normal;
  int _defaultSpeed = 1;
  TextSize _textSize = TextSize.normal;
  bool _reducedMotion = false;
  bool _highContrast = false;
  GraphicsQuality _quality = GraphicsQuality.high;

  static Future<VillageSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = VillageSettings._(prefs);
    final fps = prefs.getInt('fps');
    if (fps != null && fpsChoices.contains(fps)) s._fps = fps;
    s._music = (prefs.getDouble('musicVolume') ?? defaultMusicVolume).clamp(0.0, 1.0);
    s._sfx = (prefs.getDouble('sfxVolume') ?? defaultSfxVolume).clamp(0.0, 1.0);
    s._muted = prefs.getBool('muted') ?? false;
    s._textSpeed = TextSpeed.values.where((e) => e.name == prefs.getString('textSpeed')).firstOrNull ?? TextSpeed.normal;
    final speed = prefs.getInt('defaultSpeed');
    if (speed != null && speedChoices.contains(speed)) s._defaultSpeed = speed;
    s._textSize = TextSize.values.where((e) => e.name == prefs.getString('textSize')).firstOrNull ?? TextSize.normal;
    s._reducedMotion = prefs.getBool('reducedMotion') ?? false;
    s._highContrast = prefs.getBool('highContrast') ?? false;
    s._quality = GraphicsQuality.parse(prefs.getString('graphicsQuality'));
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

  TextSpeed get textSpeed => _textSpeed;
  set textSpeed(TextSpeed value) {
    if (value == _textSpeed) return;
    _textSpeed = value;
    _prefs?.setString('textSpeed', value.name);
    notifyListeners();
  }

  /// The time speed a new game or a loaded save starts at.
  int get defaultSpeed => _defaultSpeed;
  set defaultSpeed(int value) {
    if (!speedChoices.contains(value) || value == _defaultSpeed) return;
    _defaultSpeed = value;
    _prefs?.setInt('defaultSpeed', value);
    notifyListeners();
  }

  TextSize get textSize => _textSize;
  set textSize(TextSize value) {
    if (value == _textSize) return;
    _textSize = value;
    _prefs?.setString('textSize', value.name);
    notifyListeners();
  }

  /// Shortens camera moves, turns off camera shake, calms the animals and
  /// thins the particles.
  bool get reducedMotion => _reducedMotion;
  set reducedMotion(bool value) {
    if (value == _reducedMotion) return;
    _reducedMotion = value;
    _prefs?.setBool('reducedMotion', value);
    notifyListeners();
  }

  /// Black-on-white speech bubbles with a heavy outline.
  bool get highContrast => _highContrast;
  set highContrast(bool value) {
    if (value == _highContrast) return;
    _highContrast = value;
    _prefs?.setBool('highContrast', value);
    notifyListeners();
  }

  GraphicsQuality get quality => _quality;
  set quality(GraphicsQuality value) {
    if (value == _quality) return;
    _quality = value;
    _prefs?.setString('graphicsQuality', value.name);
    notifyListeners();
  }
}

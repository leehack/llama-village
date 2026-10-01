import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Player settings, persisted with shared_preferences.
class VillageSettings extends ChangeNotifier {
  VillageSettings._(this._prefs);

  /// Settings that are never saved, for tests and self-test runs.
  VillageSettings.ephemeral() : _prefs = null;

  static const List<int> fpsChoices = [30, 60, 120];
  static const int defaultFps = 60;

  final SharedPreferences? _prefs;
  int _fps = defaultFps;

  static Future<VillageSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = VillageSettings._(prefs);
    final fps = prefs.getInt('fps');
    if (fps != null && fpsChoices.contains(fps)) s._fps = fps;
    return s;
  }

  int get fps => _fps;
  set fps(int value) {
    if (!fpsChoices.contains(value) || value == _fps) return;
    _fps = value;
    _prefs?.setInt('fps', value);
    notifyListeners();
  }
}

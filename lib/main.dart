import 'package:flutter/material.dart';

import 'app.dart';
import 'self_test.dart';
import 'settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final test = SelfTest.fromEnvironment();
  final fps = test.fps, language = test.language;
  // A self-test run that forces a setting must not change the player's own.
  final settings = fps != null || language != null ? VillageSettings.ephemeral() : await VillageSettings.load();
  if (fps != null) settings.fps = fps;
  if (language != null) settings.language = language;
  runApp(VillageApp(test: test, settings: settings));
}

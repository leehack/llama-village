import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/render/quality.dart';
import 'package:llama_village/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to 60 fps, music 0.5, effects 0.7, not muted', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await VillageSettings.load();
    expect(s.fps, 60);
    expect(s.musicVolume, 0.5);
    expect(s.sfxVolume, 0.7);
    expect(s.muted, isFalse);
  });

  test('volumes and mute persist across loads', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await VillageSettings.load();
    s
      ..musicVolume = 0.2
      ..sfxVolume = 1.4
      ..muted = true;
    final again = await VillageSettings.load();
    expect(again.musicVolume, 0.2);
    expect(again.sfxVolume, 1.0, reason: 'clamped');
    expect(again.muted, isTrue);
  });

  test('a changed frame rate persists across loads', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await VillageSettings.load();
    var notified = 0;
    s.addListener(() => notified++);
    s.fps = 120;
    expect(notified, 1);
    expect((await SharedPreferences.getInstance()).getInt('fps'), 120);
    expect((await VillageSettings.load()).fps, 120);
  });

  test('ignores an unsupported stored or requested frame rate', () async {
    SharedPreferences.setMockInitialValues({'fps': 75});
    final s = await VillageSettings.load();
    expect(s.fps, 60);
    s.fps = 45;
    expect(s.fps, 60);
  });

  test('ephemeral settings never write', () async {
    SharedPreferences.setMockInitialValues({});
    VillageSettings.ephemeral().fps = 30;
    expect((await SharedPreferences.getInstance()).getInt('fps'), isNull);
  });

  test('gameplay and accessibility settings default sensibly and persist', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await VillageSettings.load();
    expect(s.textSpeed, TextSpeed.normal);
    expect(s.defaultSpeed, 1);
    expect(s.textSize, TextSize.normal);
    expect(s.reducedMotion, isFalse);
    expect(s.highContrast, isFalse);
    var notified = 0;
    s.addListener(() => notified++);
    s
      ..textSpeed = TextSpeed.slow
      ..defaultSpeed = 4
      ..defaultSpeed = 3
      ..textSize = TextSize.larger
      ..reducedMotion = true
      ..highContrast = true;
    expect(notified, 5, reason: 'an unsupported speed is ignored');
    final again = await VillageSettings.load();
    expect(again.textSpeed.pace, 1.5);
    expect(again.defaultSpeed, 4);
    expect(again.textSize.scale, 1.4);
    expect(again.reducedMotion, isTrue);
    expect(again.highContrast, isTrue);
  });

  test('unknown stored values fall back to the defaults', () async {
    SharedPreferences.setMockInitialValues({'textSpeed': 'warp', 'textSize': 'huge', 'defaultSpeed': 32});
    final s = await VillageSettings.load();
    expect(s.textSpeed, TextSpeed.normal);
    expect(s.textSize, TextSize.normal);
    expect(s.defaultSpeed, 1);
  });

  test('graphics quality defaults to High and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await VillageSettings.load();
    expect(s.quality, GraphicsQuality.high);
    var notified = 0;
    s.addListener(() => notified++);
    s.quality = GraphicsQuality.low;
    expect(notified, 1);
    expect((await SharedPreferences.getInstance()).getString('graphicsQuality'), 'low');
    expect((await VillageSettings.load()).quality, GraphicsQuality.low);
  });

  test('an unknown stored graphics quality falls back to High', () async {
    SharedPreferences.setMockInitialValues({'graphicsQuality': 'ultra'});
    expect((await VillageSettings.load()).quality, GraphicsQuality.high);
  });

  test('lower qualities switch off the costly passes and thin the details', () {
    expect(GraphicsQuality.low.ambientOcclusion, isFalse);
    expect(GraphicsQuality.low.bloom, isFalse);
    expect(GraphicsQuality.medium.godRays, isFalse);
    expect(GraphicsQuality.high.godRays, isTrue);
    expect(GraphicsQuality.low.foliage, lessThan(GraphicsQuality.medium.foliage));
    expect(GraphicsQuality.medium.particles, lessThan(GraphicsQuality.high.particles));
  });

  test('the language follows the system by default, persists, and only its own listenable fires on it', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await VillageSettings.load();
    expect(s.language, AppLanguage.system);
    var language = 0;
    s.languageListenable.addListener(() => language++);
    s.musicVolume = 0.1;
    expect(language, 0);
    s.language = AppLanguage.ko;
    expect(language, 1);
    expect((await SharedPreferences.getInstance()).getString('language'), 'ko');
    expect((await VillageSettings.load()).language, AppLanguage.ko);
    expect(AppLanguage.ko.nativeName, '한국어');
    expect(AppLanguage.fr.code, 'fr');
    SharedPreferences.setMockInitialValues({'language': 'tlh'});
    expect((await VillageSettings.load()).language, AppLanguage.system);
  });
}

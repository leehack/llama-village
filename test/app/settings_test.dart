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
}

import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to 60 fps', () async {
    SharedPreferences.setMockInitialValues({});
    expect((await VillageSettings.load()).fps, 60);
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
}

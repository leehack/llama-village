import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/game/save_store.dart';
import 'package:llama_village/sim/canned.dart';
import 'package:llama_village/sim/endings.dart';
import 'package:llama_village/sim/snapshot.dart';
import 'package:llama_village/sim/storybook.dart';
import 'package:llama_village/sim/village.dart';

import '../sim/harness.dart';

void main() {
  late Directory dir;
  late SaveStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('village_saves');
    store = SaveStore(Directory('${dir.path}/saves'));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('a save written to a slot loads back equal and is listed as the latest', () async {
    final v = testVillage(seed: 4);
    await v.begin();
    await runMinutes(v, 200);
    final at = DateTime.utc(2026, 10, 1, 9);
    final save = snapshotVillage(v, at: at);
    await store.write('slot2', save);
    await store.write(SaveStore.autoSlot, snapshotVillage(v, at: at.subtract(const Duration(hours: 1))));

    final back = await store.read('slot2');
    final copy = Village(chat: CannedChat(), embed: HashEmbed(), seed: 0, msPerMinute: 10);
    restoreVillage(copy, back);
    expect(snapshotVillage(copy, at: at), save);

    final latest = await store.latest();
    expect(latest!.slot, 'slot2');
    expect(latest.when, 'Day 1, ${v.now.hhmm}');
    expect(latest.name, 'Slot 2');
    final all = await store.list();
    expect(all.keys, SaveStore.allSlots);
    expect(all['slot1'], isNull);
    expect(File('${store.dir.path}/slot2.json.tmp').existsSync(), isFalse);
  });

  test('a corrupted save is flagged, skipped by Continue and fails to load with a SaveException', () async {
    final v = testVillage();
    await store.write('slot1', snapshotVillage(v, at: DateTime.utc(2026, 1, 1)));
    await store.write('slot3', snapshotVillage(v, at: DateTime.utc(2026, 1, 2)));
    final f = File('${store.dir.path}/slot3.json');
    f.writeAsStringSync(f.readAsStringSync().substring(0, 200));
    File('${store.dir.path}/autosave.json').writeAsBytesSync([0xff, 0xfe, 0x00, 0x41]);

    final slot3 = await store.info('slot3');
    expect(slot3!.damaged, isTrue);
    expect(slot3.when, 'damaged');
    expect((await store.info(SaveStore.autoSlot))!.damaged, isTrue);
    expect((await store.latest())!.slot, 'slot1', reason: 'Continue picks the newest save that loads');
    await expectLater(store.read('slot3'), throwsA(isA<SaveException>()));
    await expectLater(store.read(SaveStore.autoSlot), throwsA(isA<SaveException>()));
    await expectLater(store.read('slot2'), throwsA(isA<SaveException>()));
  });

  test('with no saves there is nothing to continue', () async {
    expect(await store.latest(), isNull);
  });

  test('unlocked endings persist, and a damaged gallery reads as empty', () async {
    expect(await store.unlocked(), isEmpty);
    expect(await store.unlock(Ending.dramaLlama), isTrue);
    expect(await store.unlock(Ending.dramaLlama), isFalse);
    expect(await store.unlock(Ending.quietValley), isTrue);
    expect(await SaveStore(store.dir).unlocked(), {Ending.dramaLlama, Ending.quietValley});
    File('${store.dir.path}/endings.json').writeAsStringSync('{"unlocked": [');
    expect(await store.unlocked(), isEmpty);
  });

  test('finished storybooks are kept in the gallery, newest first, and a damaged one is skipped', () async {
    expect(await store.storybooks(), isEmpty);
    Storybook book(String id, DateTime at) => Storybook(
      id: id,
      title: storyTitle,
      ending: Ending.harmonyFestival,
      finishedAt: at,
      pages: [
        StoryPage(PageKind.cover, shot: Uint8List.fromList([137, 80, 78, 71])),
        for (var d = 1; d <= 5; d++) StoryPage(PageKind.day, day: d, text: 'Day $d was lovely. Everyone sang.'),
        StoryPage(PageKind.ending, text: 'And so the week ended.', fallback: true),
      ],
    );
    final older = book('w1', DateTime.utc(2026, 9, 1));
    final newer = book('w2', DateTime.utc(2026, 9, 2));
    await store.writeStorybook(older);
    await store.writeStorybook(newer);
    File('${store.dir.path}/storybooks/broken.json').writeAsStringSync('{"game": "llama_village_storybook"');

    final books = await SaveStore(store.dir).storybooks();
    expect([for (final b in books) b.id], ['w2', 'w1']);
    expect(books.first.toJson(), newer.toJson());
    expect(books.first.pages.first.shot, [137, 80, 78, 71]);
    expect(books.first.complete, isTrue);
  });
}

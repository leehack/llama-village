import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../sim/endings.dart';
import '../sim/snapshot.dart';
import '../sim/storybook.dart';

/// One save slot as the menus list it.
class SaveInfo {
  const SaveInfo(this.slot, {this.savedAt, this.day, this.time, this.playtime = Duration.zero, this.thumbnail, this.error});

  /// The header of a decoded save. Saves from before playtime and
  /// thumbnails have neither; a damaged thumbnail is left out.
  factory SaveInfo.fromSave(String slot, Map<String, Object?> j) {
    final played = j['playtime'];
    return SaveInfo(
      slot,
      savedAt: DateTime.parse(j['savedAt'] as String),
      day: j['day'] as int,
      time: j['time'] as String,
      playtime: Duration(milliseconds: played is num ? (played * 1000).round() : 0),
      thumbnail: _thumbnail(j[SaveStore.thumbKey]),
    );
  }

  final String slot;
  final DateTime? savedAt;
  final int? day;
  final String? time;

  /// Real time played in that game.
  final Duration playtime;

  /// A small PNG of the 3D view when the game was saved.
  final Uint8List? thumbnail;

  /// Why the file cannot be loaded, if it cannot.
  final String? error;

  bool get damaged => error != null;
  bool get isAuto => slot == SaveStore.autoSlot;
  String get name => isAuto ? 'Autosave' : 'Slot ${slot.substring(4)}';
  String get when => damaged ? 'damaged' : 'Day $day, $time';

  static Uint8List? _thumbnail(Object? b64) {
    if (b64 is! String) return null;
    try {
      return base64Decode(b64);
    } on FormatException {
      return null;
    }
  }
}

/// Save files (an autosave and three manual slots) and the endings gallery,
/// as JSON files in one directory. Writes go to a temporary file first and
/// are renamed into place, so a crash mid-write leaves the old save intact.
class SaveStore {
  SaveStore(this.dir);

  final Directory dir;

  static const String autoSlot = 'autosave';
  static const List<String> manualSlots = ['slot1', 'slot2', 'slot3'];
  static const List<String> allSlots = [autoSlot, ...manualSlots];

  /// Where a save keeps its thumbnail (base64 PNG); loading ignores it.
  static const String thumbKey = 'thumb';

  /// The store in the app support directory.
  static Future<SaveStore> open() async => SaveStore(Directory('${(await getApplicationSupportDirectory()).path}/saves'));

  File _file(String slot) => File('${dir.path}/$slot.json');
  File get _gallery => File('${dir.path}/endings.json');
  Directory get _books => Directory('${dir.path}/storybooks');

  Future<void> _writeAtomic(File file, String text) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(text, flush: true);
    await tmp.rename(file.path);
  }

  /// Writes [save] (from snapshotVillage) to [slot] with its [thumbnail],
  /// encoding off the UI isolate.
  Future<void> write(String slot, Map<String, Object?> save, {Uint8List? thumbnail}) async {
    final text = await Isolate.run(() => jsonEncode({...save, if (thumbnail != null) thumbKey: base64Encode(thumbnail)}));
    await _writeAtomic(_file(slot), text);
  }

  Future<String> _text(String slot) async {
    final f = _file(slot);
    if (!await f.exists()) throw SaveException('no save in $slot');
    try {
      return await f.readAsString();
    } on FileSystemException catch (e) {
      throw SaveException('cannot read $slot (${e.osError?.message ?? e.message})');
    } on FormatException {
      throw SaveException('$slot is not text');
    }
  }

  /// Reads and checks [slot]; throws [SaveException] when it is missing or damaged.
  Future<Map<String, Object?>> read(String slot) async {
    final text = await _text(slot);
    return Isolate.run(() => decodeSave(text));
  }

  /// The slot's header, or null when the slot is empty. Only the header
  /// leaves the decoding isolate.
  Future<SaveInfo?> info(String slot) async {
    if (!await _file(slot).exists()) return null;
    try {
      final text = await _text(slot);
      return await Isolate.run(() => SaveInfo.fromSave(slot, decodeSave(text)));
    } on SaveException catch (e) {
      return SaveInfo(slot, error: e.message);
    } catch (e) {
      return SaveInfo(slot, error: 'unreadable header (${e.runtimeType})');
    }
  }

  /// Every slot, empty ones as null.
  Future<Map<String, SaveInfo?>> list() async {
    final infos = await Future.wait(allSlots.map(info));
    return {for (final (i, s) in allSlots.indexed) s: infos[i]};
  }

  /// The newest save that loads.
  Future<SaveInfo?> latest() async => newest((await list()).values);

  /// The newest of [saves] that loads.
  static SaveInfo? newest(Iterable<SaveInfo?> saves) {
    final good = saves.whereType<SaveInfo>().where((s) => !s.damaged).toList()..sort((a, b) => b.savedAt!.compareTo(a.savedAt!));
    return good.firstOrNull;
  }

  /// Endings unlocked so far; a damaged gallery file counts as empty.
  Future<Set<Ending>> unlocked() async {
    try {
      if (!await _gallery.exists()) return {};
      final j = jsonDecode(await _gallery.readAsString());
      return {
        for (final n in (j as Map)['unlocked'] as List)
          if (Ending.values.any((e) => e.name == n)) Ending.values.byName(n as String),
      };
    } catch (_) {
      return {};
    }
  }

  /// Unlocks [ending]; true when it is new.
  Future<bool> unlock(Ending ending) async {
    final have = await unlocked();
    if (!have.add(ending)) return false;
    await _writeAtomic(
      _gallery,
      jsonEncode({
        'unlocked': [for (final e in have) e.name],
      }),
    );
    return true;
  }

  /// Keeps a finished week's storybook in the gallery (one file per book).
  Future<void> writeStorybook(Storybook book) async {
    final text = await Isolate.run(() => jsonEncode(book.toJson()));
    await _writeAtomic(File('${_books.path}/${book.id}.json'), text);
  }

  /// Every storybook in the gallery, newest first; damaged files are skipped.
  Future<List<Storybook>> storybooks() async {
    if (!await _books.exists()) return [];
    final books = <Storybook>[];
    await for (final f in _books.list()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      try {
        final text = await f.readAsString();
        books.add(await Isolate.run(() => Storybook.fromJson((jsonDecode(text) as Map).cast<String, Object?>())));
      } catch (_) {
        // A damaged book is left out of the gallery.
      }
    }
    return books..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
  }
}

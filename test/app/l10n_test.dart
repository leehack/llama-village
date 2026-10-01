import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _arb(String locale) =>
    (jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync()) as Map).cast<String, Object?>();

Set<String> _keys(Map<String, Object?> arb) => {
  for (final k in arb.keys)
    if (!k.startsWith('@')) k,
};

/// Strings that read the same in every language (numbers, units, names).
const Set<String> _same = {'fps', 'harmonyValue', 'lockedTitle', 'saveDetail', 'speedChoice', 'fpsChoice', 'creditsFlutter', 'laLaLa'};

void main() {
  final en = _arb('en');

  test('Korean and French have every English key, and nothing else', () {
    for (final locale in ['ko', 'fr']) {
      final arb = _arb(locale);
      expect(arb['@@locale'], locale);
      expect(_keys(arb).difference(_keys(en)), isEmpty, reason: '$locale has keys English lacks');
      expect(_keys(en).difference(_keys(arb)), isEmpty, reason: '$locale is missing keys');
      for (final k in _keys(arb)) {
        expect((arb[k] as String).trim(), isNotEmpty, reason: '$locale:$k');
      }
    }
  });

  test('every translation uses each placeholder its English message declares', () {
    for (final locale in ['ko', 'fr']) {
      final arb = _arb(locale);
      for (final k in _keys(en)) {
        final meta = en['@$k'] as Map?;
        final placeholders = (meta?['placeholders'] as Map?)?.keys.cast<String>() ?? const <String>[];
        for (final p in placeholders) {
          expect(arb[k] as String, matches(RegExp('\\{$p[,}]')), reason: '$locale:$k drops {$p}');
        }
      }
    }
  });

  test('the Korean strings are written in Korean', () {
    final ko = _arb('ko');
    final hangul = RegExp(r'[가-힣]');
    for (final k in _keys(ko)) {
      if (_same.contains(k)) continue;
      expect(hangul.hasMatch(ko[k] as String), isTrue, reason: 'ko:$k looks untranslated: ${ko[k]}');
    }
  });

  test('the French strings are not left in English', () {
    final fr = _arb('fr');
    final untranslated = [
      for (final k in _keys(fr))
        if (!_same.contains(k) && fr[k] == en[k] && (en[k] as String).contains(' ')) k,
    ];
    expect(untranslated, isEmpty, reason: 'French keys still in English');
  });
}

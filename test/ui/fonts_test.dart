import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/ui/fonts.dart';

void main() {
  test('Hangul is spotted in mixed-script lines', () {
    expect(hasHangul('Pip이 웃었어요'), isTrue);
    expect(hasHangul('Pip이'), isTrue);
    expect(hasHangul('ㅋㅋ'), isTrue, reason: 'compatibility jamo');
    expect(hasHangul('Pip laughed. Ça va ?'), isFalse);
  });

  test('Korean text takes the bundled face; other text keeps its own', () {
    const style = TextStyle(fontSize: 13, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic);

    final ko = Face.display.on(style, korean: true);
    expect(ko.fontFamily, 'Jua');
    expect(ko.fontWeight, FontWeight.w400, reason: 'Jua has one weight; no synthetic bold');
    expect(ko.fontStyle, FontStyle.normal, reason: 'no slanted Hangul');
    expect(ko.fontFamilyFallback, ['Apple SD Gothic Neo']);

    final en = Face.display.on(style, korean: false, text: 'Hello');
    expect(en.fontFamily, isNull, reason: 'English keeps the inherited face');
    expect(en.fontWeight, FontWeight.w900);
    expect(en.fontFamilyFallback, ['Jua', 'Apple SD Gothic Neo'], reason: 'a stray Hangul word still matches');

    final mixed = Face.ui.on(style, korean: false, text: 'Pip이 왔어요');
    expect(mixed.fontFamily, 'GowunDodum', reason: 'a Hangul line in another language is set whole');
    expect(mixed.fontWeight, FontWeight.w900, reason: 'the UI face keeps the weight');

    final book = Face.serif.on(const TextStyle(fontFamily: 'Baskerville', fontFamilyFallback: ['Georgia']), korean: true);
    expect(book.fontFamily, 'GowunBatang');
    expect(book.fontFamilyFallback, ['AppleMyungjo', 'Georgia']);
  });

  test('the theme sets Korean in Gowun Dodum and keeps it behind other languages', () {
    expect(villageTheme(korean: true).textTheme.bodyMedium!.fontFamily, 'GowunDodum');
    final en = villageTheme(korean: false).textTheme.bodyMedium!;
    expect(en.fontFamily, isNot('GowunDodum'));
    expect(en.fontFamilyFallback, contains('GowunDodum'));
  });

  test('every face is bundled with its licence', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final (face, dir, files) in [
      (Face.ui, 'gowundodum', ['GowunDodum-Regular.ttf']),
      (Face.display, 'jua', ['Jua-Regular.ttf']),
      (Face.serif, 'gowunbatang', ['GowunBatang-Regular.ttf', 'GowunBatang-Bold.ttf']),
    ]) {
      expect(pubspec, contains('- family: ${face.family}\n'));
      expect(File('assets/fonts/$dir/OFL.txt').readAsStringSync(), contains('SIL Open Font License, Version 1.1'));
      for (final f in files) {
        expect(pubspec, contains('assets/fonts/$dir/$f'));
        expect(File('assets/fonts/$dir/$f').lengthSync(), lessThan(2200 * 1024), reason: '$f is a subset');
      }
    }
  });
}

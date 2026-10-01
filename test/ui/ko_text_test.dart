import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_village/ui/ko_text.dart';

void main() {
  group('keepWords', () {
    test('joins the characters of each word and keeps every space', () {
      const s = 'Pip이 빨간 목도리를  찾았어요!\n정말?';
      final out = keepWords(s);
      expect(out.split(wordJoiner).join(), s, reason: 'only joiners are added');
      expect(out, 'P⁠i⁠p⁠이 빨⁠간 목⁠도⁠리⁠를  찾⁠았⁠어⁠요⁠!\n정⁠말⁠?');
    });

    test('never puts a joiner next to a space', () {
      final out = keepWords(' 아침 이슬이\t반짝여요. ');
      expect(RegExp('\\s$wordJoiner|$wordJoiner\\s').hasMatch(out), isFalse);
      expect(out.startsWith(wordJoiner) || out.endsWith(wordJoiner), isFalse);
    });

    test('dropping the joiners gives the original back, and it is idempotent', () {
      for (final s in ['', ' ', '가', 'Mo가 "노래할게!"라고 했어요.', '👩‍👩‍👧 가족 🎉!', 'été 가']) {
        expect(dropWordJoiners(keepWords(s)), s);
        expect(keepWords(keepWords(s)), keepWords(s));
      }
    });

    test('keeps grapheme clusters whole', () {
      expect(keepWords('👩‍👩‍👧가'), '👩‍👩‍👧$wordJoiner가');
      expect(keepWords('é가'), 'é$wordJoiner가');
    });

    test('leaves non-Korean text alone unless the UI is Korean', () {
      expect(keepWords('Pip laughed. Ça va ?'), 'Pip laughed. Ça va ?');
      expect(keepWords('Pip', korean: true), 'P${wordJoiner}i${wordJoiner}p');
    });

    test('keepWordsSpan maps text and children and keeps styles', () {
      const bold = TextStyle(fontWeight: FontWeight.w900);
      final span = keepWordsSpan(
        const TextSpan(
          text: 'Mo  ',
          style: bold,
          children: [TextSpan(text: '안녕')],
        ),
        korean: true,
      ) as TextSpan;
      expect(span.text, 'M${wordJoiner}o  ');
      expect(span.style, bold);
      expect((span.children!.single as TextSpan).text, '안$wordJoiner녕');
    });
  });

  group('layout', () {
    setUpAll(() async {
      final bytes = File('assets/fonts/gowundodum/GowunDodum-Regular.ttf').readAsBytesSync();
      await (FontLoader('GowunDodum')..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    });

    const style = TextStyle(fontFamily: 'GowunDodum', fontSize: 16);
    const sentence = '어제 저녁 빵집 앞에서 Pip이 준에게 빨간 목도리를 찾았다고 조용히 말했어요.';

    List<String> lines(String shown, double width) {
      final painter = TextPainter(
        text: TextSpan(text: shown, style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width);
      final out = <String>[];
      var at = 0;
      while (at < shown.length) {
        final line = painter.getLineBoundary(TextPosition(offset: at));
        out.add(dropWordJoiners(shown.substring(line.start, line.end)));
        at = line.end > at ? line.end : at + 1;
      }
      expect(painter.width, lessThanOrEqualTo(width), reason: 'nothing overflows');
      painter.dispose();
      return out;
    }

    test('Korean breaks only at spaces once words are kept', () {
      final words = sentence.split(' ').toSet();
      for (final width in [90.0, 120.0, 170.0]) {
        final kept = lines(keepWords(sentence), width);
        expect(kept.length, greaterThan(1));
        for (final line in kept) {
          for (final w in line.trim().split(' ')) {
            expect(words, contains(w), reason: 'at $width "$line" starts or ends mid-word');
          }
        }
        expect(kept.map((l) => l.trim()).join(' '), sentence);
      }
      final plain = lines(sentence, 120);
      expect(plain.any((line) => line.trim().split(' ').any((w) => !words.contains(w))), isTrue, reason: 'Flutter alone splits words');
    });

    test('a word wider than the line still wraps instead of overflowing', () {
      const long = '가나다라마바사아자차카타파하가나다라마바사아자차카타파하 끝';
      final kept = lines(keepWords(long), 80);
      expect(kept.length, greaterThan(2));
      expect(kept.join().replaceAll(' ', ''), long.replaceAll(' ', ''));
    });
  });

  testWidgets('KoText keeps words in a Korean UI and shows other text as is', (tester) async {
    Future<String> shown(Locale locale, String text) async {
      await tester.pumpWidget(
        Localizations(
          locale: locale,
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: Directionality(textDirection: TextDirection.ltr, child: KoText(text)),
        ),
      );
      return tester.widget<Text>(find.byType(Text)).data!;
    }

    expect(await shown(const Locale('ko'), 'Pip'), 'P${wordJoiner}i${wordJoiner}p');
    expect(await shown(const Locale('en'), 'Pip이 왔다'), 'P${wordJoiner}i${wordJoiner}p$wordJoiner이 왔$wordJoiner다');
    expect(await shown(const Locale('en'), 'Pip came'), 'Pip came');
  });
}

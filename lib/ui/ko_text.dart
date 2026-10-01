import 'package:flutter/material.dart';

import 'fonts.dart';

/// U+2060 WORD JOINER: no line break on either side, and no width.
const String wordJoiner = '⁠';

final RegExp _space = RegExp(r'\s');

/// [text] for display with Korean line breaking: lines break only at
/// spaces, never inside a word (eojeol). Flutter breaks Korean between any
/// two syllables, so this puts a [wordJoiner] between neighbouring
/// characters of each word, Latin, digits and punctuation included, so
/// "Pip이" and "왔어요!" stay whole. A word wider than the line is still
/// broken by the paragraph layout, so nothing overflows.
///
/// Applies when [korean] (the UI's language) or when [text] has Hangul;
/// other text comes back unchanged. Display only: copy, length and
/// comparisons use the original, which [dropWordJoiners] gives back.
String keepWords(String text, {bool korean = false}) {
  if (!korean && !hasHangul(text)) return text;
  final out = StringBuffer();
  var joinable = false;
  for (final c in dropWordJoiners(text).characters) {
    final space = _space.hasMatch(c);
    if (joinable && !space) out.write(wordJoiner);
    out.write(c);
    joinable = !space;
  }
  return out.toString();
}

/// [text] without the [wordJoiner]s that [keepWords] put in.
String dropWordJoiners(String text) => text.replaceAll(wordJoiner, '');

/// [span] with [keepWords] applied to the text of it and its children.
InlineSpan keepWordsSpan(InlineSpan span, {bool korean = false}) {
  if (span is! TextSpan) return span;
  return TextSpan(
    text: span.text == null ? null : keepWords(span.text!, korean: korean),
    children: span.children?.map((c) => keepWordsSpan(c, korean: korean)).toList(),
    style: span.style,
    recognizer: span.recognizer,
    mouseCursor: span.mouseCursor,
    onEnter: span.onEnter,
    onExit: span.onExit,
    semanticsLabel: span.semanticsLabel,
    locale: span.locale,
    spellOut: span.spellOut,
  );
}

/// A [Text] that wraps Korean only at spaces ([keepWords]) in a Korean UI
/// or for a line with Hangul.
class KoText extends StatelessWidget {
  const KoText(String this.data, {super.key, this.style, this.textAlign, this.softWrap, this.overflow, this.maxLines}) : span = null;

  const KoText.rich(InlineSpan this.span, {super.key, this.style, this.textAlign, this.softWrap, this.overflow, this.maxLines})
    : data = null;

  final String? data;
  final InlineSpan? span;
  final TextStyle? style;
  final TextAlign? textAlign;
  final bool? softWrap;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final korean = koreanUi(context);
    if (span != null) {
      return Text.rich(
        keepWordsSpan(span!, korean: korean),
        style: style,
        textAlign: textAlign,
        softWrap: softWrap,
        overflow: overflow,
        maxLines: maxLines,
      );
    }
    return Text(
      keepWords(data!, korean: korean),
      style: style,
      textAlign: textAlign,
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
    );
  }
}

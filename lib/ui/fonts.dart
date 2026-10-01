import 'package:flutter/material.dart';

/// The bundled Korean faces (SIL OFL 1.1, in `assets/fonts/`). They are
/// subsets with Latin and the 2,350 common Hangul syllables of KS X 1001,
/// so a rarer syllable falls back to the system's Korean face.
enum Face {
  /// Menus, the HUD, the inspector, the log and settings. It has one weight,
  /// and Flutter does not embolden it, so headings use [display].
  ui('GowunDodum', 'Apple SD Gothic Neo'),

  /// Titles, headings, speech and thought bubbles and Dash's options.
  display('Jua', 'Apple SD Gothic Neo'),

  /// The storybook.
  serif('GowunBatang', 'AppleMyungjo');

  const Face(this.family, this.system);
  final String family;
  final String system;

  /// [style] in this face for Korean: when [korean] (the UI's language) or
  /// when [text] has Hangul. Otherwise [style] keeps its own family, with
  /// this face added to its fallbacks so a stray Hangul word still matches.
  TextStyle on(TextStyle style, {required bool korean, String? text}) {
    if (korean || (text != null && hasHangul(text))) {
      return style.copyWith(
        fontFamily: family,
        fontFamilyFallback: [system, ...?style.fontFamilyFallback],
        // Jua has one weight, already heavy; a synthetic bold smears it.
        fontWeight: this == display ? FontWeight.w400 : style.fontWeight,
        // None of these faces has an italic.
        fontStyle: FontStyle.normal,
      );
    }
    return style.copyWith(fontFamilyFallback: [...?style.fontFamilyFallback, family, system]);
  }

  /// [on] for the UI language of [context].
  TextStyle of(BuildContext context, TextStyle style, {String? text}) => on(style, korean: koreanUi(context), text: text);
}

/// Whether [text] has a Hangul syllable or jamo.
bool hasHangul(String text) => text.runes.any(
  (c) => (c >= 0xAC00 && c <= 0xD7A3) || (c >= 0x1100 && c <= 0x11FF) || (c >= 0x3130 && c <= 0x318F) || (c >= 0xA960 && c <= 0xA97F),
);

/// Whether the UI is in Korean.
bool koreanUi(BuildContext context) => Localizations.maybeLocaleOf(context)?.languageCode == 'ko';

/// The app theme: Gowun Dodum for Korean, the system face otherwise (with
/// Gowun Dodum behind it for Hangul in an English or French line).
ThemeData villageTheme({required bool korean}) => ThemeData(
  useMaterial3: true,
  colorSchemeSeed: const Color(0xFF3E8EF0),
  fontFamily: korean ? Face.ui.family : null,
  fontFamilyFallback: korean ? [Face.ui.system] : [Face.ui.family, Face.ui.system],
);

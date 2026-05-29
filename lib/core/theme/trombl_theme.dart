import 'package:flutter/material.dart';

/// Trombl's visual identity — ported directly from the prototype.
/// Dark, warm, two-vibe accent system with NEW DROP teal.
class TromblColors {
  // Backgrounds
  static const bg       = Color(0xFF090909);  // prototype: #090909
  static const card     = Color(0xFF111115);  // prototype: #111115
  static const cardLit  = Color(0xFF18181E);  // prototype: #18181E (sheets)
  static const faint    = Color(0xFF13131A);  // prototype: #13131A (preview boxes)

  // Borders
  static const border    = Color(0x12FFFFFF); // ~7% white
  static const borderMid = Color(0x1EFFFFFF); // ~12% white

  // Text
  static const text      = Color(0xFFEDE9DC); // prototype: #EDE9DC (warm white)
  static const textSub   = Color(0xFF7A7A8C); // prototype: #7A7A8C
  static const textMuted = Color(0xFF3E3E50); // prototype: #3E3E50

  // Vibe accents
  static const fomo      = Color(0xFFF2B705); // gold
  static const jomo      = Color(0xFFC4B0FF); // lavender

  // NEW DROP accent
  static const newDrop   = Color(0xFF00E5B0); // teal

  // Glow variants (low opacity fills)
  static const fomoGlow  = Color(0x1FF2B705); // 12% fomo
  static const jomoGlow  = Color(0x1AC4B0FF); // 10% jomo
  static const newGlow   = Color(0x1A00E5B0); // 10% newDrop

  static Color accentFor(String? vibe) =>
      vibe == 'fomo' ? fomo : vibe == 'jomo' ? jomo : text;

  static Color glowFor(String? vibe) =>
      vibe == 'fomo' ? fomoGlow : vibe == 'jomo' ? jomoGlow : border;
}

class TromblText {
  static const sans  = 'DMSans';
  static const serif = 'Fraunces';
}

class TromblTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: TromblColors.bg,
        fontFamily: TromblText.sans,
        colorScheme: const ColorScheme.dark(
          surface: TromblColors.bg,
          primary: TromblColors.fomo,
          secondary: TromblColors.jomo,
        ),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        // Ensure all text uses DM Sans by default
        textTheme: const TextTheme(
          bodyLarge:  TextStyle(fontFamily: TromblText.sans, color: TromblColors.text),
          bodyMedium: TextStyle(fontFamily: TromblText.sans, color: TromblColors.text),
          bodySmall:  TextStyle(fontFamily: TromblText.sans, color: TromblColors.textSub),
        ),
      );
}

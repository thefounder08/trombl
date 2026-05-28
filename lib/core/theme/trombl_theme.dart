import 'package:flutter/material.dart';

/// Trombl's visual identity, ported from the prototype.
/// Dark, warm, two-vibe accent system.
class TromblColors {
  static const bg = Color(0xFF0B0B0D);
  static const card = Color(0xFF161618);
  static const border = Color(0x12FFFFFF); // ~7% white
  static const borderMid = Color(0x1AFFFFFF);

  static const text = Color(0xFFF5F3EE);
  static const textSub = Color(0x80FFFFFF); // 50%
  static const textMuted = Color(0x4DFFFFFF); // 30%

  static const fomo = Color(0xFFF2B705); // gold
  static const jomo = Color(0xFFC4B0FF); // lavender

  static Color accentFor(String? vibe) =>
      vibe == 'fomo' ? fomo : vibe == 'jomo' ? jomo : text;
}

class TromblText {
  static const sans = 'DMSans';
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
      );
}

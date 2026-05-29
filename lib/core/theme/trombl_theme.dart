import 'package:flutter/material.dart';

/// Trombl's design tokens — exact values from the prototype, no drift.
class TromblColors {
  // ── Backgrounds ─────────────────────────────────────────────────────────────
  static const bg      = Color(0xFF090909);
  static const card    = Color(0xFF111115);
  static const cardLit = Color(0xFF18181E);

  // ── Borders ──────────────────────────────────────────────────────────────────
  static const border    = Color(0x12FFFFFF); // 7% white
  static const borderMid = Color(0x1EFFFFFF); // 12% white

  // ── Text ─────────────────────────────────────────────────────────────────────
  static const text      = Color(0xFFEDE9DC);
  static const textSub   = Color(0xFF7A7A8C);
  static const textMuted = Color(0xFF3E3E50);

  // ── Vibe accents ─────────────────────────────────────────────────────────────
  static const fomo    = Color(0xFFF2B705); // gold
  static const jomo    = Color(0xFFC4B0FF); // lavender
  static const newDrop = Color(0xFF00E5B0); // teal

  // ── Tag colors ───────────────────────────────────────────────────────────────
  static const tagSquad   = Color(0xFF25D366); // WhatsApp green
  static const tagOrderIn = Color(0xFFE23744); // Zomato red
  static const tagContent = Color(0xFFE1306C); // Instagram pink

  // ── Accent helpers ───────────────────────────────────────────────────────────

  static Color accentFor(String? vibe) =>
      vibe == 'fomo' ? fomo : vibe == 'jomo' ? jomo : text;

  /// Low-opacity fill for glow cards / backgrounds.
  static Color glowFor(String? vibe) {
    switch (vibe) {
      case 'fomo':    return fomo.withValues(alpha: 0.12);
      case 'jomo':    return jomo.withValues(alpha: 0.10);
      default:        return border;
    }
  }

  /// Subtle border tint for accent-bordered containers.
  static Color borderFor(String? vibe) {
    switch (vibe) {
      case 'fomo':    return fomo.withValues(alpha: 0.25);
      case 'jomo':    return jomo.withValues(alpha: 0.25);
      default:        return borderMid;
    }
  }

  /// Tag chip color for a given tag string.
  static Color tagColorFor(String tag) {
    switch (tag) {
      case 'squad':    return tagSquad;
      case 'order in': return tagOrderIn;
      case 'content':  return tagContent;
      case 'discover': return fomo;
      case 'rest':     return jomo;
      default:         return textMuted;
    }
  }
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
          surface:   TromblColors.bg,
          primary:   TromblColors.fomo,
          secondary: TromblColors.jomo,
        ),
        splashColor:    Colors.transparent,
        highlightColor: Colors.transparent,
        textTheme: const TextTheme(
          bodyLarge:  TextStyle(fontFamily: TromblText.sans, color: TromblColors.text),
          bodyMedium: TextStyle(fontFamily: TromblText.sans, color: TromblColors.text),
          bodySmall:  TextStyle(fontFamily: TromblText.sans, color: TromblColors.textSub),
        ),
      );
}

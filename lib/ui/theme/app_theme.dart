import 'package:flutter/material.dart';

/// TapNova premium design tokens
class AppTheme {
  AppTheme._();

  // ── Colors ──────────────────────────────────────────────────────────────
  static const Color bgDark = Color(0xFF060814);
  static const Color bgCard = Color(0xFF0D1128);
  static const Color bgCardElevated = Color(0xFF131A35);

  static const Color accentCyan = Color(0xFF00E5FF);
  static const Color accentPurple = Color(0xFFB44FFF);
  static const Color accentGold = Color(0xFFFFB830);
  static const Color accentGreen = Color(0xFF00E5A0);
  static const Color accentRed = Color(0xFFFF4A6E);
  static const Color accentOrange = Color(0xFFFF8C42);

  static const Color borderGlow = Color(0x4400E5FF);
  static const Color borderGoldGlow = Color(0x44FFB830);
  static const Color borderSubtle = Color(0x28FFFFFF);

  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF8899BB);
  static const Color textMuted = Color(0xFF4A5568);

  // ── Gradients ────────────────────────────────────────────────────────────
  static const LinearGradient cyanPurpleGradient = LinearGradient(
    colors: [accentCyan, accentPurple],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient redOrangeGradient = LinearGradient(
    colors: [accentRed, accentOrange],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFD060), accentGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanGreenGradient = LinearGradient(
    colors: [accentCyan, accentGreen],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF0D1228), Color(0xFF0A0E1E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Glow Shadows ────────────────────────────────────────────────────────
  static List<BoxShadow> cyanGlow({double spread = 6, double blur = 18}) => [
        BoxShadow(
          color: accentCyan.withValues(alpha: 0.35),
          blurRadius: blur,
          spreadRadius: spread,
        ),
      ];

  static List<BoxShadow> purpleGlow({double spread = 6, double blur = 18}) => [
        BoxShadow(
          color: accentPurple.withValues(alpha: 0.35),
          blurRadius: blur,
          spreadRadius: spread,
        ),
      ];

  static List<BoxShadow> goldGlow({double spread = 4, double blur = 14}) => [
        BoxShadow(
          color: accentGold.withValues(alpha: 0.4),
          blurRadius: blur,
          spreadRadius: spread,
        ),
      ];

  static List<BoxShadow> redGlow({double spread = 6, double blur = 20}) => [
        BoxShadow(
          color: accentRed.withValues(alpha: 0.4),
          blurRadius: blur,
          spreadRadius: spread,
        ),
      ];

  // ── Glass Card Decoration ────────────────────────────────────────────────
  static BoxDecoration glassCard({
    Color borderColor = borderGlow,
    double radius = 20,
    List<BoxShadow>? shadows,
  }) =>
      BoxDecoration(
        color: bgCard.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: shadows ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
      );

  // ── Text Styles ──────────────────────────────────────────────────────────
  static const TextStyle gameTitleStyle = TextStyle(
    fontSize: 38,
    fontWeight: FontWeight.w900,
    color: textPrimary,
    letterSpacing: 3,
  );

  static const TextStyle headingStyle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: 2,
  );

  static const TextStyle labelStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: textSecondary,
    letterSpacing: 1.8,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 14,
    color: textSecondary,
    height: 1.5,
  );

  static const TextStyle scoreStyle = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w900,
    color: accentCyan,
    letterSpacing: 2,
  );

  static const TextStyle chipStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: 0.5,
  );

  // ── Material Theme ───────────────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgDark,
        colorScheme: const ColorScheme.dark(
          primary: accentCyan,
          secondary: accentPurple,
          surface: bgCard,
        ),
        fontFamily: 'sans-serif',
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: bgCardElevated,
          contentTextStyle: TextStyle(color: textPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            side: BorderSide(color: borderGlow, width: 1),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
}

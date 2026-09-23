import 'package:flutter/material.dart';

/// Zero Air — Modern Pure White & Minimalist Design System
/// Clean plain white canvas, crisp typography, soft subtle shadows.
class ZeroTheme {
  // ─── CORE PALETTE ──────────────────────────────────────────────────────────
  static const Color cream = Color(0xFFFFFFFF); // Plain white clean canvas
  static const Color white = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF0F172A); // Modern dark slate
  static const Color accent = Color(0xFF0284C7); // Clean sky cyan
  static const Color muted = Color(0xFF64748B);
  static const Color dimText = Color(0xFF94A3B8);
  static const Color background = Color(0xFFFFFFFF); // Clean white default
  static const Color surface = Color(0xFFF8FAFC); // Very light subtle surface
  static const Color borderLight = Color(0xFFE2E8F0);

  // ─── PREMIUM SOFT UI ────────────────────────────────────────────────────────
  static const double borderWidth = 1.0;
  static const double cardRadius = 18.0;

  static BoxDecoration hardCard({
    Color fill = white,
    Color borderColor = borderLight,
    Color shadowColor = const Color(0xFF0F172A),
    double radius = cardRadius,
  }) {
    return BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: borderWidth),
      boxShadow: [
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.05), // Ultra-soft elegant shadow
          offset: const Offset(0, 4),
          blurRadius: 14.0,
          spreadRadius: 0.0,
        ),
      ],
    );
  }

  static BoxDecoration accentCard({
    Color fill = white,
    double radius = cardRadius,
  }) {
    return BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: accent.withValues(alpha: 0.3), width: 1.0),
      boxShadow: [
        BoxShadow(
          color: accent.withValues(alpha: 0.10),
          offset: const Offset(0, 4),
          blurRadius: 14.0,
        ),
      ],
    );
  }

  // ─── TEXT STYLES ───────────────────────────────────────────────────────────
  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: ink,
    letterSpacing: -0.5,
    height: 1.15,
  );
  static const TextStyle heading = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: ink,
    letterSpacing: -0.2,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: ink,
    height: 1.5,
    letterSpacing: 0.0,
  );
  static const TextStyle bodyMuted = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: muted,
    height: 1.5,
  );
  static const TextStyle mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: ink,
    letterSpacing: 0.0,
  );
  static const TextStyle chatText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: ink,
    height: 1.5,
  );
  static const TextStyle chatTextWhite = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Colors.white,
    height: 1.5,
  );

  // ─── LIGHT THEME (default) ─────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: white,
      primaryColor: accent,
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: ink),
        titleTextStyle: TextStyle(
          color: ink,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: white),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderLight, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderLight, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: const TextStyle(color: muted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  // ─── DARK THEME ────────────────────────────────────────────────────────────
  static ThemeData get darkTheme => lightTheme;
}

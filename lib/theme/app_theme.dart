import 'package:flutter/material.dart';

class AppTheme {
  // Theme Name: Shield Dark
  static const Color background = Color(0xFF0A1628);
  static const Color surface = Color(0xFF0F2035);
  static const Color primaryBlue = Color(0xFF2E75B6);
  static const Color safeGreen = Color(0xFF1A8A4A);
  static const Color warningAmber = Color(0xFFE6A800);
  static const Color dangerRed = Color(0xFFCC2200);
  
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color divider = Color(0xFF1E3550);

  // Added colors for blocklist_screen
  static const Color emerald = Color(0xFF10B981);
  static const Color primaryViolet = Color(0xFF8B5CF6);
  static const Color neonCyan = Color(0xFF06B6D4);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color surfaceCard = Color(0xFF1F2937);
  static const Color primaryLight = Color(0xFFA78BFA);
  static const Color danger = Color(0xFFEF4444);

  static const LinearGradient violetGradient = LinearGradient(
    colors: [primaryViolet, Color(0xFF6D28D9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'objectionable': return warningAmber;
      case 'pornography': return dangerRed;
      case 'gambling': return neonCyan;
      case 'violence': return dangerRed;
      case 'drugs': return emerald;
      case 'hate': return dangerRed;
      case 'weapons': return dangerRed;
      default: return textMuted;
    }
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primaryBlue,
      cardColor: surface,
      dividerColor: divider,
      
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      
      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        surface: surface,
        error: dangerRed,
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: textPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryBlue),
        ),
        labelStyle: const TextStyle(color: textSecondary),
      ),
    );
  }
}

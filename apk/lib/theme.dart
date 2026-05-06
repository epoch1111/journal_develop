import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color bg = Color(0xFFF7F9F7);
  static const Color surface = Colors.white;
  static const Color accent = Color(0xFF34D399);
  static const Color accentLight = Color(0xFFD1FAE5);
  static const Color accentBg = Color(0xFFECFDF5);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFFD1D5DB);
  static const Color danger = Color(0xFFF87171);
  static const Color dangerLight = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFFBBF24);
  static const Color amberStart = Color(0xFFFDE68A);
  static const Color amberEnd = Color(0xFFFCD34D);

  // Border radius
  static const double radiusXs = 8.0;
  static const double radiusSm = 12.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 24.0;
  static const double radiusXl = 40.0;

  // Shadows
  static final cardShadow = BoxShadow(
    color: Colors.black.withOpacity(0.04),
    blurRadius: 12,
    offset: const Offset(0, 2),
  );

  static final cardShadowSm = BoxShadow(
    color: Colors.black.withOpacity(0.03),
    blurRadius: 8,
    offset: const Offset(0, 1),
  );

  // Gradients
  static const avatarGradient = LinearGradient(
    colors: [amberStart, amberEnd],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  // Text styles
  static const TextStyle headingLarge = TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      );

  static const TextStyle headingMedium = TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      );

  static const TextStyle bodyText = TextStyle(
        fontSize: 14,
        color: textSecondary,
      );

  static const TextStyle caption = TextStyle(
        fontSize: 11,
        color: textMuted,
      );

  // Input decoration
  static InputDecorationTheme get inputTheme => InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: TextStyle(color: textMuted, fontSize: 13),
      );

  // Card decoration
  static BoxDecoration cardDecoration({double radius = radiusLg}) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [cardShadow],
    );
  }

  // AppBar theme
  static AppBarTheme get appBarTheme => AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        foregroundColor: textPrimary,
      );

  // Elevated button style
  static ElevatedButtonThemeData get elevatedButtonTheme =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      );
}

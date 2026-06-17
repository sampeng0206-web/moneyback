import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Color Palette
  static const Color primaryNavy = Color(0xFF1A2B4C);
  static const Color secondaryYellow = Color(0xFFF4C430);
  static const Color actionGreen = Color(0xFF2E7D32);
  static const Color dangerRed = Color(0xFFD32F2F);
  
  static const Color bgLight = Color(0xFFF8F9FA);
  static const Color cardBg = Colors.white;
  static const Color textDark = Color(0xFF212529);
  static const Color textMuted = Color(0xFF6C757D);
  static const Color accentBlue = Color(0xFFEEF4FF);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryNavy,
      scaffoldBackgroundColor: bgLight,
      colorScheme: const ColorScheme.light(
        primary: primaryNavy,
        secondary: secondaryYellow,
        error: dangerRed,
        surface: bgLight,
      ),
      
      // Text Theme
      textTheme: GoogleFonts.notoSansTcTextTheme(
        ThemeData.light().textTheme.copyWith(
          titleLarge: const TextStyle(
            color: primaryNavy, 
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
          titleMedium: const TextStyle(
            color: primaryNavy,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          bodyLarge: const TextStyle(
            color: textDark,
            fontSize: 15,
          ),
          bodyMedium: const TextStyle(
            color: textMuted,
            fontSize: 13,
          ),
        ),
      ),

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryNavy,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(
          color: Colors.white,
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: primaryNavy, fontSize: 14, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryNavy, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: dangerRed, width: 1),
        ),
      ),

      // Card Theme
      cardTheme: CardTheme(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE9ECEF), width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // ElevatedButton Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: actionGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      
      // Segmented Button Theme
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return primaryNavy;
            }
            return Colors.white;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return primaryNavy;
          }),
          side: WidgetStateProperty.all(const BorderSide(color: primaryNavy, width: 1)),
        ),
      ),
    );
  }
}

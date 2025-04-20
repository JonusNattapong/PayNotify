import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF4CAF50); // Green
  static const Color accentColor = Color(0xFF03A9F4);  // Blue
  static const Color errorColor = Color(0xFFE53935);   // Red
  static const Color warningColor = Color(0xFFFFA000); // Amber

  // Light theme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: accentColor,
      error: errorColor,
      surface: Colors.white,
      background: const Color(0xFFF5F5F5),
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    appBarTheme: AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: Typography.englishLike2021.headlineSmall?.copyWith(
        fontFamily: 'Kanit',
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
    ),
    cardTheme: CardTheme(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    textTheme: _getTextTheme(Colors.black87),
    fontFamily: 'Kanit',
  );

  // Dark theme
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      secondary: accentColor,
      error: errorColor,
      surface: const Color(0xFF1E1E1E),
      background: const Color(0xFF121212),
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: Typography.englishLike2021.headlineSmall?.copyWith(
        fontFamily: 'Kanit',
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
    ),
    cardTheme: CardTheme(
      color: const Color(0xFF1E1E1E),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    textTheme: _getTextTheme(Colors.white),
    fontFamily: 'Kanit',
  );

  static TextTheme _getTextTheme(Color textColor) {
    return TextTheme(
      displayLarge: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      headlineLarge: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      headlineMedium: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: textColor),
      titleSmall: TextStyle(color: textColor),
      bodyLarge: TextStyle(color: textColor),
      bodyMedium: TextStyle(color: textColor),
      bodySmall: TextStyle(color: textColor.withOpacity(0.8)),
    );
  }
}
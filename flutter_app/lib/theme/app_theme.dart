// lib/theme/app_theme.dart

import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryDarkGreen = Color(0xFF2E7D32);
  static const Color primaryLightGreen = Color(0xFF4CAF50);
  static const Color lightBackground = Color(0xFFF5F5F5);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    
    colorScheme: const ColorScheme.light(
      primary: primaryDarkGreen,
      secondary: primaryLightGreen,
      surface: lightBackground,
      surfaceContainer: Colors.white,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.black,
    ),

    scaffoldBackgroundColor: lightBackground,

    textTheme: const TextTheme(
      displayMedium: TextStyle(fontWeight: FontWeight.bold, color: primaryDarkGreen),
      titleLarge: TextStyle(fontWeight: FontWeight.bold),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: primaryDarkGreen,
      foregroundColor: Colors.white,
      elevation: 4.0,
    ),
    
    // --- ERRO CORRIGIDO AQUI ---
    // Corrigido de 'BottomAppBarTheme' para 'BottomAppBarThemeData'
    bottomAppBarTheme: const BottomAppBarThemeData(
      color: primaryDarkGreen,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryLightGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryDarkGreen, width: 2),
      ),
    ),

    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}
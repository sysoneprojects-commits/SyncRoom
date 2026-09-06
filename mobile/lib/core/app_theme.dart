import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF040815);
  static const bg2 = Color(0xFF081226);
  static const card = Color(0xFF0B1530);
  static const card2 = Color(0xFF101B38);
  static const border = Color(0xFF24365E);
  static const muted = Color(0xFF8EA2C9);
  static const blue = Color(0xFF26B7FF);
  static const indigo = Color(0xFF466BFF);
  static const violet = Color(0xFF9458FF);
  static const danger = Color(0xFFFF5D72);
  static const success = Color(0xFF43D18B);

  static const accentGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [blue, indigo, violet],
  );
}

class AppTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.indigo,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        hintStyle: const TextStyle(color: AppColors.muted),
        labelStyle: const TextStyle(color: AppColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.indigo, width: 1.4),
        ),
      ),
    );
  }
}

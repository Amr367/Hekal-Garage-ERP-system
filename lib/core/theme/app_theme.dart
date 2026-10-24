import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const String fontFamily = 'Cairo';

  static ThemeData get light {
    const Color seed = Color(0xFF1F4E5F);
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    final TextTheme textTheme = ThemeData(brightness: Brightness.light).textTheme
        .apply(
          fontFamily: fontFamily,
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
        )
        .copyWith(
          bodyLarge: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            height: 1.5,
          ),
          bodyMedium: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            height: 1.5,
          ),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: const Color(0xFFF4F6F7),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF12262E),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const textTheme = TextTheme(
    displaySmall: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0),
    headlineMedium: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0),
    titleLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0),
    titleMedium: TextStyle(fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(height: 1.4),
    bodyMedium: TextStyle(height: 1.35),
  );
}

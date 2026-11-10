import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static final _lightScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primaryGreen,
    primary: AppColors.primaryGreen,
    onPrimary: AppColors.inverseText,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.deepGreen,
    secondary: AppColors.pigPink,
    onSecondary: AppColors.text,
    secondaryContainer: AppColors.secondaryContainer,
    onSecondaryContainer: AppColors.text,
    tertiary: AppColors.warmGold,
    onTertiary: AppColors.text,
    error: AppColors.danger,
    onError: AppColors.inverseText,
    errorContainer: AppColors.dangerContainer,
    onErrorContainer: AppColors.danger,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    surfaceContainerHighest: AppColors.surfaceMuted,
    onSurfaceVariant: AppColors.mutedText,
    outline: AppColors.outline,
    brightness: Brightness.light,
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.leaf,
    onPrimary: AppColors.deepGreen,
    primaryContainer: AppColors.darkPrimaryContainer,
    onPrimaryContainer: AppColors.darkText,
    secondary: AppColors.pigPink,
    onSecondary: AppColors.darkText,
    secondaryContainer: Color(0xFF633541),
    onSecondaryContainer: Color(0xFFF4DCE2),
    tertiary: AppColors.warmGold,
    onTertiary: Color(0xFF2A210D),
    tertiaryContainer: Color(0xFF5D4819),
    onTertiaryContainer: Color(0xFFF6E7C5),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkText,
    surfaceContainerHighest: AppColors.darkSurfaceMuted,
    onSurfaceVariant: AppColors.darkMutedText,
    outline: AppColors.darkOutline,
  );

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: _lightScheme,
    textTheme: AppTypography.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
    ),
    iconTheme: const IconThemeData(color: AppColors.primaryGreen),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radius),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radius),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radius),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radius),
        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
      ),
      prefixIconColor: AppColors.primaryGreen,
      hintStyle: const TextStyle(color: AppColors.mutedText),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? AppColors.deepGreen
              : AppColors.mutedText,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w600,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.deepGreen
              : AppColors.mutedText,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.primaryContainer,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: const TextStyle(
        color: AppColors.deepGreen,
        fontWeight: FontWeight.w600,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.inverseText,
        minimumSize: const Size(0, AppDimensions.controlHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radius),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.inverseText,
        minimumSize: const Size(0, AppDimensions.controlHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.deepGreen,
        side: const BorderSide(color: AppColors.outline),
        minimumSize: const Size(0, AppDimensions.controlHeight),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.warmGold,
      foregroundColor: AppColors.text,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.pigPink,
      linearTrackColor: AppColors.primaryContainer,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.navy,
      contentTextStyle: const TextStyle(color: AppColors.inverseText),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radius),
      ),
    ),
    dividerColor: AppColors.outline,
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: _darkScheme,
    textTheme: AppTypography.textTheme.apply(
      bodyColor: AppColors.darkText,
      displayColor: AppColors.darkText,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: AppColors.darkBackground,
      foregroundColor: AppColors.darkText,
    ),
    iconTheme: const IconThemeData(color: AppColors.leaf),
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radius),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radius),
        borderSide: const BorderSide(color: AppColors.darkOutline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radius),
        borderSide: const BorderSide(color: AppColors.darkOutline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radius),
        borderSide: const BorderSide(color: AppColors.leaf, width: 2),
      ),
      prefixIconColor: AppColors.leaf,
      hintStyle: const TextStyle(color: AppColors.darkMutedText),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      indicatorColor: const Color(0xFF24553F),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? AppColors.inverseText
              : AppColors.darkMutedText,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w600,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.leaf
              : AppColors.darkMutedText,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF24553F),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: const TextStyle(
        color: AppColors.inverseText,
        fontWeight: FontWeight.w600,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.leaf,
        foregroundColor: AppColors.deepGreen,
        minimumSize: const Size(0, AppDimensions.controlHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radius),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.leaf,
        foregroundColor: AppColors.deepGreen,
        minimumSize: const Size(0, AppDimensions.controlHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.leaf,
        side: const BorderSide(color: AppColors.darkOutline),
        minimumSize: const Size(0, AppDimensions.controlHeight),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.warmGold,
      foregroundColor: Color(0xFF2A210D),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.leaf,
      linearTrackColor: AppColors.darkSurfaceMuted,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.darkSurfaceMuted,
      contentTextStyle: const TextStyle(color: AppColors.darkText),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radius),
      ),
    ),
    dividerColor: AppColors.darkOutline,
  );
}

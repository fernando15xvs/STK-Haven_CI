import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/models/appearance_settings.dart';
import 'app_palette.dart';

class AppearanceTheme {
  static ThemeMode mode(AppThemeMode mode) => switch (mode) {
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.system => ThemeMode.system,
  };
  static ThemeData build(AppearanceSettings settings, Brightness brightness) {
    final p = AppColors.from(settings, brightness);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.accentSeed(settings.accent),
          brightness: brightness,
        ).copyWith(
          primary: p.primary,
          onPrimary: p.onPrimary,
          primaryContainer: p.primarySoft,
          onPrimaryContainer: p.textPrimary,
          surface: p.surface,
          onSurface: p.textPrimary,
          onSurfaceVariant: p.textSecondary,
          error: p.error,
          onError: AppColors.contrast(p.error, Colors.white) >= 4.5
              ? Colors.white
              : Colors.black,
          outline: p.surfaceBorder,
        );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Outfit',
    );
    // Material widgets (lists, menus, settings, search and dialogs) must be
    // as readable as widgets explicitly using AppTypography. Material 3
    // defaults to many thin w400 labels, creating a split typography system.
    // Keep Outfit and the platform's text scale; strengthen weights without
    // forcing a fixed MediaQuery.textScaleFactor across the app.
    final text = base.textTheme;
    // Flutter 3.38.9 does not automatically drive the variable font's
    // wght design axis from FontWeight. Set BOTH for real weight on iOS.
    TextStyle? outfitWeight(
      TextStyle? style,
      FontWeight weight,
      double axis,
    ) => style?.copyWith(
      fontWeight: weight,
      fontVariations: [FontVariation('wght', axis)],
    );
    final readableText = text.copyWith(
      displayLarge: outfitWeight(text.displayLarge, FontWeight.w700, 700),
      displayMedium: outfitWeight(text.displayMedium, FontWeight.w700, 700),
      displaySmall: outfitWeight(text.displaySmall, FontWeight.w700, 700),
      headlineLarge: outfitWeight(text.headlineLarge, FontWeight.w700, 700),
      headlineMedium: outfitWeight(text.headlineMedium, FontWeight.w600, 600),
      headlineSmall: outfitWeight(text.headlineSmall, FontWeight.w600, 600),
      titleLarge: outfitWeight(text.titleLarge, FontWeight.w600, 600),
      titleMedium: outfitWeight(text.titleMedium, FontWeight.w600, 600),
      titleSmall: outfitWeight(text.titleSmall, FontWeight.w600, 600),
      bodyLarge: outfitWeight(text.bodyLarge, FontWeight.w500, 500),
      bodyMedium: outfitWeight(text.bodyMedium, FontWeight.w500, 500),
      bodySmall: outfitWeight(text.bodySmall, FontWeight.w500, 500),
      labelLarge: outfitWeight(text.labelLarge, FontWeight.w600, 600),
      labelMedium: outfitWeight(text.labelMedium, FontWeight.w600, 600),
      labelSmall: outfitWeight(text.labelSmall, FontWeight.w600, 600),
    ).apply(
      bodyColor: p.textPrimary,
      displayColor: p.textPrimary,
    );
    return base.copyWith(
      extensions: [p],
      scaffoldBackgroundColor: p.background,
      textTheme: readableText,
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: p.elevatedCards ? 2 : 0,
        shadowColor: Colors.black.withValues(alpha: .12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.surfaceBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.primarySoft,
        surfaceTintColor: Colors.transparent,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.primarySoft,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.surfaceBorder),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: p.surfaceBorder,
        thickness: 1,
        space: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

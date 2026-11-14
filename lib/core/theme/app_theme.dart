import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static const serif = 'Lora';
  static const sans = 'Inter';

  static const tabular = [FontFeature.tabularFigures()];

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.maroon,
      onPrimary: AppColors.ivory,
      primaryContainer: AppColors.maroon100,
      onPrimaryContainer: AppColors.maroon900,
      secondary: AppColors.gold,
      onSecondary: AppColors.maroon900,
      secondaryContainer: AppColors.goldPale,
      onSecondaryContainer: AppColors.maroon900,
      tertiary: Color(0xFF2E6F6A),
      onTertiary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: AppColors.errorBg,
      onErrorContainer: AppColors.error,
      surface: AppColors.ivory,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkMuted,
      surfaceContainerLowest: AppColors.card,
      surfaceContainerLow: AppColors.card,
      surfaceContainer: AppColors.cream,
      surfaceContainerHigh: AppColors.cream,
      surfaceContainerHighest: AppColors.sand,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      shadow: Color(0x1A3E0A17),
      scrim: Color(0x993E0A17),
      inverseSurface: AppColors.maroon900,
      onInverseSurface: AppColors.ivory,
      inversePrimary: AppColors.goldLight,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: sans,
      scaffoldBackgroundColor: AppColors.ivory,
      splashFactory: InkSparkle.splashFactory,
    );

    final text = base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
    final textTheme = text.copyWith(
      displaySmall: text.displaySmall?.copyWith(fontFamily: serif, fontWeight: FontWeight.w600, letterSpacing: -0.5),
      headlineMedium: text.headlineMedium?.copyWith(fontFamily: serif, fontWeight: FontWeight.w600, letterSpacing: -0.3),
      headlineSmall: text.headlineSmall?.copyWith(fontFamily: serif, fontWeight: FontWeight.w600, letterSpacing: -0.2),
      titleLarge: text.titleLarge?.copyWith(fontFamily: serif, fontWeight: FontWeight.w600, fontSize: 21),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 15.5),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 15.5, height: 1.4),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 14, height: 1.4),
      bodySmall: text.bodySmall?.copyWith(color: AppColors.inkMuted, height: 1.35),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2),
      labelMedium: text.labelMedium?.copyWith(color: AppColors.inkMuted, fontWeight: FontWeight.w500),
      labelSmall: text.labelSmall?.copyWith(
          color: AppColors.inkMuted, fontWeight: FontWeight.w600, letterSpacing: 0.8),
    );

    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

    return base.copyWith(
      textTheme: textTheme,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.maroon,
          foregroundColor: AppColors.ivory,
          disabledBackgroundColor: AppColors.sand,
          minimumSize: const Size(64, 52),
          shape: rounded,
          textStyle: const TextStyle(fontFamily: sans, fontWeight: FontWeight.w600, fontSize: 15.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.maroon,
          minimumSize: const Size(64, 50),
          side: const BorderSide(color: AppColors.maroon, width: 1.2),
          shape: rounded,
          textStyle: const TextStyle(fontFamily: sans, fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.maroon,
          textStyle: const TextStyle(fontFamily: sans, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.maroon,
        foregroundColor: AppColors.ivory,
        extendedTextStyle: TextStyle(fontFamily: sans, fontWeight: FontWeight.w600, fontSize: 15),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.card,
        indicatorColor: AppColors.goldPale,
        elevation: 0,
        height: 70,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? AppColors.maroon : AppColors.inkSoft,
              size: 24,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontFamily: sans,
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
              color: states.contains(WidgetState.selected) ? AppColors.maroon : AppColors.inkMuted,
            )),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.card,
        selectedColor: AppColors.maroon,
        secondarySelectedColor: AppColors.maroon,
        checkmarkColor: AppColors.ivory,
        side: const BorderSide(color: AppColors.border),
        labelStyle: const TextStyle(fontFamily: sans, fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink),
        secondaryLabelStyle: const TextStyle(fontFamily: sans, fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ivory),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? AppColors.maroon : AppColors.card),
          foregroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? AppColors.ivory : AppColors.ink),
          side: const WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
          textStyle: const WidgetStatePropertyAll(
              TextStyle(fontFamily: sans, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.maroon900,
        contentTextStyle: const TextStyle(fontFamily: sans, color: AppColors.ivory),
        actionTextColor: AppColors.goldLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.ivory,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.maroon,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.maroon),
    );
  }

  /// Shared input decoration used by [AppTextField] and dropdowns.
  static InputDecoration input({
    String? label,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? prefixText,
    String? helperText,
    String? errorText,
    bool dense = false,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      prefixText: prefixText,
      helperText: helperText,
      errorText: errorText,
      isDense: dense,
      filled: true,
      fillColor: AppColors.card,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: dense ? 12 : 16),
      labelStyle: const TextStyle(color: AppColors.inkMuted),
      floatingLabelStyle: const TextStyle(color: AppColors.maroon, fontWeight: FontWeight.w600),
      hintStyle: const TextStyle(color: AppColors.inkSoft),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.maroon, 1.6),
      errorBorder: border(AppColors.error),
      focusedErrorBorder: border(AppColors.error, 1.6),
    );
  }
}

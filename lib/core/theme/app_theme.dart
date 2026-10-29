import 'package:flutter/material.dart';

import '../domain/statuses.dart';

class AppColors {
  const AppColors._();

  static const primary = Color(0xff003FB1);
  static const text = Color(0xff191C1D);
  static const lightText = Color(0xff434654);
  static const background = Color(0xffF8F9FA);
  static const surfaceDim = Color(0xffF3F4F5);
  static const surface = Colors.white;
  static const border = Color(0xffDDE1E6);
  static const danger = Color(0xffBA1A1A);
  static const positive = Color(0xff1B7F4B);
  static const attention = Color(0xffA15C00);
  static const waiting = Color(0xff5B4BB7);

  static Color forTone(StatusTone tone) => switch (tone) {
    StatusTone.positive => positive,
    StatusTone.active => primary,
    StatusTone.attention => attention,
    StatusTone.waiting => waiting,
    StatusTone.neutral => lightText,
    StatusTone.negative => danger,
  };

  static IconData iconForTone(StatusTone tone) => switch (tone) {
    StatusTone.positive => Icons.check_circle_outline,
    StatusTone.active => Icons.play_circle_outline,
    StatusTone.attention => Icons.notifications_active_outlined,
    StatusTone.waiting => Icons.hourglass_empty,
    StatusTone.neutral => Icons.history,
    StatusTone.negative => Icons.cancel_outlined,
  };
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary, primary: AppColors.primary, error: AppColors.danger);
  OutlineInputBorder border(Color color) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: color));
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surfaceDim,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w600),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: AppColors.text),
      bodySmall: TextStyle(color: AppColors.lightText),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: border(AppColors.lightText),
      enabledBorder: border(AppColors.lightText),
      focusedBorder: border(AppColors.primary),
      errorBorder: border(AppColors.danger),
      focusedErrorBorder: border(AppColors.danger),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    chipTheme: const ChipThemeData(side: BorderSide(color: AppColors.border)),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

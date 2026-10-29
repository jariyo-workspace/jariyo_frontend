import 'package:flutter/material.dart';

import '../domain/statuses.dart';

/// 디자인 토큰.
///
/// 회색 바탕 위에 테두리 없는 흰 카드를 올리고, 행동은 큰 둥근 버튼 하나로 강조한다.
class AppColors {
  const AppColors._();

  /// 브랜드 색 (로고와 동일)
  static const primary = Color(0xff003FB1);
  static const primarySoft = Color(0xffE6EDFA);
  static const text = Color(0xff191F28);
  static const lightText = Color(0xff6B7684);
  static const mutedText = Color(0xff8B95A1);
  static const background = Color(0xffF2F4F6);
  static const surfaceDim = Color(0xffF2F4F6);
  static const surface = Colors.white;
  static const border = Color(0xffE5E8EB);
  static const danger = Color(0xffD92D20);
  static const positive = Color(0xff0B7A55);
  static const attention = Color(0xffC2410C);
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
    StatusTone.positive => Icons.check_circle_rounded,
    StatusTone.active => Icons.play_circle_rounded,
    StatusTone.attention => Icons.notifications_active_rounded,
    StatusTone.waiting => Icons.hourglass_top_rounded,
    StatusTone.neutral => Icons.history_rounded,
    StatusTone.negative => Icons.cancel_rounded,
  };
}

/// 간격과 모서리
class AppSpace {
  const AppSpace._();

  static const page = 20.0;
  static const cardRadius = 20.0;
  static const buttonRadius = 14.0;
  static const fieldRadius = 14.0;
}

/// 글자 크기 체계
class AppText {
  const AppText._();

  static const display = TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.text, height: 1.35);
  static const title = TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text, height: 1.4);
  static const section = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text);
  static const bodyStrong = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text);
  static const body = TextStyle(fontSize: 15, color: AppColors.text, height: 1.5);
  static const sub = TextStyle(fontSize: 14, color: AppColors.lightText, height: 1.45);
  static const caption = TextStyle(fontSize: 13, color: AppColors.mutedText);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    error: AppColors.danger,
    surface: AppColors.surface,
  );
  OutlineInputBorder field([Color? color, double width = 1.5]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppSpace.fieldRadius),
    borderSide: color == null ? BorderSide.none : BorderSide(color: color, width: width),
  );
  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpace.buttonRadius));
  const buttonText = TextStyle(fontSize: 17, fontWeight: FontWeight.w700);
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      titleTextStyle: TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.w700),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.text, fontSize: 16),
      bodyMedium: TextStyle(color: AppColors.text, fontSize: 15),
      bodySmall: TextStyle(color: AppColors.lightText, fontSize: 13),
      titleMedium: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: AppColors.mutedText),
      border: field(),
      enabledBorder: field(),
      focusedBorder: field(AppColors.primary),
      errorBorder: field(AppColors.danger),
      focusedErrorBorder: field(AppColors.danger),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpace.cardRadius)),
    ),
    listTileTheme: const ListTileThemeData(
      titleTextStyle: TextStyle(fontSize: 16, color: AppColors.text, fontWeight: FontWeight.w500),
      subtitleTextStyle: TextStyle(fontSize: 14, color: AppColors.lightText),
      iconColor: AppColors.lightText,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: AppColors.primary,
      secondarySelectedColor: AppColors.primary,
      side: const BorderSide(color: AppColors.border),
      labelStyle: const TextStyle(fontSize: 14, color: AppColors.text, fontWeight: FontWeight.w500),
      secondaryLabelStyle: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
      checkmarkColor: Colors.white,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1, thickness: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: buttonShape,
        textStyle: buttonText,
        disabledBackgroundColor: const Color(0xffE5E8EB),
        disabledForegroundColor: AppColors.mutedText,
      ),
    ),
    // 보조 버튼은 테두리 대신 옅은 브랜드 색 면으로 구분한다.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: buttonShape,
        textStyle: buttonText,
        side: BorderSide.none,
        backgroundColor: AppColors.primarySoft,
        foregroundColor: AppColors.primary,
        disabledForegroundColor: AppColors.mutedText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: buttonShape,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: const BorderSide(color: AppColors.mutedText, width: 1.5),
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text),
      contentTextStyle: const TextStyle(fontSize: 15, color: AppColors.lightText, height: 1.5),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xff333D4B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primarySoft,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.lightText,
        ),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.primarySoft,
      selectedIconTheme: IconThemeData(color: AppColors.primary),
      selectedLabelTextStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.primary,
        selectedForegroundColor: Colors.white,
        side: const BorderSide(color: AppColors.border),
      ),
    ),
  );
}

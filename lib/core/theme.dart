import 'package:flutter/material.dart';

import 'strings.dart';

/// media-files/data/ui_spec.json 의 color.
class AppColors {
  static const primary = Color(0xFF003FB1);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFDBE1FF);
  static const text = Color(0xFF191C1D);
  static const textSub = Color(0xFF434654);
  static const outline = Color(0xFFC3C5D7);
  static const outlineStrong = Color(0xFF737686);
  static const background = Color(0xFFF8F9FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceContainer = Color(0xFFF3F4F5);
  static const surfaceVariant = Color(0xFFE1E3E4);
  static const success = Color(0xFF0E9F6E);
  static const error = Color(0xFFBA1A1A);
  static const accent = Color(0xFFFD761A);
  static const onAccentContainer = Color(0xFF9D4300);
  static const accentContainer = Color(0xFFFFF7ED);
  static const scrim = Color(0x80000000);

  static const thumbnailGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF003FB1), Color(0xFF3D6FE0)],
  );
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0E2F7A), Color(0xFF003FB1), Color(0xFF3D6FE0)],
    stops: [0, 0.55, 1],
  );
}

class StatusStyle {
  final String label;
  final IconData icon;
  final Color fg;
  final Color bg;

  const StatusStyle(this.label, this.icon, this.fg, this.bg);
}

const _successBg = Color(0x1A0E9F6E);
const _errorBg = Color(0x1ABA1A1A);

const _reservationStatus = {
  'HELD': StatusStyle('예약 확인 중', Icons.hourglass_top, AppColors.onAccentContainer, AppColors.accentContainer),
  'CONFIRMED': StatusStyle('예약 확정', Icons.check_circle, AppColors.success, _successBg),
  'CHECKED_IN': StatusStyle('체크인 완료', Icons.how_to_reg, AppColors.primary, AppColors.primaryContainer),
  'IN_SERVICE': StatusStyle('이용 중', Icons.timelapse, AppColors.primary, AppColors.primaryContainer),
  'COMPLETED': StatusStyle('이용 완료', Icons.task_alt, AppColors.textSub, AppColors.surfaceVariant),
  'CANCELLED': StatusStyle('취소됨', Icons.cancel, AppColors.error, _errorBg),
  'NO_SHOW': StatusStyle('미방문', Icons.person_off, AppColors.error, _errorBg),
  'EXPIRED': StatusStyle('만료됨', Icons.timer_off, AppColors.textSub, AppColors.surfaceVariant),
};

const _storeStatus = {
  'ACTIVE': StatusStyle('운영 중', Icons.check_circle, AppColors.success, _successBg),
  'TEMPORARILY_CLOSED': StatusStyle('임시 휴무', Icons.pause_circle, AppColors.onAccentContainer, AppColors.accentContainer),
  'PREPARING': StatusStyle('준비 중', Icons.construction, AppColors.textSub, AppColors.surfaceVariant),
  'CLOSED': StatusStyle('운영 종료', Icons.block, AppColors.error, _errorBg),
};

const _unknownStatus = StatusStyle(S.unknownStatus, Icons.help_outline, AppColors.textSub, AppColors.surfaceVariant);

StatusStyle reservationStatusStyle(String? status) => _reservationStatus[status] ?? _unknownStatus;

StatusStyle storeStatusStyle(String? status) => _storeStatus[status] ?? _unknownStatus;

String reservationStatusLabel(String? status) => reservationStatusStyle(status).label;

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryContainer,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.textSub,
    outline: AppColors.outline,
    error: AppColors.error,
  );
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppColors.outline),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarHeight: 56,
      foregroundColor: AppColors.text,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.primary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      errorBorder: inputBorder.copyWith(borderSide: const BorderSide(color: AppColors.error, width: 2)),
      focusedErrorBorder: inputBorder.copyWith(borderSide: const BorderSide(color: AppColors.error, width: 2)),
      hintStyle: const TextStyle(color: AppColors.outlineStrong),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: AppColors.scrim,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      barrierColor: AppColors.scrim,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
  );
}

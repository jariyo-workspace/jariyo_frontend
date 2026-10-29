import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../app_nav.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double borderWidth;
  final Color color;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.borderColor,
    this.borderWidth = 1,
    this.color = AppColors.surface,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? AppColors.outline, width: borderWidth),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2)],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// 매장명 첫 글자를 primary 그라데이션 위에 흰 글자로 표시한다.
class Thumbnail extends StatelessWidget {
  final String name;
  final double size;

  const Thumbnail({super.key, required this.name, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: AppColors.thumbnailGradient,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        firstChar(name),
        style: TextStyle(color: AppColors.onPrimary, fontSize: size * 0.4, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final StatusStyle style;
  final Color? background;

  const StatusBadge(this.style, {super.key, this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: background ?? style.bg, borderRadius: BorderRadius.circular(9999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 15, color: style.fg),
          const SizedBox(width: 4),
          Text(style.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: style.fg)),
        ],
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  final String name;
  final double size;

  const Avatar(this.name, {super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
      child: Text(
        firstChar(name),
        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: size * 0.4),
      ),
    );
  }
}

class AppBottomNav extends StatelessWidget {
  /// 0: 매장 탐색, 1: 내 예약
  final int current;

  /// 현재 화면이 해당 탭의 첫 화면인지 여부.
  final bool isRoot;

  const AppBottomNav({super.key, required this.current, this.isRoot = false});

  @override
  Widget build(BuildContext context) {
    Widget item(int index, IconData icon, String label) {
      final active = index == current;
      return Expanded(
        child: Center(
          child: Material(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9999),
            child: InkWell(
              borderRadius: BorderRadius.circular(9999),
              onTap: () {
                if (active && isRoot) return;
                index == 0 ? AppNav.toStores() : AppNav.toMyReservations();
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 120),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 22, color: active ? AppColors.onPrimary : AppColors.textSub),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: active ? AppColors.onPrimary : AppColors.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Color(0x4DC3C5D7))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              item(0, Icons.storefront_outlined, S.navStores),
              item(1, Icons.event_note_outlined, S.navMyReservations),
            ],
          ),
        ),
      ),
    );
  }
}

/// 네트워크 실패·타임아웃·5xx 공통 표시.
class NetworkErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  final bool compact;

  const NetworkErrorView({super.key, required this.onRetry, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(compact ? 12 : 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact) ...[
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(color: AppColors.surfaceVariant, shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off, color: AppColors.textSub),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (compact) ...[const Icon(Icons.wifi_off, size: 18, color: AppColors.textSub), const SizedBox(width: 6)],
              Flexible(
                child: Text(
                  S.networkError,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: compact ? 14 : 16, fontWeight: FontWeight.w700, color: AppColors.text),
                ),
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 4),
            const Text(S.networkErrorSub,
                textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.textSub)),
          ],
          SizedBox(height: compact ? 8 : 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text(S.retry),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              minimumSize: const Size(120, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}

enum BannerTone { error, warning }

class MessageBanner extends StatelessWidget {
  final String title;
  final String? sub;
  final IconData icon;
  final BannerTone tone;

  const MessageBanner({
    super.key,
    required this.title,
    this.sub,
    this.icon = Icons.error,
    this.tone = BannerTone.error,
  });

  @override
  Widget build(BuildContext context) {
    final isError = tone == BannerTone.error;
    final fg = isError ? AppColors.error : AppColors.onAccentContainer;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFF9EAEA) : AppColors.accentContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isError ? const Color(0x4DBA1A1A) : const Color(0x4DFD761A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isError ? AppColors.text : fg)),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(sub!, style: const TextStyle(fontSize: 14, color: AppColors.textSub)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool pill;
  final Color color;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.pill = false,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: loading ? color.withValues(alpha: 0.85) : const Color(0xFFB9BAC4),
          disabledForegroundColor: loading ? AppColors.onPrimary : AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(pill ? 9999 : 8)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
              )
            else if (icon != null)
              Icon(icon, size: 20),
            if (loading || icon != null) const SizedBox(width: 8),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;

  const SecondaryButton({super.key, required this.label, this.onPressed, this.icon, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: onPressed == null ? AppColors.outline : color, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final IconData? icon;
  final int? number;
  final Color iconColor;

  const SectionTitle(this.text, {super.key, this.icon, this.number, this.iconColor = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (number != null)
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
              child: Text('$number',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
            )
          else if (icon != null)
            Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class Loader extends StatelessWidget {
  const Loader({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

/// 회색 바탕 안내 상자.
class InfoBox extends StatelessWidget {
  final Widget child;

  const InfoBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(12)),
      child: child,
    );
  }
}

class Bullet extends StatelessWidget {
  final String text;

  const Bullet(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14, color: AppColors.text)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.text))),
        ],
      ),
    );
  }
}

void showAppSnackBar(BuildContext context, String message, {IconData? icon, Color iconColor = AppColors.success}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    duration: AppConfig.snackBarDuration,
    backgroundColor: const Color(0xFF2E3132),
    content: Row(
      children: [
        if (icon != null) ...[Icon(icon, color: iconColor), const SizedBox(width: 12)],
        Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 15))),
      ],
    ),
  ));
}

/// 시트 상단 손잡이.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 20),
        width: 36,
        height: 4,
        decoration: BoxDecoration(color: AppColors.outline, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../domain/statuses.dart';
import '../error/app_failure.dart';
import '../theme/app_theme.dart';

/// 상태 배지. 색상만으로 구분하지 않도록 아이콘과 문구를 함께 표시한다.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.tone, this.large = false});

  final String label;
  final StatusTone tone;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forTone(tone);
    return Semantics(
      label: '상태: $label',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: large ? 12 : 8, vertical: large ? 6 : 3),
        decoration: BoxDecoration(color: color.withAlpha(24), borderRadius: BorderRadius.circular(100)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppColors.iconForTone(tone), size: large ? 18 : 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: large ? 14 : 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

enum AppButtonVariant { primary, secondary, danger, text }

/// 요청 중에는 비활성화되고 로딩 문구를 표시하는 버튼.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.loadingLabel,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final String? loadingLabel;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = !loading && onPressed != null;
    final child = loading
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: variant == AppButtonVariant.primary || variant == AppButtonVariant.danger
                      ? Colors.white
                      : AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(child: Text(loadingLabel ?? '요청을 처리하고 있어요', overflow: TextOverflow.ellipsis)),
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 6)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );
    final minSize = expand ? const Size.fromHeight(50) : const Size(0, 44);
    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(minimumSize: minSize),
        child: child,
      ),
      AppButtonVariant.danger => FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(minimumSize: minSize, backgroundColor: AppColors.danger),
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(minimumSize: minSize),
        child: child,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: enabled ? onPressed : null,
        style: TextButton.styleFrom(minimumSize: minSize),
        child: child,
      ),
    };
    return button;
  }
}

/// 화면 하단에 고정되는 주요 행동 영역.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 8), children[i]],
          ],
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: const TextStyle(color: AppColors.lightText)),
          ],
        ],
      ),
    );
  }
}

/// 오류 화면. 단순한 "오류 발생" 대신 현재 상태가 안전한지와 다음 행동을 안내한다.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.failure, this.onRetry, this.secondaryLabel, this.onSecondary});

  final AppFailure failure;
  final VoidCallback? onRetry;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final icon = switch (failure.kind) {
      FailureKind.forbidden => Icons.lock_outline,
      FailureKind.notFound => Icons.search_off,
      FailureKind.network || FailureKind.server || FailureKind.unknownOutcome => Icons.wifi_off,
      _ => Icons.info_outline,
    };
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.lightText),
            const SizedBox(height: 16),
            Text(
              failure.message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.text, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 20),
            if (onRetry != null)
              AppButton(label: '다시 시도', onPressed: onRetry, expand: false, variant: AppButtonVariant.secondary),
            if (onSecondary != null && secondaryLabel != null) ...[
              const SizedBox(height: 8),
              AppButton(label: secondaryLabel!, onPressed: onSecondary, expand: false, variant: AppButtonVariant.text),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.lightText),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.lightText)),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              AppButton(label: actionLabel!, onPressed: onAction, expand: false),
            ],
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 8),
              AppButton(
                label: secondaryLabel!,
                onPressed: onSecondary,
                expand: false,
                variant: AppButtonVariant.secondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 기존 데이터를 유지한 채 갱신에 실패했을 때 보여주는 안내 띠.
class StaleBanner extends StatelessWidget {
  const StaleBanner({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.attention.withAlpha(24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        child: Row(
          children: [
            const Icon(Icons.sync_problem, size: 18, color: AppColors.attention),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(color: AppColors.attention))),
            TextButton(onPressed: onRetry, child: const Text('새로고침')),
          ],
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, required this.child, this.trailing, this.padding});

  final String? title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value, this.emphasize = false, this.labelWidth = 96});

  final String label;
  final String value;
  final bool emphasize;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: labelWidth, child: Text(label, style: const TextStyle(color: AppColors.lightText))),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.text,
                fontWeight: emphasize ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 화면 상단에서 현재 상태를 가장 먼저 보여주는 영역.
class StatusHeader extends StatelessWidget {
  const StatusHeader({super.key, required this.title, required this.tone, this.subtitle, this.badge});

  final String title;
  final String? subtitle;
  final StatusTone tone;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forTone(tone);
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge != null) ...[StatusBadge(label: badge!, tone: tone), const SizedBox(height: 10)],
            Row(
              children: [
                Icon(AppColors.iconForTone(tone), color: color, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text),
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: const TextStyle(fontSize: 15, color: AppColors.lightText, height: 1.4)),
            ],
          ],
        ),
      ),
    );
  }
}

class NoticeBox extends StatelessWidget {
  const NoticeBox({super.key, required this.message, this.icon = Icons.info_outline, this.color});

  final String message;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.lightText;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.withAlpha(16), borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: c, height: 1.4))),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// 숫자 입력용 간단 스테퍼.
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 20,
    this.unit = '',
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '줄이기',
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$value$unit', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        IconButton(
          tooltip: '늘리기',
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

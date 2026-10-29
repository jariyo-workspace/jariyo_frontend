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
        padding: EdgeInsets.symmetric(horizontal: large ? 12 : 8, vertical: large ? 6 : 4),
        decoration: BoxDecoration(color: color.withAlpha(22), borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppColors.iconForTone(tone), size: large ? 16 : 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: large ? 14 : 12, fontWeight: FontWeight.w700),
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
    final onDark = variant == AppButtonVariant.primary || variant == AppButtonVariant.danger;
    final child = loading
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: onDark ? Colors.white : AppColors.primary),
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
    final minSize = expand ? const Size.fromHeight(56) : const Size(0, 44);
    final compactText = expand ? null : const TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
    final compactPadding = expand ? null : const EdgeInsets.symmetric(horizontal: 16);
    return switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(minimumSize: minSize, textStyle: compactText, padding: compactPadding),
        child: child,
      ),
      AppButtonVariant.danger => FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          minimumSize: minSize,
          backgroundColor: AppColors.danger,
          textStyle: compactText,
          padding: compactPadding,
        ),
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(minimumSize: minSize, textStyle: compactText, padding: compactPadding),
        child: child,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: enabled ? onPressed : null,
        style: TextButton.styleFrom(minimumSize: minSize, padding: compactPadding),
        child: child,
      ),
    };
  }
}

/// 화면 하단에 고정되는 주요 행동 영역.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 12, AppSpace.page, 12),
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
          const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
          if (message != null) ...[const SizedBox(height: 16), Text(message!, style: AppText.sub)],
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
      FailureKind.forbidden => Icons.lock_outline_rounded,
      FailureKind.notFound => Icons.search_off_rounded,
      FailureKind.network || FailureKind.server || FailureKind.unknownOutcome => Icons.wifi_off_rounded,
      _ => Icons.info_outline_rounded,
    };
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconBubble(icon: icon),
            const SizedBox(height: 20),
            Text(failure.message, textAlign: TextAlign.center, style: AppText.body),
            const SizedBox(height: 24),
            if (onRetry != null) AppButton(label: '다시 시도', onPressed: onRetry, expand: false),
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

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 72,
    height: 72,
    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
    child: Icon(icon, size: 34, color: AppColors.mutedText),
  );
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
            _IconBubble(icon: icon),
            const SizedBox(height: 20),
            Text(title, textAlign: TextAlign.center, style: AppText.bodyStrong),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!, textAlign: TextAlign.center, style: AppText.sub),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              AppButton(label: actionLabel!, onPressed: onAction, expand: false),
            ],
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 8),
              AppButton(label: secondaryLabel!, onPressed: onSecondary, expand: false, variant: AppButtonVariant.text),
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
      color: const Color(0xffFFF4E5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.page, 4, 8, 4),
        child: Row(
          children: [
            const Icon(Icons.sync_problem_rounded, size: 18, color: AppColors.attention),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(color: AppColors.attention, fontSize: 14))),
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
        padding: padding ?? const EdgeInsets.all(AppSpace.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(child: Text(title!, style: AppText.bodyStrong)),
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

/// 라벨은 왼쪽, 값은 오른쪽에 두는 정보 행.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value, this.emphasize = false, this.labelWidth = 96});

  final String label;
  final String value;
  final bool emphasize;

  /// 라벨이 길어도 줄바꿈되지 않도록 확보하는 최소 폭
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: labelWidth),
            child: Text(label, style: const TextStyle(color: AppColors.lightText, fontSize: 15)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
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
        padding: const EdgeInsets.all(AppSpace.page),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppSpace.cardRadius)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: color.withAlpha(24), shape: BoxShape.circle),
              child: Icon(AppColors.iconForTone(tone), color: color, size: 26),
            ),
            const SizedBox(height: 14),
            if (badge != null) ...[StatusBadge(label: badge!, tone: tone), const SizedBox(height: 8)],
            Text(title, style: AppText.title),
            if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: AppText.sub)],
          ],
        ),
      ),
    );
  }
}

class NoticeBox extends StatelessWidget {
  const NoticeBox({super.key, required this.message, this.icon = Icons.info_outline_rounded, this.color});

  final String message;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.lightText;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color == null ? Colors.white : c.withAlpha(18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: c, fontSize: 14, height: 1.45))),
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
      padding: const EdgeInsets.fromLTRB(4, 24, 0, 10),
      child: Row(
        children: [
          Expanded(child: Text(text, style: AppText.section)),
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
    Widget button(IconData icon, String tooltip, VoidCallback? onPressed) => IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(backgroundColor: AppColors.background),
      icon: Icon(icon, size: 20),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(Icons.remove_rounded, '줄이기', value > min ? () => onChanged(value - 1) : null),
        SizedBox(
          width: 56,
          child: Text('$value$unit', textAlign: TextAlign.center, style: AppText.bodyStrong),
        ),
        button(Icons.add_rounded, '늘리기', value < max ? () => onChanged(value + 1) : null),
      ],
    );
  }
}

/// 둥근 사각형 안의 아이콘. 목록 앞머리에 쓴다.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, this.color = AppColors.primary, this.size = 44});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color.withAlpha(22), borderRadius: BorderRadius.circular(size * 0.32)),
    child: Icon(icon, color: color, size: size * 0.52),
  );
}

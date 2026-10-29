import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 복구가 어려운 행동(취소, 노쇼, 순서 변경 등) 전에 사용하는 확인 모달.
///
/// 어떤 작업인지, 미치는 영향, 되돌릴 수 있는지를 [message]에 포함한다.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = '닫기',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message, style: const TextStyle(height: 1.5)),
      actions: [
        DialogButtons(
          cancelLabel: cancelLabel,
          confirmLabel: confirmLabel,
          destructive: destructive,
          onCancel: () => Navigator.pop(context, false),
          onConfirm: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// 사유를 입력받는 모달. [presets]를 주면 선택지와 직접 입력을 함께 제공한다.
Future<String?> showReasonDialog(
  BuildContext context, {
  required String title,
  String? message,
  String hint = '사유를 입력해 주세요',
  List<String> presets = const [],
  String confirmLabel = '확인',
  String cancelLabel = '닫기',
  bool destructive = false,
  int maxLength = 255,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _ReasonDialog(
      title: title,
      message: message,
      hint: hint,
      presets: presets,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      maxLength: maxLength,
    ),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.message,
    required this.hint,
    required this.presets,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
    required this.maxLength,
  });

  final String title;
  final String? message;
  final String hint;
  final List<String> presets;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final int maxLength;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();
  String? _preset;

  bool get _custom => widget.presets.isEmpty || _preset == _directInput;
  static const _directInput = '직접 입력';

  String get _reason => _custom ? _controller.text.trim() : (_preset ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message != null) ...[
              Text(widget.message!, style: const TextStyle(height: 1.5)),
              const SizedBox(height: 12),
            ],
            if (widget.presets.isNotEmpty)
              RadioGroup<String>(
                groupValue: _preset,
                onChanged: (value) => setState(() => _preset = value),
                child: Column(
                  children: [
                    for (final preset in [...widget.presets, _directInput])
                      RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: preset,
                        title: Text(preset),
                      ),
                  ],
                ),
              ),
            if (_custom)
              TextField(
                controller: _controller,
                autofocus: widget.presets.isEmpty,
                maxLength: widget.maxLength,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(hintText: widget.hint),
                onChanged: (_) => setState(() {}),
              ),
          ],
        ),
      ),
      actions: [
        DialogButtons(
          cancelLabel: widget.cancelLabel,
          confirmLabel: widget.confirmLabel,
          destructive: widget.destructive,
          onCancel: () => Navigator.pop(context),
          onConfirm: _reason.isEmpty ? null : () => Navigator.pop(context, _reason),
        ),
      ],
    );
  }
}

/// 선택 목록 바텀시트.
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<(T value, String label, String? description)> options,
  T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final (value, label, description) in options)
                    ListTile(
                      title: Text(label),
                      subtitle: description == null ? null : Text(description),
                      trailing: value == selected ? const Icon(Icons.check, color: AppColors.primary) : null,
                      onTap: () => Navigator.pop(context, value),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 매장 현지 시각 선택. `HH:mm`을 돌려준다.
Future<String?> pickHm(BuildContext context, {String? initial, String? helpText}) async {
  final parts = (initial ?? '09:00').split(':');
  final picked = await showTimePicker(
    context: context,
    helpText: helpText,
    initialTime: TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts.elementAtOrNull(1) ?? '') ?? 0),
  );
  if (picked == null) return null;
  return '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
}

/// 확인 모달 하단의 [취소 | 확인] 버튼 쌍.
class DialogButtons extends StatelessWidget {
  const DialogButtons({
    super.key,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.destructive = false,
  });

  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback? onConfirm;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    const size = Size(0, 52);
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: size,
              backgroundColor: AppColors.background,
              foregroundColor: AppColors.lightText,
            ),
            onPressed: onCancel,
            child: Text(cancelLabel),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: size,
              backgroundColor: destructive ? AppColors.danger : null,
            ),
            onPressed: onConfirm,
            child: Text(confirmLabel),
          ),
        ),
      ],
    );
  }
}

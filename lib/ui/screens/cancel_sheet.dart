import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/api_client.dart';
import '../widgets/common.dart';

enum CancelResultKind { success, conflict, deadlinePassed }

class CancelResult {
  final CancelResultKind kind;
  final String? message;

  const CancelResult(this.kind, {this.message});
}

class CancelSheet extends StatefulWidget {
  final String reservationId;

  /// 요청이 끝나기 전에 시트가 닫힌 경우, 서버가 응답하면 호출된다.
  final VoidCallback? onClosedResult;

  const CancelSheet({super.key, required this.reservationId, this.onClosedResult});

  @override
  State<CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<CancelSheet> {
  final _reason = TextEditingController();
  String? _fieldError;
  String? _error;
  bool _networkFailed = false;
  bool _submitting = false;

  // 같은 사유의 재시도에는 같은 키를 쓰고, 사유가 바뀌면 새 키를 만든다.
  String? _key;
  String? _keyReason;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final reason = _reason.text.trim();
    if (reason.isEmpty || reason.length > 255) {
      setState(() => _fieldError = S.csReasonRequired);
      return;
    }
    if (_key == null || _keyReason != reason) {
      _key = uuidV4();
      _keyReason = reason;
    }
    setState(() {
      _fieldError = null;
      _error = null;
      _networkFailed = false;
      _submitting = true;
    });
    try {
      await Api.cancelReservation(widget.reservationId, reason, _key!);
      if (!mounted) return widget.onClosedResult?.call();
      Navigator.of(context).pop(const CancelResult(CancelResultKind.success));
    } on SessionExpiredException {
      return;
    } on ApiException catch (e) {
      if (!mounted) return widget.onClosedResult?.call();
      switch (e.code) {
        case 'RESERVATION_ALREADY_CANCELLED':
        case 'RESERVATION_INVALID_STATE':
          Navigator.of(context).pop(CancelResult(CancelResultKind.conflict, message: e.message));
        case 'RESERVATION_CANCELLATION_DEADLINE_PASSED':
          Navigator.of(context).pop(CancelResult(CancelResultKind.deadlinePassed, message: e.message));
        default:
          if (e.code == 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_REQUEST') _key = null;
          setState(() {
            _submitting = false;
            _error = e.message.isNotEmpty ? e.message : S.networkError;
          });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _networkFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 로딩 중에도 Back은 막지 않는다. 닫은 뒤 도착한 결과는 onClosedResult로 상세에 알린다.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const Text(
              S.csTitle,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text),
            ),
            const SizedBox(height: 12),
            const Text(
              '${S.csBody1}\n${S.csBody2}',
              style: TextStyle(fontSize: 15, height: 1.5, color: AppColors.textSub),
            ),
            const SizedBox(height: 20),
            const Text(
              S.csReason,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reason,
              maxLength: 255,
              minLines: 3,
              maxLines: 5,
              enabled: !_submitting,
              onChanged: (_) {
                if (_fieldError != null) setState(() => _fieldError = null);
              },
              decoration: InputDecoration(
                hintText: S.csReasonRequired,
                enabledBorder: _fieldError == null
                    ? null
                    : OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.error, width: 2),
                      ),
              ),
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) =>
                  Text('$currentLength / $maxLength', style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
            ),
            if (_fieldError != null)
              Row(
                children: [
                  const Icon(Icons.error, size: 16, color: AppColors.error),
                  const SizedBox(width: 4),
                  Text(_fieldError!, style: const TextStyle(fontSize: 13, color: AppColors.error)),
                ],
              ),
            if (_error != null) ...[const SizedBox(height: 12), MessageBanner(title: _error!)],
            if (_networkFailed) ...[
              const SizedBox(height: 12),
              const MessageBanner(title: S.networkError, sub: S.networkErrorSub, icon: Icons.wifi_off),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: S.csKeep,
                    onPressed: _submitting ? null : () => Navigator.of(context).maybePop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _networkFailed
                      ? PrimaryButton(label: S.retry, icon: Icons.refresh, color: AppColors.error, onPressed: _submit)
                      : PrimaryButton(
                          label: S.csConfirm,
                          color: AppColors.error,
                          loading: _submitting,
                          onPressed: _submit,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

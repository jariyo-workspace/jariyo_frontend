import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../widgets/common.dart';
import 'store_detail_screen.dart' show policyLines;

enum ConfirmResultKind { success, conflict, checkMine }

class ConfirmResult {
  final ConfirmResultKind kind;
  final String? reservationId;
  final String? code;
  final String? message;

  const ConfirmResult(this.kind, {this.reservationId, this.code, this.message});
}

class ConfirmSheet extends StatefulWidget {
  final StoreDetail store;
  final String serviceId, serviceName, staffId, staffName, startAt, serviceEndAt;
  final String? note;
  final String Function() obtainKey;
  final VoidCallback discardKey;

  const ConfirmSheet({
    super.key,
    required this.store,
    required this.serviceId,
    required this.serviceName,
    required this.staffId,
    required this.staffName,
    required this.startAt,
    required this.serviceEndAt,
    required this.note,
    required this.obtainKey,
    required this.discardKey,
  });

  @override
  State<ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends State<ConfirmSheet> {
  bool _agreed = false;
  bool _submitting = false;
  bool _unknown = false;
  String? _error;

  Future<void> _submit() async {
    if (_submitting || !_agreed) return;
    setState(() {
      _submitting = true;
      _unknown = false;
      _error = null;
    });
    try {
      final id = await Api.createReservation(
        idempotencyKey: widget.obtainKey(),
        storeId: widget.store.id,
        serviceId: widget.serviceId,
        staffId: widget.staffId,
        startAt: widget.startAt,
        customerNote: widget.note,
      );
      if (!mounted) return;
      Navigator.of(context).pop(ConfirmResult(ConfirmResultKind.success, reservationId: id));
    } on SessionExpiredException {
      // 로그인 화면으로 이동하며 시트는 폐기된다.
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'RESERVATION_SLOT_ALREADY_TAKEN' || e.code == 'STAFF_NOT_AVAILABLE') {
        Navigator.of(context).pop(ConfirmResult(ConfirmResultKind.conflict, code: e.code, message: e.message));
        return;
      }
      if (e.code == 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_REQUEST') widget.discardKey();
      setState(() {
        _submitting = false;
        _error = e.message.isNotEmpty ? e.message : S.networkError;
      });
    } catch (_) {
      // 타임아웃·네트워크 실패·5xx: 결과를 알 수 없다. 자동 재시도하지 않는다.
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _unknown = true;
      });
    }
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: const TextStyle(fontSize: 15, color: AppColors.textSub)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final policy = widget.store.policy;
    final lines = policy == null ? const <String>[] : policyLines(policy);
    return PopScope(
      canPop: !_submitting,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              const Text(S.titleConfirm,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text)),
              const SizedBox(height: 16),
              const Text(S.confirmSummary,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSub, letterSpacing: 0.6)),
              const SizedBox(height: 8),
              AppCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Thumbnail(name: widget.store.name, size: 48),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.store.name,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
                              Text(widget.serviceName,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _row(S.confirmService, widget.serviceName),
                    _row(S.confirmStaff, widget.staffName),
                    _row(S.confirmDateTime, formatDateTime(widget.startAt), bold: true),
                    _row(S.confirmEnd, formatTimeOnly(widget.serviceEndAt)),
                    const Divider(height: 20, color: AppColors.outline),
                    _row(S.note, widget.note ?? S.none),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Material(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _submitting ? null : () => setState(() => _agreed = !_agreed),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _agreed,
                          onChanged: _submitting ? null : (v) => setState(() => _agreed = v ?? false),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(S.confirmAgree,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                                for (final line in lines)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(line, style: const TextStyle(fontSize: 14, color: AppColors.textSub)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                MessageBanner(title: _error!),
                const SizedBox(height: 16),
              ],
              if (_unknown) ...[
                const MessageBanner(title: S.confirmUnknown, sub: S.confirmUnknownSub, icon: Icons.help),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: S.confirmCheckMine,
                  icon: Icons.event_note_outlined,
                  onPressed: () => Navigator.of(context).pop(const ConfirmResult(ConfirmResultKind.checkMine)),
                ),
                const SizedBox(height: 12),
                SecondaryButton(label: S.retry, icon: Icons.refresh, onPressed: _submit),
              ] else ...[
                PrimaryButton(
                  label: _submitting ? S.confirmSubmitting : S.confirmSubmit,
                  icon: Icons.check_circle,
                  loading: _submitting,
                  onPressed: _agreed ? _submit : null,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: TextButton(
                    onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(foregroundColor: AppColors.textSub),
                    child: const Text(S.close, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

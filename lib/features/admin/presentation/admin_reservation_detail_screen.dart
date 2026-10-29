import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/statuses.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../../core/network/idempotency.dart';
import '../../../core/presentation/view_model.dart';
import '../../../core/realtime/refresh_bus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_time_format.dart';
import '../../../core/utils/external_links.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/view_model_scope.dart';
import '../domain/admin_entities.dart';
import '../domain/admin_operation_usecases.dart';
import '../domain/admin_repositories.dart';
import 'admin_common.dart';

class AdminReservationViewModel extends LoadableViewModel<AdminReservation> {
  AdminReservationViewModel(this.storeId, this.reservationId, AdminOperationRepository repository, this._bus)
    : _get = GetStoreReservation(repository),
      _checkIn = CheckInStoreReservation(repository),
      _start = StartService(repository),
      _complete = CompleteService(repository),
      _noShow = MarkReservationNoShow(repository),
      _cancel = CancelStoreReservation(repository),
      _reschedule = RescheduleReservation(repository),
      _assign = AssignReservationStaff(repository) {
    listenTopics(_bus, {RefreshTopic.adminReservations}, refresh);
  }

  final String storeId;
  final String reservationId;
  final RefreshBus _bus;
  final GetStoreReservation _get;
  final CheckInStoreReservation _checkIn;
  final StartService _start;
  final CompleteService _complete;
  final MarkReservationNoShow _noShow;
  final CancelStoreReservation _cancel;
  final RescheduleReservation _reschedule;
  final AssignReservationStaff _assign;
  final _keys = <String, IdempotencyKeyHolder>{};

  @override
  Future<AdminReservation> fetch() => _get(storeId, reservationId);

  bool get canComplete => _complete.canComplete(reservationId);

  /// 상태 변경 명령 공통 처리: 멱등성 키, 무효화, 상태 충돌 시 재조회
  Future<bool> _command(String action, Object request, Future<void> Function(String key) task, {String? success}) {
    final holder = _keys.putIfAbsent(action, IdempotencyKeyHolder.new);
    final key = holder.keyFor(request);
    return runAction(
      action,
      () async {
        await task(key);
        holder.settle();
        _bus.emit({...RefreshBus.afterAdminReservationChanged, ...RefreshBus.afterServiceSessionChanged});
        if (success != null) AppMessenger.show(success);
        await refresh();
      },
      onFailure: (failure) {
        if (failure.kind != FailureKind.unknownOutcome) holder.settle();
        if (failure.isStateConflict || failure.kind == FailureKind.unknownOutcome) {
          AppMessenger.show(
            failure.kind == FailureKind.unknownOutcome ? '처리 결과를 확인하지 못했어요. 최신 상태를 다시 불러올게요.' : failure.message,
          );
          refresh();
          return true;
        }
        return false;
      },
    );
  }

  Future<bool> checkIn() => _command(
    'checkIn',
    {'id': reservationId},
    (key) => _checkIn(storeId, reservationId, idempotencyKey: key),
    success: '체크인을 처리했어요.',
  );

  Future<bool> startService(String staffId) => _command(
    'start',
    {'id': reservationId, 'staff': staffId},
    (key) => _start.reservation(storeId, reservationId, staffId: staffId, idempotencyKey: key),
    success: '서비스를 시작했어요.',
  );

  Future<bool> completeService(String? note) => _command(
    'complete',
    {'id': reservationId},
    (key) => _complete(storeId, reservationId, note: note, idempotencyKey: key),
    success: '서비스를 완료했어요.',
  );

  Future<bool> markNoShow(String reason) => _command(
    'noShow',
    {'id': reservationId, 'reason': reason},
    (key) => _noShow(storeId, reservationId, reason: reason, idempotencyKey: key),
    success: '노쇼로 처리했어요.',
  );

  Future<bool> cancel(String reasonCode, String reason) => _command(
    'cancel',
    {'id': reservationId, 'code': reasonCode, 'reason': reason},
    (key) => _cancel(storeId, reservationId, reasonCode: reasonCode, reason: reason, idempotencyKey: key),
    success: '예약을 취소했어요.',
  );

  Future<bool> reschedule({required String staffId, required String startAt, required String reason, required bool notify}) =>
      _command(
        'reschedule',
        {'id': reservationId, 'staff': staffId, 'startAt': startAt, 'reason': reason},
        (key) => _reschedule(
          storeId,
          reservationId,
          staffId: staffId,
          startAt: startAt,
          reason: reason,
          sendNotification: notify,
          idempotencyKey: key,
        ),
        success: '예약 시간을 변경했어요.',
      );

  Future<bool> assignStaff(String staffId, String reason) => _command(
    'assign',
    {'id': reservationId, 'staff': staffId, 'reason': reason},
    (key) => _assign(storeId, reservationId, staffId: staffId, reason: reason, idempotencyKey: key),
    success: '담당 직원을 변경했어요.',
  );
}

/// A-04 운영자 예약 상세 (단독 화면)
class AdminReservationDetailScreen extends StatelessWidget {
  const AdminReservationDetailScreen({super.key, required this.storeId, required this.reservationId});

  final String storeId;
  final String reservationId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('예약 상세')),
      body: AdminReservationDetailView(storeId: storeId, reservationId: reservationId),
    );
  }
}

/// 넓은 화면에서는 캘린더 옆 상세 패널로도 사용한다.
class AdminReservationDetailView extends StatelessWidget {
  const AdminReservationDetailView({super.key, required this.storeId, required this.reservationId});

  final String storeId;
  final String reservationId;

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<AdminReservationViewModel>(
      key: ValueKey(reservationId),
      create: () => AdminReservationViewModel(
        storeId,
        reservationId,
        GetIt.I<AdminOperationRepository>(),
        GetIt.I<RefreshBus>(),
      ),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => LoadableBody<AdminReservation>(
        vm: vm,
        builder: (context, r) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.customerName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                ),
                StatusBadge(label: r.status.label, tone: r.status.tone, large: true),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [StatusBadge(label: r.checkInStatus.label, tone: r.checkInStatus.tone)],
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: '기본 정보',
              child: Column(
                children: [
                  InfoRow(label: '연락처', value: r.customerPhone ?? '-'),
                  InfoRow(label: '서비스', value: r.serviceName),
                  InfoRow(label: '담당 직원', value: r.staffName),
                  InfoRow(label: '예약 시간', value: '${formatDateTime(r.startAt)} – ${formatTime(r.serviceEndAt)}', emphasize: true),
                  InfoRow(label: '인원', value: '${r.partySize}명'),
                  if (r.source != ReservationSource.unknown) InfoRow(label: '예약 경로', value: r.source.label),
                  InfoRow(label: '요청사항', value: r.customerNote ?? '-'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ActionPanel(vm: vm, reservation: r, storeId: storeId),
            const SizedBox(height: 12),
            SectionCard(
              title: '상태 이력',
              child: r.timeline.isEmpty
                  ? const Text('아직 변경 기록이 없어요.', style: TextStyle(color: AppColors.lightText))
                  : Column(
                      children: [
                        for (final (time, label) in r.timeline)
                          InfoRow(
                            label: '${formatShortCalendarDate(toStoreTime(time))} ${formatTime(time)}',
                            value: label,
                            labelWidth: 136,
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({required this.vm, required this.reservation, required this.storeId});

  final AdminReservationViewModel vm;
  final AdminReservation reservation;
  final String storeId;

  Future<void> _startService(BuildContext context) async {
    final staff = await pickStaff(context, storeId, title: '서비스를 진행할 직원', preferName: reservation.staffName);
    if (staff != null) await vm.startService(staff.id);
  }

  Future<void> _complete(BuildContext context) async {
    final note = await showReasonDialog(
      context,
      title: '서비스를 완료할까요?',
      message: '완료 처리 후에는 되돌릴 수 없어요.',
      hint: '완료 메모',
      presets: const ['정상 완료'],
      confirmLabel: '서비스 완료',
      maxLength: 1000,
    );
    if (note != null) await vm.completeService(note);
  }

  Future<void> _noShow(BuildContext context) async {
    final reason = await showReasonDialog(
      context,
      title: '이 예약을 노쇼로 처리할까요?',
      message: '고객이 매장에 도착하지 않았는지 다시 확인해 주세요.\n노쇼 처리는 되돌릴 수 없어요.',
      presets: const ['예약 시간 이후 연락 없이 미방문', '고객이 방문하지 않겠다고 연락함'],
      confirmLabel: '노쇼 처리',
      destructive: true,
    );
    if (reason != null) await vm.markNoShow(reason);
  }

  Future<void> _cancel(BuildContext context) async {
    const codes = {
      '고객 요청': 'CUSTOMER_REQUEST',
      '매장 일정 변경': 'STORE_SCHEDULE_CHANGED',
      '담당 직원 사정': 'STAFF_UNAVAILABLE',
    };
    final reason = await showReasonDialog(
      context,
      title: '예약을 취소할까요?',
      message: '고객에게 취소 안내가 전송되고, 취소 후에는 되돌릴 수 없어요.',
      presets: codes.keys.toList(),
      confirmLabel: '예약 취소',
      cancelLabel: '예약 유지',
      destructive: true,
    );
    if (reason != null) await vm.cancel(codes[reason] ?? 'OTHER', reason);
  }

  Future<void> _assign(BuildContext context) async {
    final staff = await pickStaff(context, storeId, title: '새 담당 직원', preferName: reservation.staffName);
    if (staff == null || !context.mounted) return;
    final reason = await showReasonDialog(
      context,
      title: '담당 직원을 ${staff.displayName}(으)로 변경할까요?',
      presets: const ['근무 일정 변경', '고객 요청'],
      confirmLabel: '변경',
    );
    if (reason != null) await vm.assignStaff(staff.id, reason);
  }

  Future<void> _reschedule(BuildContext context) async {
    final staff = await pickStaff(context, storeId, title: '변경 후 담당 직원', preferName: reservation.staffName);
    if (staff == null || !context.mounted) return;
    final current = toStoreTime(reservation.startAt);
    final date = await showDatePicker(
      context: context,
      helpText: '변경할 날짜',
      initialDate: DateTime(current.year, current.month, current.day),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (date == null || !context.mounted) return;
    final hm = await pickHm(context, initial: hmOf(current.hour, current.minute), helpText: '변경할 시간');
    if (hm == null || !context.mounted) return;
    final parts = hm.split(':');
    final newStart = storeIso(DateTime.utc(date.year, date.month, date.day), int.parse(parts[0]), int.parse(parts[1]));
    final reason = await showReasonDialog(
      context,
      title: '예약 시간을 변경할까요?',
      message:
          '기존 시간: ${formatDateTime(reservation.startAt)}\n'
          '변경 시간: ${formatDateTime(DateTime.parse(newStart))}\n'
          '담당 직원: ${staff.displayName}\n\n'
          '고객에게 변경 안내가 전송됩니다.',
      presets: const ['고객 요청', '매장 일정 변경'],
      confirmLabel: '변경',
    );
    if (reason == null) return;
    final ok = await vm.reschedule(staffId: staff.id, startAt: newStart, reason: reason, notify: true);
    if (!ok && context.mounted) AppMessenger.show('선택한 시간에 예약할 수 없어요. 다른 시간을 선택해 주세요.');
  }

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final buttons = <Widget>[
      if (r.canCheckIn)
        AppButton(label: '체크인 처리', icon: Icons.how_to_reg, loading: vm.isBusy('checkIn'), onPressed: vm.checkIn),
      if (r.canStartService)
        AppButton(label: '서비스 시작', icon: Icons.play_arrow, loading: vm.isBusy('start'), onPressed: () => _startService(context)),
      if (r.canComplete) ...[
        AppButton(
          label: '서비스 완료',
          icon: Icons.check,
          loading: vm.isBusy('complete'),
          onPressed: vm.canComplete ? () => _complete(context) : null,
        ),
        if (!vm.canComplete)
          const Text(
            '이 기기에서 시작한 서비스가 아니에요. 서비스를 시작한 기기에서 완료해 주세요.',
            style: TextStyle(color: AppColors.lightText, fontSize: 13),
          ),
      ],
      if (r.canReschedule || r.canAssignStaff)
        Row(
          children: [
            if (r.canReschedule)
              Expanded(
                child: AppButton(
                  label: '시간 변경',
                  variant: AppButtonVariant.secondary,
                  loading: vm.isBusy('reschedule'),
                  onPressed: () => _reschedule(context),
                ),
              ),
            if (r.canReschedule && r.canAssignStaff) const SizedBox(width: 8),
            if (r.canAssignStaff)
              Expanded(
                child: AppButton(
                  label: '담당자 변경',
                  variant: AppButtonVariant.secondary,
                  loading: vm.isBusy('assign'),
                  onPressed: () => _assign(context),
                ),
              ),
          ],
        ),
      if (r.canCancel || r.canMarkNoShow)
        Row(
          children: [
            if (r.canCancel)
              Expanded(
                child: AppButton(
                  label: '예약 취소',
                  variant: AppButtonVariant.secondary,
                  loading: vm.isBusy('cancel'),
                  onPressed: () => _cancel(context),
                ),
              ),
            if (r.canCancel && r.canMarkNoShow) const SizedBox(width: 8),
            if (r.canMarkNoShow)
              Expanded(
                child: AppButton(
                  label: '노쇼 처리',
                  variant: AppButtonVariant.danger,
                  loading: vm.isBusy('noShow'),
                  onPressed: () => _noShow(context),
                ),
              ),
          ],
        ),
      if (r.customerPhone != null)
        AppButton(
          label: '고객에게 연락',
          icon: Icons.call_outlined,
          variant: AppButtonVariant.text,
          onPressed: () => callPhone(r.customerPhone),
        ),
    ];
    if (buttons.isEmpty) {
      return const NoticeBox(message: '조회만 가능한 예약이에요.');
    }
    return SectionCard(
      title: '처리',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[if (i > 0) const SizedBox(height: 8), buttons[i]],
        ],
      ),
    );
  }
}

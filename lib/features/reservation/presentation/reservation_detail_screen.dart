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
import '../../store/domain/store_repository.dart';
import '../../store/domain/store_usecases.dart';
import '../../store/presentation/store_detail_screen.dart';
import 'booking/booking_flow.dart';
import 'booking/booking_screen.dart';
import '../domain/reservation_entities.dart';
import '../domain/reservation_repository.dart';
import '../domain/reservation_usecases.dart';

class ReservationDetailData {
  const ReservationDetailData({required this.reservation, this.history = const [], this.checkIn});

  final Reservation reservation;
  final List<ReservationHistoryEntry> history;
  final CheckInAvailability? checkIn;

  ReservationDetailData copyWith({Reservation? reservation, CheckInAvailability? checkIn}) =>
      ReservationDetailData(reservation: reservation ?? this.reservation, history: history, checkIn: checkIn ?? this.checkIn);
}

class ReservationDetailViewModel extends LoadableViewModel<ReservationDetailData> {
  ReservationDetailViewModel({
    required this.reservationId,
    required ReservationRepository repository,
    required this._bus,
  }) : _get = GetReservationDetail(repository),
       _history = GetReservationHistory(repository),
       _checkInAvailability = GetCheckInAvailability(repository),
       _cancel = CancelReservation(repository),
       _checkIn = CheckInReservation(repository) {
    listenTopics(_bus, {RefreshTopic.reservationDetail, RefreshTopic.myReservations}, refresh);
  }

  final String reservationId;
  final RefreshBus _bus;
  final GetReservationDetail _get;
  final GetReservationHistory _history;
  final GetCheckInAvailability _checkInAvailability;
  final CancelReservation _cancel;
  final CheckInReservation _checkIn;
  final _cancelKeys = IdempotencyKeyHolder();
  final _checkInKeys = IdempotencyKeyHolder();

  /// 체크인 완료 직후 보여줄 안내
  String? checkInMessage;

  @override
  Future<ReservationDetailData> fetch() async {
    final reservation = await _get(reservationId);
    final results = await Future.wait<Object?>([
      _history(reservationId).then<Object?>((v) => v, onError: (_) => <ReservationHistoryEntry>[]),
      reservation.status == ReservationStatus.confirmed
          ? _checkInAvailability(reservationId).then<Object?>((v) => v, onError: (_) => null)
          : Future<Object?>.value(),
    ]);
    return ReservationDetailData(
      reservation: reservation,
      history: results[0] as List<ReservationHistoryEntry>,
      checkIn: results[1] as CheckInAvailability?,
    );
  }

  bool get canCheckIn {
    final d = data;
    if (d == null || d.reservation.status != ReservationStatus.confirmed) return false;
    return d.checkIn?.available ?? d.reservation.checkInAvailable;
  }

  /// 취소 결과: null(성공) 또는 마감 안내가 필요한 실패
  Future<AppFailure?> cancel(String reason) async {
    AppFailure? deadline;
    final key = _cancelKeys.keyFor({'id': reservationId, 'reason': reason});
    final ok = await runAction(
      'cancel',
      () async {
        await _cancel(reservationId, reason: reason, idempotencyKey: key);
        _cancelKeys.settle();
        data = data?.copyWith(
          reservation: data!.reservation.copyWith(status: ReservationStatus.cancelled, canCancel: false),
        );
        _bus.emit(RefreshBus.afterReservationCancelled);
        AppMessenger.show('예약을 취소했어요.');
      },
      onFailure: (failure) {
        if (failure.kind != FailureKind.unknownOutcome) _cancelKeys.settle();
        switch (failure.code) {
          case 'RESERVATION_ALREADY_CANCELLED':
          case 'RESERVATION_INVALID_STATE':
            AppMessenger.show(failure.message);
            refresh();
            return true;
          case 'RESERVATION_CANCELLATION_DEADLINE_PASSED':
            deadline = failure;
            return true;
        }
        if (failure.kind == FailureKind.unknownOutcome) {
          // 결과가 불명확하면 상세를 다시 조회해 실제 상태를 확인한다.
          AppMessenger.show('취소 결과를 바로 확인하지 못했어요. 최신 상태를 다시 확인할게요.');
          refresh();
          return true;
        }
        return false;
      },
    );
    return ok ? null : deadline;
  }

  Future<void> checkIn() async {
    final key = _checkInKeys.keyFor({'id': reservationId});
    await runAction(
      'checkIn',
      () async {
        final result = await _checkIn(reservationId, idempotencyKey: key);
        _checkInKeys.settle();
        checkInMessage = result.alreadyCheckedIn
            ? '이미 체크인된 예약이에요.'
            : '체크인이 완료되었어요.\n직원의 안내를 기다려 주세요.';
        _bus.emit({RefreshTopic.reservationDetail, RefreshTopic.home, RefreshTopic.myReservations});
        await refresh();
      },
      onFailure: (failure) {
        if (failure.kind != FailureKind.unknownOutcome) _checkInKeys.settle();
        if (failure.isStateConflict || failure.code.startsWith('CHECK_IN_')) refresh();
        return false;
      },
    );
  }
}

/// C-10 예약 상세 + C-17 체크인
class ReservationDetailScreen extends StatelessWidget {
  const ReservationDetailScreen({super.key, required this.reservationId});

  final String reservationId;

  Future<void> _cancel(BuildContext context, ReservationDetailViewModel vm) async {
    final reason = await showReasonDialog(
      context,
      title: '예약을 취소할까요?',
      message: '취소한 시간은 다른 고객에게 제공될 수 있으며,\n취소 후에는 되돌릴 수 없어요.',
      presets: const ['개인 일정이 생겼어요', '다른 시간으로 다시 예약할게요', '다른 매장을 이용할게요'],
      confirmLabel: '예약 취소',
      cancelLabel: '예약 유지',
      destructive: true,
    );
    if (reason == null || !context.mounted) return;
    final deadline = await vm.cancel(reason);
    if (deadline != null && context.mounted) {
      final call = await showConfirmDialog(
        context,
        title: '취소 가능 시간이 지났어요',
        message: '${deadline.message}\n일정 변경이 필요하면 매장에 직접 연락해 주세요.',
        confirmLabel: '매장에 전화',
      );
      if (call) await callPhone(vm.data?.reservation.store.phoneNumber);
    }
  }

  /// 지난 예약과 같은 서비스·직원을 미리 고른 상태로 예약 화면을 연다.
  Future<void> _rebook(BuildContext context, Reservation r) async {
    try {
      final store = await GetStoreDetail(GetIt.I<StoreRepository>())(r.store.id);
      if (!context.mounted) return;
      pushPage<void>(
        context,
        BookingScreen(
          flow: BookingFlow(store: store, drafts: BookingDrafts(GetIt.I<ReservationRepository>())),
          initialServiceId: r.service?.id,
          initialStaffId: r.staff?.id,
        ),
      );
    } on AppFailure {
      if (context.mounted) pushPage<void>(context, StoreDetailScreen(storeId: r.store.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<ReservationDetailViewModel>(
      create: () => ReservationDetailViewModel(
        reservationId: reservationId,
        repository: GetIt.I<ReservationRepository>(),
        bus: GetIt.I<RefreshBus>(),
      ),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: const Text('예약 상세')),
        body: LoadableBody<ReservationDetailData>(
          vm: vm,
          builder: (context, data) => _body(context, vm, data),
        ),
        bottomNavigationBar: vm.data == null ? null : _actions(context, vm, vm.data!),
      ),
    );
  }

  (String, String?) _header(ReservationDetailData data, bool canCheckIn) {
    final r = data.reservation;
    return switch (r.status) {
      ReservationStatus.confirmed when canCheckIn => ('이제 체크인할 수 있어요', '매장에 도착했다면 체크인해 주세요.'),
      ReservationStatus.confirmed => ('예약이 확정되었어요', formatDateTime(r.startAt)),
      ReservationStatus.held => ('예약을 확인하고 있어요', formatDateTime(r.startAt)),
      ReservationStatus.checkedIn => ('체크인이 완료되었어요', '직원의 안내를 기다려 주세요.'),
      ReservationStatus.inService => ('서비스가 진행 중이에요', null),
      ReservationStatus.completed => ('이용이 완료되었어요', '다음에도 자리요로 예약해 주세요.'),
      ReservationStatus.cancelled => ('취소된 예약이에요', null),
      ReservationStatus.noShow => ('미방문 처리된 예약이에요', '자세한 내용은 매장에 문의해 주세요.'),
      ReservationStatus.expired => ('예약 시간이 만료되었어요', null),
      ReservationStatus.unknown => ('예약 상태를 확인하고 있어요', null),
    };
  }

  Widget _body(BuildContext context, ReservationDetailViewModel vm, ReservationDetailData data) {
    final r = data.reservation;
    final (title, subtitle) = _header(data, vm.canCheckIn);
    final checkIn = data.checkIn;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        StatusHeader(title: title, subtitle: subtitle, tone: r.status.tone, badge: r.status.label),
        if (vm.checkInMessage != null) ...[
          const SizedBox(height: 12),
          NoticeBox(message: vm.checkInMessage!, icon: Icons.how_to_reg, color: AppColors.positive),
        ],
        if (r.status == ReservationStatus.confirmed && !vm.canCheckIn && checkIn != null) ...[
          const SizedBox(height: 12),
          if (checkIn.alreadyCheckedIn)
            const NoticeBox(message: '이미 체크인된 예약이에요.', icon: Icons.how_to_reg)
          else if (checkIn.notYetOpen)
            NoticeBox(message: '${formatDateTime(checkIn.availableFrom!)}부터 체크인할 수 있어요.', icon: Icons.schedule)
          else if (checkIn.windowClosed)
            const NoticeBox(message: '체크인 가능 시간이 지났어요. 직원에게 문의해 주세요.', icon: Icons.info_outline),
        ],
        const SizedBox(height: 16),
        SectionCard(
          title: '예약 정보',
          child: Column(
            children: [
              InfoRow(label: '매장', value: r.store.name),
              InfoRow(label: '서비스', value: r.service?.name ?? '-'),
              InfoRow(label: '직원', value: r.staff?.name ?? '-'),
              InfoRow(label: '예약 시간', value: formatDateTime(r.startAt), emphasize: true),
              InfoRow(label: '', value: formatRelative(r.startAt)),
              InfoRow(label: '예상 소요', value: '${formatMinutes(r.durationMinutes)} (${formatTime(r.serviceEndAt)} 종료 예정)'),
              InfoRow(label: '인원', value: '${r.partySize}명'),
              if (r.customerNote != null) InfoRow(label: '요청사항', value: r.customerNote!),
              if (r.cancellationDeadlineAt != null && r.status.isUpcoming)
                InfoRow(label: '취소 가능', value: '${formatDateTime(r.cancellationDeadlineAt!)}까지'),
            ],
          ),
        ),
        if (data.history.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionCard(
            title: '상태 변경 이력',
            child: Column(
              children: [
                for (final h in data.history.reversed)
                  InfoRow(
                    label: '${formatShortCalendarDate(toStoreTime(h.occurredAt))} ${formatTime(h.occurredAt)}',
                    value: h.description,
                    labelWidth: 136,
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        SectionCard(
          title: '매장',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (r.store.address != null) InfoRow(label: '주소', value: r.store.address!),
              if (r.store.phoneNumber != null) InfoRow(label: '전화', value: r.store.phoneNumber!),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: '매장에 전화',
                      icon: Icons.call_outlined,
                      variant: AppButtonVariant.secondary,
                      expand: false,
                      onPressed: () => callPhone(r.store.phoneNumber),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppButton(
                      label: '길찾기',
                      icon: Icons.map_outlined,
                      variant: AppButtonVariant.secondary,
                      expand: false,
                      onPressed: () => openMap(r.store.address, name: r.store.name),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget? _actions(BuildContext context, ReservationDetailViewModel vm, ReservationDetailData data) {
    final r = data.reservation;
    final children = <Widget>[];
    if (vm.canCheckIn) {
      children.add(
        AppButton(
          label: '체크인하기',
          icon: Icons.how_to_reg,
          loading: vm.isBusy('checkIn'),
          loadingLabel: '체크인하고 있어요',
          onPressed: vm.checkIn,
        ),
      );
    }
    if (r.status.isUpcoming && r.status != ReservationStatus.checkedIn) {
      children.add(
        AppButton(
          label: '예약 취소',
          variant: vm.canCheckIn ? AppButtonVariant.text : AppButtonVariant.secondary,
          loading: vm.isBusy('cancel'),
          loadingLabel: '예약을 취소하고 있어요',
          onPressed: r.canCancel ? () => _cancel(context, vm) : null,
        ),
      );
      if (!r.canCancel) {
        children.add(
          const Text(
            '지금은 앱에서 취소할 수 없어요. 매장에 문의해 주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.lightText, fontSize: 13),
          ),
        );
      }
    }
    if (r.status == ReservationStatus.noShow) {
      children.add(AppButton(label: '매장 문의', icon: Icons.call, onPressed: () => callPhone(r.store.phoneNumber)));
    }
    if (r.status == ReservationStatus.completed ||
        r.status == ReservationStatus.cancelled ||
        r.status == ReservationStatus.expired) {
      children.add(
        AppButton(
          label: '같은 조건으로 다시 예약',
          onPressed: () => _rebook(context, r),
        ),
      );
    }
    return children.isEmpty ? null : BottomActionBar(children: children);
  }
}

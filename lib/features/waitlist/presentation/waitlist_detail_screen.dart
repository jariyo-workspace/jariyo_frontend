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
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/countdown.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/view_model_scope.dart';
import '../../reservation/presentation/reservation_detail_screen.dart';
import '../../store/presentation/store_detail_screen.dart';
import '../domain/waitlist_entities.dart';
import '../domain/waitlist_repository.dart';
import '../domain/waitlist_usecases.dart';
import 'slot_offer_screen.dart';
import 'waitlist_apply_screen.dart';

class WaitlistDetailViewModel extends LoadableViewModel<WaitlistEntry> {
  WaitlistDetailViewModel(this.waitlistId, WaitlistRepository repository, this._bus)
    : _get = GetWaitlistDetail(repository),
      _cancel = CancelWaitlist(repository) {
    listenTopics(_bus, {RefreshTopic.waitlists, RefreshTopic.slotOffers}, refresh);
    startPolling(const Duration(seconds: 30), refresh);
  }

  final String waitlistId;
  final RefreshBus _bus;
  final GetWaitlistDetail _get;
  final CancelWaitlist _cancel;
  final _keys = IdempotencyKeyHolder();

  @override
  Future<WaitlistEntry> fetch() => _get(waitlistId);

  Future<void> cancel(String reason) async {
    final key = _keys.keyFor({'id': waitlistId, 'reason': reason});
    await runAction(
      'cancel',
      () async {
        await _cancel(waitlistId, reason: reason, idempotencyKey: key);
        _keys.settle();
        _bus.emit(RefreshBus.afterWaitlistChanged);
        AppMessenger.show('예약 대기를 취소했어요.');
        await refresh();
      },
      onFailure: (failure) {
        if (failure.kind != FailureKind.unknownOutcome) _keys.settle();
        if (failure.isStateConflict || failure.kind == FailureKind.unknownOutcome) {
          refresh();
          AppMessenger.show(failure.kind == FailureKind.unknownOutcome ? '취소 결과를 다시 확인할게요.' : failure.message);
          return true;
        }
        return false;
      },
    );
  }
}

/// C-12 예약 대기 상세
class WaitlistDetailScreen extends StatelessWidget {
  const WaitlistDetailScreen({super.key, required this.waitlistId});

  final String waitlistId;

  (String, String?) _header(WaitlistEntry entry) => switch (entry.status) {
    WaitlistStatus.waiting => ('빈자리를 기다리고 있어요', '조건에 맞는 빈자리가 생기면 바로 알려드릴게요.'),
    WaitlistStatus.offered => ('예약 가능한 자리가 생겼어요', '제한 시간 안에 예약을 확정해 주세요.'),
    WaitlistStatus.reserved => ('예약으로 전환되었어요', '생성된 예약에서 방문 정보를 확인하세요.'),
    WaitlistStatus.cancelled => ('대기를 취소했어요', null),
    WaitlistStatus.expired => ('대기 기간이 끝났어요', '다른 날짜로 다시 신청할 수 있어요.'),
    WaitlistStatus.unknown => ('대기 상태를 확인하고 있어요', null),
  };

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<WaitlistDetailViewModel>(
      create: () => WaitlistDetailViewModel(waitlistId, GetIt.I<WaitlistRepository>(), GetIt.I<RefreshBus>()),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: const Text('예약 대기')),
        body: LoadableBody<WaitlistEntry>(
          vm: vm,
          staleMessage: '대기 정보를 새로 불러오지 못했어요.',
          builder: (context, entry) {
            final (title, subtitle) = _header(entry);
            final offer = entry.activeOffer;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                StatusHeader(title: title, subtitle: subtitle, tone: entry.status.tone, badge: entry.status.label),
                if (offer != null && offer.status == SlotOfferStatus.pending) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: AppColors.attention.withAlpha(16),
                    child: ListTile(
                      leading: const Icon(Icons.local_fire_department_outlined, color: AppColors.attention),
                      title: Text(offer.startAt == null ? '빈자리 제안' : '${formatDateTime(offer.startAt!)} 빈자리'),
                      subtitle: offer.expiresAt == null
                          ? null
                          : CountdownText(expiresAt: offer.expiresAt!, suffix: ' 안에 선택해 주세요', onExpired: vm.refresh),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => pushPage<void>(context, SlotOfferScreen(offerId: offer.id)),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SectionCard(
                  title: '대기 조건',
                  child: Column(
                    children: [
                      InfoRow(label: '매장', value: entry.store?.name ?? '-'),
                      InfoRow(label: '서비스', value: entry.service?.name ?? '-'),
                      InfoRow(label: '희망 날짜', value: formatYmdLabel(entry.desiredDate), emphasize: true),
                      InfoRow(label: '가능 시간', value: entry.timeRangeLabel),
                      InfoRow(
                        label: '선호 직원',
                        value: entry.preferredStaff == null
                            ? entry.staffPreferenceType.label
                            : '${entry.preferredStaff!.name} · ${entry.staffPreferenceType.label}',
                      ),
                      if (entry.createdAt != null) InfoRow(label: '신청 시각', value: formatDateTime(entry.createdAt!)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                NoticeBox(
                  message: [
                    if (entry.sequenceNumber != null) '신청 순서 ${entry.sequenceNumber}번',
                    '신청 순서와 희망 조건을 함께 확인해 빈자리를 안내해 드려요.',
                  ].join(' · '),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: vm.data == null ? null : _actions(context, vm, vm.data!),
      ),
    );
  }

  Widget _actions(BuildContext context, WaitlistDetailViewModel vm, WaitlistEntry entry) {
    final storeId = entry.effectiveStoreId;
    return BottomActionBar(
      children: [
        if (entry.status == WaitlistStatus.offered && entry.activeOffer != null)
          AppButton(
            label: '빈자리 확인하기',
            onPressed: () => pushPage<void>(context, SlotOfferScreen(offerId: entry.activeOffer!.id)),
          ),
        if (entry.status == WaitlistStatus.reserved && entry.resultingReservationId != null)
          AppButton(
            label: '예약 보기',
            onPressed: () => pushPage<void>(context, ReservationDetailScreen(reservationId: entry.resultingReservationId!)),
          ),
        if (entry.status == WaitlistStatus.waiting)
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: '조건 수정',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => pushPage<void>(context, WaitlistApplyScreen.edit(entry: entry)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: '대기 취소',
                  variant: AppButtonVariant.secondary,
                  loading: vm.isBusy('cancel'),
                  loadingLabel: '취소 중',
                  onPressed: () async {
                    final reason = await showReasonDialog(
                      context,
                      title: '예약 대기를 취소할까요?',
                      message: '취소하면 빈자리 안내를 더 이상 받을 수 없어요.\n다시 신청하면 신청 순서가 새로 정해져요.',
                      presets: const ['다른 시간에 예약했어요', '방문 계획이 바뀌었어요'],
                      confirmLabel: '대기 취소',
                      cancelLabel: '대기 유지',
                      destructive: true,
                    );
                    if (reason != null) await vm.cancel(reason);
                  },
                ),
              ),
            ],
          ),
        if (storeId != null)
          AppButton(
            label: '매장 상세 보기',
            variant: AppButtonVariant.text,
            onPressed: () => pushPage<void>(context, StoreDetailScreen(storeId: storeId)),
          ),
      ],
    );
  }
}

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
import '../domain/waitlist_entities.dart';
import '../domain/waitlist_repository.dart';
import '../domain/waitlist_usecases.dart';
import 'waitlist_detail_screen.dart';

class SlotOfferViewModel extends LoadableViewModel<SlotOffer> {
  SlotOfferViewModel(this.offerId, WaitlistRepository repository, this._bus)
    : _get = GetSlotOffer(repository),
      _accept = AcceptSlotOffer(repository),
      _decline = DeclineSlotOffer(repository) {
    listenTopics(_bus, {RefreshTopic.slotOffers}, refresh);
  }

  final String offerId;
  final RefreshBus _bus;
  final GetSlotOffer _get;
  final AcceptSlotOffer _accept;
  final DeclineSlotOffer _decline;
  final _acceptKeys = IdempotencyKeyHolder();
  final _declineKeys = IdempotencyKeyHolder();

  /// 수락 중 다른 상태 변경으로 예약이 불가능해졌을 때
  bool noLongerAvailable = false;
  bool timerExpired = false;

  bool get processing => isBusy('accept') || isBusy('decline');

  bool get canRespond => data?.isPending == true && !timerExpired && !noLongerAvailable && !processing;

  @override
  Future<SlotOffer> fetch() async {
    final offer = await _get(offerId);
    timerExpired = offer.isPending && offer.deadline.isBefore(DateTime.now());
    return offer;
  }

  /// 남은 시간이 0이 되면 버튼을 비활성화하고 서버 상태를 다시 확인한다.
  void onTimerExpired() {
    timerExpired = true;
    notify();
    refresh();
  }

  /// 생성된 예약 ID
  Future<String?> accept() async {
    String? reservationId;
    final key = _acceptKeys.keyFor({'offer': offerId});
    await runAction(
      'accept',
      () async {
        final result = await _accept(offerId, idempotencyKey: key);
        _acceptKeys.settle();
        _bus.emit(RefreshBus.afterSlotOfferAccepted);
        reservationId = result.reservationId;
      },
      onFailure: (failure) {
        if (failure.kind != FailureKind.unknownOutcome) _acceptKeys.settle();
        switch (failure.code) {
          case 'SLOT_OFFER_NO_LONGER_AVAILABLE':
          case 'RESERVATION_SLOT_ALREADY_TAKEN':
            noLongerAvailable = true;
            _bus.emit(RefreshBus.afterWaitlistChanged);
            refresh();
            return true;
          case 'SLOT_OFFER_EXPIRED':
          case 'SLOT_OFFER_ALREADY_ACCEPTED':
          case 'SLOT_OFFER_ALREADY_DECLINED':
          case 'WAITLIST_INVALID_STATE':
            _bus.emit(RefreshBus.afterWaitlistChanged);
            refresh();
            return true;
        }
        if (failure.kind == FailureKind.unknownOutcome) {
          AppMessenger.show('수락 결과를 바로 확인하지 못했어요. 최신 상태를 다시 확인할게요.');
          refresh();
          return true;
        }
        return false;
      },
    );
    return reservationId;
  }

  Future<bool> decline({required bool keepWaitlistActive}) async {
    final key = _declineKeys.keyFor({'offer': offerId, 'keep': keepWaitlistActive});
    return runAction(
      'decline',
      () async {
        await _decline(offerId, keepWaitlistActive: keepWaitlistActive, idempotencyKey: key);
        _declineKeys.settle();
        _bus.emit(RefreshBus.afterWaitlistChanged);
        AppMessenger.show(keepWaitlistActive ? '이번 제안을 건너뛰었어요. 대기는 계속 유지돼요.' : '제안을 건너뛰고 대기를 취소했어요.');
      },
      onFailure: (failure) {
        if (failure.kind != FailureKind.unknownOutcome) _declineKeys.settle();
        // 제안과 대기 상세를 다시 조회한다.
        _bus.emit(RefreshBus.afterWaitlistChanged);
        refresh();
        return failure.code.startsWith('SLOT_OFFER_') || failure.code == 'WAITLIST_INVALID_STATE';
      },
    );
  }
}

/// C-13 빈자리 제안
class SlotOfferScreen extends StatelessWidget {
  const SlotOfferScreen({super.key, required this.offerId});

  final String offerId;

  Future<void> _decline(BuildContext context, SlotOfferViewModel vm) async {
    final keep = await showChoiceSheet<bool>(
      context,
      title: '이번 제안을 건너뛸까요?',
      options: const [
        (true, '대기 유지하고 건너뛰기', '조건에 맞는 다른 빈자리를 계속 기다려요.'),
        (false, '대기도 함께 취소', '더 이상 빈자리 안내를 받지 않아요.'),
      ],
    );
    if (keep == null || !context.mounted) return;
    final ok = await vm.decline(keepWaitlistActive: keep);
    final waitlistId = vm.data?.waitlistId;
    if (ok && context.mounted && waitlistId != null) {
      replacePage<void>(context, WaitlistDetailScreen(waitlistId: waitlistId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<SlotOfferViewModel>(
      create: () => SlotOfferViewModel(offerId, GetIt.I<WaitlistRepository>(), GetIt.I<RefreshBus>()),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: const Text('빈자리 제안')),
        body: LoadableBody<SlotOffer>(vm: vm, builder: (context, offer) => _body(context, vm, offer)),
        bottomNavigationBar: vm.data == null ? null : _actions(context, vm, vm.data!),
      ),
    );
  }

  Widget _body(BuildContext context, SlotOfferViewModel vm, SlotOffer offer) {
    final Widget header;
    if (vm.noLongerAvailable) {
      header = const StatusHeader(
        title: '아쉽게도 이 자리를 더 이상 예약할 수 없어요',
        subtitle: '대기 신청은 그대로 유지됩니다.',
        tone: StatusTone.neutral,
      );
    } else {
      header = switch (offer.status) {
        SlotOfferStatus.pending when !vm.timerExpired => StatusHeader(
          title: '원하던 시간에 빈자리가 생겼어요',
          subtitle: formatDateTime(offer.startAt),
          tone: StatusTone.attention,
        ),
        SlotOfferStatus.pending || SlotOfferStatus.expired => const StatusHeader(
          title: '빈자리 제안 시간이 끝났어요',
          subtitle: '대기 신청은 계속 유지돼요.',
          tone: StatusTone.neutral,
        ),
        SlotOfferStatus.accepted => const StatusHeader(
          title: '이미 수락한 제안이에요',
          subtitle: '생성된 예약에서 방문 정보를 확인하세요.',
          tone: StatusTone.positive,
        ),
        SlotOfferStatus.declined => const StatusHeader(title: '이번 제안을 건너뛰었어요', tone: StatusTone.neutral),
        SlotOfferStatus.revoked => const StatusHeader(
          title: '매장에서 제안을 취소했어요',
          subtitle: '대기 상태를 확인해 주세요.',
          tone: StatusTone.negative,
        ),
        SlotOfferStatus.unknown => const StatusHeader(title: '제안 상태를 확인하고 있어요', tone: StatusTone.attention),
      };
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        header,
        if (offer.isPending && !vm.timerExpired && !vm.noLongerAvailable) ...[
          const SizedBox(height: 16),
          Center(
            child: CountdownText(
              expiresAt: offer.deadline,
              suffix: ' 안에 선택해 주세요',
              onExpired: vm.onTimerExpired,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.attention),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text('시간이 지나면 다음 대기 고객에게 기회가 넘어가요.', style: TextStyle(color: AppColors.lightText)),
          ),
        ],
        const SizedBox(height: 16),
        SectionCard(
          title: '제안 정보',
          child: Column(
            children: [
              InfoRow(label: '매장', value: offer.store?.name ?? '-'),
              InfoRow(label: '서비스', value: offer.service?.name ?? '-'),
              InfoRow(label: '직원', value: offer.staff?.name ?? '-'),
              InfoRow(label: '날짜와 시간', value: formatDateTime(offer.startAt), emphasize: true),
              if (offer.durationMinutes != null) InfoRow(label: '예상 소요', value: formatMinutes(offer.durationMinutes!)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const NoticeBox(message: '수락하면 바로 예약이 확정돼요. 예약 취소는 매장의 취소 정책을 따라요.'),
      ],
    );
  }

  Widget? _actions(BuildContext context, SlotOfferViewModel vm, SlotOffer offer) {
    final waitlistId = offer.waitlistId;
    if (offer.status == SlotOfferStatus.accepted && offer.resultingReservationId != null) {
      return BottomActionBar(
        children: [
          AppButton(
            label: '예약 보기',
            onPressed: () => replacePage<void>(context, ReservationDetailScreen(reservationId: offer.resultingReservationId!)),
          ),
        ],
      );
    }
    if (offer.isPending && !vm.timerExpired && !vm.noLongerAvailable) {
      return BottomActionBar(
        children: [
          AppButton(
            label: '이 시간 예약하기',
            loading: vm.isBusy('accept'),
            loadingLabel: '예약을 확정하고 있어요',
            onPressed: vm.canRespond
                ? () async {
                    final reservationId = await vm.accept();
                    if (reservationId != null && context.mounted) {
                      AppMessenger.show('예약이 확정되었어요.');
                      replacePage<void>(context, ReservationDetailScreen(reservationId: reservationId));
                    }
                  }
                : null,
          ),
          AppButton(
            label: '이번에는 건너뛰기',
            variant: AppButtonVariant.text,
            loading: vm.isBusy('decline'),
            onPressed: vm.canRespond ? () => _decline(context, vm) : null,
          ),
        ],
      );
    }
    if (waitlistId == null) return null;
    return BottomActionBar(
      children: [
        AppButton(
          label: '대기 상태 확인',
          onPressed: () => replacePage<void>(context, WaitlistDetailScreen(waitlistId: waitlistId)),
        ),
      ],
    );
  }
}

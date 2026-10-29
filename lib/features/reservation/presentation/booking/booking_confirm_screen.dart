import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../app/session_controller.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/network/idempotency.dart';
import '../../../../core/presentation/view_model.dart';
import '../../../../core/realtime/refresh_bus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_time_format.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/dialogs.dart';
import '../../../../core/widgets/view_model_scope.dart';
import '../../../home/presentation/my_activity_screen.dart';
import '../../domain/reservation_entities.dart';
import '../../domain/reservation_repository.dart';
import '../../domain/reservation_usecases.dart';
import 'booking_complete_screen.dart';
import 'booking_flow.dart';

enum BookingConfirmResult { slotTaken }

sealed class _SubmitOutcome {
  const _SubmitOutcome();
}

class _Created extends _SubmitOutcome {
  const _Created(this.reservation);

  final Reservation reservation;
}

class _Failed extends _SubmitOutcome {
  const _Failed(this.failure);

  final AppFailure failure;
}

class _Ignored extends _SubmitOutcome {
  const _Ignored();
}

class _ConfirmViewModel extends ViewModel {
  _ConfirmViewModel(this._create, this._bus, this.flow);

  final CreateReservation _create;
  final RefreshBus _bus;
  final BookingFlow flow;
  final _keys = IdempotencyKeyHolder();

  bool agreePolicy = false;
  bool agreePrivacy = false;

  bool get submitting => isBusy('create');

  bool get canSubmit => agreePolicy && agreePrivacy && !submitting;

  void setAgreements({bool? policy, bool? privacy}) {
    agreePolicy = policy ?? agreePolicy;
    agreePrivacy = privacy ?? agreePrivacy;
    notify();
  }

  Future<_SubmitOutcome> submit() async {
    if (submitting) return const _Ignored();
    final request = flow.toRequest();
    // 같은 요청을 재시도할 때는 기존 키를 재사용하고, 내용이 바뀌면 새 키를 만든다.
    final key = _keys.keyFor(request.toJson());
    _SubmitOutcome outcome = const _Ignored();
    await runAction(
      'create',
      () async {
        final reservation = await _create(request, idempotencyKey: key);
        _keys.settle();
        await flow.finish();
        _bus.emit(RefreshBus.afterReservationCreated);
        outcome = _Created(reservation);
      },
      onFailure: (failure) {
        if (failure.kind != FailureKind.unknownOutcome) _keys.settle();
        outcome = _Failed(failure);
        return true;
      },
    );
    return outcome;
  }
}

/// C-08 예약 확인
class BookingConfirmScreen extends StatelessWidget {
  const BookingConfirmScreen({super.key, required this.flow});

  final BookingFlow flow;

  Future<void> _submit(BuildContext context, _ConfirmViewModel vm) async {
    final outcome = await vm.submit();
    if (!context.mounted) return;
    switch (outcome) {
      case _Created(:final reservation):
        Navigator.of(context).pushAndRemoveUntil(
          pageRoute<void>(BookingCompleteScreen(reservation: reservation)),
          (route) => route.isFirst,
        );
      case _Failed(:final failure):
        await _handleFailure(context, vm, failure);
      case _Ignored():
        break;
    }
  }

  Future<void> _handleFailure(BuildContext context, _ConfirmViewModel vm, AppFailure failure) async {
    switch (failure.code) {
      case 'RESERVATION_SLOT_ALREADY_TAKEN':
      case 'STAFF_NOT_AVAILABLE':
        Navigator.pop(context, BookingConfirmResult.slotTaken);
        return;
      case 'CUSTOMER_HAS_OVERLAPPING_RESERVATION':
        final open = await showConfirmDialog(
          context,
          title: '같은 시간에 예약이 있어요',
          message: '${failure.message}\n기존 예약을 확인하거나 다른 시간을 선택해 주세요.',
          confirmLabel: '내 예약 보기',
          cancelLabel: '다른 시간 선택',
        );
        if (!context.mounted) return;
        if (open) {
          pushPage<void>(context, const MyActivityScreen(standalone: true));
        } else {
          Navigator.pop(context);
        }
        return;
      case 'RESERVATION_OUTSIDE_BOOKING_WINDOW':
      case 'RESERVATION_TOO_CLOSE_TO_START':
        final days = flow.store.policy.bookingOpenDays;
        final notice = flow.store.policy.minimumBookingNoticeMinutes;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('예약 가능 기간이 아니에요'),
            content: Text(
              [
                failure.message,
                if (days != null) '오늘부터 $days일 뒤까지 예약할 수 있어요.',
                if (notice != null && notice > 0) '예약 시작 ${formatMinutes(notice)} 전까지 예약할 수 있어요.',
              ].join('\n'),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('다른 시간 선택'))],
          ),
        );
        if (context.mounted) Navigator.pop(context, BookingConfirmResult.slotTaken);
        return;
      case 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_REQUEST':
        AppMessenger.show('요청 정보가 바뀌었어요. 예약 확정하기를 다시 눌러 주세요.');
        return;
    }
    if (!context.mounted) return;
    if (failure.kind == FailureKind.unknownOutcome) {
      final retry = await showConfirmDialog(
        context,
        title: '예약 결과를 확인하지 못했어요',
        message: '예약 결과를 바로 확인하지 못했어요.\n중복 예약을 막기 위해 다시 예약하기 전에 내 예약에서 처리 결과를 확인해 주세요.',
        confirmLabel: '다시 시도',
        cancelLabel: '예약 내역 확인',
      );
      if (!context.mounted) return;
      if (retry) {
        await _submit(context, vm);
      } else {
        GetIt.I<RefreshBus>().emit({RefreshTopic.myReservations, RefreshTopic.home});
        Navigator.of(context).pushAndRemoveUntil(
          pageRoute<void>(const MyActivityScreen(standalone: true)),
          (route) => route.isFirst,
        );
      }
      return;
    }
    AppMessenger.showFailure(failure);
  }

  @override
  Widget build(BuildContext context) {
    final profile = GetIt.I<SessionController>().profile;
    final slot = flow.slot!;
    final policy = flow.store.policy;
    return ViewModelScope<_ConfirmViewModel>(
      create: () => _ConfirmViewModel(
        CreateReservation(GetIt.I<ReservationRepository>()),
        GetIt.I<RefreshBus>(),
        flow,
      ),
      builder: (context, vm) => PopScope(
        canPop: !vm.submitting,
        child: Scaffold(
          appBar: AppBar(title: const Text('예약 확인')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                '예약 정보를 확인해 주세요',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: '예약 정보',
                child: Column(
                  children: [
                    InfoRow(label: '매장', value: flow.store.name),
                    InfoRow(label: '서비스', value: flow.service!.name),
                    InfoRow(label: '담당 직원', value: flow.staff?.displayName ?? '가능한 직원 (자동 배정)'),
                    InfoRow(label: '예약 날짜', value: formatDate(slot.startAt), emphasize: true),
                    InfoRow(label: '시작 시간', value: formatTime(slot.startAt), emphasize: true),
                    InfoRow(label: '예상 종료', value: formatTime(slot.serviceEndAt)),
                    InfoRow(label: '인원', value: '${flow.partySize}명'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: '고객 정보',
                child: Column(
                  children: [
                    InfoRow(label: '이름', value: profile?.displayName ?? '-'),
                    InfoRow(label: '연락처', value: profile?.phoneNumber ?? '-'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: '요청사항',
                child: TextFormField(
                  initialValue: flow.customerNote,
                  maxLength: 1000,
                  maxLines: 3,
                  minLines: 2,
                  onChanged: flow.updateNote,
                  decoration: const InputDecoration(hintText: '매장에 전달할 요청사항을 입력해 주세요. (선택)'),
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: '취소 정책',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final sentence in policy.customerSentences)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('• $sentence', style: const TextStyle(color: AppColors.lightText)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    CheckboxListTile(
                      value: vm.agreePolicy,
                      onChanged: vm.submitting ? null : (v) => vm.setAgreements(policy: v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('[필수] 예약 및 취소 정책을 확인했어요'),
                    ),
                    CheckboxListTile(
                      value: vm.agreePrivacy,
                      onChanged: vm.submitting ? null : (v) => vm.setAgreements(privacy: v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('[필수] 예약을 위한 개인정보 제공에 동의해요'),
                      subtitle: const Text('이름과 연락처가 매장에 제공돼요.'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: BottomActionBar(
            children: [
              AppButton(
                label: '예약 확정하기',
                loading: vm.submitting,
                loadingLabel: '예약을 확인하고 있어요',
                onPressed: vm.canSubmit ? () => _submit(context, vm) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

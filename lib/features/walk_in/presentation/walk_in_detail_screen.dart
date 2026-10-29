import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../store/domain/store_entities.dart';
import '../../store/domain/store_repository.dart';
import '../../store/domain/store_usecases.dart';
import '../domain/walk_in_entities.dart';
import '../domain/walk_in_repository.dart';
import '../domain/walk_in_usecases.dart';
import 'walk_in_call_screen.dart';

class WalkInDetailViewModel extends LoadableViewModel<WalkIn> {
  WalkInDetailViewModel(this.walkInId, WalkInRepository repository, StoreRepository stores, this._bus)
    : _get = GetWalkInDetail(repository),
      _cancel = CancelWalkIn(repository),
      _getStore = GetStoreDetail(stores) {
    listenTopics(_bus, {RefreshTopic.walkIns}, refresh);
    // 실시간 연결이 없어도 순서 변화를 놓치지 않도록 주기적으로 재조회한다.
    startPolling(const Duration(seconds: 15), refresh);
  }

  final String walkInId;
  final RefreshBus _bus;
  final GetWalkInDetail _get;
  final CancelWalkIn _cancel;
  final GetStoreDetail _getStore;
  final _keys = IdempotencyKeyHolder();
  StoreDetail? store;

  /// 호출 화면을 자동으로 띄운 적이 있는지. 같은 호출에 대해 한 번만 띄운다.
  DateTime? _announcedCallAt;
  void Function(WalkIn walkIn)? onCalled;

  @override
  Future<WalkIn> fetch() async {
    final walkIn = await _get(walkInId);
    final storeId = walkIn.effectiveStoreId;
    if (store == null && storeId != null) {
      try {
        store = await _getStore(storeId);
      } on AppFailure {
        store = null;
      }
    }
    if (walkIn.status == WalkInStatus.called && walkIn.calledAt != _announcedCallAt) {
      _announcedCallAt = walkIn.calledAt;
      onCalled?.call(walkIn);
    }
    return walkIn;
  }

  Future<void> cancel(String reason) async {
    final key = _keys.keyFor({'id': walkInId, 'reason': reason});
    await runAction(
      'cancel',
      () async {
        await _cancel(walkInId, reason: reason, idempotencyKey: key);
        _keys.settle();
        _bus.emit(RefreshBus.afterWalkInChanged);
        AppMessenger.show('현장 대기를 취소했어요.');
        await refresh();
      },
      onFailure: (failure) {
        if (failure.kind != FailureKind.unknownOutcome) _keys.settle();
        if (failure.isStateConflict || failure.kind == FailureKind.unknownOutcome) {
          refresh();
          return failure.kind == FailureKind.unknownOutcome;
        }
        return false;
      },
    );
  }
}

/// C-15 현장 대기 상세
class WalkInDetailScreen extends StatelessWidget {
  const WalkInDetailScreen({super.key, required this.walkInId});

  final String walkInId;

  (String, String?) _header(WalkIn w) => switch (w.status) {
    WalkInStatus.waiting => ('현재 대기 중이에요', '앞에 ${w.waitingAhead}팀이 있어요 · 약 ${formatMinutes(w.estimatedWaitMinutes)} 예상'),
    WalkInStatus.called => ('고객님의 차례예요', '지금 매장으로 입장해 주세요.'),
    WalkInStatus.checkedIn => ('입장이 확인되었어요', '직원의 안내를 기다려 주세요.'),
    WalkInStatus.inService => ('서비스가 진행 중이에요', null),
    WalkInStatus.completed => ('이용이 완료되었어요', null),
    WalkInStatus.skipped => ('순서가 잠시 보류되었어요', '매장에 문의해 주세요.'),
    WalkInStatus.cancelled => ('대기를 취소했어요', null),
    WalkInStatus.noShow => ('호출에 응답이 없어 처리되었어요', '매장에 문의해 주세요.'),
    WalkInStatus.unknown => ('대기 상태를 확인하고 있어요', null),
  };

  void _openCall(BuildContext context, WalkIn walkIn) {
    HapticFeedback.heavyImpact();
    pushPage<void>(context, WalkInCallScreen(walkInId: walkIn.id));
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<WalkInDetailViewModel>(
      create: () => WalkInDetailViewModel(
        walkInId,
        GetIt.I<WalkInRepository>(),
        GetIt.I<StoreRepository>(),
        GetIt.I<RefreshBus>(),
      ),
      onReady: (vm) {
        vm.onCalled = (walkIn) {
          if (context.mounted) _openCall(context, walkIn);
        };
        vm.load();
      },
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: const Text('현장 대기')),
        body: LoadableBody<WalkIn>(
          vm: vm,
          staleMessage: '대기 정보를 새로 불러오지 못했어요.',
          builder: (context, w) {
            final (title, subtitle) = _header(w);
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                StatusHeader(title: title, subtitle: subtitle, tone: w.status.tone, badge: w.status.label),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      children: [
                        Expanded(child: _Big(label: '내 대기 번호', value: '${w.queueNumber}번')),
                        Expanded(child: _Big(label: '앞에 남은 팀', value: '${w.waitingAhead}팀')),
                        Expanded(child: _Big(label: '예상 대기', value: formatMinutes(w.estimatedWaitMinutes))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _ProgressSteps(step: w.progressStep),
                const SizedBox(height: 16),
                SectionCard(
                  child: Column(
                    children: [
                      InfoRow(label: '매장', value: w.store?.name ?? store(vm)?.name ?? '-'),
                      InfoRow(label: '신청 서비스', value: w.service?.name ?? '-'),
                      if (w.createdAt != null) InfoRow(label: '등록 시각', value: formatDateTime(w.createdAt!)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: '매장에 전화',
                        icon: Icons.call_outlined,
                        variant: AppButtonVariant.secondary,
                        expand: false,
                        onPressed: () => callPhone(store(vm)?.phoneNumber),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton(
                        label: '매장 위치',
                        icon: Icons.map_outlined,
                        variant: AppButtonVariant.secondary,
                        expand: false,
                        onPressed: () => openMap(store(vm)?.address, name: store(vm)?.name),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: vm.data == null ? null : _actions(context, vm, vm.data!),
      ),
    );
  }

  StoreDetail? store(WalkInDetailViewModel vm) => vm.store;

  Widget? _actions(BuildContext context, WalkInDetailViewModel vm, WalkIn w) {
    switch (w.status) {
      case WalkInStatus.called:
        return BottomActionBar(children: [AppButton(label: '입장 확인하기', onPressed: () => _openCall(context, w))]);
      case WalkInStatus.waiting:
        return BottomActionBar(
          children: [
            AppButton(
              label: '대기 취소',
              variant: AppButtonVariant.secondary,
              loading: vm.isBusy('cancel'),
              loadingLabel: '대기를 취소하고 있어요',
              onPressed: () async {
                final reason = await showReasonDialog(
                  context,
                  title: '현장 대기를 취소할까요?',
                  message: '취소하면 대기 순서가 사라지고 되돌릴 수 없어요.',
                  presets: const ['다른 일정이 생겼어요', '대기 시간이 너무 길어요'],
                  confirmLabel: '대기 취소',
                  cancelLabel: '계속 기다리기',
                  destructive: true,
                );
                if (reason != null) await vm.cancel(reason);
              },
            ),
          ],
        );
      case WalkInStatus.skipped:
      case WalkInStatus.noShow:
        return BottomActionBar(
          children: [AppButton(label: '매장 문의', icon: Icons.call, onPressed: () => callPhone(vm.store?.phoneNumber))],
        );
      default:
        return null;
    }
  }
}

class _Big extends StatelessWidget {
  const _Big({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: const TextStyle(color: AppColors.lightText, fontSize: 13)),
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
    ],
  );
}

/// 대기 등록 → 호출 대기 → 입장 확인 → 서비스 시작
class _ProgressSteps extends StatelessWidget {
  const _ProgressSteps({required this.step});

  final int step;

  static const _labels = ['대기 등록', '호출 대기', '입장 확인', '서비스 시작'];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '진행 단계: ${_labels[step.clamp(0, 3)]}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < _labels.length; i++) ...[
              Expanded(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: i <= step ? AppColors.primary : AppColors.border,
                      child: i < step
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Colors.white)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _labels[i],
                      style: TextStyle(
                        fontSize: 12,
                        color: i <= step ? AppColors.primary : AppColors.lightText,
                        fontWeight: i == step ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

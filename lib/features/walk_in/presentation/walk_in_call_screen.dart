import 'dart:async';

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
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/countdown.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/view_model_scope.dart';
import '../domain/walk_in_entities.dart';
import '../domain/walk_in_repository.dart';
import '../domain/walk_in_usecases.dart';

class WalkInCallViewModel extends LoadableViewModel<WalkIn> {
  WalkInCallViewModel(this.walkInId, WalkInRepository repository, this._bus)
    : _get = GetWalkInDetail(repository),
      _respond = RespondToCall(repository) {
    listenTopics(_bus, {RefreshTopic.walkIns}, refresh);
    startPolling(const Duration(seconds: 10), refresh);
  }

  final String walkInId;
  final RefreshBus _bus;
  final GetWalkInDetail _get;
  final RespondToCall _respond;
  final _keys = IdempotencyKeyHolder();
  bool callExpired = false;

  @override
  Future<WalkIn> fetch() => _get(walkInId);

  bool get responding => isBusy('respond');

  Future<WalkIn?> respond(CallResponse response) async {
    WalkIn? result;
    final key = _keys.keyFor({'id': walkInId, 'response': response.code});
    await runAction(
      'respond',
      () async {
        result = await _respond(walkInId, response, idempotencyKey: key);
        _keys.settle();
        _bus.emit(RefreshBus.afterWalkInChanged);
        await refresh();
      },
      onFailure: (failure) {
        if (failure.kind != FailureKind.unknownOutcome) _keys.settle();
        if (failure.code == 'WALK_IN_CALL_EXPIRED') {
          callExpired = true;
          refresh();
          return true;
        }
        if (failure.isStateConflict) {
          refresh();
          return false;
        }
        return false;
      },
    );
    return result;
  }
}

/// C-16 호출 화면. 차례가 되었음을 즉시 알 수 있도록 전체 화면으로 강조한다.
class WalkInCallScreen extends StatefulWidget {
  const WalkInCallScreen({super.key, required this.walkInId});

  final String walkInId;

  @override
  State<WalkInCallScreen> createState() => _WalkInCallScreenState();
}

class _WalkInCallScreenState extends State<WalkInCallScreen> {
  Timer? _alertTimer;
  int _alerts = 0;

  @override
  void initState() {
    super.initState();
    _alert();
    // 진동과 소리로 몇 차례 더 알린다.
    _alertTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (++_alerts >= 4) timer.cancel();
      _alert();
    });
  }

  void _alert() {
    HapticFeedback.vibrate();
    SystemSound.play(SystemSoundType.alert);
  }

  @override
  void dispose() {
    _alertTimer?.cancel();
    super.dispose();
  }

  Future<void> _respond(WalkInCallViewModel vm, CallResponse response) async {
    if (response == CallResponse.cancel) {
      final ok = await showConfirmDialog(
        context,
        title: '현장 대기를 취소할까요?',
        message: '취소하면 대기 순서가 사라지고 되돌릴 수 없어요.',
        confirmLabel: '대기 취소',
        cancelLabel: '돌아가기',
        destructive: true,
      );
      if (!ok) return;
    }
    _alertTimer?.cancel();
    final result = await vm.respond(response);
    if (result == null || !mounted) return;
    AppMessenger.show(switch (response) {
      CallResponse.entering => '입장 의사를 전달했어요. 직원의 안내를 받아 주세요.',
      CallResponse.delayed => '조금 늦는다고 매장에 전달했어요.',
      CallResponse.cancel => '현장 대기를 취소했어요.',
    });
    if (response != CallResponse.delayed) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<WalkInCallViewModel>(
      create: () => WalkInCallViewModel(widget.walkInId, GetIt.I<WalkInRepository>(), GetIt.I<RefreshBus>()),
      onReady: (vm) => vm.load(),
      builder: (context, vm) {
        final walkIn = vm.data;
        if (walkIn == null) {
          return Scaffold(
            appBar: AppBar(),
            body: vm.error != null ? ErrorView(failure: vm.error!, onRetry: vm.load) : const LoadingView(),
          );
        }
        final stillCalled = walkIn.status == WalkInStatus.called && !vm.callExpired;
        return Scaffold(
          backgroundColor: stillCalled ? AppColors.primary : AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: stillCalled ? Colors.white : AppColors.text,
            title: Text(walkIn.store?.name ?? '호출', style: TextStyle(color: stillCalled ? Colors.white : AppColors.primary)),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: stillCalled ? _called(vm, walkIn) : _notCalled(walkIn, vm.callExpired),
            ),
          ),
        );
      },
    );
  }

  Widget _called(WalkInCallViewModel vm, WalkIn walkIn) {
    return Column(
      children: [
        const Spacer(),
        Semantics(
          liveRegion: true,
          child: const Column(
            children: [
              Icon(Icons.campaign, size: 80, color: Colors.white),
              SizedBox(height: 16),
              Text('고객님의 차례예요', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
              SizedBox(height: 8),
              Text('지금 매장으로 입장해 주세요.', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('대기 번호 ${walkIn.queueNumber}번', style: const TextStyle(color: Colors.white70, fontSize: 16)),
        if (walkIn.callExpiresAt != null) ...[
          const SizedBox(height: 16),
          CountdownText(
            expiresAt: walkIn.callExpiresAt!,
            suffix: ' 안에 응답해 주세요',
            onExpired: vm.refresh,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ],
        const Spacer(),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
            minimumSize: const Size.fromHeight(64),
            textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          onPressed: vm.responding ? null : () => _respond(vm, CallResponse.entering),
          child: vm.responding ? const CircularProgressIndicator() : const Text('지금 입장할게요'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: vm.responding ? null : () => _respond(vm, CallResponse.delayed),
                child: const Text('조금 늦어요'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52)),
                onPressed: vm.responding ? null : () => _respond(vm, CallResponse.cancel),
                child: const Text('대기 취소'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _notCalled(WalkIn walkIn, bool expired) {
    final (title, message) = expired || walkIn.status == WalkInStatus.skipped || walkIn.status == WalkInStatus.noShow
        ? ('응답 시간이 지났어요', '매장에 문의하면 다시 안내받을 수 있어요.')
        : (walkIn.status.label, '현재 상태를 확인했어요.');
    return EmptyView(
      icon: Icons.info_outline,
      title: title,
      message: message,
      actionLabel: '대기 상세로 돌아가기',
      onAction: () => Navigator.pop(context),
    );
  }
}

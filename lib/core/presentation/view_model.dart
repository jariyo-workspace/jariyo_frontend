import 'dart:async';

import 'package:flutter/widgets.dart';

import '../error/app_failure.dart';
import '../navigation/app_navigator.dart';
import '../realtime/refresh_bus.dart';

/// 화면 상태 기반 클래스.
///
/// * [runAction]: 사용자 명령 실행. 처리 중에는 같은 명령을 다시 실행하지 않는다(버튼 로딩).
/// * [listenTopics]: 데이터 무효화 주제 구독.
/// * [startPolling]: 실시간 연결이 없어도 동작하도록 주기적으로 재조회.
abstract class ViewModel extends ChangeNotifier {
  bool _disposed = false;
  final Set<String> _busy = {};
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Timer? _pollTimer;

  bool get disposed => _disposed;

  bool isBusy(String action) => _busy.contains(action);

  bool get anyBusy => _busy.isNotEmpty;

  void notify() {
    if (!_disposed) notifyListeners();
  }

  /// [onFailure]가 true를 돌려주면 오류를 직접 처리한 것으로 보고 기본 안내를 생략한다.
  Future<bool> runAction(
    String action,
    Future<void> Function() task, {
    bool Function(AppFailure failure)? onFailure,
  }) async {
    if (_busy.contains(action)) return false;
    _busy.add(action);
    notify();
    try {
      await task();
      return true;
    } on AppFailure catch (failure) {
      final handled = onFailure?.call(failure) ?? false;
      if (!handled) AppMessenger.showFailure(failure);
      return false;
    } finally {
      _busy.remove(action);
      notify();
    }
  }

  void listenTopics(RefreshBus bus, Set<RefreshTopic> topics, VoidCallback onRefresh) {
    _subscriptions.add(bus.stream.where((emitted) => emitted.any(topics.contains)).listen((_) => onRefresh()));
  }

  void startPolling(Duration interval, VoidCallback tick) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) {
      if (!_disposed) tick();
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _pollTimer?.cancel();
    super.dispose();
  }
}

/// 단일 데이터를 불러와 보여주는 화면 상태.
///
/// 첫 진입은 전체 화면 로딩, 이후 갱신은 기존 화면을 유지한 채 부분 로딩으로 처리한다.
abstract class LoadableViewModel<T> extends ViewModel {
  T? data;
  AppFailure? error;

  /// 조용한 갱신이 실패했을 때의 오류. 기존 데이터는 유지된다.
  AppFailure? refreshError;
  bool loading = false;
  bool refreshing = false;

  Future<T> fetch();

  bool get hasData => data != null;

  Future<void> load({bool silent = false}) async {
    if (loading || refreshing) return;
    if (silent && data != null) {
      refreshing = true;
    } else {
      loading = true;
      error = null;
    }
    notify();
    try {
      data = await fetch();
      error = null;
      refreshError = null;
    } on AppFailure catch (failure) {
      if (data == null) {
        error = failure;
      } else {
        refreshError = failure;
      }
    } finally {
      loading = false;
      refreshing = false;
      notify();
    }
  }

  Future<void> refresh() => load(silent: true);
}

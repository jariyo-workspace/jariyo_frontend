import 'package:flutter/foundation.dart';

import '../core/error/app_failure.dart';
import '../core/realtime/realtime_service.dart';
import '../core/storage/key_value_store.dart';
import '../features/auth/domain/auth_entities.dart';
import '../features/auth/domain/auth_usecases.dart';

enum SessionStatus { restoring, restoreFailed, signedOut, guest, signedIn }

enum AppMode { customer, operator }

/// 로그인 상태, 고객/운영자 모드, 운영 매장 선택을 관리한다.
class SessionController extends ChangeNotifier {
  SessionController({
    required this._getProfile,
    required this._signOut,
    required this._hasStoredSession,
    required this._store,
    required this._realtime,
  });

  static const _modeKey = 'session.mode';
  static const _storeKey = 'session.operatorStoreId';

  final GetMyProfile _getProfile;
  final SignOut _signOut;
  final bool Function() _hasStoredSession;
  final KeyValueStore _store;
  final RealtimeService _realtime;

  SessionStatus status = SessionStatus.restoring;
  UserProfile? profile;
  AppFailure? restoreError;
  AppMode mode = AppMode.customer;
  String? operatorStoreId;

  /// 세션이 만료되어 로그인 화면으로 돌아왔는지. 로그인 화면에서 안내 문구를 보여준다.
  bool expiredNotice = false;

  bool get isSignedIn => status == SessionStatus.signedIn;

  Future<void> restore() async {
    if (!_hasStoredSession()) {
      _set(SessionStatus.signedOut);
      return;
    }
    _set(SessionStatus.restoring);
    try {
      profile = await _getProfile();
      _restoreMode();
      _set(SessionStatus.signedIn);
      _connectRealtime();
    } on AppFailure catch (failure) {
      if (failure.kind == FailureKind.sessionExpired || failure.kind == FailureKind.unauthorized) {
        _set(SessionStatus.signedOut);
      } else {
        restoreError = failure;
        _set(SessionStatus.restoreFailed);
      }
    }
  }

  /// 로그인·회원가입 성공 직후 호출한다.
  Future<void> completeSignIn() async {
    profile = await _getProfile();
    expiredNotice = false;
    _restoreMode();
    _set(SessionStatus.signedIn);
    _connectRealtime();
  }

  Future<void> reloadProfile() async {
    profile = await _getProfile();
    notifyListeners();
  }

  void continueAsGuest() => _set(SessionStatus.guest);

  /// 비회원이 로그인이 필요한 기능을 눌렀을 때.
  void requestSignIn() => _set(SessionStatus.signedOut);

  void handleSessionExpired() {
    if (status != SessionStatus.signedIn) return;
    _realtime.disconnectAll();
    profile = null;
    expiredNotice = true;
    _set(SessionStatus.signedOut);
  }

  Future<void> signOut() async {
    _realtime.disconnectAll();
    await _signOut();
    profile = null;
    mode = AppMode.customer;
    operatorStoreId = null;
    await _store.remove(_modeKey);
    await _store.remove(_storeKey);
    _set(SessionStatus.signedOut);
  }

  Future<void> enterOperator(String storeId) async {
    mode = AppMode.operator;
    operatorStoreId = storeId;
    await _store.setString(_modeKey, AppMode.operator.name);
    await _store.setString(_storeKey, storeId);
    _realtime.connectOperator(storeId);
    notifyListeners();
  }

  Future<void> enterCustomer() async {
    mode = AppMode.customer;
    await _store.setString(_modeKey, AppMode.customer.name);
    _realtime.disconnectOperator();
    notifyListeners();
  }

  void _restoreMode() {
    final storedStore = _store.getString(_storeKey);
    final wantsOperator = _store.getString(_modeKey) == AppMode.operator.name;
    if (wantsOperator && storedStore != null && profile?.membershipFor(storedStore) != null) {
      mode = AppMode.operator;
      operatorStoreId = storedStore;
    } else {
      mode = AppMode.customer;
      operatorStoreId = null;
    }
  }

  void _connectRealtime() {
    _realtime.connectCustomer();
    final storeId = operatorStoreId;
    if (mode == AppMode.operator && storeId != null) _realtime.connectOperator(storeId);
  }

  void _set(SessionStatus next) {
    status = next;
    notifyListeners();
  }
}

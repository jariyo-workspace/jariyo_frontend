import 'key_value_store.dart';

/// Access Token과 Refresh Token을 보관한다.
///
/// 서버는 Refresh Token을 `jariyo_refresh` 쿠키로 내려주므로, 모바일 앱은 이 값을 직접 저장해
/// 재발급 요청 시 Cookie 헤더로 다시 보낸다.
class TokenStorage {
  TokenStorage(this._store)
    : _accessToken = _store.getString(_accessKey),
      _refreshToken = _store.getString(_refreshKey);

  static const _accessKey = 'auth.accessToken';
  static const _refreshKey = 'auth.refreshToken';

  final KeyValueStore _store;
  String? _accessToken;
  String? _refreshToken;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get hasSession => _accessToken != null;

  Future<void> saveAccessToken(String token) async {
    _accessToken = token;
    await _store.setString(_accessKey, token);
  }

  Future<void> saveRefreshToken(String token) async {
    _refreshToken = token;
    await _store.setString(_refreshKey, token);
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    await _store.remove(_accessKey);
    await _store.remove(_refreshKey);
  }
}

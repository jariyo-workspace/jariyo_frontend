import '../../../core/error/app_failure.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/auth_entities.dart';
import '../domain/auth_repository.dart';
import 'auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._remote, this._tokens);

  final AuthRemoteDataSource _remote;
  final TokenStorage _tokens;

  @override
  bool get hasStoredSession => _tokens.hasSession;

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _save(await _remote.signIn(email, password));
  }

  @override
  Future<void> signUp(SignUpParams params) async {
    await _save(await _remote.signUp(params));
  }

  @override
  Future<void> signOut() async {
    try {
      await _remote.signOut();
    } on AppFailure {
      // 서버 로그아웃이 실패해도 기기의 세션은 정리한다.
    } finally {
      await _tokens.clear();
    }
  }

  @override
  Future<UserProfile> getProfile() => _remote.getProfile();

  Future<void> _save(AuthTokens tokens) async {
    // Refresh Token은 응답 쿠키에서 ApiClient가 이미 저장했다. 본문으로 내려오는 경우도 함께 처리한다.
    if (tokens.refreshToken != null) await _tokens.saveRefreshToken(tokens.refreshToken!);
    await _tokens.saveAccessToken(tokens.accessToken);
  }
}

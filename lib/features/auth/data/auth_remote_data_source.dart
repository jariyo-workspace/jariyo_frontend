import '../../../core/domain/statuses.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../domain/auth_entities.dart';

class AuthTokens {
  const AuthTokens({required this.accessToken, this.refreshToken});

  final String accessToken;
  final String? refreshToken;
}

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._api);

  final ApiClient _api;

  Future<AuthTokens> signIn(String email, String password) async {
    final result = await _api.post('/auth/sign-in', body: {'email': email, 'password': password}, auth: false);
    return _tokens(result.json);
  }

  Future<AuthTokens> signUp(SignUpParams params) async {
    final result = await _api.post(
      '/auth/sign-up',
      auth: false,
      body: {
        'email': params.email,
        'password': params.password,
        'displayName': params.displayName,
        'phoneNumber': params.phoneNumber,
        'agreements': {'terms': params.agreeTerms, 'privacy': params.agreePrivacy, 'marketing': params.agreeMarketing},
      },
    );
    return _tokens(result.json);
  }

  Future<void> signOut() => _api.post('/auth/sign-out', withRefreshCookie: true);

  Future<UserProfile> getProfile() async => userProfileFromJson((await _api.get('/me')).json);

  AuthTokens _tokens(Json json) =>
      AuthTokens(accessToken: str(json['accessToken']), refreshToken: strOrNull(json['refreshToken']));
}

UserProfile userProfileFromJson(Json json) {
  final profile = asJson(json['customerProfile']);
  return UserProfile(
    id: str(json['id']),
    email: str(json['email']),
    displayName: str(json['displayName']),
    phoneNumber: str(json['phoneNumber']),
    notificationConsent: boolOf(profile['notificationConsent'], true),
    marketingConsent: boolOf(profile['marketingConsent']),
    memberships: asJsonList(json['storeMemberships'])
        .map(
          (m) => StoreMembership(
            storeId: str(m['storeId']),
            role: StoreRole.parse(m['role']),
            status: MemberStatus.parse(m['status']),
          ),
        )
        .toList(),
  );
}

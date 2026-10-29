import 'auth_entities.dart';

abstract interface class AuthRepository {
  bool get hasStoredSession;

  Future<void> signIn({required String email, required String password});

  Future<void> signUp(SignUpParams params);

  Future<void> signOut();

  Future<UserProfile> getProfile();
}

import 'auth_entities.dart';
import 'auth_repository.dart';

class SignIn {
  const SignIn(this._repository);

  final AuthRepository _repository;

  Future<void> call({required String email, required String password}) =>
      _repository.signIn(email: email.trim(), password: password);
}

class SignUp {
  const SignUp(this._repository);

  final AuthRepository _repository;

  Future<void> call(SignUpParams params) => _repository.signUp(params);
}

class SignOut {
  const SignOut(this._repository);

  final AuthRepository _repository;

  Future<void> call() => _repository.signOut();
}

class GetMyProfile {
  const GetMyProfile(this._repository);

  final AuthRepository _repository;

  Future<UserProfile> call() => _repository.getProfile();
}

/// 회원가입 입력 규칙. 서버 검증과 같은 기준을 사용한다.
class AccountRules {
  const AccountRules._();

  static const passwordMinLength = 15;
  static const passwordMaxLength = 64;

  static String? validateEmail(String email) {
    final value = email.trim();
    if (value.isEmpty) return '이메일은 필수 입력사항입니다.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) return '올바른 이메일 형식이 아니에요.';
    return null;
  }

  static String? validatePassword(String password) {
    final length = password.runes.length;
    if (length == 0) return '비밀번호는 필수 입력사항입니다.';
    if (length < passwordMinLength || length > passwordMaxLength) {
      return '비밀번호는 $passwordMinLength자 이상 $passwordMaxLength자 이하로 입력해 주세요.';
    }
    return null;
  }

  static String? validateName(String name) {
    final value = name.trim();
    if (value.isEmpty) return '이름은 필수 입력사항입니다.';
    if (!RegExp(r'^[A-Za-z가-힣 ]+$').hasMatch(value)) return '이름은 한글 또는 영문만 입력가능합니다.';
    if (value.length > 100) return '이름은 100자 이하로 입력해 주세요.';
    return null;
  }

  /// 서버는 `010`으로 시작하는 11자리 휴대폰 번호만 허용한다.
  static String? validatePhone(String digits) {
    if (digits.isEmpty) return '휴대폰 번호는 필수 입력사항입니다.';
    if (!RegExp(r'^010\d{8}$').hasMatch(digits)) return '010으로 시작하는 휴대폰 번호 11자리를 입력해 주세요.';
    return null;
  }
}

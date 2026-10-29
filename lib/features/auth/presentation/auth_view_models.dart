import '../../../app/session_controller.dart';
import '../../../core/presentation/view_model.dart';
import '../domain/auth_entities.dart';
import '../domain/auth_usecases.dart';

class SignInViewModel extends ViewModel {
  SignInViewModel(this._signIn, this._session);

  final SignIn _signIn;
  final SessionController _session;

  String? emailError;
  String? passwordError;

  bool get submitting => isBusy('signIn');

  Future<void> submit({required String email, required String password}) async {
    emailError = AccountRules.validateEmail(email);
    passwordError = password.isEmpty ? '비밀번호는 필수 입력사항입니다.' : null;
    notify();
    if (emailError != null || passwordError != null) return;
    await runAction(
      'signIn',
      () async {
        await _signIn(email: email, password: password);
        await _session.completeSignIn();
      },
      onFailure: (failure) {
        if (failure.code == 'INVALID_CREDENTIALS') {
          passwordError = failure.message;
          notify();
          return true;
        }
        return false;
      },
    );
  }
}

class SignUpViewModel extends ViewModel {
  SignUpViewModel(this._signUp, this._session);

  final SignUp _signUp;
  final SessionController _session;

  String? emailError;
  String? passwordError;
  String? passwordConfirmError;
  String? nameError;
  String? phoneError;
  String? agreementError;
  bool agreeTerms = false;
  bool agreePrivacy = false;
  bool agreeMarketing = false;

  bool get submitting => isBusy('signUp');

  bool get agreeAll => agreeTerms && agreePrivacy && agreeMarketing;

  void setAgreeAll(bool value) {
    agreeTerms = agreePrivacy = agreeMarketing = value;
    agreementError = null;
    notify();
  }

  void setAgreement({bool? terms, bool? privacy, bool? marketing}) {
    agreeTerms = terms ?? agreeTerms;
    agreePrivacy = privacy ?? agreePrivacy;
    agreeMarketing = marketing ?? agreeMarketing;
    agreementError = null;
    notify();
  }

  Future<void> submit({
    required String email,
    required String password,
    required String passwordConfirm,
    required String name,
    required String phoneDigits,
  }) async {
    emailError = AccountRules.validateEmail(email);
    passwordError = AccountRules.validatePassword(password);
    passwordConfirmError = password == passwordConfirm ? null : '비밀번호와 비밀번호 확인이 일치하지 않습니다.';
    nameError = AccountRules.validateName(name);
    phoneError = AccountRules.validatePhone(phoneDigits);
    agreementError = agreeTerms && agreePrivacy ? null : '이용약관과 개인정보 처리방침에 동의해야 가입할 수 있어요.';
    notify();
    if ([
      emailError,
      passwordError,
      passwordConfirmError,
      nameError,
      phoneError,
      agreementError,
    ].any((e) => e != null)) {
      return;
    }
    await runAction(
      'signUp',
      () async {
        await _signUp(
          SignUpParams(
            email: email.trim(),
            password: password,
            displayName: name.trim(),
            phoneNumber: phoneDigits,
            agreeTerms: agreeTerms,
            agreePrivacy: agreePrivacy,
            agreeMarketing: agreeMarketing,
          ),
        );
        await _session.completeSignIn();
      },
      onFailure: (failure) {
        switch (failure.code) {
          case 'EMAIL_ALREADY_EXISTS':
            emailError = failure.message;
          case 'PHONE_NUMBER_ALREADY_EXISTS':
            phoneError = failure.message;
          case 'INVALID_PASSWORD_FORMAT':
            passwordError = failure.message;
          case 'REQUIRED_AGREEMENT_MISSING':
            agreementError = failure.message;
          default:
            return false;
        }
        notify();
        return true;
      },
    );
  }
}

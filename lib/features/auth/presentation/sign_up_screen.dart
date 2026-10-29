import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

import '../../../app/session_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/view_model_scope.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_usecases.dart';
import 'auth_view_models.dart';
import 'sign_in_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    for (final c in [_email, _password, _passwordConfirm, _name, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<SignUpViewModel>(
      create: () => SignUpViewModel(SignUp(GetIt.I<AuthRepository>()), GetIt.I<SessionController>()),
      builder: (context, vm) => Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            const AuthBackground(),
            SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: '뒤로',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: AppColors.text),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 24),
                            const Text(
                              '회원가입',
                              style: TextStyle(color: AppColors.text, fontSize: 24, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            const Text('회원 정보를 입력하여 계정을 만들어주세요.'),
                            const SizedBox(height: 14),
                            const FieldLabel('이메일'),
                            AppTextField(
                              controller: _email,
                              svg: 'email',
                              hint: '이메일을 입력해주세요.',
                              error: vm.emailError,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                            ),
                            const SizedBox(height: 14),
                            const FieldLabel('비밀번호'),
                            AppTextField(
                              controller: _password,
                              svg: 'lock',
                              hint: '15자 이상 입력해주세요.',
                              error: vm.passwordError,
                              isPassword: true,
                              autofillHints: const [AutofillHints.newPassword],
                            ),
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                '기억하기 쉬운 문장을 사용하면 안전하고 편리해요. (15~64자)',
                                style: TextStyle(color: AppColors.lightText, fontSize: 12),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const FieldLabel('비밀번호 확인'),
                            AppTextField(
                              controller: _passwordConfirm,
                              svg: 'lock',
                              hint: '비밀번호를 다시 입력해주세요.',
                              error: vm.passwordConfirmError,
                              isPassword: true,
                            ),
                            const SizedBox(height: 14),
                            const FieldLabel('이름'),
                            AppTextField(
                              controller: _name,
                              svg: 'person',
                              hint: '이름을 입력해주세요.',
                              error: vm.nameError,
                              autofillHints: const [AutofillHints.name],
                            ),
                            const SizedBox(height: 14),
                            const FieldLabel('휴대폰 번호'),
                            AppTextField(
                              controller: _phone,
                              hint: '01012345678',
                              error: vm.phoneError,
                              keyboardType: TextInputType.phone,
                              maxLength: 11,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              autofillHints: const [AutofillHints.telephoneNumber],
                            ),
                            const SizedBox(height: 14),
                            _AgreementBox(vm: vm),
                            if (vm.agreementError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(vm.agreementError!, style: const TextStyle(color: AppColors.danger)),
                              ),
                            const SizedBox(height: 14),
                            AppButton(
                              label: '회원가입',
                              loading: vm.submitting,
                              loadingLabel: '계정을 만들고 있어요',
                              onPressed: () => vm.submit(
                                email: _email.text,
                                password: _password.text,
                                passwordConfirm: _passwordConfirm.text,
                                name: _name.text,
                                phoneDigits: _phone.text,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('이미 계정이 있으신가요?', style: TextStyle(color: AppColors.text)),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text(
                                    '로그인',
                                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 64),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgreementBox extends StatelessWidget {
  const _AgreementBox({required this.vm});

  final SignUpViewModel vm;

  @override
  Widget build(BuildContext context) {
    Widget item(String label, bool value, ValueChanged<bool> onChanged, {bool required = true}) => CheckboxListTile(
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: AppColors.primary,
      title: Text('${required ? '[필수]' : '[선택]'} $label'),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          children: [
            CheckboxListTile(
              value: vm.agreeAll,
              onChanged: (v) => vm.setAgreeAll(v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.primary,
              title: const Text('전체 동의', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const Divider(),
            item('이용약관에 동의합니다.', vm.agreeTerms, (v) => vm.setAgreement(terms: v)),
            item('개인정보 처리방침에 동의합니다.', vm.agreePrivacy, (v) => vm.setAgreement(privacy: v)),
            item('마케팅 정보 수신에 동의합니다.', vm.agreeMarketing, (v) => vm.setAgreement(marketing: v), required: false),
          ],
        ),
      ),
    );
  }
}

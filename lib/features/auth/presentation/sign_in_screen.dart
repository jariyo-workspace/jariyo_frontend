import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../app/session_controller.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/view_model_scope.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_usecases.dart';
import 'auth_view_models.dart';
import 'sign_up_screen.dart';

/// C-01 시작 및 로그인 / A-01 운영자 로그인
///
/// 운영자도 같은 계정으로 로그인하며, 매장 멤버십이 있으면 마이페이지에서 운영 화면으로 전환한다.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = GetIt.I<SessionController>();
    return ViewModelScope<SignInViewModel>(
      create: () => SignInViewModel(SignIn(GetIt.I<AuthRepository>()), session),
      builder: (context, vm) => Scaffold(
        backgroundColor: AppColors.background,
        body: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(24, MediaQuery.paddingOf(context).top + 40, 24, 0),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset('assets/images/logo.png', width: 32),
                          const SizedBox(width: 10),
                          const Text(
                            'Jariyo',
                            style: TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const Text('예약도 대기도\n한자리에서', style: AppText.display),
                      const SizedBox(height: 8),
                      const Text('기다림은 짧게, 경험은 풍성하게.', style: AppText.sub),
                      if (session.expiredNotice) ...[
                        const SizedBox(height: 16),
                        const NoticeBox(
                          icon: Icons.lock_clock,
                          color: AppColors.attention,
                          message: '로그인이 만료되었어요. 다시 로그인하면 진행하던 예약을 이어서 할 수 있어요.',
                        ),
                      ],
                      const SizedBox(height: 32),
                      const FieldLabel('이메일', required: false),
                      AppTextField(
                        controller: _email,
                        svg: 'email',
                        hint: '이메일을 입력해주세요.',
                        error: vm.emailError,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      const FieldLabel('비밀번호', required: false),
                      AppTextField(
                        controller: _password,
                        svg: 'lock',
                        hint: '비밀번호를 입력해주세요.',
                        isPassword: true,
                        error: vm.passwordError,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => vm.submit(email: _email.text, password: _password.text),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => AppMessenger.show('비밀번호 재설정 기능은 준비 중이에요. 매장이나 고객센터에 문의해 주세요.'),
                          child: const Text('비밀번호를 잊으셨나요?', style: TextStyle(color: AppColors.text)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppButton(
                        label: '로그인',
                        loading: vm.submitting,
                        loadingLabel: '로그인하고 있어요',
                        onPressed: () => vm.submit(email: _email.text, password: _password.text),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Expanded(child: Divider(color: AppColors.lightText)),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14),
                            child: Text('또는', style: TextStyle(color: AppColors.lightText, fontSize: 12)),
                          ),
                          const Expanded(child: Divider(color: AppColors.lightText)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: '로그인 없이 매장 둘러보기',
                        variant: AppButtonVariant.secondary,
                        onPressed: session.continueAsGuest,
                      ),
                      const SizedBox(height: 8),
                      AppButton(
                        label: '비회원 현장 대기 조회',
                        variant: AppButtonVariant.text,
                        onPressed: () => _showGuestWalkInInfo(context),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('계정이 없으신가요?', style: TextStyle(color: AppColors.text)),
                          TextButton(
                            onPressed: () => pushPage<void>(context, const SignUpScreen()),
                            child: const Text(
                              '회원가입',
                              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGuestWalkInInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('비회원 현장 대기'),
        content: const Text(
          '비회원 현장 대기는 매장 직원이 대신 등록해 드려요.\n'
          '대기 순서와 호출은 매장에서 직접 안내받을 수 있어요.\n\n'
          '앱에서 대기 순서를 확인하고 호출 알림을 받으려면 로그인해 주세요.',
          style: TextStyle(height: 1.5),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
      ),
    );
  }
}

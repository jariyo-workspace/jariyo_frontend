import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/api_client.dart';
import '../app_nav.dart';
import '../widgets/common.dart';

class SignInScreen extends StatefulWidget {
  /// 세션 만료 전에 보던 매장. 다시 로그인하면 이 매장의 매장 상세·예약을 연다.
  final String? returnStoreId;

  const SignInScreen({super.key, this.returnStoreId});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _emailError;
  String? _passwordError;
  String? _bannerTitle;
  String? _bannerSub;
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final email = _email.text.trim();
    final password = _password.text;
    setState(() {
      _emailError = email.isEmpty
          ? S.signInEmailRequired
          : (_emailPattern.hasMatch(email) ? null : S.signInEmailInvalid);
      _passwordError = password.isEmpty ? S.signInPasswordRequired : null;
      _bannerTitle = null;
      _bannerSub = null;
    });
    if (_emailError != null || _passwordError != null) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      await Api.signIn(email, password);
      if (!mounted) return;
      AppNav.afterSignIn(widget.returnStoreId);
    } on ApiException catch (e) {
      Session.clear();
      if (!mounted) return;
      setState(() {
        _submitting = false;
        if (e.code == 'INVALID_CREDENTIALS' || e.code == 'USER_SUSPENDED') {
          _bannerTitle = e.message;
          _bannerSub = null;
          _password.clear();
        } else if (e.message.isNotEmpty && e.status < 500) {
          _bannerTitle = e.message;
          _bannerSub = null;
        } else {
          _bannerTitle = S.networkError;
          _bannerSub = S.networkErrorSub;
        }
      });
    } catch (_) {
      Session.clear();
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _bannerTitle = S.networkError;
        _bannerSub = S.networkErrorSub;
      });
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
      );

  Widget _fieldError(String? error) {
    if (error == null) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          const Icon(Icons.error, size: 16, color: AppColors.error),
          const SizedBox(width: 4),
          Expanded(child: Text(error, style: const TextStyle(fontSize: 13, color: AppColors.error))),
        ],
      ),
    );
  }

  InputDecoration _decoration(IconData icon, String hint, bool hasError) => InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.textSub),
        hintText: hint,
        enabledBorder: hasError
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.error, width: 2),
              )
            : null,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 72),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.confirmation_number, size: 40, color: AppColors.primary),
                        SizedBox(width: 10),
                        Text(S.appName,
                            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(S.appTagline,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.text)),
                    const SizedBox(height: 8),
                    const Text(S.appSubtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSub)),
                    const SizedBox(height: 40),
                    if (_bannerTitle != null) ...[
                      MessageBanner(title: _bannerTitle!, sub: _bannerSub),
                      const SizedBox(height: 20),
                    ],
                    _label(S.signInEmail),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: _decoration(Icons.mail_outline, 'minsu.kim@example.com', _emailError != null),
                    ),
                    _fieldError(_emailError),
                    const SizedBox(height: 16),
                    _label(S.signInPassword),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: _decoration(Icons.lock_outline, S.signInPassword, _passwordError != null),
                    ),
                    _fieldError(_passwordError),
                    const SizedBox(height: 28),
                    PrimaryButton(label: S.signInSubmit, loading: _submitting, onPressed: _submit),
                    const Spacer(),
                    const Padding(
                      padding: EdgeInsets.only(top: 40, bottom: 24),
                      child: Text(S.appCopyright,
                          textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textSub)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

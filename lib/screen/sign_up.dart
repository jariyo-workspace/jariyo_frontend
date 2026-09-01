import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:jariyo_frontend/core/core.dart';
import 'package:jariyo_frontend/main.dart';
import 'package:jariyo_frontend/screen/sign_in.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordRe = TextEditingController();
  final _name = TextEditingController();
  final _number1 = TextEditingController();
  final _number2 = TextEditingController();
  final _number3 = TextEditingController();

  bool hasAgreeTermsAndPrivacy = false;
  bool hasAgreeMarketing = false;

  String? _emailError;
  String? _passwordError;
  String? _passwordReError;
  String? _nameError;
  String? _numberError;

  signUp() async {
    try {
      final body = {
        'email': _email.text,
        'password': _password.text,
        'displayName': _name.text,
        'phoneNumber': '${_number1.text}-${_number2.text}-${_number3.text}',
        'agreements': {
          'terms': hasAgreeTermsAndPrivacy,
          'privacy': hasAgreeTermsAndPrivacy,
          'marketing': hasAgreeMarketing,
        }
      };
      final response = await client.post(
        Uri.parse('http://$baseUrl/auth/sign-up'),
        headers: {'Content-Type':'application/json'},
        body: jsonEncode(body),
      );
      print(response.body);
      if (response.statusCode == 201) {
        Navigator.pop(context);
        Core.toast('회원가입 되었습니다.');
      } else {
        Core.toast('이미 가입된 전화번호입니다.');
      }
    } catch (e) {
      Core.toast('인터넷 연결 상태를 확인해주세요.');
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordRe.dispose();
    _name.dispose();
    _number1.dispose();
    _number2.dispose();
    _number3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          background(),
          Column(
            children: [
              SizedBox(height: 54),
              Container(
                height: 50,
                padding: .only(left: 18),
                alignment: .centerLeft,
                child: GestureDetector(onTap: () => Navigator.pop(context), child: Icon(Icons.arrow_back, color: textColor)),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        SizedBox(height: 24),
                        Align(alignment: .centerLeft, child: Text('회원가입', style: TextStyle(color: textColor, fontSize: 24, fontWeight: .w600))),
                        SizedBox(height: 8),
                        Align(alignment: .centerLeft, child: Text('회원 정보를 입력하여 계정을 만들어주세요.')),
                        SizedBox(height: 14),
                        title('이메일'),
                        CustomTextField(controller: _email, svg: 'email', text: '이메일을 입력해주세요.', error: _emailError),
                        SizedBox(height: 14),
                        title('비밀번호'),
                        CustomTextField(controller: _password, svg: 'lock', text: '비밀번호를 입력해주세요.', error: _passwordError, isPassword: true),
                        SizedBox(height: 14),
                        title('비밀번호 확인'),
                        CustomTextField(controller: _passwordRe, svg: 'lock', text: '비밀번호를 다시 입력해주세요.', error: _passwordReError, isPassword: true),
                        SizedBox(height: 14),
                        title('이름'),
                        CustomTextField(controller: _name, svg: 'person', text: '이름을 입력해주세요.', error: _nameError),
                        SizedBox(height: 14),
                        title('휴대폰 번호'),
                        Row(
                          spacing: 8,
                          children: [
                            Expanded(child: CustomTextField(controller: _number1, text: '010', maxLength: 3)),
                            Text('-'),
                            Expanded(child: CustomTextField(controller: _number2, text: '1234', maxLength: 4)),
                            Text('-') ,
                            Expanded(child: CustomTextField(controller: _number3, text: '5678', maxLength: 4)),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text(_numberError ?? ''),
                        Row(
                          children: [
                            Checkbox(value: hasAgreeTermsAndPrivacy, onChanged: (value) => setState(() => hasAgreeTermsAndPrivacy = value!), activeColor: primaryColor, side: BorderSide(color: textColor, width: 2)),
                            Text('이용약관 및 개인정보처리방침에 동의합니다.'),
                          ],
                        ),
                        Row(
                          children: [
                            Checkbox(value: hasAgreeMarketing, onChanged: (value) => setState(() => hasAgreeMarketing = value!), activeColor: primaryColor, side: BorderSide(color: textColor, width: 2)),
                            Text('마케팅 수신에 동의합니다.'),
                          ],
                        ),
                        SizedBox(height: 14),
                        GestureDetector(
                          onTap: () {
                            if (!_email.text.contains('@')) {
                              _emailError = '이메일에는 "@"이 포함되어야 합니다.';
                              setState(() {});
                              return;
                            }
                            if (!_email.text.contains('.')) {
                              _emailError = '이메일에는 "."이 포함되어야 합니다.';
                              setState(() {});
                              return;
                            }
                            _emailError = null;
                            setState(() {});
                            if (_password.text.length < 8) {
                              _passwordError = '비밀번호는 최소 8자 이상이어야 합니다.';
                              setState(() {});
                              return;
                            }
                            if (!_password.text.contains(RegExp(r'[A-Z]'))) {
                              _passwordError = '비밀번호에는 대문자를 최소 1자 이상 입력해야합니다.';
                              setState(() {});
                              return;
                            }
                            if (!_password.text.contains(RegExp(r'[a-z]'))) {
                              _passwordError = '비밀번호에는 소문자를 최소 1자 이상 입력해야합니다.';
                              setState(() {});
                              return;
                            }
                            if (!_password.text.contains(RegExp(r'[0-9]'))) {
                              _passwordError = '비밀번호에는 숫자를 최소 1자 이상 입력해야합니다.';
                              setState(() {});
                              return;
                            }
                            if (!_password.text.contains(RegExp(r'[!@#$%^&*]'))) {
                              _passwordError = '비밀번호에는 특수문자를 최소 1자 이상 입력해야합니다.';
                              setState(() {});
                              return;
                            }
                            _passwordError = null;
                            setState(() {});
                            if (_password.text != _passwordRe.text) {
                              _passwordReError = '비밀번호와 비밀번호 확인이 일치하지 않습니다.';
                              setState(() {});
                              return;
                            }
                            _passwordReError = null;
                            setState(() {});
                            if (!RegExp(r'^[A-Za-z가-힣]+$').hasMatch(_name.text)) {
                              _nameError = '이름은 한글 또는 영문만 입력가능합니다.';
                              setState(() {});
                              return;
                            }
                            _nameError = null;
                            setState(() {});
                            if (_number1.text.isEmpty) {
                              _numberError = '휴대폰 번호는 필수 입력사항입니다.';
                              setState(() {});
                              return;
                            }
                            if (_number2.text.isEmpty) {
                              _numberError = '휴대폰 번호는 필수 입력사항입니다.';
                              setState(() {});
                              return;
                            }
                            if (_number3.text.isEmpty) {
                              _numberError = '휴대폰 번호는 필수 입력사항입니다.';
                              setState(() {});
                              return;
                            }
                            if (!RegExp(r'^[0-9]+$').hasMatch(_number1.text)) {
                              _numberError = '휴대폰 번호에는 숫자만 입력가능합니다.';
                              setState(() {});
                              return;
                            }
                            if (!RegExp(r'^[0-9]+$').hasMatch(_number2.text)) {
                              _numberError = '휴대폰 번호에는 숫자만 입력가능합니다.';
                              setState(() {});
                              return;
                            }
                            if (!RegExp(r'^[0-9]+$').hasMatch(_number3.text)) {
                              _numberError = '휴대폰 번호에는 숫자만 입력가능합니다.';
                              setState(() {});
                              return;
                            }
                            _numberError = null;
                            setState(() {});
                            if (!hasAgreeTermsAndPrivacy) {
                              Core.toast('회원가입을 하려면 이용약관에 동의해야 합니다.');
                              return;
                            }
                            signUp();
                          },
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: .circular(8),
                            ),
                            alignment: .center,
                            child: Text('회원가입', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: .w700)),
                          ),
                        ),
                        SizedBox(height: 14),
                        Row(
                          spacing: 8,
                          mainAxisAlignment: .center,
                          children: [
                            Text('이미 계정이 있으신가요?', style: TextStyle(color: textColor)),
                            GestureDetector(onTap: () => Navigator.pop(context), child: Text('로그인', style: TextStyle(color: primaryColor, fontWeight: .w600))),
                          ],
                        ),
                        SizedBox(height: 64),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

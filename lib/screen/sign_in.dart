import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:jariyo_frontend/core/core.dart';
import 'package:jariyo_frontend/main.dart';
import 'package:jariyo_frontend/screen/main.dart';
import 'package:jariyo_frontend/screen/sign_up.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool isHide = true;

  signIn() async {
    final body = {
      'email': _email.text,
      'password': _password.text,
    };
    final response = await client.post(
      Uri.parse('http://$baseUrl/auth/sign-in'),
      headers: {'Content-Type':'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      Core.accessToken = responseData['data']['accessToken'];
      Core.refreshToken = responseData['data']['refreshToken'];
      Navigator.of(context).pushAndRemoveUntil(move(MainScreen()), (route) => false);
      Core.toast('로그인되었습니다.');
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xffF8F9FA),
      body: Column(
        children: [
          background(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: .center,
              children: [
                SizedBox(height: 34),
                Row(
                  spacing: 12,
                  children: [
                    Image.asset('assets/images/logo.png', width: 34),
                    Text('Jariyo', style: TextStyle(color: primaryColor, fontSize: 24, fontWeight: .w600)),
                  ],
                ),
                SizedBox(height: 18),
                Align(alignment: .centerLeft, child: Text('예약도 대기도 한 자리에서', style: TextStyle(color: textColor, fontSize: 24, fontWeight: .w500))),
                SizedBox(height: 8),
                Align(alignment: .centerLeft, child: Text('기다림은 짧게, 경험은 풍성하게.\n자리요와 함께 특별한 시간을 보내세요.', style: TextStyle(color: lightTextColor, fontSize: 16))),
                SizedBox(height: 24),
                title('Email'),
                CustomTextField(controller: _email, svg: 'email', text: '이메일을 입력해주세요.'),
                SizedBox(height: 12),
                title('Password'),
                CustomTextField(controller: _password, svg: 'lock', text: '비밀번호를 입력해주세요.', isPassword: true),
                SizedBox(height: 18),
                Align(alignment: .centerRight, child: Text('비밀번호를 잊으셨나요?', style: TextStyle(color: textColor))),
                SizedBox(height: 24),
                GestureDetector(
                  onTap: () {
                    if (_email.text.isEmpty) {
                      Core.toast('이메일은 필수 입력사항입니다.');
                      return;
                    }
                    if (!_email.text.contains('@')) {
                      Core.toast('이메일에는 "@"이 포함되어야 합니다.');
                      return;
                    }
                    if (!_email.text.contains('.')) {
                      Core.toast('이메일에는 "."이 포함되어야 합니다.');
                      return;
                    }
                    if (_password.text.isEmpty) {
                      Core.toast('비밀번호는 필수 입력사항입니다.');
                      return;
                    }
                    signIn();
                  },
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: .circular(8),
                    ),
                    alignment: .center,
                    child: Text('Sign In', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: .w600)),
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  spacing: 14,
                  children: [
                    Expanded(child: Container(color: lightTextColor, height: 1)),
                    Text('또는', style: TextStyle(color: lightTextColor, fontSize: 12)),
                    Expanded(child: Container(color: lightTextColor, height: 1)),
                  ],
                ),
                SizedBox(height: 18),
                Row(
                  spacing: 8,
                  mainAxisAlignment: .center,
                  children: [
                    GestureDetector(child: Text('계정이 없으신가요?', style: TextStyle(color: textColor))),
                    GestureDetector(onTap: () => Navigator.of(context).push(move(SignUpScreen())), child: Text('회원가입', style: TextStyle(color: primaryColor, fontWeight: .w600))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String baseUrl = '10.0.2.2:8000/api/v1';

move(screen) => MaterialPageRoute(builder: (context) => screen);

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String text;
  final String? svg;
  final bool isPassword;
  final String? error;
  final int? maxLength;
  final int? maxLines;
  const CustomTextField({super.key, required this.controller, required this.text, this.svg, this.isPassword = false, this.error, this.maxLength, this.maxLines});

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool isHide = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: ValueKey(widget.text),
      maxLines: widget.maxLines ?? 1,
      onChanged: (value) {
        if (widget.maxLength == null) return;
        if (widget.maxLength == value.length) FocusScope.of(context).nextFocus();
      },
      obscureText: isHide && widget.isPassword,
      onTapOutside: (event) => FocusScope.of(context).unfocus(),
      style: TextStyle(color: textColor, fontSize: 14.8),
      controller: widget.controller,
      textAlign: widget.maxLength == null ? .start : .center,
      decoration: InputDecoration(
        errorText: widget.error,
        errorStyle: TextStyle(color: Colors.red),
        counterText: '',
        filled: true,
        fillColor: Colors.white,
        hintText: widget.text,
        hintStyle: TextStyle(color: textColor, fontSize: 14.8),
        prefixIcon: widget.svg == null ? null : UnconstrainedBox(child: SvgPicture.asset('assets/icons/${widget.svg}.svg', color: textColor)),
        suffixIcon: !widget.isPassword ? null : GestureDetector(onTap: () => setState(() => isHide = !isHide), child: UnconstrainedBox(child: SvgPicture.asset('assets/icons/visibility${isHide ? '' : '-off'}.svg', color: textColor))),
        focusedErrorBorder: OutlineInputBorder(borderRadius: .circular(8), borderSide: BorderSide(color: Colors.red)),
        errorBorder: OutlineInputBorder(borderRadius: .circular(8), borderSide: BorderSide(color: Colors.red)),
        disabledBorder: OutlineInputBorder(borderRadius: .circular(8), borderSide: BorderSide(color: lightTextColor)),
        focusedBorder: OutlineInputBorder(borderRadius: .circular(8), borderSide: BorderSide(color: primaryColor)),
        enabledBorder: OutlineInputBorder(borderRadius: .circular(8), borderSide: BorderSide(color: lightTextColor)),
        border: OutlineInputBorder(borderRadius: .circular(8), borderSide: BorderSide(color: lightTextColor)),
      ),
    );
  }
}

title(text) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Row(
    spacing: 4,
    children: [
      Text(text, style: TextStyle(color: textColor, fontWeight: .w500)),
      Text('*', style: TextStyle(color: Colors.red)),
    ],
  ),
);

background() => ImageFiltered(
  imageFilter: .blur(sigmaX: 2, sigmaY: 2),
  child: Container(
    height: 240,
    decoration: BoxDecoration(
      image: DecorationImage(image: AssetImage('assets/images/background.png'), fit: .cover, colorFilter: .mode(Colors.white.withAlpha(110), .lighten)),
    ),
  ),
);

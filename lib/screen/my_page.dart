import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:jariyo_frontend/core/core.dart';
import 'package:jariyo_frontend/main.dart';
import 'package:jariyo_frontend/model/me.dart';
import 'package:jariyo_frontend/screen/sign_in.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  getMe() async {
    final response = await client.get(
      Uri.parse('http://$baseUrl/me'),
      headers: {'Authorization':'Bearer ${Core.accessToken}', 'Accept':'application/json'},
    );
    print(response.body);
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      Core.me = MeModel.fromJson(responseData['data']);
      Core.update();
    }
  }

  @override
  void initState() {
    super.initState();
    getMe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xffF8F9FA),
      appBar: AppBar(
        backgroundColor: Color(0xffF3F4F5),
        title: Text('마이페이지', style: TextStyle(color: primaryColor, fontSize: 20, fontWeight: .w600)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: .center,
          children: [
            SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: textColor.withAlpha(30),
                borderRadius: .circular(12),
              ),
              padding: .all(14),
              alignment: .center,
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: primaryColor.withAlpha(100),
                      shape: .circle,
                    ),
                    alignment: .center,
                    child: SvgPicture.asset('assets/icons/person.svg', color: primaryColor, width: 40),
                  ),
                  SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(Core.me?.displayName ?? 'Unknown', style: TextStyle(color: textColor, fontSize: 16, fontWeight: .w600)),
                      Text(Core.me?.email ?? 'Unknown@mail.com', style: TextStyle(color: textColor)),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            tile('상품 등록', '', () {}),
            tile('내 등록 상품', '', () {}),
            Divider(),
            tile('판매내역', '', () {}),
            tile('구매내역', '', () {}),
            Divider(),
            tile('고객센터', '', () {}),
            tile('앱 정보', '', () {}),
            SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                showDialog(context: context, builder: (context) {
                  return CupertinoAlertDialog(
                    title: Text('정말 로그아웃 하시겠습니까?'),
                    actions: [
                      CupertinoDialogAction(child: Text('취소', style: TextStyle(color: Colors.black)), onPressed: () {
                        Navigator.pop(context);
                      }),
                      CupertinoDialogAction(child: Text('로그아웃', style: TextStyle(color: Colors.red)), onPressed: () {
                        Core.accessToken = null;
                        Core.refreshToken = null;
                        Navigator.of(context).pushAndRemoveUntil(move(SignInScreen()), (route) => false);
                      }),
                    ],
                  );
                });
              },
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  border: .all(color: Colors.red),
                  borderRadius: .circular(100),
                ),
                alignment: .center,
                child: Text('로그아웃', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: .w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  tile(text, svg, onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 64,
      color: Color(0xffF8F9FA),
      child: Row(
        children: [
          SvgPicture.asset('assets/icons/$svg.svg', color: textColor, width: 24),
          Text(text, style: TextStyle(color: textColor, fontSize: 16)),
          Spacer(),
          Icon(Icons.keyboard_arrow_right, color: textColor, size: 28),
        ],
      ),
    ),
  );
}

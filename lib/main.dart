import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jariyo_frontend/screen/sign_in.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([.portraitUp]);
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SignInScreen(),
      theme: ThemeData(
        colorSchemeSeed: primaryColor,
      ),
    )
  );
}

Color lightTextColor = Color(0xff434654);
Color textColor = Color(0xff191C1D);
Color primaryColor = Color(0xff003FB1);

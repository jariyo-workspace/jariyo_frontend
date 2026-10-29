import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/strings.dart';
import 'core/theme.dart';
import 'ui/app_nav.dart';
import 'ui/screens/sign_in_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  AppNav.init();
  runApp(const JariyoApp());
}

class JariyoApp extends StatelessWidget {
  const JariyoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: S.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: AppNav.navigatorKey,
      theme: buildTheme(),
      home: const SignInScreen(),
    );
  }
}

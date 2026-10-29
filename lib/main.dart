import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/injector.dart';
import 'app/jariyo_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    // 운영자 화면은 태블릿 가로 모드를 지원한다.
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await configureDependencies();
  runApp(const JariyoApp());
}

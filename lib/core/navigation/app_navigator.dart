import 'package:flutter/material.dart';

import '../error/app_failure.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

Route<T> pageRoute<T>(Widget page) => MaterialPageRoute<T>(builder: (_) => page);

Future<T?> pushPage<T>(BuildContext context, Widget page) => Navigator.of(context).push<T>(pageRoute(page));

Future<T?> replacePage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).pushReplacement<T, Object?>(pageRoute(page));

/// 복구 가능한 가벼운 작업 결과를 스낵바로 안내한다.
class AppMessenger {
  const AppMessenger._();

  static void show(String message, {String? actionLabel, VoidCallback? onAction, Duration? duration}) {
    final messenger = appMessengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: duration ?? const Duration(seconds: 4),
          action: actionLabel == null || onAction == null
              ? null
              : SnackBarAction(label: actionLabel, onPressed: onAction),
        ),
      );
  }

  static void showFailure(AppFailure failure) {
    if (failure.kind == FailureKind.sessionExpired) return; // 로그인 화면에서 별도로 안내한다.
    show(failure.message);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/navigation/app_navigator.dart';
import '../core/network/json.dart';
import '../core/realtime/event_stream_client.dart';
import '../core/realtime/realtime_service.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/common_widgets.dart';
import '../features/admin/presentation/operator_shell.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/waitlist/presentation/slot_offer_screen.dart';
import '../features/walk_in/presentation/walk_in_call_screen.dart';
import 'customer_shell.dart';
import 'injector.dart';
import 'session_controller.dart';

class JariyoApp extends StatefulWidget {
  const JariyoApp({super.key});

  @override
  State<JariyoApp> createState() => _JariyoAppState();
}

class _JariyoAppState extends State<JariyoApp> {
  final _session = sl<SessionController>();
  SessionStatus? _lastStatus;
  AppMode? _lastMode;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
    sl<RealtimeService>().onAttention = _onAttention;
    _session.restore();
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }

  /// 로그인 상태나 모드가 바뀌면 쌓여 있던 화면을 정리한다.
  void _onSessionChanged() {
    final changed = _lastStatus != _session.status || _lastMode != _session.mode;
    _lastStatus = _session.status;
    _lastMode = _session.mode;
    if (changed) appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  /// 현장 호출과 빈자리 제안은 어느 화면에 있든 바로 알린다.
  void _onAttention(ServerEvent event) {
    final data = event.data;
    if (event.type == 'WALK_IN_CALLED') {
      final walkInId = strOrNull(data['walkInId']);
      if (walkInId == null) return;
      HapticFeedback.heavyImpact();
      appNavigatorKey.currentState?.push(pageRoute<void>(WalkInCallScreen(walkInId: walkInId)));
    } else if (event.type == 'SLOT_OFFER_CREATED') {
      final offerId = strOrNull(data['slotOfferId'] ?? data['offerId']);
      if (offerId == null) return;
      AppMessenger.show(
        '원하던 시간에 빈자리가 생겼어요',
        actionLabel: '확인',
        duration: const Duration(seconds: 10),
        onAction: () => appNavigatorKey.currentState?.push(pageRoute<void>(SlotOfferScreen(offerId: offerId))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '자리요',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: appMessengerKey,
      theme: buildAppTheme(),
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ListenableBuilder(listenable: _session, builder: (context, _) => _home()),
    );
  }

  Widget _home() {
    switch (_session.status) {
      case SessionStatus.restoring:
        return const _Splash();
      case SessionStatus.restoreFailed:
        return Scaffold(body: ErrorView(failure: _session.restoreError!, onRetry: _session.restore));
      case SessionStatus.signedOut:
        return const SignInScreen();
      case SessionStatus.guest:
        return const CustomerShell(key: ValueKey('guest'));
      case SessionStatus.signedIn:
        final storeId = _session.operatorStoreId;
        if (_session.mode == AppMode.operator && storeId != null) {
          return OperatorShell(key: ValueKey(storeId), storeId: storeId);
        }
        return const CustomerShell(key: ValueKey('customer'));
    }
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', width: 64),
            const SizedBox(height: 16),
            const Text('Jariyo', style: TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
      ),
    );
  }
}

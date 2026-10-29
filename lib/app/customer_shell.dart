import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../core/error/app_failure.dart';
import '../core/navigation/app_navigator.dart';
import '../core/network/idempotency.dart';
import '../core/realtime/refresh_bus.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/dialogs.dart';
import '../core/widgets/qr_scanner_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/home/presentation/my_activity_screen.dart';
import '../features/my_page/presentation/my_page_screen.dart';
import '../features/reservation/domain/reservation_entities.dart';
import '../features/reservation/domain/reservation_repository.dart';
import '../features/reservation/domain/reservation_usecases.dart';
import '../features/reservation/presentation/booking/booking_flow.dart';
import '../features/reservation/presentation/booking/booking_screen.dart';
import '../features/reservation/presentation/reservation_detail_screen.dart';
import '../features/store/domain/store_repository.dart';
import '../features/store/domain/store_usecases.dart';
import '../features/store/presentation/store_detail_screen.dart';
import '../features/store/presentation/store_search_screen.dart';
import '../features/walk_in/domain/walk_in_usecases.dart';
import '../features/walk_in/presentation/walk_in_register_screen.dart';
import 'session_controller.dart';

/// 고객용 하단 탭: 홈 · 탐색 · (빠른 실행) · 내 예약 · 마이페이지
class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  final _session = GetIt.I<SessionController>();
  final _drafts = BookingDrafts(GetIt.I<ReservationRepository>());
  final _qrCheckInKeys = IdempotencyKeyHolder();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (_session.isSignedIn) WidgetsBinding.instance.addPostFrameCallback((_) => _offerDraftResume());
  }

  void _select(int index) => setState(() => _index = index);

  /// 로그인 만료나 비회원 진입으로 중단된 예약을 이어서 진행한다.
  Future<void> _offerDraftResume() async {
    final draft = _drafts.load();
    if (draft == null || !mounted) return;
    final resume = await showConfirmDialog(
      context,
      title: draft.walkIn ? '현장 대기 등록을 이어서 할까요?' : '진행하던 예약을 이어서 할까요?',
      message: [
        draft.storeName,
        if (draft.serviceName != null) draft.serviceName!,
        if (draft.staffName != null) '${draft.staffName} 직원',
      ].join(' · '),
      confirmLabel: '이어서 하기',
      cancelLabel: '처음부터 다시',
    );
    if (!resume) {
      await _drafts.clear();
      return;
    }
    if (!mounted) return;
    await _resume(draft);
  }

  Future<void> _resume(BookingDraft draft) async {
    if (draft.walkIn) {
      await _drafts.clear();
      if (mounted) pushPage<void>(context, WalkInRegisterScreen(storeId: draft.storeId));
      return;
    }
    try {
      final store = await GetStoreDetail(GetIt.I<StoreRepository>())(draft.storeId);
      if (!mounted) return;
      // 저장해 둔 서비스와 직원을 미리 고른 상태로 예약 화면을 연다.
      pushPage<void>(
        context,
        BookingScreen(
          flow: BookingFlow(store: store, drafts: _drafts),
          initialServiceId: draft.serviceId,
          initialStaffId: draft.staffId,
        ),
      );
    } on AppFailure catch (failure) {
      AppMessenger.showFailure(failure);
      if (mounted) pushPage<void>(context, StoreDetailScreen(storeId: draft.storeId));
    }
  }

  bool _requireSignIn() {
    if (_session.isSignedIn) return false;
    AppMessenger.show('로그인 후 이용할 수 있어요.');
    _session.requestSignIn();
    return true;
  }

  Future<void> _scanWalkInQr() async {
    if (_requireSignIn()) return;
    final raw = await pushPage<String>(
      context,
      const QrScannerScreen(title: '현장 대기 QR', guide: '매장에 비치된 현장 대기 QR 코드를 화면에 맞춰 주세요.'),
    );
    if (raw == null || !mounted) return;
    final storeId = parseStoreIdFromQr(raw);
    if (storeId == null) {
      AppMessenger.show('자리요 매장 QR 코드가 아니에요. 다시 확인해 주세요.');
      return;
    }
    pushPage<void>(context, WalkInRegisterScreen(storeId: storeId));
  }

  Future<void> _scanCheckInQr() async {
    if (_requireSignIn()) return;
    final token = await pushPage<String>(
      context,
      const QrScannerScreen(title: 'QR 체크인', guide: '매장에 비치된 체크인 QR 코드를 화면에 맞춰 주세요.'),
    );
    if (token == null || !mounted) return;
    final key = _qrCheckInKeys.keyFor(token);
    try {
      final result = await CheckInWithQr(GetIt.I<ReservationRepository>())(token, idempotencyKey: key);
      _qrCheckInKeys.settle();
      GetIt.I<RefreshBus>().emit({RefreshTopic.reservationDetail, RefreshTopic.home, RefreshTopic.myReservations});
      AppMessenger.show('체크인이 완료되었어요. 직원의 안내를 기다려 주세요.');
      if (mounted && result.reservationId.isNotEmpty) {
        pushPage<void>(context, ReservationDetailScreen(reservationId: result.reservationId));
      }
    } on AppFailure catch (failure) {
      if (failure.kind != FailureKind.unknownOutcome) _qrCheckInKeys.settle();
      AppMessenger.show(switch (failure.code) {
        'CHECK_IN_TOKEN_INVALID' => '올바른 체크인 QR 코드가 아니에요.',
        'CHECK_IN_TOKEN_EXPIRED' => 'QR 코드의 유효 시간이 지났어요. 매장에 새 코드를 요청해 주세요.',
        'CHECK_IN_TOKEN_ALREADY_USED' || 'CHECK_IN_ALREADY_COMPLETED' => '이미 체크인된 예약이에요.',
        _ => failure.message,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const tabs = [
      (Icons.home_outlined, Icons.home_rounded, '홈'),
      (Icons.search_rounded, Icons.search_rounded, '탐색'),
      (Icons.confirmation_number_outlined, Icons.confirmation_number_rounded, '내 예약'),
      (Icons.person_outline_rounded, Icons.person_rounded, '마이'),
    ];
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            onOpenSearch: () => _select(1),
            onOpenActivity: () => _select(2),
            onScanQr: _scanWalkInQr,
            onScanCheckIn: _scanCheckInQr,
          ),
          const StoreSearchScreen(),
          MyActivityScreen(onFindStore: () => _select(1)),
          const MyPageScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final (icon, selected, label) in tabs)
            NavigationDestination(
              icon: Icon(icon, color: AppColors.mutedText),
              selectedIcon: Icon(selected, color: AppColors.primary),
              label: label,
            ),
        ],
      ),
    );
  }
}

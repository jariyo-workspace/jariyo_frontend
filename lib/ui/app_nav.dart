import 'package:flutter/material.dart';

import '../data/api_client.dart';
import 'screens/my_reservations_screen.dart';
import 'screens/reservation_detail_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/store_detail_screen.dart';
import 'screens/stores_screen.dart';

/// 화면 전환. 탭(매장 탐색, 내 예약) 첫 화면은 항상 스택의 맨 아래에 있어
/// 이 화면들과 로그인에서 Back을 누르면 앱이 종료된다.
class AppNav {
  static final navigatorKey = GlobalKey<NavigatorState>();

  /// 지금 보고 있는 매장 상세·예약의 매장 ID. 세션 만료 후 같은 매장을 다시 연다.
  static String? activeStoreId;

  static NavigatorState get _nav => navigatorKey.currentState!;

  static Route<T> _instant<T>(Widget page) => PageRouteBuilder<T>(
        pageBuilder: (_, _, _) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      );

  static Route<T> _push<T>(Widget page) => MaterialPageRoute<T>(builder: (_) => page);

  static void toSignIn({String? returnStoreId}) {
    _nav.pushAndRemoveUntil(_instant(SignInScreen(returnStoreId: returnStoreId)), (_) => false);
  }

  static void toStores() {
    _nav.pushAndRemoveUntil(_instant(const StoresScreen()), (_) => false);
  }

  static void toMyReservations({String? openBookedReservationId}) {
    _nav.pushAndRemoveUntil(
      _instant(MyReservationsScreen(openBookedReservationId: openBookedReservationId)),
      (_) => false,
    );
  }

  static Future<void> openStore(String storeId) => _nav.push(_push(StoreDetailScreen(storeId: storeId)));

  static Future<void> openReservation(
    String reservationId, {
    bool justBooked = false,
    void Function(String id, String status)? onStatusChanged,
  }) =>
      _nav.push(_push(ReservationDetailScreen(
        reservationId: reservationId,
        justBooked: justBooked,
        onStatusChanged: onStatusChanged,
      )));

  /// 로그인 성공 후 이동. 세션 만료 전에 보던 매장이 있으면 그 매장을 다시 연다.
  static void afterSignIn(String? returnStoreId) {
    toStores();
    if (returnStoreId != null) openStore(returnStoreId);
  }

  /// 예약 생성 성공: 매장 상세를 닫고 내 예약 탭으로 전환한 뒤 예약 상세를 연다.
  static void afterBooked(String reservationId) {
    toMyReservations(openBookedReservationId: reservationId);
  }

  static void handleSessionExpired() {
    toSignIn(returnStoreId: activeStoreId);
  }

  static void init() {
    ApiClient.onSessionExpired = handleSessionExpired;
  }
}

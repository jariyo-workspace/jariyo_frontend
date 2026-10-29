import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jariyo_frontend/app/injector.dart';
import 'package:jariyo_frontend/app/jariyo_app.dart';
import 'package:jariyo_frontend/core/realtime/realtime_service.dart';
import 'package:jariyo_frontend/core/utils/date_time_format.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _store = 'b1b2c3d4-0000-4000-8000-000000000001';
const _cut = 'b1b2c3d4-0000-4000-8000-000000000011';
const _perm = 'b1b2c3d4-0000-4000-8000-000000000012';
const _minji = 'b1b2c3d4-0000-4000-8000-000000000021';
const _sujin = 'b1b2c3d4-0000-4000-8000-000000000022';

String _at(int dayOffset, int hour, [int minute = 0]) =>
    storeIso(storeToday().add(Duration(days: dayOffset)), hour, minute);

/// 백엔드 DTO 형태를 따른 가짜 서버.
class FakeBackend {
  final requests = <String>[];

  /// 예약이 생성되면 그 시간은 더 이상 가능 시간으로 내려주지 않는다.
  bool booked = false;

  http.Response _ok(Object? data, {int status = 200}) =>
      http.Response(jsonEncode({'success': true, 'data': data}), status, headers: {'content-type': 'application/json; charset=utf-8'});

  http.Response _missing() => http.Response(
    jsonEncode({
      'success': false,
      'error': {'code': 'COMMON-500', 'message': '서버 오류가 발생했습니다.'},
    }),
    500,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path.replaceFirst('/api/v1', '');
    requests.add('${request.method} $path');
    final today = formatYmd(storeToday());
    switch ((request.method, path)) {
      case ('GET', '/me'):
        return _ok({
          'id': 'u1',
          'email': 'test@example.com',
          'displayName': '김자리',
          'phoneNumber': '+821012345678',
          'customerProfile': {'notificationConsent': true, 'marketingConsent': false},
          'storeMemberships': [
            {'storeId': _store, 'role': 'OWNER', 'status': 'ACTIVE'},
          ],
        });
      case ('GET', '/me/reservations'):
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'id': 'r1',
                'store': {'id': _store, 'name': '자리요 헤어'},
                'service': {'id': _cut, 'name': '커트'},
                'staff': {'id': _minji, 'name': '민지'},
                'status': 'CONFIRMED',
                'startAt': _at(1, 14),
                'serviceEndAt': _at(1, 14, 30),
              },
            ],
            'page': {'cursor': null, 'hasNext': false},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      case ('GET', '/me/waitlists'):
        return _ok([]);
      case ('GET', '/me/walk-ins'):
        return _ok([
          {
            'id': 'w1',
            'storeId': _store,
            'serviceId': _cut,
            'queueNumber': 12,
            'status': 'WAITING',
            'waitingAhead': 3,
            'estimatedWaitMinutes': 25,
            'createdAt': DateTime.now().toUtc().toIso8601String(),
          },
        ]);
      case ('GET', '/me/slot-offers'):
        return _ok([
          {
            'id': 'o1',
            'waitlistId': 'q1',
            'status': 'PENDING',
            'startAt': _at(0, 15, 30),
            'expiresAt': DateTime.now().add(const Duration(minutes: 3)).toUtc().toIso8601String(),
            'remainingSeconds': 161,
          },
        ]);
      case ('GET', '/stores'):
        return _ok([
          {
            'id': _store,
            'name': '자리요 헤어',
            'description': '예약과 현장 대기가 가능한 헤어숍',
            'phoneNumber': '053-123-4567',
            'address': '대구광역시 중구',
            'timezone': 'Asia/Seoul',
            'status': 'ACTIVE',
          },
        ]);
      case ('GET', '/stores/$_store'):
        return _ok({
          'id': _store,
          'name': '자리요 헤어',
          'description': '예약과 현장 대기가 가능한 헤어숍',
          'phoneNumber': '053-123-4567',
          'address': '대구광역시 중구',
          'timezone': 'Asia/Seoul',
          'status': 'ACTIVE',
          'businessHours': [
            for (final d in ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'])
              {
                'dayOfWeek': d,
                'isClosed': false,
                'periods': [
                  {'openTime': '10:00:00', 'closeTime': '20:00:00'},
                ],
              },
            {'dayOfWeek': 'SUNDAY', 'isClosed': true, 'periods': []},
          ],
          'policySummary': {
            'bookingOpenDays': 30,
            'minimumBookingNoticeMinutes': 120,
            'cancellationDeadlineMinutes': 1440,
            'checkInOpenBeforeMinutes': 20,
            'lateToleranceMinutes': 10,
            'noShowAfterMinutes': 15,
            'reservationHoldMinutes': 5,
            'slotOfferExpirationMinutes': 3,
            'walkInCallTimeoutMinutes': 3,
            'waitlistEnabled': true,
            'walkInEnabled': true,
            'autoNoShowEnabled': false,
          },
        });
      case ('GET', '/stores/$_store/services'):
        return _ok([
          {
            'id': _cut,
            'name': '커트',
            'description': '기본 커트',
            'durationMinutes': 30,
            'cleanupMinutes': 10,
            'capacity': 1,
            'status': 'ACTIVE',
            'availableStaffCount': 2,
          },
          {
            'id': _perm,
            'name': '펌',
            'description': '',
            'durationMinutes': 120,
            'cleanupMinutes': 10,
            'capacity': 1,
            'status': 'INACTIVE',
            'availableStaffCount': 0,
          },
        ]);
      case ('GET', '/stores/$_store/services/$_cut/staff'):
        return _ok([
          {'id': _minji, 'displayName': '민지', 'bookingEnabled': true, 'customDurationMinutes': null},
          {'id': _sujin, 'displayName': '수진', 'bookingEnabled': true, 'customDurationMinutes': 40},
        ]);
      case ('GET', '/stores/$_store/availability'):
        Map<String, Object?> slot(int day, int hour, String staff, String status) => {
          'startAt': _at(day, hour),
          'serviceEndAt': _at(day, hour, 30),
          'occupiedUntil': _at(day, hour, 40),
          'staffId': staff,
          'status': status,
        };
        return _ok({
          'storeId': _store,
          'serviceId': _cut,
          'staffId': null,
          'dates': [
            {
              'date': today,
              'slots': [slot(0, 10, _minji, 'UNAVAILABLE'), slot(0, 11, _minji, 'WAITLIST_AVAILABLE')],
            },
            {
              'date': formatYmd(storeToday().add(const Duration(days: 1))),
              'slots': [
                slot(1, 14, _minji, booked ? 'UNAVAILABLE' : 'AVAILABLE'),
                slot(1, 14, _sujin, booked ? 'UNAVAILABLE' : 'AVAILABLE'),
                slot(1, 15, _sujin, 'AVAILABLE'),
              ],
            },
          ],
        });
      case ('GET', '/stores/$_store/walk-in-status'):
        return _ok({
          'storeId': _store,
          'walkInEnabled': true,
          'acceptingEntries': true,
          'waitingCount': 3,
          'estimatedWaitMinutes': 25,
          'lastEntryAt': '19:00',
        });
      case ('POST', '/reservations'):
        expect(request.headers['Idempotency-Key'], isNotEmpty);
        booked = true;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return _ok({
          'id': 'r2',
          'store': {'id': _store, 'name': '자리요 헤어'},
          'service': {'id': _cut, 'name': '커트'},
          'staff': {'id': body['staffId'], 'name': '민지'},
          'source': 'CUSTOMER_BOOKING',
          'status': 'CONFIRMED',
          'startAt': body['startAt'],
          'serviceEndAt': _at(1, 14, 30),
          'occupiedUntil': _at(1, 14, 40),
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        }, status: 201);
      case ('GET', '/admin/stores/$_store/dashboard/today'):
        return _ok({
          'date': today,
          'summary': {
            'reservationCount': 2,
            'waitingWalkInCount': 1,
            'checkedInCount': 0,
            'inServiceCount': 0,
            'noShowCandidateCount': 1,
            'pendingSlotOfferCount': 0,
          },
          'alerts': [
            {'type': 'NO_SHOW_CANDIDATE', 'referenceId': 'r1', 'message': '11:00 예약이 아직 체크인되지 않았어요.'},
          ],
          'timeline': [],
        });
      case ('GET', '/admin/stores/$_store/reservations'):
        return _ok([
          {
            'id': 'r1',
            'customerName': '홍길동',
            'serviceName': '커트',
            'assignedStaffName': '민지',
            'startAt': _at(0, 11),
            'serviceEndAt': _at(0, 11, 30),
            'status': 'CONFIRMED',
            'checkInStatus': 'NOT_CHECKED_IN',
            'partySize': 1,
          },
        ]);
      case ('GET', '/admin/stores/$_store/walk-ins'):
        return _ok([
          {
            'id': 'w1',
            'queueNumber': 12,
            'customerName': '이자리',
            'serviceName': '커트',
            'preferredStaffName': null,
            'status': 'WAITING',
            'waitingMinutes': 20,
            'estimatedWaitMinutes': 15,
          },
          {
            'id': 'w2',
            'queueNumber': 13,
            'customerName': '박자리',
            'serviceName': '커트',
            'preferredStaffName': '수진',
            'status': 'CALLED',
            'waitingMinutes': 30,
            'estimatedWaitMinutes': 0,
          },
        ]);
      case ('GET', '/admin/stores/$_store/staff'):
        return _ok([
          {'id': _minji, 'displayName': '민지', 'role': 'OWNER', 'status': 'ACTIVE', 'bookingEnabled': true},
          {'id': _sujin, 'displayName': '수진', 'role': 'STAFF', 'status': 'ACTIVE', 'bookingEnabled': true},
        ]);
      case ('GET', '/admin/stores/$_store/analytics/summary'):
        return _ok({
          'reservationCount': 12,
          'completionRate': 0.8,
          'cancellationRate': 0.1,
          'noShowRate': 0.05,
          'waitlistOfferAcceptanceRate': 0.5,
          'cancelledSlotRefillRate': 0.4,
          'averageWalkInWaitMinutes': 24,
          'walkInAbandonmentRate': 0.1,
        });
      case ('GET', '/admin/stores/$_store/analytics/reservations/daily'):
        return _ok([
          for (var i = 0; i < 7; i++)
            {
              'date': formatYmd(storeToday().subtract(Duration(days: 6 - i))),
              'reservationCount': i + 1,
              'confirmedCount': 0,
              'checkedInCount': 0,
              'inServiceCount': 0,
              'completedCount': i,
              'cancelledCount': i % 2,
              'noShowCount': 0,
            },
        ]);
      case ('GET', '/admin/stores/$_store/analytics/staff'):
      case ('GET', '/admin/stores/$_store/analytics/services/duration'):
        return _ok([]);
    }
    // 아직 구현되지 않은 API(/me/home 등)는 백엔드처럼 500으로 응답한다.
    return _missing();
  }
}

Future<void> _pumpFor(WidgetTester tester, [int steps = 12]) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<FakeBackend> _start(WidgetTester tester, {required Size size, Map<String, Object> prefs = const {}}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'auth.accessToken': 'a1', 'auth.refreshToken': 'r1', ...prefs});
  final backend = FakeBackend();
  await GetIt.I.reset();
  await configureDependencies(httpClient: MockClient(backend.handle));
  await tester.pumpWidget(const JariyoApp());
  await _pumpFor(tester);
  return backend;
}

Future<void> _finish(WidgetTester tester) async {
  sl<RealtimeService>().disconnectAll();
  await tester.pumpWidget(const SizedBox.shrink());
  await _pumpFor(tester, 2);
}

void main() {
  testWidgets('고객: 홈 → 매장 → 서비스 → 직원 → 시간 → 확인 → 예약 완료', (tester) async {
    final backend = await _start(tester, size: const Size(390, 844));

    // 통합 홈 API가 없으면 목록 API로 홈을 구성하고, 빈자리 제안을 가장 먼저 강조한다.
    expect(find.textContaining('김자리님'), findsOneWidget);
    expect(find.text('빈자리가 생겼어요'), findsWidgets);
    expect(backend.requests, contains('GET /me/slot-offers'));

    await tester.tap(find.text('탐색'));
    await _pumpFor(tester);
    await tester.tap(find.text('자리요 헤어').last);
    await _pumpFor(tester, 20);
    expect(find.text('길찾기'), findsOneWidget);

    await tester.tap(find.text('예약하기').last);
    await _pumpFor(tester);
    // 서비스·직원·시간을 한 화면에서 고른다. 비활성 서비스는 선택할 수 없게 표시한다.
    expect(find.text('지금은 예약을 받지 않아요'), findsOneWidget);
    // 예약 가능한 서비스가 하나뿐이면 미리 골라 두고 바로 시간 선택으로 안내한다.
    await _pumpFor(tester, 20);
    expect(find.text('시간을 골라 주세요'), findsOneWidget);
    expect(find.text('누구나'), findsOneWidget);
    expect(find.text('가장 빠른 예약 가능 시간'), findsOneWidget);

    await tester.tap(find.text('가장 빠른 예약 가능 시간'));
    await _pumpFor(tester);
    await tester.tap(find.text('다음'));
    await _pumpFor(tester);

    expect(find.text('예약 정보를 확인해 주세요'), findsOneWidget);
    final confirmList =
        find.ancestor(of: find.text('예약 정보를 확인해 주세요'), matching: find.byType(Scrollable)).evaluate().first;
    await tester.scrollUntilVisible(
      find.text('[필수] 예약을 위한 개인정보 제공에 동의해요'),
      300,
      scrollable: find.byElementPredicate((element) => element == confirmList),
    );
    await tester.tap(find.text('[필수] 예약 및 취소 정책을 확인했어요'));
    await tester.tap(find.text('[필수] 예약을 위한 개인정보 제공에 동의해요'));
    await _pumpFor(tester, 2);
    await tester.tap(find.text('예약 확정하기'));
    await _pumpFor(tester, 20);

    expect(find.text('예약이 확정되었어요'), findsOneWidget);
    expect(backend.requests, contains('POST /reservations'));
    // 예약 완료 후 남아 있던 시간 선택 화면이 가능 시간을 다시 조회해도 임시 예약 정보가 다시 저장되면 안 된다.
    await _pumpFor(tester, 20);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('reservation.bookingDraft'), isNull);
    await _finish(tester);
  });

  testWidgets('고객: 실시간 예약 필터로 조건 안에 예약 가능한 매장만 찾는다', (tester) async {
    await _start(tester, size: const Size(390, 844));
    await tester.tap(find.text('탐색'));
    await _pumpFor(tester);

    // 오늘은 예약 가능한 시간이 없으므로 조건에 맞는 매장이 없다.
    await tester.tap(find.text('실시간 예약'));
    await _pumpFor(tester);
    await tester.tap(find.text('예약 가능한 매장 보기'));
    await _pumpFor(tester, 20);
    expect(find.text('조건에 맞게 예약할 수 있는 매장이 없어요'), findsOneWidget);

    // 내일로 바꾸면 가장 빠른 예약 가능 시간과 함께 매장이 보인다.
    await tester.tap(find.textContaining('오늘 · 1명'));
    await _pumpFor(tester);
    await tester.tap(find.byType(ChoiceChip).at(1));
    await tester.tap(find.text('예약 가능한 매장 보기'));
    await _pumpFor(tester, 20);
    expect(find.textContaining('부터 예약 가능 · 커트'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('고객: 내 예약 탭과 마이페이지를 그린다', (tester) async {
    await _start(tester, size: const Size(390, 844));
    await tester.tap(find.text('내 예약').last);
    await _pumpFor(tester, 20);
    expect(find.textContaining('예정'), findsWidgets);
    await tester.tap(find.textContaining('대기').first);
    await _pumpFor(tester);
    await tester.tap(find.text('마이'));
    await _pumpFor(tester);
    expect(find.text('매장 운영 화면으로 전환'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('운영자(태블릿): 오늘 → 예약 캘린더 → 현장 대기열 → 매장 관리 → 통계', (tester) async {
    final backend = await _start(
      tester,
      size: const Size(1280, 800),
      prefs: const {'session.mode': 'operator', 'session.operatorStoreId': _store},
    );

    expect(find.text('11:00 예약이 아직 체크인되지 않았어요.'), findsOneWidget);
    expect(find.text('노쇼 후보'), findsOneWidget);

    await tester.tap(find.text('예약').first);
    await _pumpFor(tester, 20);
    expect(find.text('홍길동 · 커트'), findsOneWidget);

    await tester.tap(find.text('현장 대기').first);
    await _pumpFor(tester, 20);
    expect(find.textContaining('호출 필요'), findsOneWidget);
    expect(find.text('입장 확인'), findsOneWidget);

    await tester.tap(find.text('매장 관리'));
    await _pumpFor(tester);
    expect(find.text('운영 정책'), findsOneWidget);

    await tester.tap(find.text('통계'));
    await _pumpFor(tester, 20);
    expect(find.text('예약 완료율'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(backend.requests, contains('GET /admin/stores/$_store/analytics/summary'));
    await _finish(tester);
  });

  testWidgets('운영자(모바일): 현장 처리 위주의 하단 탭', (tester) async {
    await _start(
      tester,
      size: const Size(390, 844),
      prefs: const {'session.mode': 'operator', 'session.operatorStoreId': _store},
    );
    expect(find.text('더보기'), findsOneWidget);
    await tester.tap(find.text('현장 대기').last);
    await _pumpFor(tester, 20);
    expect(find.text('호출하기'), findsWidgets);
    await _finish(tester);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:jariyo_frontend/core/domain/named_ref.dart';
import 'package:jariyo_frontend/core/domain/statuses.dart';
import 'package:jariyo_frontend/features/admin/domain/admin_entities.dart';
import 'package:jariyo_frontend/features/home/domain/home_entities.dart';
import 'package:jariyo_frontend/features/home/domain/home_usecases.dart';
import 'package:jariyo_frontend/features/reservation/domain/reservation_entities.dart';
import 'package:jariyo_frontend/features/store/domain/store_entities.dart';
import 'package:jariyo_frontend/features/waitlist/domain/waitlist_entities.dart';
import 'package:jariyo_frontend/features/walk_in/domain/walk_in_entities.dart';

DateTime _t(String iso) => DateTime.parse(iso);

ReservationSummary _reservation(String id, String start, {ReservationStatus status = ReservationStatus.confirmed}) =>
    ReservationSummary(id: id, storeName: '자리요 헤어', status: status, startAt: _t(start));

void main() {
  group('홈 우선순위 카드', () {
    final now = _t('2026-07-18T10:00:00+09:00');
    final waitingWalkIn = WalkIn(id: 'w1', queueNumber: 3, status: WalkInStatus.waiting, waitingAhead: 2);
    final calledWalkIn = WalkIn(id: 'w2', queueNumber: 4, status: WalkInStatus.called);
    final offer = SlotOffer(
      id: 'o1',
      status: SlotOfferStatus.pending,
      startAt: _t('2026-07-18T15:00:00+09:00'),
      deadline: DateTime.now().add(const Duration(minutes: 2)),
    );
    const waitlist = WaitlistEntry(
      id: 'q1',
      status: WaitlistStatus.waiting,
      desiredDate: '2026-07-20',
      acceptableStartTime: '13:00',
      acceptableEndTime: '17:00',
      staffPreferenceType: StaffPreferenceType.anyStaff,
    );
    final today = _reservation('r-today', '2026-07-18T14:00:00+09:00');
    final later = _reservation('r-later', '2026-07-25T14:00:00+09:00');

    test('현장 호출이 가장 먼저다', () {
      final action = computePriorityAction(
        reservations: [today],
        waitlists: [waitlist],
        walkIns: [waitingWalkIn, calledWalkIn],
        offers: [offer],
        now: now,
      );
      expect(action?.type, PriorityActionType.walkInCalled);
      expect(action?.referenceId, 'w2');
    });

    test('빈자리 제안 → 체크인 가능 → 오늘 예약 → 현장 대기 → 예약 대기 → 다가오는 예약 순서', () {
      expect(
        computePriorityAction(reservations: [today], waitlists: [waitlist], walkIns: [waitingWalkIn], offers: [offer], now: now)?.type,
        PriorityActionType.slotOffer,
      );
      expect(
        computePriorityAction(
          reservations: [today, later],
          waitlists: const [],
          walkIns: const [],
          offers: const [],
          checkInAvailableIds: {'r-later'},
          now: now,
        )?.type,
        PriorityActionType.checkInAvailable,
      );
      expect(
        computePriorityAction(reservations: [later, today], waitlists: [waitlist], walkIns: [waitingWalkIn], offers: const [], now: now)
            ?.referenceId,
        'r-today',
      );
      expect(
        computePriorityAction(reservations: [later], waitlists: [waitlist], walkIns: [waitingWalkIn], offers: const [], now: now)?.type,
        PriorityActionType.walkIn,
      );
      expect(
        computePriorityAction(reservations: [later], waitlists: [waitlist], walkIns: const [], offers: const [], now: now)?.type,
        PriorityActionType.waitlist,
      );
      final upcoming = computePriorityAction(reservations: [later], waitlists: const [], walkIns: const [], offers: const [], now: now);
      expect(upcoming?.title, '다가오는 예약');
      expect(computePriorityAction(reservations: const [], waitlists: const [], walkIns: const [], offers: const [], now: now), isNull);
    });
  });

  test('직원별 슬롯을 같은 시작 시각으로 묶고, 누구나 선택 시 첫 가능 직원을 배정한다', () {
    TimeSlot slot(String staff, String start, SlotStatus status) => TimeSlot(
      startAtRaw: start,
      startAt: _t(start),
      serviceEndAt: _t(start).add(const Duration(minutes: 30)),
      occupiedUntil: _t(start).add(const Duration(minutes: 40)),
      staffId: staff,
      status: status,
    );
    final options = groupSlotsByTime([
      slot('minji', '2026-07-18T14:00:00+09:00', SlotStatus.unavailable),
      slot('sujin', '2026-07-18T14:00:00+09:00', SlotStatus.available),
      slot('minji', '2026-07-18T10:00:00+09:00', SlotStatus.waitlistAvailable),
    ]);
    expect(options.length, 2);
    expect(options.first.isMorning, isTrue);
    expect(options.first.status, SlotStatus.waitlistAvailable);
    expect(options.last.status, SlotStatus.available);
    expect(options.last.firstAvailable?.staffId, 'sujin');
    expect(options.last.availableFor('minji'), isNull);
  });

  test('현장 대기열: 가장 앞선 대기 고객은 호출 필요로 분류한다', () {
    AdminWalkIn w(String id, int n, WalkInStatus s) =>
        AdminWalkIn(id: id, queueNumber: n, customerName: id, serviceName: '커트', status: s);
    final groups = groupWalkIns([
      w('c', 13, WalkInStatus.waiting),
      w('a', 11, WalkInStatus.waiting),
      w('b', 12, WalkInStatus.called),
      w('d', 10, WalkInStatus.skipped),
      w('e', 9, WalkInStatus.inService),
    ]);
    expect(groups[WalkInGroup.needsCall]!.single.id, 'a');
    expect(groups[WalkInGroup.waiting]!.single.id, 'c');
    expect(groups[WalkInGroup.calling]!.single.id, 'b');
    expect(groups[WalkInGroup.held]!.single.id, 'd');
    expect(groups[WalkInGroup.inService]!.single.id, 'e');
  });

  test('운영자 예약 상세는 상태별 가능한 행동만 연다', () {
    AdminReservation r(ReservationStatus s) => AdminReservation(
      id: 'r',
      customerName: '김자리',
      serviceName: '커트',
      staffName: '민지',
      startAt: _t('2026-07-18T14:00:00+09:00'),
      serviceEndAt: _t('2026-07-18T14:30:00+09:00'),
      status: s,
      checkInStatus: CheckInStatus.notCheckedIn,
    );
    final confirmed = r(ReservationStatus.confirmed);
    expect([confirmed.canCheckIn, confirmed.canReschedule, confirmed.canCancel, confirmed.canMarkNoShow], everyElement(isTrue));
    expect(confirmed.canStartService, isFalse);
    final checkedIn = r(ReservationStatus.checkedIn);
    expect([checkedIn.canStartService, checkedIn.canCancel], everyElement(isTrue));
    expect(checkedIn.canMarkNoShow, isFalse);
    expect(r(ReservationStatus.inService).canComplete, isTrue);
    final done = r(ReservationStatus.completed);
    expect([done.canCheckIn, done.canCancel, done.canStartService, done.canComplete], everyElement(isFalse));
  });

  test('예약 대기 조건을 자연어로 요약한다', () {
    expect(
      describeWaitlistCondition(
        desiredDate: '2026-07-18',
        startTime: '13:00',
        endTime: '17:00',
        preference: StaffPreferenceType.specificPreferred,
        staffName: '민지',
      ),
      '7월 18일 오후 1:00부터 오후 5:00 사이,\n민지 직원을 우선으로 기다릴게요.\n다른 직원도 가능합니다.',
    );
  });

  test('예약 요청은 가능 시간 API가 준 시각과 슬롯의 직원을 그대로 보낸다', () {
    const request = NewReservation(
      storeId: 's',
      serviceId: 'v',
      staffId: 'sujin',
      startAt: '2026-07-18T14:00:00+09:00',
      customerNote: '  ',
    );
    expect(request.toJson(), {
      'storeId': 's',
      'serviceId': 'v',
      'staffId': 'sujin',
      'startAt': '2026-07-18T14:00:00+09:00',
      'partySize': 1,
    });
  });

  test('NamedRef는 name과 displayName을 모두 받는다', () {
    expect(NamedRef.fromJson({'id': '1', 'displayName': '민지'})?.name, '민지');
    expect(NamedRef.fromJson(null), isNull);
  });

  test('통계 인사이트는 관찰된 데이터만 설명한다', () {
    const report = AnalyticsReport(
      summary: AnalyticsSummary(reservationCount: 10, waitlistOfferAcceptanceRate: 0.5),
      daily: [
        DailyReservationStat(date: '2026-07-18', reservationCount: 7, cancelledCount: 2),
        DailyReservationStat(date: '2026-07-19', reservationCount: 3),
      ],
    );
    expect(report.insights, contains('7월 18일 토요일에 예약이 7건으로 가장 많았어요.'));
    expect(report.insights, contains('빈자리 제안의 50%가 수락되었어요.'));
  });
}

import '../../reservation/domain/reservation_entities.dart';
import '../../store/domain/store_entities.dart';
import '../../waitlist/domain/waitlist_entities.dart';
import '../../walk_in/domain/walk_in_entities.dart';

/// 고객 홈에서 가장 크게 강조할 행동의 종류. 선언 순서가 우선순위다.
enum PriorityActionType {
  walkInCalled('WALK_IN_CALLED'),
  slotOffer('SLOT_OFFER'),
  checkInAvailable('CHECK_IN_AVAILABLE'),
  reservation('RESERVATION'),
  walkIn('WALK_IN'),
  waitlist('WAITLIST');

  const PriorityActionType(this.code);

  final String code;

  static PriorityActionType? parse(Object? raw) => values.where((v) => v.code == raw).firstOrNull;
}

class PriorityAction {
  const PriorityAction({
    required this.type,
    required this.referenceId,
    required this.title,
    this.subtitle,
    this.expiresAt,
    this.actionLabel,
  });

  final PriorityActionType type;
  final String referenceId;
  final String title;
  final String? subtitle;
  final DateTime? expiresAt;
  final String? actionLabel;
}

class HomeSummary {
  const HomeSummary({
    this.priorityAction,
    this.upcomingReservations = const [],
    this.activeWaitlists = const [],
    this.activeWalkIns = const [],
    this.pendingOffers = const [],
    this.recentStores = const [],
  });

  final PriorityAction? priorityAction;
  final List<ReservationSummary> upcomingReservations;
  final List<WaitlistEntry> activeWaitlists;
  final List<WalkIn> activeWalkIns;
  final List<SlotOffer> pendingOffers;
  final List<RecentStore> recentStores;

  bool get isEmpty =>
      priorityAction == null &&
      upcomingReservations.isEmpty &&
      activeWaitlists.isEmpty &&
      activeWalkIns.isEmpty &&
      pendingOffers.isEmpty;

  HomeSummary withRecentStores(List<RecentStore> stores) => HomeSummary(
    priorityAction: priorityAction,
    upcomingReservations: upcomingReservations,
    activeWaitlists: activeWaitlists,
    activeWalkIns: activeWalkIns,
    pendingOffers: pendingOffers,
    recentStores: stores,
  );
}

/// 내 예약·대기 화면(C-18)의 한 항목.
sealed class ActivityItem {
  const ActivityItem();

  /// 정렬 기준 시각
  DateTime get sortTime;
}

class ReservationActivity extends ActivityItem {
  const ReservationActivity(this.reservation);

  final ReservationSummary reservation;

  @override
  DateTime get sortTime => reservation.startAt;
}

class WaitlistActivity extends ActivityItem {
  const WaitlistActivity(this.entry);

  final WaitlistEntry entry;

  @override
  DateTime get sortTime => entry.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
}

class WalkInActivity extends ActivityItem {
  const WalkInActivity(this.walkIn);

  final WalkIn walkIn;

  @override
  DateTime get sortTime => walkIn.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
}

class OfferActivity extends ActivityItem {
  const OfferActivity(this.offer);

  final SlotOffer offer;

  @override
  DateTime get sortTime => offer.deadline;
}

class MyActivity {
  const MyActivity({
    this.inUse = const [],
    this.upcoming = const [],
    this.waiting = const [],
    this.past = const [],
    this.finishedWaits = const [],
    this.pastCursor,
    this.pastHasNext = false,
  });

  final List<ActivityItem> inUse;
  final List<ActivityItem> upcoming;
  final List<ActivityItem> waiting;
  final List<ReservationSummary> past;

  /// 종료된 예약 대기·현장 대기
  final List<ActivityItem> finishedWaits;
  final String? pastCursor;
  final bool pastHasNext;

  MyActivity appendPast(List<ReservationSummary> more, {String? cursor, required bool hasNext}) => MyActivity(
    inUse: inUse,
    upcoming: upcoming,
    waiting: waiting,
    past: [...past, ...more],
    finishedWaits: finishedWaits,
    pastCursor: cursor,
    pastHasNext: hasNext,
  );
}

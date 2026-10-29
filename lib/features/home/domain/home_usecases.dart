import '../../../core/domain/statuses.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/utils/date_time_format.dart';
import '../../reservation/domain/reservation_entities.dart';
import '../../reservation/domain/reservation_repository.dart';
import '../../store/domain/store_repository.dart';
import '../../waitlist/domain/waitlist_entities.dart';
import '../../waitlist/domain/waitlist_repository.dart';
import '../../walk_in/domain/walk_in_entities.dart';
import '../../walk_in/domain/walk_in_repository.dart';
import 'home_entities.dart';
import 'home_repository.dart';

bool _isSessionFailure(AppFailure failure) =>
    failure.kind == FailureKind.sessionExpired || failure.kind == FailureKind.unauthorized;

/// 개별 목록 조회 실패가 화면 전체를 막지 않도록 한다. 모두 실패하면 첫 오류를 던진다.
class _Collector {
  AppFailure? firstFailure;
  int successes = 0;

  Future<List<T>> collect<T>(Future<List<T>> Function() task) async {
    try {
      final result = await task();
      successes++;
      return result;
    } on AppFailure catch (failure) {
      if (_isSessionFailure(failure)) rethrow;
      firstFailure ??= failure;
      return <T>[];
    }
  }

  void throwIfAllFailed() {
    if (successes == 0 && firstFailure != null) throw firstFailure!;
  }
}

/// C-02 고객 홈.
///
/// 통합 홈 API를 우선 사용하고, 사용할 수 없으면 예약·대기·현장 대기·빈자리 제안 목록으로 같은 화면을 구성한다.
class GetCustomerHome {
  const GetCustomerHome({
    required this._home,
    required this._reservations,
    required this._waitlists,
    required this._walkIns,
    required this._stores,
  });

  final HomeRepository _home;
  final ReservationRepository _reservations;
  final WaitlistRepository _waitlists;
  final WalkInRepository _walkIns;
  final StoreRepository _stores;

  Future<HomeSummary> call() async {
    HomeSummary summary;
    try {
      summary = await _home.fetchHome();
    } on AppFailure catch (failure) {
      if (_isSessionFailure(failure)) rethrow;
      summary = await _compose();
    }
    final recent = summary.recentStores.isNotEmpty ? summary.recentStores : _stores.recentStores();
    return summary.withRecentStores(recent.take(5).toList());
  }

  Future<HomeSummary> _compose() async {
    final collector = _Collector();
    final today = storeToday();
    final results = await Future.wait<Object>([
      collector.collect(() async {
        final page = await _reservations.listMine(from: today, limit: 100);
        return page.items;
      }),
      collector.collect(() => _waitlists.listMine()),
      collector.collect(() => _walkIns.listMine()),
      collector.collect(() => _waitlists.listOffers(status: SlotOfferStatus.pending)),
    ]);
    collector.throwIfAllFailed();
    final reservations = (results[0] as List<ReservationSummary>)
        .where((r) => r.status.isUpcoming || r.status.isInUse)
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    final waitlists = (results[1] as List<WaitlistEntry>).where((w) => w.status.isActive).toList();
    final walkIns = (results[2] as List<WalkIn>).where((w) => w.status.isActive).toList();
    final offers = (results[3] as List<SlotOffer>).where((o) => o.isPending).toList();
    return HomeSummary(
      priorityAction: computePriorityAction(
        reservations: reservations,
        waitlists: waitlists,
        walkIns: walkIns,
        offers: offers,
      ),
      upcomingReservations: reservations,
      activeWaitlists: waitlists,
      activeWalkIns: walkIns,
      pendingOffers: offers,
    );
  }
}

/// 홈 상단 카드 우선순위: 현장 호출 → 빈자리 제안 → 체크인 가능 → 오늘 예약 → 현장 대기 → 예약 대기 → 다가오는 예약
PriorityAction? computePriorityAction({
  required List<ReservationSummary> reservations,
  required List<WaitlistEntry> waitlists,
  required List<WalkIn> walkIns,
  required List<SlotOffer> offers,
  Set<String> checkInAvailableIds = const {},
  DateTime? now,
}) {
  final today = now == null ? storeToday() : () {
    final t = toStoreTime(now);
    return DateTime.utc(t.year, t.month, t.day);
  }();

  final called = walkIns.where((w) => w.status == WalkInStatus.called).firstOrNull;
  if (called != null) {
    return PriorityAction(
      type: PriorityActionType.walkInCalled,
      referenceId: called.id,
      title: '고객님의 차례예요',
      subtitle: '${called.store?.name ?? '매장'} · 지금 매장으로 입장해 주세요.',
      expiresAt: called.callExpiresAt,
      actionLabel: '입장 확인하기',
    );
  }

  final offer = (offers.where((o) => o.isPending).toList()..sort((a, b) => a.deadline.compareTo(b.deadline)))
      .firstOrNull;
  if (offer != null) {
    return PriorityAction(
      type: PriorityActionType.slotOffer,
      referenceId: offer.id,
      title: '빈자리가 생겼어요',
      subtitle: '${formatRelative(offer.startAt)}${offer.service == null ? '' : ' · ${offer.service!.name}'}',
      expiresAt: offer.deadline,
      actionLabel: '예약 확인',
    );
  }

  final upcoming = reservations.where((r) => r.status.isUpcoming).toList()
    ..sort((a, b) => a.startAt.compareTo(b.startAt));

  final checkIn = upcoming.where((r) => checkInAvailableIds.contains(r.id)).firstOrNull;
  if (checkIn != null) {
    return PriorityAction(
      type: PriorityActionType.checkInAvailable,
      referenceId: checkIn.id,
      title: '이제 체크인할 수 있어요',
      subtitle: '${checkIn.storeName} · ${formatTime(checkIn.startAt)}',
      actionLabel: '체크인하기',
    );
  }

  bool isToday(DateTime instant) {
    final local = toStoreTime(instant);
    return DateTime.utc(local.year, local.month, local.day) == today;
  }

  final todays = upcoming.where((r) => isToday(r.startAt)).firstOrNull;
  if (todays != null) {
    return PriorityAction(
      type: PriorityActionType.reservation,
      referenceId: todays.id,
      title: '오늘 예약이 있어요',
      subtitle: '${todays.storeName} · ${formatRelative(todays.startAt, now: now)}',
      actionLabel: '예약 보기',
    );
  }

  final waitingWalkIn = walkIns.where((w) => w.status.isActive).firstOrNull;
  if (waitingWalkIn != null) {
    return PriorityAction(
      type: PriorityActionType.walkIn,
      referenceId: waitingWalkIn.id,
      title: '현재 대기 중이에요',
      subtitle: '대기 ${waitingWalkIn.queueNumber}번 · 앞에 ${waitingWalkIn.waitingAhead}팀',
      actionLabel: '대기 보기',
    );
  }

  final waitlist = waitlists.where((w) => w.status.isActive).firstOrNull;
  if (waitlist != null) {
    return PriorityAction(
      type: PriorityActionType.waitlist,
      referenceId: waitlist.id,
      title: '빈자리를 기다리고 있어요',
      subtitle: '${formatYmdLabel(waitlist.desiredDate)} · ${waitlist.timeRangeLabel}',
      actionLabel: '대기 보기',
    );
  }

  final next = upcoming.firstOrNull;
  if (next != null) {
    return PriorityAction(
      type: PriorityActionType.reservation,
      referenceId: next.id,
      title: '다가오는 예약',
      subtitle: '${next.storeName} · ${formatDateTime(next.startAt)}',
      actionLabel: '예약 보기',
    );
  }
  return null;
}

/// C-18 내 예약·대기. 이용 중 / 예정 / 대기 / 지난 내역으로 나눈다.
class GetMyActivity {
  const GetMyActivity({required this._reservations, required this._waitlists, required this._walkIns});

  final ReservationRepository _reservations;
  final WaitlistRepository _waitlists;
  final WalkInRepository _walkIns;

  Future<MyActivity> call() async {
    final collector = _Collector();
    // 예정 예약은 오늘 이후 시작분에 모두 포함된다. 하루 전부터 조회해 시간대 경계를 보완한다.
    final from = storeToday().subtract(const Duration(days: 1));
    final results = await Future.wait<Object>([
      collector.collect(() async => (await _reservations.listMine(from: from, limit: 100)).items),
      collector.collect(() => _waitlists.listMine()),
      collector.collect(() => _walkIns.listMine()),
      collector.collect(() => _waitlists.listOffers(status: SlotOfferStatus.pending)),
    ]);
    final pastPage = await _pastPage(collector, null);
    collector.throwIfAllFailed();

    final reservations = results[0] as List<ReservationSummary>;
    final waitlists = results[1] as List<WaitlistEntry>;
    final walkIns = results[2] as List<WalkIn>;
    final offers = (results[3] as List<SlotOffer>).where((o) => o.isPending).toList();

    final inUse = <ActivityItem>[
      ...reservations.where((r) => r.status.isInUse).map(ReservationActivity.new),
      ...walkIns
          .where((w) => w.status == WalkInStatus.checkedIn || w.status == WalkInStatus.inService)
          .map(WalkInActivity.new),
    ];

    final upcoming = reservations.where((r) => r.status.isUpcoming).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));

    // 즉시 행동이 필요한 상태 → 현장 대기 → 일반 예약 대기
    final waiting = <ActivityItem>[
      ...walkIns.where((w) => w.status == WalkInStatus.called).map(WalkInActivity.new),
      ...offers.map(OfferActivity.new),
      ...walkIns.where((w) => w.status == WalkInStatus.waiting || w.status == WalkInStatus.skipped).map(WalkInActivity.new),
      ...waitlists.where((w) => w.status.isActive).map(WaitlistActivity.new),
    ];

    final finished = <ActivityItem>[
      ...waitlists.where((w) => !w.status.isActive).map(WaitlistActivity.new),
      ...walkIns.where((w) => !w.status.isActive).map(WalkInActivity.new),
    ]..sort((a, b) => b.sortTime.compareTo(a.sortTime));

    return MyActivity(
      inUse: inUse,
      upcoming: upcoming.map(ReservationActivity.new).toList(),
      waiting: waiting,
      past: pastPage.$1,
      finishedWaits: finished,
      pastCursor: pastPage.$2,
      pastHasNext: pastPage.$3,
    );
  }

  /// 지난 내역 다음 페이지
  Future<MyActivity> loadMorePast(MyActivity current) async {
    final page = await _reservations.listMine(cursor: current.pastCursor, limit: 20);
    return current.appendPast(
      page.items.where((r) => r.status.isPast).toList(),
      cursor: page.cursor,
      hasNext: page.hasNext,
    );
  }

  Future<(List<ReservationSummary>, String?, bool)> _pastPage(_Collector collector, String? cursor) async {
    final pages = await collector.collect(() async => [await _reservations.listMine(cursor: cursor, limit: 30)]);
    final page = pages.firstOrNull;
    if (page == null) return (const <ReservationSummary>[], null, false);
    return (page.items.where((r) => r.status.isPast).toList(), page.cursor, page.hasNext);
  }
}

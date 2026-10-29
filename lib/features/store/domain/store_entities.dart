import '../../../core/domain/statuses.dart';
import '../../../core/utils/date_time_format.dart';

class TimePeriod {
  const TimePeriod({required this.start, required this.end});

  /// `HH:mm`
  final String start;
  final String end;

  String get label => '${formatHm(start)} – ${formatHm(end)}';

  bool contains(int hour, int minute) {
    final now = hmOf(hour, minute);
    return start.compareTo(now) <= 0 && now.compareTo(end) < 0;
  }
}

const dayOfWeekCodes = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
const dayOfWeekLabels = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];

String dayOfWeekLabel(String code) {
  final index = dayOfWeekCodes.indexOf(code);
  return index < 0 ? code : dayOfWeekLabels[index];
}

class BusinessDay {
  const BusinessDay({required this.dayOfWeek, required this.isClosed, this.periods = const []});

  final String dayOfWeek;
  final bool isClosed;
  final List<TimePeriod> periods;

  String get hoursLabel => isClosed || periods.isEmpty ? '휴무' : periods.map((p) => p.label).join(', ');
}

class StorePolicy {
  const StorePolicy({
    this.bookingOpenDays,
    this.minimumBookingNoticeMinutes,
    this.cancellationDeadlineMinutes,
    this.checkInOpenBeforeMinutes,
    this.lateToleranceMinutes,
    this.noShowAfterMinutes,
    this.reservationHoldMinutes,
    this.slotOfferExpirationMinutes,
    this.walkInCallTimeoutMinutes,
    this.waitlistEnabled = false,
    this.walkInEnabled = false,
    this.autoNoShowEnabled = false,
  });

  final int? bookingOpenDays;
  final int? minimumBookingNoticeMinutes;
  final int? cancellationDeadlineMinutes;
  final int? checkInOpenBeforeMinutes;
  final int? lateToleranceMinutes;
  final int? noShowAfterMinutes;
  final int? reservationHoldMinutes;
  final int? slotOfferExpirationMinutes;
  final int? walkInCallTimeoutMinutes;
  final bool waitlistEnabled;
  final bool walkInEnabled;
  final bool autoNoShowEnabled;

  StorePolicy copyWith({
    int? bookingOpenDays,
    int? minimumBookingNoticeMinutes,
    int? cancellationDeadlineMinutes,
    int? checkInOpenBeforeMinutes,
    int? lateToleranceMinutes,
    int? noShowAfterMinutes,
    int? reservationHoldMinutes,
    int? slotOfferExpirationMinutes,
    int? walkInCallTimeoutMinutes,
    bool? waitlistEnabled,
    bool? walkInEnabled,
    bool? autoNoShowEnabled,
  }) => StorePolicy(
    bookingOpenDays: bookingOpenDays ?? this.bookingOpenDays,
    minimumBookingNoticeMinutes: minimumBookingNoticeMinutes ?? this.minimumBookingNoticeMinutes,
    cancellationDeadlineMinutes: cancellationDeadlineMinutes ?? this.cancellationDeadlineMinutes,
    checkInOpenBeforeMinutes: checkInOpenBeforeMinutes ?? this.checkInOpenBeforeMinutes,
    lateToleranceMinutes: lateToleranceMinutes ?? this.lateToleranceMinutes,
    noShowAfterMinutes: noShowAfterMinutes ?? this.noShowAfterMinutes,
    reservationHoldMinutes: reservationHoldMinutes ?? this.reservationHoldMinutes,
    slotOfferExpirationMinutes: slotOfferExpirationMinutes ?? this.slotOfferExpirationMinutes,
    walkInCallTimeoutMinutes: walkInCallTimeoutMinutes ?? this.walkInCallTimeoutMinutes,
    waitlistEnabled: waitlistEnabled ?? this.waitlistEnabled,
    walkInEnabled: walkInEnabled ?? this.walkInEnabled,
    autoNoShowEnabled: autoNoShowEnabled ?? this.autoNoShowEnabled,
  );

  /// 숫자 필드를 그대로 나열하지 않고 자연어 문장으로 보여준다.
  List<String> get customerSentences => [
    if (bookingOpenDays != null) '오늘부터 $bookingOpenDays일 뒤까지 예약할 수 있어요.',
    if (minimumBookingNoticeMinutes != null && minimumBookingNoticeMinutes! > 0)
      '예약 시작 ${formatMinutes(minimumBookingNoticeMinutes!)} 전까지 예약을 받아요.',
    if (cancellationDeadlineMinutes != null)
      cancellationDeadlineMinutes == 0
          ? '예약 시작 전까지 직접 취소할 수 있어요.'
          : '예약 시작 ${formatMinutes(cancellationDeadlineMinutes!)} 전까지 직접 취소할 수 있어요.',
    if (checkInOpenBeforeMinutes != null) '예약 시작 ${formatMinutes(checkInOpenBeforeMinutes!)} 전부터 체크인할 수 있어요.',
    if (lateToleranceMinutes != null && lateToleranceMinutes! > 0) '${formatMinutes(lateToleranceMinutes!)}까지 늦어도 기다려 드려요.',
    if (waitlistEnabled) '예약이 마감되면 예약 대기를 신청할 수 있어요.',
    if (walkInEnabled) '매장에서 현장 대기를 등록할 수 있어요.',
  ];
}

class StoreSummary {
  const StoreSummary({
    required this.id,
    required this.name,
    required this.status,
    this.description = '',
    this.address = '',
    this.phoneNumber = '',
    this.category,
    this.openNow,
    this.todayHours,
    this.nextAvailableAt,
    this.walkInEnabled,
    this.waitlistEnabled,
  });

  final String id;
  final String name;
  final String description;
  final String address;
  final String phoneNumber;
  final String? category;
  final StoreStatus status;
  final bool? openNow;
  final TimePeriod? todayHours;
  final DateTime? nextAvailableAt;
  final bool? walkInEnabled;
  final bool? waitlistEnabled;
}

class StoreDetail {
  const StoreDetail({
    required this.id,
    required this.name,
    required this.status,
    this.description = '',
    this.phoneNumber = '',
    this.address = '',
    this.timezone = 'Asia/Seoul',
    this.businessHours = const [],
    this.policy = const StorePolicy(),
  });

  final String id;
  final String name;
  final String description;
  final String phoneNumber;
  final String address;
  final String timezone;
  final StoreStatus status;
  final List<BusinessDay> businessHours;
  final StorePolicy policy;

  BusinessDay? businessDayFor(DateTime localDate) {
    final code = dayOfWeekCodes[localDate.weekday - 1];
    return businessHours.where((d) => d.dayOfWeek == code).firstOrNull;
  }

  BusinessDay? get today => businessDayFor(storeToday());

  bool get isOpenNow {
    if (status != StoreStatus.active) return false;
    final day = today;
    if (day == null || day.isClosed) return false;
    final now = storeNow();
    return day.periods.any((p) => p.contains(now.hour, now.minute));
  }

  bool get isActive => status == StoreStatus.active;

  /// 예약 버튼: 예약 미운영 매장은 없으므로 운영 상태만 확인한다. 임시 휴무면 비활성.
  bool get canBook => isActive;

  bool get offersWalkIn => policy.walkInEnabled;

  bool get offersWaitlist => policy.waitlistEnabled;
}

class ServiceItem {
  const ServiceItem({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.status,
    this.description = '',
    this.cleanupMinutes = 0,
    this.capacity = 1,
    this.availableStaffCount = 0,
  });

  final String id;
  final String name;
  final String description;
  final int durationMinutes;
  final int cleanupMinutes;
  final int capacity;
  final String status;
  final int availableStaffCount;

  bool get isActive => status == 'ACTIVE';

  bool get isBookable => isActive && availableStaffCount > 0;
}

class StaffOption {
  const StaffOption({
    required this.id,
    required this.displayName,
    required this.bookingEnabled,
    this.customDurationMinutes,
    this.nextAvailableAt,
  });

  final String id;
  final String displayName;
  final bool bookingEnabled;
  final int? customDurationMinutes;
  final DateTime? nextAvailableAt;
}

enum SlotStatus {
  available('AVAILABLE'),
  unavailable('UNAVAILABLE'),
  waitlistAvailable('WAITLIST_AVAILABLE');

  const SlotStatus(this.code);

  final String code;

  static SlotStatus parse(Object? raw) =>
      values.firstWhere((s) => s.code == raw, orElse: () => SlotStatus.unavailable);
}

class TimeSlot {
  const TimeSlot({
    required this.startAtRaw,
    required this.startAt,
    required this.serviceEndAt,
    required this.occupiedUntil,
    required this.staffId,
    required this.status,
  });

  /// 예약 생성 시 서버가 준 시각 문자열을 그대로 돌려보낸다.
  final String startAtRaw;
  final DateTime startAt;
  final DateTime serviceEndAt;
  final DateTime occupiedUntil;
  final String staffId;
  final SlotStatus status;
}

class AvailabilityDay {
  const AvailabilityDay({required this.date, required this.slots});

  /// 매장 현지 날짜
  final DateTime date;
  final List<TimeSlot> slots;

  List<TimeOption> get timeOptions => groupSlotsByTime(slots);

  bool get hasAvailable => slots.any((s) => s.status == SlotStatus.available);

  bool get hasWaitlistOption => slots.any((s) => s.status == SlotStatus.waitlistAvailable);
}

/// 같은 시작 시각의 직원별 슬롯을 하나의 시간 버튼으로 묶는다.
class TimeOption {
  const TimeOption({required this.startAt, required this.candidates});

  final DateTime startAt;

  /// 서버 정렬(직원명 오름차순)을 유지한 같은 시각의 슬롯들.
  final List<TimeSlot> candidates;

  SlotStatus get status {
    if (candidates.any((s) => s.status == SlotStatus.available)) return SlotStatus.available;
    if (candidates.any((s) => s.status == SlotStatus.waitlistAvailable)) return SlotStatus.waitlistAvailable;
    return SlotStatus.unavailable;
  }

  /// "가능한 직원 누구나"를 선택했을 때 배정할 슬롯.
  TimeSlot? get firstAvailable => candidates.where((s) => s.status == SlotStatus.available).firstOrNull;

  TimeSlot? availableFor(String staffId) =>
      candidates.where((s) => s.staffId == staffId && s.status == SlotStatus.available).firstOrNull;

  bool get isMorning => toStoreTime(startAt).hour < 12;
}

List<TimeOption> groupSlotsByTime(List<TimeSlot> slots) {
  final byTime = <int, List<TimeSlot>>{};
  for (final slot in slots) {
    byTime.putIfAbsent(slot.startAt.millisecondsSinceEpoch, () => []).add(slot);
  }
  final keys = byTime.keys.toList()..sort();
  return [
    for (final key in keys) TimeOption(startAt: byTime[key]!.first.startAt, candidates: byTime[key]!),
  ];
}

class WalkInAvailability {
  const WalkInAvailability({
    required this.walkInEnabled,
    required this.acceptingEntries,
    required this.waitingCount,
    required this.estimatedWaitMinutes,
    this.lastEntryAt,
  });

  final bool walkInEnabled;
  final bool acceptingEntries;
  final int waitingCount;
  final int estimatedWaitMinutes;

  /// `HH:mm`
  final String? lastEntryAt;
}

class StoreSearchQuery {
  const StoreSearchQuery({this.query = '', this.category, this.openNow = false, this.availableToday = false});

  final String query;
  final String? category;
  final bool openNow;
  final bool availableToday;

  StoreSearchQuery copyWith({String? query, String? category, bool clearCategory = false, bool? openNow, bool? availableToday}) =>
      StoreSearchQuery(
        query: query ?? this.query,
        category: clearCategory ? null : (category ?? this.category),
        openNow: openNow ?? this.openNow,
        availableToday: availableToday ?? this.availableToday,
      );
}

class RecentStore {
  const RecentStore({required this.id, required this.name, this.address, this.lastServiceName, required this.viewedAt});

  final String id;
  final String name;
  final String? address;
  final String? lastServiceName;
  final DateTime viewedAt;
}

/// 실시간 예약 필터: 날짜·시간대·인원으로 지금 예약할 수 있는 매장만 찾는다.
enum DayPart {
  any('하루 종일', 0, 24),
  morning('오전', 0, 12),
  afternoon('오후', 12, 17),
  evening('저녁', 17, 24);

  const DayPart(this.label, this.fromHour, this.toHour);

  final String label;
  final int fromHour;
  final int toHour;

  bool contains(DateTime localTime) => localTime.hour >= fromHour && localTime.hour < toHour;
}

class AvailabilityFilter {
  const AvailabilityFilter({required this.date, this.dayPart = DayPart.any, this.partySize = 1});

  /// 매장 현지 날짜
  final DateTime date;
  final DayPart dayPart;
  final int partySize;
}

/// 조건에 맞는 가장 빠른 예약 가능 시간
class AvailabilityMatch {
  const AvailabilityMatch({required this.startAt, required this.serviceName, required this.serviceId});

  final DateTime startAt;
  final String serviceName;
  final String serviceId;
}

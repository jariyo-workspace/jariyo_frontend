import '../../../core/domain/statuses.dart';
import '../../../core/utils/date_time_format.dart';

// ───────────── 오늘의 운영 ─────────────

class TodaySummary {
  const TodaySummary({
    this.reservationCount = 0,
    this.waitingWalkInCount = 0,
    this.checkedInCount = 0,
    this.inServiceCount = 0,
    this.noShowCandidateCount = 0,
    this.pendingSlotOfferCount = 0,
  });

  final int reservationCount;
  final int waitingWalkInCount;
  final int checkedInCount;
  final int inServiceCount;
  final int noShowCandidateCount;
  final int pendingSlotOfferCount;
}

class DashboardAlert {
  const DashboardAlert({required this.type, required this.referenceId, required this.message});

  /// 현재 `NO_SHOW_CANDIDATE`, `PENDING_SLOT_OFFER`
  final String type;
  final String referenceId;
  final String message;
}

class TimelineItem {
  const TimelineItem({required this.type, required this.referenceId, required this.label, this.scheduledAt});

  final String type;
  final String referenceId;
  final String label;
  final DateTime? scheduledAt;
}

class TodayDashboard {
  const TodayDashboard({
    required this.date,
    required this.summary,
    this.alerts = const [],
    this.timeline = const [],
  });

  final String date;
  final TodaySummary summary;
  final List<DashboardAlert> alerts;
  final List<TimelineItem> timeline;
}

// ───────────── 예약 ─────────────

class AdminReservation {
  const AdminReservation({
    required this.id,
    required this.customerName,
    required this.serviceName,
    required this.staffName,
    required this.startAt,
    required this.serviceEndAt,
    required this.status,
    required this.checkInStatus,
    this.partySize = 1,
    this.customerNote,
    this.customerPhone,
    this.source = ReservationSource.unknown,
    this.cancellationReason,
    this.cancelledAt,
    this.checkedInAt,
    this.serviceStartedAt,
    this.completedAt,
  });

  final String id;
  final String customerName;
  final String serviceName;
  final String staffName;
  final DateTime startAt;
  final DateTime serviceEndAt;
  final ReservationStatus status;
  final CheckInStatus checkInStatus;
  final int partySize;
  final String? customerNote;
  final String? customerPhone;
  final ReservationSource source;
  final String? cancellationReason;
  final DateTime? cancelledAt;
  final DateTime? checkedInAt;
  final DateTime? serviceStartedAt;
  final DateTime? completedAt;

  /// 상태별 가능한 행동 (문서 8.3). 버튼 노출과 별개로 서버가 최종 검증한다.
  bool get canCheckIn => status == ReservationStatus.confirmed;
  bool get canReschedule => status == ReservationStatus.confirmed;
  bool get canAssignStaff => status == ReservationStatus.confirmed;
  bool get canMarkNoShow => status == ReservationStatus.confirmed;
  bool get canStartService => status == ReservationStatus.checkedIn;
  bool get canComplete => status == ReservationStatus.inService;
  bool get canCancel => status == ReservationStatus.confirmed || status == ReservationStatus.checkedIn;

  /// 상태 이력 요약 (최근 순)
  List<(DateTime, String)> get timeline => [
    if (completedAt != null) (completedAt!, '서비스 완료'),
    if (serviceStartedAt != null) (serviceStartedAt!, '서비스 시작'),
    if (checkedInAt != null) (checkedInAt!, '고객 체크인'),
    if (cancelledAt != null) (cancelledAt!, '예약 취소${cancellationReason == null ? '' : ' · $cancellationReason'}'),
  ]..sort((a, b) => b.$1.compareTo(a.$1));
}

class ManualReservationRequest {
  const ManualReservationRequest({
    required this.serviceId,
    required this.staffId,
    required this.startAt,
    this.userId,
    this.guestName,
    this.guestPhoneNumber,
    this.partySize = 1,
    this.storeNote,
    this.sendNotification = true,
  });

  final String? userId;
  final String? guestName;
  final String? guestPhoneNumber;
  final String serviceId;
  final String staffId;
  final String startAt;
  final int partySize;
  final String? storeNote;
  final bool sendNotification;

  Map<String, Object?> toJson() => {
    'customer': userId != null
        ? {'userId': userId}
        : {'guestName': guestName, 'guestPhoneNumber': guestPhoneNumber},
    'serviceId': serviceId,
    'staffId': staffId,
    'startAt': startAt,
    'partySize': partySize,
    'storeNote': storeNote,
    'sendNotification': sendNotification,
  };
}

// ───────────── 현장 대기 ─────────────

class AdminWalkIn {
  const AdminWalkIn({
    required this.id,
    required this.queueNumber,
    required this.customerName,
    required this.serviceName,
    required this.status,
    this.preferredStaffName,
    this.waitingMinutes = 0,
    this.estimatedWaitMinutes = 0,
    this.callExpiresAt,
    this.createdAt,
  });

  final String id;
  final int queueNumber;
  final String customerName;
  final String serviceName;
  final String? preferredStaffName;
  final WalkInStatus status;
  final int waitingMinutes;
  final int estimatedWaitMinutes;
  final DateTime? callExpiresAt;
  final DateTime? createdAt;

  AdminWalkIn withCallExpiresAt(DateTime? value) => AdminWalkIn(
    id: id,
    queueNumber: queueNumber,
    customerName: customerName,
    serviceName: serviceName,
    status: status,
    preferredStaffName: preferredStaffName,
    waitingMinutes: waitingMinutes,
    estimatedWaitMinutes: estimatedWaitMinutes,
    callExpiresAt: value,
    createdAt: createdAt,
  );
}

/// 현장 대기열 상태 그룹 (문서 8.6)
enum WalkInGroup {
  needsCall('호출 필요'),
  waiting('대기 중'),
  calling('호출 중'),
  held('보류'),
  checkedIn('체크인 완료'),
  inService('서비스 진행 중');

  const WalkInGroup(this.label);

  final String label;
}

/// 대기 중 고객 가운데 가장 앞선 고객은 "호출 필요"로 분류한다.
Map<WalkInGroup, List<AdminWalkIn>> groupWalkIns(List<AdminWalkIn> walkIns) {
  final waiting = walkIns.where((w) => w.status == WalkInStatus.waiting).toList()
    ..sort((a, b) => a.queueNumber.compareTo(b.queueNumber));
  return {
    WalkInGroup.needsCall: waiting.take(1).toList(),
    WalkInGroup.waiting: waiting.skip(1).toList(),
    WalkInGroup.calling: walkIns.where((w) => w.status == WalkInStatus.called).toList(),
    WalkInGroup.held: walkIns.where((w) => w.status == WalkInStatus.skipped).toList(),
    WalkInGroup.checkedIn: walkIns.where((w) => w.status == WalkInStatus.checkedIn).toList(),
    WalkInGroup.inService: walkIns.where((w) => w.status == WalkInStatus.inService).toList(),
  };
}

class GuestWalkInRequest {
  const GuestWalkInRequest({
    required this.guestName,
    required this.guestPhoneNumber,
    required this.serviceId,
    this.preferredStaffId,
    this.partySize = 1,
  });

  final String guestName;
  final String guestPhoneNumber;
  final String serviceId;
  final String? preferredStaffId;
  final int partySize;

  Map<String, Object?> toJson() => {
    'customer': {'guestName': guestName, 'guestPhoneNumber': guestPhoneNumber},
    'serviceId': serviceId,
    'preferredStaffId': preferredStaffId,
    'partySize': partySize,
  };
}

// ───────────── 예약 대기와 빈자리 제안 ─────────────

class AdminWaitlist {
  const AdminWaitlist({
    required this.id,
    required this.customerName,
    required this.serviceName,
    required this.desiredDate,
    required this.acceptableStartTime,
    required this.acceptableEndTime,
    required this.status,
    this.preferredStaffName,
    this.staffPreferenceType,
    this.sequenceNumber,
    this.partySize,
    this.pendingOffer = false,
    this.pendingOfferExpiresAt,
    this.pendingOfferId,
    this.pendingOfferStartAt,
    this.createdAt,
  });

  final String id;
  final String customerName;
  final String serviceName;
  final String? preferredStaffName;
  final StaffPreferenceType? staffPreferenceType;
  final String desiredDate;
  final String acceptableStartTime;
  final String acceptableEndTime;
  final WaitlistStatus status;
  final int? sequenceNumber;
  final int? partySize;
  final bool pendingOffer;
  final DateTime? pendingOfferExpiresAt;
  final String? pendingOfferId;
  final DateTime? pendingOfferStartAt;
  final DateTime? createdAt;

  String get timeRangeLabel => '${formatHm(acceptableStartTime)} – ${formatHm(acceptableEndTime)}';
}

class AdminSlotOffer {
  const AdminSlotOffer({
    required this.id,
    required this.status,
    this.customerName,
    this.serviceName,
    this.staffName,
    this.startAt,
    this.expiresAt,
    this.waitlistId,
    this.waitlistCondition,
    this.sourceDescription,
  });

  final String id;
  final SlotOfferStatus status;
  final String? customerName;
  final String? serviceName;
  final String? staffName;
  final DateTime? startAt;
  final DateTime? expiresAt;
  final String? waitlistId;
  final String? waitlistCondition;
  final String? sourceDescription;
}

class ManualOfferRequest {
  const ManualOfferRequest({
    required this.staffId,
    required this.startAt,
    this.expiresInMinutes = 3,
    this.sourceReservationId,
  });

  final String staffId;
  final String startAt;
  final int expiresInMinutes;
  final String? sourceReservationId;

  Map<String, Object?> toJson() => {
    'staffId': staffId,
    'startAt': startAt,
    'expiresInMinutes': expiresInMinutes,
    'sourceReservationId': sourceReservationId,
  };
}

// ───────────── 매장 설정 ─────────────

class StaffMember {
  const StaffMember({
    required this.id,
    required this.displayName,
    required this.role,
    required this.status,
    required this.bookingEnabled,
  });

  final String id;
  final String displayName;
  final StoreRole role;
  final MemberStatus status;
  final bool bookingEnabled;

  bool get isActive => status == MemberStatus.active;
}

class StaffServiceAssignment {
  const StaffServiceAssignment({
    required this.serviceId,
    required this.serviceName,
    required this.active,
    this.customDurationMinutes,
    this.defaultDurationMinutes,
  });

  final String serviceId;
  final String serviceName;
  final bool active;
  final int? customDurationMinutes;
  final int? defaultDurationMinutes;

  StaffServiceAssignment copyWith({bool? active, int? customDurationMinutes, bool clearDuration = false}) =>
      StaffServiceAssignment(
        serviceId: serviceId,
        serviceName: serviceName,
        active: active ?? this.active,
        customDurationMinutes: clearDuration ? null : (customDurationMinutes ?? this.customDurationMinutes),
        defaultDurationMinutes: defaultDurationMinutes,
      );
}

class ServiceInput {
  const ServiceInput({
    required this.name,
    required this.durationMinutes,
    this.description = '',
    this.cleanupMinutes = 0,
    this.capacity = 1,
  });

  final String name;
  final String description;
  final int durationMinutes;
  final int cleanupMinutes;
  final int capacity;

  Map<String, Object?> toJson() => {
    'name': name,
    'description': description,
    'durationMinutes': durationMinutes,
    'cleanupMinutes': cleanupMinutes,
    'capacity': capacity,
  };
}

class StaffScheduleEntry {
  const StaffScheduleEntry({
    required this.dayOfWeek,
    required this.start,
    required this.end,
    required this.validFrom,
    this.validUntil,
  });

  final String dayOfWeek;
  final String start;
  final String end;
  final String validFrom;
  final String? validUntil;
}

/// 요일별 반복 근무시간. 근무시간 사이의 빈 시간이 휴게시간이다.
class WeeklySchedule {
  const WeeklySchedule({required this.dayOfWeek, required this.periods});

  final String dayOfWeek;
  final List<(String start, String end)> periods;
}

enum StoreExceptionType {
  closedAllDay('CLOSED_ALL_DAY', '매장 전체 휴무', false),
  specialOpeningHours('SPECIAL_OPENING_HOURS', '특별 영업시간', true),
  blockedPeriod('BLOCKED_PERIOD', '특정 시간 예약 차단', true);

  const StoreExceptionType(this.code, this.label, this.needsTime);

  final String code;
  final String label;
  final bool needsTime;

  static StoreExceptionType parse(Object? raw) => values.firstWhere((v) => v.code == raw, orElse: () => closedAllDay);
}

enum StaffExceptionType {
  dayOff('DAY_OFF', '직원 휴가', false),
  customWorkingHours('CUSTOM_WORKING_HOURS', '특별 근무시간', true),
  blockedPeriod('BLOCKED_PERIOD', '특정 시간 예약 차단', true);

  const StaffExceptionType(this.code, this.label, this.needsTime);

  final String code;
  final String label;
  final bool needsTime;

  static StaffExceptionType parse(Object? raw) => values.firstWhere((v) => v.code == raw, orElse: () => dayOff);
}

class ScheduleException {
  const ScheduleException({
    required this.id,
    required this.targetDate,
    required this.typeCode,
    required this.typeLabel,
    this.startTime,
    this.endTime,
    this.reason,
  });

  final String id;
  final String targetDate;
  final String typeCode;
  final String typeLabel;
  final String? startTime;
  final String? endTime;
  final String? reason;

  String get timeLabel =>
      startTime == null || endTime == null ? '하루 종일' : '${formatHm(startTime)} – ${formatHm(endTime)}';
}

class ExceptionInput {
  const ExceptionInput({required this.targetDate, required this.typeCode, this.startTime, this.endTime, this.reason});

  final String targetDate;
  final String typeCode;
  final String? startTime;
  final String? endTime;
  final String? reason;

  Map<String, Object?> toJson() => {
    'targetDate': targetDate,
    'type': typeCode,
    'startTime': startTime,
    'endTime': endTime,
    'reason': reason,
  };
}

class StoreInfoInput {
  const StoreInfoInput({
    required this.name,
    required this.description,
    required this.phoneNumber,
    required this.address,
  });

  final String name;
  final String description;
  final String phoneNumber;
  final String address;
}

// ───────────── 통계·이력·실패 작업 ─────────────

class AnalyticsSummary {
  const AnalyticsSummary({
    this.reservationCount = 0,
    this.completionRate = 0,
    this.cancellationRate = 0,
    this.noShowRate = 0,
    this.waitlistOfferAcceptanceRate = 0,
    this.cancelledSlotRefillRate = 0,
    this.averageWalkInWaitMinutes = 0,
    this.walkInAbandonmentRate = 0,
  });

  final int reservationCount;
  final double completionRate;
  final double cancellationRate;
  final double noShowRate;
  final double waitlistOfferAcceptanceRate;
  final double cancelledSlotRefillRate;
  final int averageWalkInWaitMinutes;
  final double walkInAbandonmentRate;
}

class DailyReservationStat {
  const DailyReservationStat({
    required this.date,
    this.reservationCount = 0,
    this.completedCount = 0,
    this.cancelledCount = 0,
    this.noShowCount = 0,
  });

  final String date;
  final int reservationCount;
  final int completedCount;
  final int cancelledCount;
  final int noShowCount;
}

class StaffStat {
  const StaffStat({
    required this.staffId,
    required this.staffName,
    this.reservationCount = 0,
    this.completedReservationCount = 0,
    this.cancelledReservationCount = 0,
    this.noShowReservationCount = 0,
    this.completedWalkInServiceCount = 0,
    this.averageCompletedWalkInServiceMinutes = 0,
  });

  final String staffId;
  final String staffName;
  final int reservationCount;
  final int completedReservationCount;
  final int cancelledReservationCount;
  final int noShowReservationCount;
  final int completedWalkInServiceCount;
  final int averageCompletedWalkInServiceMinutes;
}

class ServiceDurationStat {
  const ServiceDurationStat({
    required this.serviceId,
    required this.serviceName,
    this.sessionCount = 0,
    this.expectedDurationMinutes = 0,
    this.averageActualDurationMinutes = 0,
    this.averageDurationDeltaMinutes = 0,
  });

  final String serviceId;
  final String serviceName;
  final int sessionCount;
  final int expectedDurationMinutes;
  final int averageActualDurationMinutes;
  final int averageDurationDeltaMinutes;
}

class AnalyticsReport {
  const AnalyticsReport({
    required this.summary,
    this.daily = const [],
    this.staff = const [],
    this.services = const [],
  });

  final AnalyticsSummary summary;
  final List<DailyReservationStat> daily;
  final List<StaffStat> staff;
  final List<ServiceDurationStat> services;

  /// 관찰된 데이터만 설명하는 인사이트 문장. 원인을 단정하지 않는다.
  List<String> get insights {
    final result = <String>[];
    if (summary.reservationCount == 0) return ['선택한 기간에 예약 데이터가 없어요.'];
    final busiest = daily.isEmpty ? null : (daily.toList()..sort((a, b) => b.reservationCount.compareTo(a.reservationCount))).first;
    if (busiest != null && busiest.reservationCount > 0) {
      result.add('${formatYmdLabel(busiest.date)}에 예약이 ${busiest.reservationCount}건으로 가장 많았어요.');
    }
    final mostCancelled = daily.isEmpty ? null : (daily.toList()..sort((a, b) => b.cancelledCount.compareTo(a.cancelledCount))).first;
    if (mostCancelled != null && mostCancelled.cancelledCount > 0) {
      result.add('${formatYmdLabel(mostCancelled.date)}의 예약 취소가 ${mostCancelled.cancelledCount}건으로 가장 많았어요.');
    }
    final slowest = services.where((s) => s.sessionCount > 0).toList()
      ..sort((a, b) => b.averageDurationDeltaMinutes.compareTo(a.averageDurationDeltaMinutes));
    if (slowest.isNotEmpty && slowest.first.averageDurationDeltaMinutes > 0) {
      final s = slowest.first;
      result.add('${s.serviceName}은(는) 예상보다 평균 ${s.averageDurationDeltaMinutes}분 더 걸렸어요.');
    }
    if (summary.waitlistOfferAcceptanceRate > 0) {
      result.add('빈자리 제안의 ${(summary.waitlistOfferAcceptanceRate * 100).round()}%가 수락되었어요.');
    }
    return result;
  }
}

class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.action,
    required this.occurredAt,
    this.actorType,
    this.actorName,
    this.targetType,
    this.targetId,
    this.reason,
  });

  final String id;
  final String? actorType;
  final String? actorName;
  final String action;
  final String? targetType;
  final String? targetId;
  final String? reason;
  final DateTime occurredAt;
}

enum FailedJobStatus {
  pending('PENDING', '재처리 대기', StatusTone.waiting),
  failed('FAILED', '확인 필요', StatusTone.negative),
  resolved('RESOLVED', '해결됨', StatusTone.positive),
  ignored('IGNORED', '무시함', StatusTone.neutral);

  const FailedJobStatus(this.code, this.label, this.tone);

  final String code;
  final String label;
  final StatusTone tone;

  static FailedJobStatus parse(Object? raw) => values.firstWhere((v) => v.code == raw, orElse: () => failed);
}

class FailedJob {
  const FailedJob({
    required this.id,
    required this.type,
    required this.status,
    required this.attemptCount,
    this.referenceType,
    this.referenceId,
    this.errorCode,
    this.errorMessage,
    this.failedAt,
    this.ignoredReason,
    this.payloadJson,
  });

  final String id;
  final String type;
  final FailedJobStatus status;
  final int attemptCount;
  final String? referenceType;
  final String? referenceId;
  final String? errorCode;
  final String? errorMessage;
  final DateTime? failedAt;
  final String? ignoredReason;
  final String? payloadJson;

  /// 운영자가 이해할 수 있는 실패 설명.
  String get typeLabel => switch (type) {
    'RESERVATION_CONFIRMED' || 'RESERVATION_HOLD_CREATED' => '예약 알림 실패',
    'RESERVATION_CANCELLED' => '예약 취소 알림 실패',
    'RESERVATION_HOLD_EXPIRED' => '자동 만료 처리 실패',
    'SLOT_OFFER_CREATED' => '빈자리 알림 실패',
    'SLOT_OFFER_ACCEPTED' => '예약 대기 승격 실패',
    final t when t.startsWith('WALK_IN') => '고객 호출 알림 실패',
    _ => '자동 처리 실패',
  };

  bool get canRetry => status == FailedJobStatus.failed;
}

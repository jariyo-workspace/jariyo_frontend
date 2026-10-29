import '../../../core/domain/statuses.dart';
import '../../../core/network/json.dart';
import '../../../core/utils/date_time_format.dart';
import '../domain/admin_entities.dart';

TodayDashboard dashboardFromJson(Json json) {
  final s = asJson(json['summary']);
  return TodayDashboard(
    date: str(json['date']),
    summary: TodaySummary(
      reservationCount: intOf(s['reservationCount']),
      waitingWalkInCount: intOf(s['waitingWalkInCount']),
      checkedInCount: intOf(s['checkedInCount']),
      inServiceCount: intOf(s['inServiceCount']),
      noShowCandidateCount: intOf(s['noShowCandidateCount']),
      pendingSlotOfferCount: intOf(s['pendingSlotOfferCount']),
    ),
    alerts: asJsonList(json['alerts'])
        .map((a) => DashboardAlert(type: str(a['type']), referenceId: str(a['referenceId']), message: str(a['message'])))
        .toList(),
    timeline: asJsonList(json['timeline'])
        .map(
          (t) => TimelineItem(
            type: str(t['type']),
            referenceId: str(t['referenceId']),
            label: str(t['label']),
            // 서버가 시간대 없는 매장 현지 시각을 줄 수 있으므로 +09:00으로 해석한다.
            scheduledAt: timeOrNull(_withOffset(strOrNull(t['scheduledAt']))),
          ),
        )
        .toList(),
  );
}

String? _withOffset(String? value) {
  if (value == null) return null;
  if (value.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(value)) return value;
  return '$value+09:00';
}

AdminReservation adminReservationFromJson(Json json) => AdminReservation(
  id: str(json['id']),
  customerName: str(json['customerName'], '고객'),
  serviceName: str(json['serviceName']),
  staffName: str(json['assignedStaffName'] ?? json['staffName']),
  startAt: timeOf(json['startAt']),
  serviceEndAt: timeOf(json['serviceEndAt'] ?? json['startAt']),
  status: ReservationStatus.parse(json['status']),
  checkInStatus: CheckInStatus.parse(json['checkInStatus']),
  partySize: intOf(json['partySize'], 1),
  customerNote: strOrNull(json['customerNote']),
  customerPhone: strOrNull(json['customerPhoneNumber'] ?? json['customerPhone']),
  source: ReservationSource.parse(json['source']),
  cancellationReason: strOrNull(json['cancellationReason']),
  cancelledAt: timeOrNull(json['cancelledAt']),
  checkedInAt: timeOrNull(json['checkedInAt']),
  serviceStartedAt: timeOrNull(json['serviceStartedAt']),
  completedAt: timeOrNull(json['completedAt']),
);

AdminWalkIn adminWalkInFromJson(Json json) => AdminWalkIn(
  id: str(json['id']),
  queueNumber: intOf(json['queueNumber']),
  customerName: str(json['customerName'], '고객'),
  serviceName: str(json['serviceName']),
  preferredStaffName: strOrNull(json['preferredStaffName']),
  status: WalkInStatus.parse(json['status']),
  waitingMinutes: intOf(json['waitingMinutes']),
  estimatedWaitMinutes: intOf(json['estimatedWaitMinutes']),
  callExpiresAt: timeOrNull(json['callExpiresAt']),
  createdAt: timeOrNull(json['createdAt']),
);

AdminWaitlist adminWaitlistFromJson(Json json) {
  final offer = asJson(json['pendingOffer']);
  final hasOfferObject = json['pendingOffer'] is Map;
  return AdminWaitlist(
    id: str(json['id']),
    customerName: str(json['customerName'], '고객'),
    serviceName: str(json['serviceName']),
    preferredStaffName: strOrNull(json['preferredStaffName']),
    staffPreferenceType: json['staffPreferenceType'] == null
        ? null
        : StaffPreferenceType.parse(json['staffPreferenceType']),
    desiredDate: str(json['desiredDate']),
    acceptableStartTime: normalizeHm(strOrNull(json['acceptableStartTime'])),
    acceptableEndTime: normalizeHm(strOrNull(json['acceptableEndTime'])),
    status: WaitlistStatus.parse(json['status']),
    sequenceNumber: intOrNull(json['sequenceNumber']),
    partySize: intOrNull(json['partySize']),
    pendingOffer: hasOfferObject || boolOf(json['pendingOffer']),
    pendingOfferExpiresAt: timeOrNull(json['pendingOfferExpiresAt'] ?? offer['expiresAt']),
    pendingOfferId: strOrNull(offer['id']),
    pendingOfferStartAt: timeOrNull(offer['startAt']),
    createdAt: timeOrNull(json['createdAt']),
  );
}

AdminSlotOffer adminSlotOfferFromJson(Json json) => AdminSlotOffer(
  id: str(json['id']),
  status: SlotOfferStatus.parse(json['status']),
  customerName: strOrNull(json['customerName'] ?? asJson(json['customer'])['displayName']),
  serviceName: strOrNull(json['serviceName'] ?? asJson(json['service'])['name']),
  staffName: strOrNull(json['staffName'] ?? asJson(json['staff'])['displayName']),
  startAt: timeOrNull(json['startAt']),
  expiresAt: timeOrNull(json['expiresAt']),
  waitlistId: strOrNull(json['waitlistId']),
  waitlistCondition: strOrNull(json['waitlistCondition']),
  sourceDescription: strOrNull(json['sourceDescription'] ?? json['reason']),
);

StaffMember staffMemberFromJson(Json json) => StaffMember(
  id: str(json['id']),
  displayName: str(json['displayName']),
  role: StoreRole.parse(json['role']),
  status: MemberStatus.parse(json['status']),
  bookingEnabled: boolOf(json['bookingEnabled']),
);

ScheduleException storeExceptionFromJson(Json json) {
  final type = StoreExceptionType.parse(json['type']);
  return ScheduleException(
    id: str(json['id']),
    targetDate: str(json['targetDate']),
    typeCode: type.code,
    typeLabel: type.label,
    startTime: strOrNull(json['startTime']),
    endTime: strOrNull(json['endTime']),
    reason: strOrNull(json['reason']),
  );
}

ScheduleException staffExceptionFromJson(Json json) {
  final type = StaffExceptionType.parse(json['type']);
  return ScheduleException(
    id: str(json['id']),
    targetDate: str(json['targetDate']),
    typeCode: type.code,
    typeLabel: type.label,
    startTime: strOrNull(json['startTime']),
    endTime: strOrNull(json['endTime']),
    reason: strOrNull(json['reason']),
  );
}

StaffScheduleEntry staffScheduleFromJson(Json json) => StaffScheduleEntry(
  dayOfWeek: str(json['dayOfWeek']),
  start: normalizeHm(strOrNull(json['startTime'])),
  end: normalizeHm(strOrNull(json['endTime'])),
  validFrom: str(json['validFrom']),
  validUntil: strOrNull(json['validUntil']),
);

AuditLogEntry auditLogFromJson(Json json) {
  final actor = asJson(json['actor']);
  return AuditLogEntry(
    id: str(json['id']),
    actorType: strOrNull(actor['type']),
    actorName: strOrNull(actor['displayName']),
    action: str(json['action']),
    targetType: strOrNull(json['targetType']),
    targetId: strOrNull(json['targetId']),
    reason: strOrNull(json['reason']),
    occurredAt: timeOf(json['occurredAt']),
  );
}

FailedJob failedJobFromJson(Json json) {
  final error = asJson(json['lastError']);
  return FailedJob(
    id: str(json['id']),
    type: str(json['type']),
    status: FailedJobStatus.parse(json['status']),
    attemptCount: intOf(json['attemptCount']),
    referenceType: strOrNull(json['referenceType']),
    referenceId: strOrNull(json['referenceId']),
    errorCode: strOrNull(error['code']),
    errorMessage: strOrNull(error['message']),
    failedAt: timeOrNull(json['failedAt']),
    ignoredReason: strOrNull(json['ignoredReason']),
    payloadJson: strOrNull(json['payloadJson']),
  );
}

AnalyticsSummary analyticsSummaryFromJson(Json json) => AnalyticsSummary(
  reservationCount: intOf(json['reservationCount']),
  completionRate: doubleOf(json['completionRate']),
  cancellationRate: doubleOf(json['cancellationRate']),
  noShowRate: doubleOf(json['noShowRate']),
  waitlistOfferAcceptanceRate: doubleOf(json['waitlistOfferAcceptanceRate']),
  cancelledSlotRefillRate: doubleOf(json['cancelledSlotRefillRate']),
  averageWalkInWaitMinutes: intOf(json['averageWalkInWaitMinutes']),
  walkInAbandonmentRate: doubleOf(json['walkInAbandonmentRate']),
);

DailyReservationStat dailyStatFromJson(Json json) => DailyReservationStat(
  date: str(json['date']),
  reservationCount: intOf(json['reservationCount']),
  completedCount: intOf(json['completedCount']),
  cancelledCount: intOf(json['cancelledCount']),
  noShowCount: intOf(json['noShowCount']),
);

StaffStat staffStatFromJson(Json json) => StaffStat(
  staffId: str(json['staffId']),
  staffName: str(json['staffName']),
  reservationCount: intOf(json['reservationCount']),
  completedReservationCount: intOf(json['completedReservationCount']),
  cancelledReservationCount: intOf(json['cancelledReservationCount']),
  noShowReservationCount: intOf(json['noShowReservationCount']),
  completedWalkInServiceCount: intOf(json['completedWalkInServiceCount']),
  averageCompletedWalkInServiceMinutes: intOf(json['averageCompletedWalkInServiceMinutes']),
);

ServiceDurationStat serviceDurationFromJson(Json json) => ServiceDurationStat(
  serviceId: str(json['serviceId']),
  serviceName: str(json['serviceName']),
  sessionCount: intOf(json['sessionCount']),
  expectedDurationMinutes: intOf(json['expectedDurationMinutes']),
  averageActualDurationMinutes: intOf(json['averageActualDurationMinutes']),
  averageDurationDeltaMinutes: intOf(json['averageDurationDeltaMinutes']),
);

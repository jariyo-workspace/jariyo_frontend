import '../../../core/domain/statuses.dart';
import '../../../core/network/json.dart';
import '../../../core/utils/date_time_format.dart';
import '../domain/store_entities.dart';

TimePeriod timePeriodFromJson(Json json) => TimePeriod(
  start: normalizeHm(strOrNull(json['openTime']) ?? strOrNull(json['startTime']) ?? ''),
  end: normalizeHm(strOrNull(json['closeTime']) ?? strOrNull(json['endTime']) ?? ''),
);

BusinessDay businessDayFromJson(Json json) => BusinessDay(
  dayOfWeek: str(json['dayOfWeek']),
  isClosed: boolOf(json['isClosed'] ?? json['closed']),
  periods: asJsonList(json['periods']).map(timePeriodFromJson).toList(),
);

StorePolicy storePolicyFromJson(Json json) => StorePolicy(
  bookingOpenDays: intOrNull(json['bookingOpenDays']),
  minimumBookingNoticeMinutes: intOrNull(json['minimumBookingNoticeMinutes']),
  cancellationDeadlineMinutes: intOrNull(json['cancellationDeadlineMinutes']),
  checkInOpenBeforeMinutes: intOrNull(json['checkInOpenBeforeMinutes']),
  lateToleranceMinutes: intOrNull(json['lateToleranceMinutes']),
  noShowAfterMinutes: intOrNull(json['noShowAfterMinutes']),
  reservationHoldMinutes: intOrNull(json['reservationHoldMinutes']),
  slotOfferExpirationMinutes: intOrNull(json['slotOfferExpirationMinutes']),
  walkInCallTimeoutMinutes: intOrNull(json['walkInCallTimeoutMinutes']),
  waitlistEnabled: boolOf(json['waitlistEnabled']),
  walkInEnabled: boolOf(json['walkInEnabled']),
  autoNoShowEnabled: boolOf(json['autoNoShowEnabled']),
);

StoreSummary storeSummaryFromJson(Json json) {
  final hours = json['todayBusinessHours'];
  return StoreSummary(
    id: str(json['id']),
    name: str(json['name']),
    description: str(json['description']),
    address: str(json['address']),
    phoneNumber: str(json['phoneNumber']),
    category: strOrNull(json['category']),
    status: StoreStatus.parse(json['status']),
    openNow: boolOrNull(json['openNow']),
    todayHours: hours is Map ? timePeriodFromJson(asJson(hours)) : null,
    nextAvailableAt: timeOrNull(json['nextAvailableAt']),
    walkInEnabled: boolOrNull(json['walkInEnabled']),
    waitlistEnabled: boolOrNull(json['waitlistEnabled']),
  );
}

StoreDetail storeDetailFromJson(Json json) => StoreDetail(
  id: str(json['id']),
  name: str(json['name']),
  description: str(json['description']),
  phoneNumber: str(json['phoneNumber']),
  address: str(json['address']),
  timezone: str(json['timezone'], 'Asia/Seoul'),
  status: StoreStatus.parse(json['status']),
  businessHours: asJsonList(json['businessHours']).map(businessDayFromJson).toList(),
  policy: storePolicyFromJson(asJson(json['policySummary'])),
);

ServiceItem serviceItemFromJson(Json json) => ServiceItem(
  id: str(json['id']),
  name: str(json['name']),
  description: str(json['description']),
  durationMinutes: intOf(json['durationMinutes']),
  cleanupMinutes: intOf(json['cleanupMinutes']),
  capacity: intOf(json['capacity'], 1),
  status: str(json['status'], 'ACTIVE'),
  availableStaffCount: intOf(json['availableStaffCount']),
);

StaffOption staffOptionFromJson(Json json) => StaffOption(
  id: str(json['id']),
  displayName: str(json['displayName']),
  bookingEnabled: boolOf(json['bookingEnabled'], true),
  customDurationMinutes: intOrNull(json['customDurationMinutes']),
  nextAvailableAt: timeOrNull(json['nextAvailableAt']),
);

TimeSlot timeSlotFromJson(Json json) => TimeSlot(
  startAtRaw: str(json['startAt']),
  startAt: timeOf(json['startAt']),
  serviceEndAt: timeOf(json['serviceEndAt']),
  occupiedUntil: timeOf(json['occupiedUntil'] ?? json['serviceEndAt']),
  staffId: str(json['staffId']),
  status: SlotStatus.parse(json['status']),
);

AvailabilityDay availabilityDayFromJson(Json json) => AvailabilityDay(
  date: parseYmd(strOrNull(json['date'])) ?? storeToday(),
  slots: asJsonList(json['slots']).map(timeSlotFromJson).toList(),
);

WalkInAvailability walkInAvailabilityFromJson(Json json) => WalkInAvailability(
  walkInEnabled: boolOf(json['walkInEnabled']),
  acceptingEntries: boolOf(json['acceptingEntries']),
  waitingCount: intOf(json['waitingCount']),
  estimatedWaitMinutes: intOf(json['estimatedWaitMinutes']),
  lastEntryAt: strOrNull(json['lastEntryAt']),
);

Json recentStoreToJson(RecentStore store) => {
  'id': store.id,
  'name': store.name,
  'address': store.address,
  'lastServiceName': store.lastServiceName,
  'viewedAt': store.viewedAt.toIso8601String(),
};

RecentStore recentStoreFromJson(Json json) => RecentStore(
  id: str(json['id']),
  name: str(json['name']),
  address: strOrNull(json['address']),
  lastServiceName: strOrNull(json['lastServiceName']),
  viewedAt: timeOrNull(json['viewedAt']) ?? DateTime.now(),
);

String _s(dynamic v) => v?.toString() ?? '';
String? _sn(dynamic v) => v?.toString();
int? _in(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');
List<Map<String, dynamic>> _list(dynamic v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];
Map<String, dynamic> _map(dynamic v) => v is Map<String, dynamic> ? v : const {};

class StoreSummary {
  final String id, name, status;
  final String? description, address, phoneNumber;

  StoreSummary.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        name = _s(j['name']),
        status = _s(j['status']),
        description = _sn(j['description']),
        address = _sn(j['address']),
        phoneNumber = _sn(j['phoneNumber']);
}

class BusinessHour {
  final String dayOfWeek;
  final bool isClosed;
  final List<(String, String)> periods;

  BusinessHour.fromJson(Map<String, dynamic> j)
      : dayOfWeek = _s(j['dayOfWeek']),
        isClosed = j['isClosed'] == true,
        periods = _list(j['periods']).map((p) => (_s(p['openTime']), _s(p['closeTime']))).toList();
}

class PolicySummary {
  final int? bookingOpenDays, minimumBookingNoticeMinutes, cancellationDeadlineMinutes;

  PolicySummary.fromJson(Map<String, dynamic> j)
      : bookingOpenDays = _in(j['bookingOpenDays']),
        minimumBookingNoticeMinutes = _in(j['minimumBookingNoticeMinutes']),
        cancellationDeadlineMinutes = _in(j['cancellationDeadlineMinutes']);
}

class StoreDetail {
  final String id, name, status;
  final String? description, phoneNumber, address, timezone;
  final List<BusinessHour> businessHours;
  final PolicySummary? policy;

  StoreDetail.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        name = _s(j['name']),
        status = _s(j['status']),
        description = _sn(j['description']),
        phoneNumber = _sn(j['phoneNumber']),
        address = _sn(j['address']),
        timezone = _sn(j['timezone']),
        businessHours = _list(j['businessHours']).map(BusinessHour.fromJson).toList(),
        policy = j['policySummary'] is Map<String, dynamic> ? PolicySummary.fromJson(j['policySummary']) : null;
}

class ServiceItem {
  final String id, name, status;
  final String? description;
  final int durationMinutes, availableStaffCount;

  ServiceItem.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        name = _s(j['name']),
        status = _s(j['status']),
        description = _sn(j['description']),
        durationMinutes = _in(j['durationMinutes']) ?? 0,
        availableStaffCount = _in(j['availableStaffCount']) ?? 0;

  bool get selectable => status != 'INACTIVE' && availableStaffCount > 0;
}

class StaffItem {
  final String id, displayName;
  final bool bookingEnabled;
  final int? customDurationMinutes;

  StaffItem.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        displayName = _s(j['displayName']),
        bookingEnabled = j['bookingEnabled'] == true,
        customDurationMinutes = _in(j['customDurationMinutes']);
}

class Slot {
  final String startAt, serviceEndAt, staffId, status;

  Slot.fromJson(Map<String, dynamic> j)
      : startAt = _s(j['startAt']),
        serviceEndAt = _s(j['serviceEndAt']),
        staffId = _s(j['staffId']),
        status = _s(j['status']);

  bool get available => status == 'AVAILABLE';
}

class Ref {
  final String id, name;
  final String? phoneNumber, address;

  Ref.fromJson(Map<String, dynamic> j, {String nameKey = 'name'})
      : id = _s(j['id']),
        name = _s(j[nameKey]),
        phoneNumber = _sn(j['phoneNumber']),
        address = _sn(j['address']);
}

class ReservationSummary {
  final String id, status, startAt;
  final Ref store, service, staff;

  ReservationSummary.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        status = _s(j['status']),
        startAt = _s(j['startAt']),
        store = Ref.fromJson(_map(j['store'])),
        service = Ref.fromJson(_map(j['service'])),
        staff = Ref.fromJson(_map(j['staff']), nameKey: 'displayName');

  ReservationSummary._copy(ReservationSummary o, this.status)
      : id = o.id,
        startAt = o.startAt,
        store = o.store,
        service = o.service,
        staff = o.staff;

  ReservationSummary withStatus(String status) => ReservationSummary._copy(this, status);
}

class ReservationDetail {
  final String id, status, startAt, serviceEndAt;
  final Ref store, service, staff;
  final int partySize;
  final String? customerNote, cancellationDeadlineAt;
  final bool canCancel;

  ReservationDetail.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        status = _s(j['status']),
        startAt = _s(j['startAt']),
        serviceEndAt = _s(j['serviceEndAt']),
        store = Ref.fromJson(_map(j['store'])),
        service = Ref.fromJson(_map(j['service'])),
        staff = Ref.fromJson(_map(j['staff']), nameKey: 'displayName'),
        partySize = _in(j['partySize']) ?? 1,
        customerNote = _sn(j['customerNote']),
        cancellationDeadlineAt = _sn(j['cancellationDeadlineAt']),
        canCancel = j['canCancel'] == true;
}

class HistoryItem {
  final String? previousStatus, note;
  final String nextStatus, occurredAt;

  HistoryItem.fromJson(Map<String, dynamic> j)
      : previousStatus = _sn(j['previousStatus']),
        nextStatus = _s(j['nextStatus']),
        note = _sn(j['note']),
        occurredAt = _s(j['occurredAt']);
}

class ReservationPage {
  final List<ReservationSummary> items;
  final String? cursor;
  final bool hasNext;

  ReservationPage(this.items, this.cursor, this.hasNext);
}

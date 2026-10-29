import '../../../core/domain/named_ref.dart';
import '../../../core/domain/statuses.dart';

class ReservationStoreRef {
  const ReservationStoreRef({required this.id, required this.name, this.phoneNumber, this.address});

  final String id;
  final String name;
  final String? phoneNumber;
  final String? address;
}

class Reservation {
  const Reservation({
    required this.id,
    required this.store,
    required this.status,
    required this.startAt,
    required this.serviceEndAt,
    this.service,
    this.staff,
    this.source = ReservationSource.unknown,
    this.occupiedUntil,
    this.partySize = 1,
    this.customerNote,
    this.checkInAvailable = false,
    this.canCancel = false,
    this.cancellationDeadlineAt,
    this.createdAt,
  });

  final String id;
  final ReservationStoreRef store;
  final NamedRef? service;
  final NamedRef? staff;
  final ReservationSource source;
  final ReservationStatus status;
  final DateTime startAt;
  final DateTime serviceEndAt;
  final DateTime? occupiedUntil;
  final int partySize;
  final String? customerNote;
  final bool checkInAvailable;
  final bool canCancel;
  final DateTime? cancellationDeadlineAt;
  final DateTime? createdAt;

  int get durationMinutes => serviceEndAt.difference(startAt).inMinutes;

  Reservation copyWith({ReservationStatus? status, bool? canCancel}) => Reservation(
    id: id,
    store: store,
    service: service,
    staff: staff,
    source: source,
    status: status ?? this.status,
    startAt: startAt,
    serviceEndAt: serviceEndAt,
    occupiedUntil: occupiedUntil,
    partySize: partySize,
    customerNote: customerNote,
    checkInAvailable: checkInAvailable,
    canCancel: canCancel ?? this.canCancel,
    cancellationDeadlineAt: cancellationDeadlineAt,
    createdAt: createdAt,
  );
}

class ReservationSummary {
  const ReservationSummary({
    required this.id,
    required this.storeName,
    required this.status,
    required this.startAt,
    this.storeId,
    this.serviceName,
    this.staffName,
    this.serviceEndAt,
  });

  final String id;
  final String? storeId;
  final String storeName;
  final String? serviceName;
  final String? staffName;
  final ReservationStatus status;
  final DateTime startAt;
  final DateTime? serviceEndAt;
}

class ReservationHistoryEntry {
  const ReservationHistoryEntry({
    required this.nextStatus,
    required this.occurredAt,
    this.previousStatus,
    this.changedByType,
    this.reasonCode,
    this.note,
  });

  final ReservationStatus? previousStatus;
  final ReservationStatus nextStatus;
  final String? changedByType;
  final String? reasonCode;
  final String? note;
  final DateTime occurredAt;

  String get description {
    final actor = actorLabel(changedByType);
    final action = switch (reasonCode) {
      'CREATED' => '예약 확정',
      'CUSTOMER_CANCELLED' => '예약 취소',
      _ => nextStatus.label,
    };
    return actor == '-' ? action : '$actor · $action';
  }
}

class CheckInAvailability {
  const CheckInAvailability({
    required this.available,
    required this.alreadyCheckedIn,
    this.availableFrom,
    this.availableUntil,
  });

  final bool available;
  final bool alreadyCheckedIn;
  final DateTime? availableFrom;
  final DateTime? availableUntil;

  bool get notYetOpen => !available && availableFrom != null && DateTime.now().isBefore(availableFrom!);

  bool get windowClosed => !available && availableUntil != null && DateTime.now().isAfter(availableUntil!);
}

class CheckInResult {
  const CheckInResult({required this.reservationId, this.checkedInAt, this.alreadyCheckedIn = false});

  final String reservationId;
  final DateTime? checkedInAt;
  final bool alreadyCheckedIn;
}

class NewReservation {
  const NewReservation({
    required this.storeId,
    required this.serviceId,
    required this.staffId,
    required this.startAt,
    this.partySize = 1,
    this.customerNote,
  });

  final String storeId;
  final String serviceId;
  final String staffId;

  /// 가능 시간 API가 준 시각 문자열 그대로.
  final String startAt;
  final int partySize;
  final String? customerNote;

  Map<String, Object?> toJson() => {
    'storeId': storeId,
    'serviceId': serviceId,
    'staffId': staffId,
    'startAt': startAt,
    'partySize': partySize,
    if (customerNote != null && customerNote!.trim().isNotEmpty) 'customerNote': customerNote!.trim(),
  };
}

/// 예약 진행 중 선택 정보. 로그인 만료 시 임시 보존했다가 로그인 후 이어서 진행한다.
class BookingDraft {
  const BookingDraft({
    required this.storeId,
    required this.storeName,
    this.serviceId,
    this.serviceName,
    this.serviceDurationMinutes,
    this.staffId,
    this.staffName,
    this.slotStartAt,
    this.slotStaffId,
    this.partySize = 1,
    this.customerNote,
    this.walkIn = false,
  });

  final String storeId;
  final String storeName;
  final String? serviceId;
  final String? serviceName;
  final int? serviceDurationMinutes;

  /// null이면 "가능한 직원 누구나".
  final String? staffId;
  final String? staffName;
  final String? slotStartAt;
  final String? slotStaffId;
  final int partySize;
  final String? customerNote;

  /// 현장 대기 등록 중이었는지.
  final bool walkIn;

  Map<String, Object?> toJson() => {
    'storeId': storeId,
    'storeName': storeName,
    'serviceId': serviceId,
    'serviceName': serviceName,
    'serviceDurationMinutes': serviceDurationMinutes,
    'staffId': staffId,
    'staffName': staffName,
    'slotStartAt': slotStartAt,
    'slotStaffId': slotStaffId,
    'partySize': partySize,
    'customerNote': customerNote,
    'walkIn': walkIn,
  };
}

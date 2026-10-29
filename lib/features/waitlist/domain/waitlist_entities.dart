import '../../../core/domain/named_ref.dart';
import '../../../core/domain/statuses.dart';
import '../../../core/utils/date_time_format.dart';

class ActiveOffer {
  const ActiveOffer({required this.id, required this.status, this.startAt, this.expiresAt});

  final String id;
  final SlotOfferStatus status;
  final DateTime? startAt;
  final DateTime? expiresAt;
}

class WaitlistEntry {
  const WaitlistEntry({
    required this.id,
    required this.status,
    required this.desiredDate,
    required this.acceptableStartTime,
    required this.acceptableEndTime,
    required this.staffPreferenceType,
    this.storeId,
    this.store,
    this.serviceId,
    this.service,
    this.preferredStaffId,
    this.preferredStaff,
    this.sequenceNumber,
    this.activeOffer,
    this.resultingReservationId,
    this.createdAt,
  });

  final String id;
  final String? storeId;
  final NamedRef? store;
  final String? serviceId;
  final NamedRef? service;
  final String? preferredStaffId;
  final NamedRef? preferredStaff;
  final StaffPreferenceType staffPreferenceType;

  /// `YYYY-MM-DD`
  final String desiredDate;

  /// `HH:mm`
  final String acceptableStartTime;
  final String acceptableEndTime;
  final WaitlistStatus status;
  final int? sequenceNumber;
  final ActiveOffer? activeOffer;
  final String? resultingReservationId;
  final DateTime? createdAt;

  String get timeRangeLabel => '${formatHm(acceptableStartTime)}부터 ${formatHm(acceptableEndTime)} 사이';

  String? get effectiveStoreId => store?.id ?? storeId;

  WaitlistEntry withNames({NamedRef? store, NamedRef? service}) => WaitlistEntry(
    id: id,
    status: status,
    desiredDate: desiredDate,
    acceptableStartTime: acceptableStartTime,
    acceptableEndTime: acceptableEndTime,
    staffPreferenceType: staffPreferenceType,
    storeId: storeId,
    store: store ?? this.store,
    serviceId: serviceId,
    service: service ?? this.service,
    preferredStaffId: preferredStaffId,
    preferredStaff: preferredStaff,
    sequenceNumber: sequenceNumber,
    activeOffer: activeOffer,
    resultingReservationId: resultingReservationId,
    createdAt: createdAt,
  );
}

/// 조건 요약 문장. 화면 하단에 자연어로 보여준다.
String describeWaitlistCondition({
  required String desiredDate,
  required String startTime,
  required String endTime,
  required StaffPreferenceType preference,
  String? staffName,
}) {
  final date = parseYmd(desiredDate);
  final dateLabel = date == null ? desiredDate : '${date.month}월 ${date.day}일';
  final lines = ['$dateLabel ${formatHm(startTime)}부터 ${formatHm(endTime)} 사이,'];
  switch (preference) {
    case StaffPreferenceType.specificOnly:
      lines.add('${staffName ?? '선택한'} 직원만 기다릴게요.');
    case StaffPreferenceType.specificPreferred:
      lines.add('${staffName ?? '선택한'} 직원을 우선으로 기다릴게요.');
      lines.add('다른 직원도 가능합니다.');
    case StaffPreferenceType.anyStaff:
      lines.add('직원과 관계없이 빈자리를 기다릴게요.');
  }
  return lines.join('\n');
}

class NewWaitlist {
  const NewWaitlist({
    required this.storeId,
    required this.serviceId,
    required this.staffPreferenceType,
    required this.desiredDate,
    required this.acceptableStartTime,
    required this.acceptableEndTime,
    this.preferredStaffId,
    this.partySize = 1,
  });

  final String storeId;
  final String serviceId;
  final String? preferredStaffId;
  final StaffPreferenceType staffPreferenceType;
  final String desiredDate;
  final String acceptableStartTime;
  final String acceptableEndTime;
  final int partySize;

  Map<String, Object?> toJson() => {
    'storeId': storeId,
    'serviceId': serviceId,
    'preferredStaffId': preferredStaffId,
    'staffPreferenceType': staffPreferenceType.code,
    'desiredDate': desiredDate,
    'acceptableStartTime': acceptableStartTime,
    'acceptableEndTime': acceptableEndTime,
    'partySize': partySize,
  };
}

class WaitlistUpdate {
  const WaitlistUpdate({
    required this.staffPreferenceType,
    required this.acceptableStartTime,
    required this.acceptableEndTime,
    this.preferredStaffId,
  });

  final String? preferredStaffId;
  final StaffPreferenceType staffPreferenceType;
  final String acceptableStartTime;
  final String acceptableEndTime;

  Map<String, Object?> toJson() => {
    'preferredStaffId': preferredStaffId,
    'staffPreferenceType': staffPreferenceType.code,
    'acceptableStartTime': acceptableStartTime,
    'acceptableEndTime': acceptableEndTime,
  };
}

class SlotOffer {
  const SlotOffer({
    required this.id,
    required this.status,
    required this.startAt,
    required this.deadline,
    this.waitlistId,
    this.store,
    this.service,
    this.staff,
    this.serviceEndAt,
    this.resultingReservationId,
  });

  final String id;
  final String? waitlistId;
  final NamedRef? store;
  final NamedRef? service;
  final NamedRef? staff;
  final DateTime startAt;
  final DateTime? serviceEndAt;
  final SlotOfferStatus status;

  /// 응답 시점의 `remainingSeconds`로 계산한 기기 기준 마감 시각. 기기 시계 오차의 영향을 줄인다.
  final DateTime deadline;
  final String? resultingReservationId;

  bool get isPending => status == SlotOfferStatus.pending;

  int? get durationMinutes => serviceEndAt?.difference(startAt).inMinutes;
}

class SlotOfferAcceptance {
  const SlotOfferAcceptance({required this.reservationId, this.waitlistId});

  final String reservationId;
  final String? waitlistId;
}

class SlotOfferDecline {
  const SlotOfferDecline({this.waitlistId, required this.waitlistStatus});

  final String? waitlistId;
  final WaitlistStatus waitlistStatus;
}

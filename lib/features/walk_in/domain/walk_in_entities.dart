import '../../../core/domain/named_ref.dart';
import '../../../core/domain/statuses.dart';

class WalkIn {
  const WalkIn({
    required this.id,
    required this.queueNumber,
    required this.status,
    this.storeId,
    this.store,
    this.serviceId,
    this.service,
    this.waitingAhead = 0,
    this.estimatedWaitMinutes = 0,
    this.calledAt,
    this.callExpiresAt,
    this.createdAt,
  });

  final String id;
  final String? storeId;
  final NamedRef? store;
  final String? serviceId;
  final NamedRef? service;
  final int queueNumber;
  final WalkInStatus status;
  final int waitingAhead;
  final int estimatedWaitMinutes;
  final DateTime? calledAt;
  final DateTime? callExpiresAt;
  final DateTime? createdAt;

  String? get effectiveStoreId => store?.id ?? storeId;

  WalkIn withNames({NamedRef? store, NamedRef? service}) => WalkIn(
    id: id,
    queueNumber: queueNumber,
    status: status,
    storeId: storeId,
    store: store ?? this.store,
    serviceId: serviceId,
    service: service ?? this.service,
    waitingAhead: waitingAhead,
    estimatedWaitMinutes: estimatedWaitMinutes,
    calledAt: calledAt,
    callExpiresAt: callExpiresAt,
    createdAt: createdAt,
  );

  /// 진행 단계: 대기 등록 → 호출 대기 → 입장 확인 → 서비스 시작
  int get progressStep => switch (status) {
    WalkInStatus.waiting || WalkInStatus.skipped => 1,
    WalkInStatus.called => 1,
    WalkInStatus.checkedIn => 2,
    WalkInStatus.inService || WalkInStatus.completed => 3,
    _ => 0,
  };
}

class NewWalkIn {
  const NewWalkIn({required this.storeId, required this.serviceId, this.preferredStaffId, this.partySize = 1});

  final String storeId;
  final String serviceId;
  final String? preferredStaffId;
  final int partySize;

  Map<String, Object?> toJson() => {
    'storeId': storeId,
    'serviceId': serviceId,
    'preferredStaffId': preferredStaffId,
    'partySize': partySize,
  };
}

enum CallResponse {
  entering('ENTERING'),
  delayed('DELAYED'),
  cancel('CANCEL');

  const CallResponse(this.code);

  final String code;
}

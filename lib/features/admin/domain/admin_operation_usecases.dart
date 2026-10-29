import '../../../core/domain/statuses.dart';
import '../../../core/error/app_failure.dart';
import 'admin_entities.dart';
import 'admin_repositories.dart';

class GetTodayDashboard {
  const GetTodayDashboard(this._repository);

  final AdminOperationRepository _repository;

  Future<TodayDashboard> call(String storeId) => _repository.getDashboard(storeId);
}

class GetStoreReservations {
  const GetStoreReservations(this._repository);

  final AdminOperationRepository _repository;

  Future<List<AdminReservation>> call(
    String storeId, {
    DateTime? from,
    DateTime? to,
    String? staffId,
    String? serviceId,
    ReservationStatus? status,
    String? customerQuery,
  }) async {
    final items = await _repository.listReservations(
      storeId,
      from: from,
      to: to,
      staffId: staffId,
      serviceId: serviceId,
      status: status,
      customerQuery: customerQuery,
    );
    return items..sort((a, b) => a.startAt.compareTo(b.startAt));
  }
}

class GetStoreReservation {
  const GetStoreReservation(this._repository);

  final AdminOperationRepository _repository;

  Future<AdminReservation> call(String storeId, String reservationId) =>
      _repository.getReservation(storeId, reservationId);
}

class CreateManualReservation {
  const CreateManualReservation(this._repository);

  final AdminOperationRepository _repository;

  Future<void> call(String storeId, ManualReservationRequest request, {required String idempotencyKey}) =>
      _repository.createReservation(storeId, request, idempotencyKey: idempotencyKey);
}

class RescheduleReservation {
  const RescheduleReservation(this._repository);

  final AdminOperationRepository _repository;

  Future<void> call(
    String storeId,
    String reservationId, {
    required String staffId,
    required String startAt,
    required String reason,
    bool sendNotification = true,
    required String idempotencyKey,
  }) => _repository.rescheduleReservation(
    storeId,
    reservationId,
    staffId: staffId,
    startAt: startAt,
    reason: reason,
    sendNotification: sendNotification,
    idempotencyKey: idempotencyKey,
  );
}

class AssignReservationStaff {
  const AssignReservationStaff(this._repository);

  final AdminOperationRepository _repository;

  Future<void> call(
    String storeId,
    String reservationId, {
    required String staffId,
    required String reason,
    required String idempotencyKey,
  }) => _repository.assignStaff(storeId, reservationId, staffId: staffId, reason: reason, idempotencyKey: idempotencyKey);
}

class CancelStoreReservation {
  const CancelStoreReservation(this._repository);

  final AdminOperationRepository _repository;

  Future<void> call(
    String storeId,
    String reservationId, {
    required String reasonCode,
    required String reason,
    bool sendNotification = true,
    required String idempotencyKey,
  }) => _repository.cancelReservation(
    storeId,
    reservationId,
    reasonCode: reasonCode,
    reason: reason,
    sendNotification: sendNotification,
    idempotencyKey: idempotencyKey,
  );
}

class MarkReservationNoShow {
  const MarkReservationNoShow(this._repository);

  final AdminOperationRepository _repository;

  Future<void> call(String storeId, String reservationId, {required String reason, required String idempotencyKey}) =>
      _repository.markReservationNoShow(storeId, reservationId, reason: reason, idempotencyKey: idempotencyKey);
}

class CheckInStoreReservation {
  const CheckInStoreReservation(this._repository);

  final AdminOperationRepository _repository;

  Future<void> call(String storeId, String reservationId, {required String idempotencyKey}) async {
    try {
      await _repository.checkInReservation(storeId, reservationId, idempotencyKey: idempotencyKey);
    } on AppFailure catch (failure) {
      // 이미 체크인된 예약은 오류로 보지 않는다.
      if (failure.code != 'CHECK_IN_ALREADY_COMPLETED') rethrow;
    }
  }
}

/// 예약·현장 고객 서비스 시작. 세션 ID를 보관해 완료 처리에 사용한다.
class StartService {
  const StartService(this._repository);

  final AdminOperationRepository _repository;

  Future<void> reservation(String storeId, String reservationId, {required String staffId, required String idempotencyKey}) async {
    final sessionId = await _repository.startReservationService(
      storeId,
      reservationId,
      staffId: staffId,
      idempotencyKey: idempotencyKey,
    );
    await _repository.rememberSession(reservationId, sessionId);
  }

  Future<void> walkIn(String storeId, String walkInId, {required String staffId, required String idempotencyKey}) async {
    final sessionId = await _repository.startWalkInService(
      storeId,
      walkInId,
      staffId: staffId,
      idempotencyKey: idempotencyKey,
    );
    await _repository.rememberSession(walkInId, sessionId);
  }
}

class CompleteService {
  const CompleteService(this._repository);

  final AdminOperationRepository _repository;

  bool canComplete(String referenceId) => _repository.sessionIdFor(referenceId) != null;

  Future<void> call(String storeId, String referenceId, {String? note, required String idempotencyKey}) async {
    final sessionId = _repository.sessionIdFor(referenceId);
    if (sessionId == null) {
      throw const AppFailure(
        kind: FailureKind.notFound,
        code: 'SERVICE_SESSION_NOT_FOUND',
        message: '이 기기에서 시작한 서비스 정보를 찾을 수 없어요.\n서비스를 시작한 기기에서 완료해 주세요.',
      );
    }
    await _repository.completeServiceSession(storeId, sessionId, note: note, idempotencyKey: idempotencyKey);
    await _repository.forgetSession(referenceId);
  }
}

class GetWalkInQueue {
  const GetWalkInQueue(this._repository);

  final AdminOperationRepository _repository;

  Future<List<AdminWalkIn>> call(String storeId, {DateTime? date}) => _repository.listWalkIns(storeId, date: date);
}

class RegisterGuestWalkIn {
  const RegisterGuestWalkIn(this._repository);

  final AdminOperationRepository _repository;

  Future<void> call(String storeId, GuestWalkInRequest request, {required String idempotencyKey}) =>
      _repository.registerGuestWalkIn(storeId, request, idempotencyKey: idempotencyKey);
}

class CallWalkIn {
  const CallWalkIn(this._repository);

  final AdminOperationRepository _repository;

  Future<DateTime?> call(String storeId, String walkInId, {int timeoutMinutes = 3, bool recall = false, required String idempotencyKey}) =>
      _repository.callWalkIn(storeId, walkInId, timeoutMinutes: timeoutMinutes, recall: recall, idempotencyKey: idempotencyKey);
}

/// 현장 대기 상태 변경 (입장 확인, 보류, 취소, 복귀, 응답 없음, 순서 변경)
class ManageWalkIn {
  const ManageWalkIn(this._repository);

  final AdminOperationRepository _repository;

  Future<void> checkIn(String storeId, String walkInId, {required String idempotencyKey}) =>
      _repository.checkInWalkIn(storeId, walkInId, idempotencyKey: idempotencyKey);

  Future<void> skip(String storeId, String walkInId, {required String reason, required String idempotencyKey}) =>
      _repository.skipWalkIn(storeId, walkInId, reason: reason, idempotencyKey: idempotencyKey);

  Future<void> cancel(String storeId, String walkInId, {required String reason, required String idempotencyKey}) =>
      _repository.cancelWalkIn(storeId, walkInId, reason: reason, idempotencyKey: idempotencyKey);

  Future<void> restore(String storeId, String walkInId, {required String idempotencyKey}) =>
      _repository.restoreWalkIn(storeId, walkInId, idempotencyKey: idempotencyKey);

  Future<void> markNoShow(String storeId, String walkInId, {required String reason, required String idempotencyKey}) =>
      _repository.markWalkInNoShow(storeId, walkInId, reason: reason, idempotencyKey: idempotencyKey);

  Future<void> reorder(
    String storeId,
    String walkInId, {
    String? beforeWalkInId,
    required String reasonCode,
    required String reason,
    required String idempotencyKey,
  }) => _repository.reorderWalkIn(
    storeId,
    walkInId,
    beforeWalkInId: beforeWalkInId,
    reasonCode: reasonCode,
    reason: reason,
    idempotencyKey: idempotencyKey,
  );
}

class GetStoreWaitlists {
  const GetStoreWaitlists(this._repository);

  final AdminOperationRepository _repository;

  Future<List<AdminWaitlist>> call(
    String storeId, {
    DateTime? date,
    String? serviceId,
    String? staffId,
    WaitlistStatus? status,
  }) async {
    final items = await _repository.listWaitlists(
      storeId,
      date: date,
      serviceId: serviceId,
      staffId: staffId,
      status: status,
    );
    return items..sort((a, b) => (a.sequenceNumber ?? 0).compareTo(b.sequenceNumber ?? 0));
  }
}

class GetStoreWaitlist {
  const GetStoreWaitlist(this._repository);

  final AdminOperationRepository _repository;

  Future<AdminWaitlist> call(String storeId, String waitlistId) => _repository.getWaitlist(storeId, waitlistId);
}

class CreateManualOffer {
  const CreateManualOffer(this._repository);

  final AdminOperationRepository _repository;

  Future<void> call(String storeId, String waitlistId, ManualOfferRequest request, {required String idempotencyKey}) =>
      _repository.createOffer(storeId, waitlistId, request, idempotencyKey: idempotencyKey);
}

class GetStoreSlotOffers {
  const GetStoreSlotOffers(this._repository);

  final AdminOperationRepository _repository;

  Future<List<AdminSlotOffer>> call(String storeId, {SlotOfferStatus? status, DateTime? date}) =>
      _repository.listSlotOffers(storeId, status: status, date: date);
}

class ManageSlotOffer {
  const ManageSlotOffer(this._repository);

  final AdminOperationRepository _repository;

  Future<void> revoke(String storeId, String offerId, {required String reason, required String idempotencyKey}) =>
      _repository.revokeOffer(storeId, offerId, reason: reason, idempotencyKey: idempotencyKey);

  Future<void> offerNext(String storeId, String offerId, {required String idempotencyKey}) =>
      _repository.offerNext(storeId, offerId, idempotencyKey: idempotencyKey);
}

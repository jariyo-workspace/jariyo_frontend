import '../../../core/domain/paged.dart';
import '../../../core/domain/statuses.dart';
import '../../../core/error/app_failure.dart';
import 'reservation_entities.dart';
import 'reservation_repository.dart';

class CreateReservation {
  const CreateReservation(this._repository);

  final ReservationRepository _repository;

  Future<Reservation> call(NewReservation request, {required String idempotencyKey}) =>
      _repository.create(request, idempotencyKey: idempotencyKey);
}

class GetMyReservations {
  const GetMyReservations(this._repository);

  final ReservationRepository _repository;

  Future<Paged<ReservationSummary>> call({
    ReservationStatus? status,
    DateTime? from,
    DateTime? to,
    String? cursor,
    int limit = 20,
  }) async {
    try {
      return await _repository.listMine(status: status, from: from, to: to, cursor: cursor, limit: limit);
    } on AppFailure catch (failure) {
      // 저장한 커서가 잘못되면 커서를 버리고 첫 페이지부터 다시 조회한다.
      if (cursor != null && failure.code == 'COMMON-400') {
        return _repository.listMine(status: status, from: from, to: to, limit: limit);
      }
      rethrow;
    }
  }
}

class GetReservationDetail {
  const GetReservationDetail(this._repository);

  final ReservationRepository _repository;

  Future<Reservation> call(String reservationId) => _repository.get(reservationId);
}

class GetReservationHistory {
  const GetReservationHistory(this._repository);

  final ReservationRepository _repository;

  Future<List<ReservationHistoryEntry>> call(String reservationId) => _repository.history(reservationId);
}

class CancelReservation {
  const CancelReservation(this._repository);

  final ReservationRepository _repository;

  Future<void> call(String reservationId, {required String reason, required String idempotencyKey}) =>
      _repository.cancel(reservationId, reason: reason, idempotencyKey: idempotencyKey);
}

class GetCheckInAvailability {
  const GetCheckInAvailability(this._repository);

  final ReservationRepository _repository;

  Future<CheckInAvailability> call(String reservationId) => _repository.checkInAvailability(reservationId);
}

/// 체크인. 이미 처리된 경우 오류로 보지 않고 기존 결과로 돌려준다.
class CheckInReservation {
  const CheckInReservation(this._repository);

  final ReservationRepository _repository;

  Future<CheckInResult> call(String reservationId, {required String idempotencyKey}) async {
    try {
      return await _repository.checkIn(reservationId, idempotencyKey: idempotencyKey);
    } on AppFailure catch (failure) {
      if (failure.code == 'CHECK_IN_ALREADY_COMPLETED') {
        return CheckInResult(reservationId: reservationId, alreadyCheckedIn: true);
      }
      rethrow;
    }
  }
}

class CheckInWithQr {
  const CheckInWithQr(this._repository);

  final ReservationRepository _repository;

  Future<CheckInResult> call(String token, {required String idempotencyKey}) =>
      _repository.checkInWithQr(token, idempotencyKey: idempotencyKey);
}

class BookingDrafts {
  const BookingDrafts(this._repository);

  final ReservationRepository _repository;

  BookingDraft? load() => _repository.loadDraft();

  Future<void> save(BookingDraft draft) => _repository.saveDraft(draft);

  Future<void> clear() => _repository.saveDraft(null);
}

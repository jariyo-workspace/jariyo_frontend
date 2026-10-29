import '../../../core/domain/paged.dart';
import '../../../core/domain/statuses.dart';
import 'reservation_entities.dart';

abstract interface class ReservationRepository {
  Future<Reservation> create(NewReservation request, {required String idempotencyKey});

  Future<Paged<ReservationSummary>> listMine({
    ReservationStatus? status,
    DateTime? from,
    DateTime? to,
    String? cursor,
    int limit = 20,
  });

  Future<Reservation> get(String reservationId);

  Future<List<ReservationHistoryEntry>> history(String reservationId);

  Future<void> cancel(String reservationId, {required String reason, required String idempotencyKey});

  Future<CheckInAvailability> checkInAvailability(String reservationId);

  Future<CheckInResult> checkIn(String reservationId, {required String idempotencyKey});

  Future<CheckInResult> checkInWithQr(String token, {required String idempotencyKey});

  BookingDraft? loadDraft();

  Future<void> saveDraft(BookingDraft? draft);
}

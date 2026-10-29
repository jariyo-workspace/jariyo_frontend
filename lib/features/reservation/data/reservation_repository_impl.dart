import '../../../core/domain/named_ref.dart';
import '../../../core/domain/paged.dart';
import '../../../core/domain/statuses.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/common_mappers.dart';
import '../../../core/network/json.dart';
import '../../../core/storage/key_value_store.dart';
import '../../../core/utils/date_time_format.dart';
import '../domain/reservation_entities.dart';
import '../domain/reservation_repository.dart';

Reservation reservationFromJson(Json json) {
  final store = asJson(json['store']);
  return Reservation(
    id: str(json['id']),
    store: ReservationStoreRef(
      id: str(store['id'] ?? json['storeId']),
      name: str(store['name'] ?? json['storeName']),
      phoneNumber: strOrNull(store['phoneNumber']),
      address: strOrNull(store['address']),
    ),
    service: NamedRef.fromJson(json['service']),
    staff: NamedRef.fromJson(json['staff']),
    source: ReservationSource.parse(json['source']),
    status: ReservationStatus.parse(json['status']),
    startAt: timeOf(json['startAt']),
    serviceEndAt: timeOf(json['serviceEndAt'] ?? json['startAt']),
    occupiedUntil: timeOrNull(json['occupiedUntil']),
    partySize: intOf(json['partySize'], 1),
    customerNote: strOrNull(json['customerNote']),
    checkInAvailable: boolOf(json['checkInAvailable']),
    canCancel: boolOf(json['canCancel']),
    cancellationDeadlineAt: timeOrNull(json['cancellationDeadlineAt']),
    createdAt: timeOrNull(json['createdAt']),
  );
}

ReservationSummary reservationSummaryFromJson(Json json) => ReservationSummary(
  id: str(json['id']),
  storeId: strOrNull(asJson(json['store'])['id'] ?? json['storeId']),
  storeName: str(asJson(json['store'])['name'] ?? json['storeName']),
  serviceName: strOrNull(asJson(json['service'])['name'] ?? json['serviceName']),
  staffName: strOrNull(asJson(json['staff'])['displayName'] ?? asJson(json['staff'])['name'] ?? json['staffName']),
  status: ReservationStatus.parse(json['status']),
  startAt: timeOf(json['startAt']),
  serviceEndAt: timeOrNull(json['serviceEndAt']),
);

ReservationHistoryEntry _historyFromJson(Json json) => ReservationHistoryEntry(
  previousStatus: json['previousStatus'] == null ? null : ReservationStatus.parse(json['previousStatus']),
  nextStatus: ReservationStatus.parse(json['nextStatus']),
  changedByType: strOrNull(json['changedByType']),
  reasonCode: strOrNull(json['reasonCode']),
  note: strOrNull(json['note']),
  occurredAt: timeOf(json['occurredAt']),
);

class ReservationRemoteDataSource {
  const ReservationRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Reservation> create(NewReservation request, String key) async =>
      reservationFromJson((await _api.post('/reservations', body: request.toJson(), idempotencyKey: key)).json);

  Future<Paged<ReservationSummary>> listMine(Map<String, Object?> query) async =>
      pagedFrom(await _api.get('/me/reservations', query: query), reservationSummaryFromJson);

  Future<Reservation> get(String id) async => reservationFromJson((await _api.get('/reservations/$id')).json);

  Future<List<ReservationHistoryEntry>> history(String id) async =>
      (await _api.get('/reservations/$id/history')).list.map(_historyFromJson).toList();

  Future<void> cancel(String id, String reason, String key) =>
      _api.post('/reservations/$id/cancel', body: {'reason': reason}, idempotencyKey: key);

  Future<CheckInAvailability> checkInAvailability(String id) async {
    final json = (await _api.get('/reservations/$id/check-in-availability')).json;
    return CheckInAvailability(
      available: boolOf(json['available']),
      alreadyCheckedIn: boolOf(json['alreadyCheckedIn']),
      availableFrom: timeOrNull(json['availableFrom']),
      availableUntil: timeOrNull(json['availableUntil']),
    );
  }

  Future<CheckInResult> checkIn(String id, String key) async {
    final json = (await _api.post(
      '/reservations/$id/check-in',
      body: {'method': 'CUSTOMER_APP'},
      idempotencyKey: key,
    )).json;
    return CheckInResult(reservationId: str(json['reservationId'], id), checkedInAt: timeOrNull(json['checkedInAt']));
  }

  Future<CheckInResult> checkInWithQr(String token, String key) async {
    final json = (await _api.post('/check-ins/qr', body: {'token': token}, idempotencyKey: key)).json;
    return CheckInResult(reservationId: str(json['reservationId']), checkedInAt: timeOrNull(json['checkedInAt']));
  }
}

class ReservationRepositoryImpl implements ReservationRepository {
  const ReservationRepositoryImpl(this._remote, this._local);

  static const _draftKey = 'reservation.bookingDraft';

  final ReservationRemoteDataSource _remote;
  final KeyValueStore _local;

  @override
  Future<Reservation> create(NewReservation request, {required String idempotencyKey}) =>
      _remote.create(request, idempotencyKey);

  @override
  Future<Paged<ReservationSummary>> listMine({
    ReservationStatus? status,
    DateTime? from,
    DateTime? to,
    String? cursor,
    int limit = 20,
  }) => _remote.listMine({
    'status': status?.code,
    'from': from == null ? null : formatYmd(from),
    'to': to == null ? null : formatYmd(to),
    'cursor': cursor,
    'limit': limit,
  });

  @override
  Future<Reservation> get(String reservationId) => _remote.get(reservationId);

  @override
  Future<List<ReservationHistoryEntry>> history(String reservationId) => _remote.history(reservationId);

  @override
  Future<void> cancel(String reservationId, {required String reason, required String idempotencyKey}) =>
      _remote.cancel(reservationId, reason, idempotencyKey);

  @override
  Future<CheckInAvailability> checkInAvailability(String reservationId) =>
      _remote.checkInAvailability(reservationId);

  @override
  Future<CheckInResult> checkIn(String reservationId, {required String idempotencyKey}) =>
      _remote.checkIn(reservationId, idempotencyKey);

  @override
  Future<CheckInResult> checkInWithQr(String token, {required String idempotencyKey}) =>
      _remote.checkInWithQr(token, idempotencyKey);

  @override
  BookingDraft? loadDraft() {
    final json = asJson(_local.getJson(_draftKey));
    if (json.isEmpty) return null;
    return BookingDraft(
      storeId: str(json['storeId']),
      storeName: str(json['storeName']),
      serviceId: strOrNull(json['serviceId']),
      serviceName: strOrNull(json['serviceName']),
      serviceDurationMinutes: intOrNull(json['serviceDurationMinutes']),
      staffId: strOrNull(json['staffId']),
      staffName: strOrNull(json['staffName']),
      slotStartAt: strOrNull(json['slotStartAt']),
      slotStaffId: strOrNull(json['slotStaffId']),
      partySize: intOf(json['partySize'], 1),
      customerNote: strOrNull(json['customerNote']),
      walkIn: boolOf(json['walkIn']),
    );
  }

  @override
  Future<void> saveDraft(BookingDraft? draft) => _local.setJson(_draftKey, draft?.toJson());
}

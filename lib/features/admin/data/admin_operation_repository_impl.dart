import '../../../core/domain/statuses.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../../../core/storage/key_value_store.dart';
import '../../../core/utils/date_time_format.dart';
import '../domain/admin_entities.dart';
import '../domain/admin_repositories.dart';
import 'admin_mappers.dart';

class AdminOperationRepositoryImpl implements AdminOperationRepository {
  const AdminOperationRepositoryImpl(this._api, this._local);

  static const _sessionsKey = 'admin.serviceSessions';

  final ApiClient _api;
  final KeyValueStore _local;

  String _base(String storeId) => '/admin/stores/$storeId';

  String? _ymd(DateTime? date) => date == null ? null : formatYmd(date);

  @override
  Future<TodayDashboard> getDashboard(String storeId) async =>
      dashboardFromJson((await _api.get('${_base(storeId)}/dashboard/today')).json);

  @override
  Future<List<AdminReservation>> listReservations(
    String storeId, {
    DateTime? from,
    DateTime? to,
    String? staffId,
    String? serviceId,
    ReservationStatus? status,
    String? customerQuery,
  }) async {
    final result = await _api.get(
      '${_base(storeId)}/reservations',
      query: {
        'from': _ymd(from),
        'to': _ymd(to),
        'staffId': staffId,
        'serviceId': serviceId,
        'status': status?.code,
        'customerQuery': customerQuery,
      },
    );
    return result.list.map(adminReservationFromJson).toList();
  }

  @override
  Future<AdminReservation> getReservation(String storeId, String reservationId) async =>
      adminReservationFromJson((await _api.get('${_base(storeId)}/reservations/$reservationId')).json);

  @override
  Future<void> createReservation(String storeId, ManualReservationRequest request, {required String idempotencyKey}) =>
      _api.post('${_base(storeId)}/reservations', body: request.toJson(), idempotencyKey: idempotencyKey);

  @override
  Future<void> rescheduleReservation(
    String storeId,
    String reservationId, {
    required String staffId,
    required String startAt,
    required String reason,
    required bool sendNotification,
    required String idempotencyKey,
  }) => _api.post(
    '${_base(storeId)}/reservations/$reservationId/reschedule',
    body: {'staffId': staffId, 'startAt': startAt, 'reason': reason, 'sendNotification': sendNotification},
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<void> assignStaff(
    String storeId,
    String reservationId, {
    required String staffId,
    required String reason,
    required String idempotencyKey,
  }) => _api.post(
    '${_base(storeId)}/reservations/$reservationId/assign-staff',
    body: {'staffId': staffId, 'reason': reason},
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<void> cancelReservation(
    String storeId,
    String reservationId, {
    required String reasonCode,
    required String reason,
    required bool sendNotification,
    required String idempotencyKey,
  }) => _api.post(
    '${_base(storeId)}/reservations/$reservationId/cancel',
    body: {'reasonCode': reasonCode, 'reason': reason, 'sendNotification': sendNotification},
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<void> markReservationNoShow(
    String storeId,
    String reservationId, {
    required String reason,
    required String idempotencyKey,
  }) => _api.post(
    '${_base(storeId)}/reservations/$reservationId/mark-no-show',
    body: {'reason': reason},
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<void> checkInReservation(String storeId, String reservationId, {required String idempotencyKey}) =>
      _api.post('${_base(storeId)}/reservations/$reservationId/check-in', idempotencyKey: idempotencyKey);

  @override
  Future<String> startReservationService(
    String storeId,
    String reservationId, {
    required String staffId,
    required String idempotencyKey,
  }) async {
    final result = await _api.post(
      '${_base(storeId)}/reservations/$reservationId/start-service',
      body: {'staffId': staffId},
      idempotencyKey: idempotencyKey,
    );
    return str(result.json['serviceSessionId']);
  }

  @override
  Future<void> completeServiceSession(String storeId, String sessionId, {String? note, required String idempotencyKey}) =>
      _api.post(
        '${_base(storeId)}/service-sessions/$sessionId/complete',
        body: {'completionNote': note},
        idempotencyKey: idempotencyKey,
      );

  @override
  Future<List<AdminWalkIn>> listWalkIns(String storeId, {WalkInStatus? status, DateTime? date}) async {
    final result = await _api.get('${_base(storeId)}/walk-ins', query: {'status': status?.code, 'date': _ymd(date)});
    return result.list.map(adminWalkInFromJson).toList();
  }

  @override
  Future<void> registerGuestWalkIn(String storeId, GuestWalkInRequest request, {required String idempotencyKey}) =>
      _api.post('${_base(storeId)}/walk-ins', body: request.toJson(), idempotencyKey: idempotencyKey);

  @override
  Future<DateTime?> callWalkIn(
    String storeId,
    String walkInId, {
    required int timeoutMinutes,
    required String idempotencyKey,
    bool recall = false,
  }) async {
    final result = await _api.post(
      '${_base(storeId)}/walk-ins/$walkInId/${recall ? 'recall' : 'call'}',
      body: {'responseTimeoutMinutes': timeoutMinutes},
      idempotencyKey: idempotencyKey,
    );
    return timeOrNull(result.json['callExpiresAt']);
  }

  @override
  Future<void> checkInWalkIn(String storeId, String walkInId, {required String idempotencyKey}) =>
      _api.post('${_base(storeId)}/walk-ins/$walkInId/check-in', idempotencyKey: idempotencyKey);

  @override
  Future<void> skipWalkIn(String storeId, String walkInId, {required String reason, required String idempotencyKey}) =>
      _api.post('${_base(storeId)}/walk-ins/$walkInId/skip', body: {'reason': reason}, idempotencyKey: idempotencyKey);

  @override
  Future<void> cancelWalkIn(String storeId, String walkInId, {required String reason, required String idempotencyKey}) =>
      _api.post('${_base(storeId)}/walk-ins/$walkInId/cancel', body: {'reason': reason}, idempotencyKey: idempotencyKey);

  @override
  Future<void> restoreWalkIn(String storeId, String walkInId, {required String idempotencyKey}) =>
      _api.post('${_base(storeId)}/walk-ins/$walkInId/restore', idempotencyKey: idempotencyKey);

  @override
  Future<void> markWalkInNoShow(
    String storeId,
    String walkInId, {
    required String reason,
    required String idempotencyKey,
  }) => _api.post(
    '${_base(storeId)}/walk-ins/$walkInId/mark-no-show',
    body: {'reason': reason},
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<String> startWalkInService(
    String storeId,
    String walkInId, {
    required String staffId,
    required String idempotencyKey,
  }) async {
    final result = await _api.post(
      '${_base(storeId)}/walk-ins/$walkInId/start-service',
      body: {'staffId': staffId},
      idempotencyKey: idempotencyKey,
    );
    return str(result.json['serviceSessionId']);
  }

  @override
  Future<void> reorderWalkIn(
    String storeId,
    String walkInId, {
    String? beforeWalkInId,
    required String reasonCode,
    required String reason,
    required String idempotencyKey,
  }) => _api.post(
    '${_base(storeId)}/walk-ins/$walkInId/reorder',
    body: {'beforeWalkInId': beforeWalkInId, 'reasonCode': reasonCode, 'reason': reason},
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<List<AdminWaitlist>> listWaitlists(
    String storeId, {
    DateTime? date,
    String? serviceId,
    String? staffId,
    WaitlistStatus? status,
  }) async {
    final result = await _api.get(
      '${_base(storeId)}/waitlists',
      query: {'date': _ymd(date), 'serviceId': serviceId, 'staffId': staffId, 'status': status?.code},
    );
    return result.list.map(adminWaitlistFromJson).toList();
  }

  @override
  Future<AdminWaitlist> getWaitlist(String storeId, String waitlistId) async =>
      adminWaitlistFromJson((await _api.get('${_base(storeId)}/waitlists/$waitlistId')).json);

  @override
  Future<void> createOffer(
    String storeId,
    String waitlistId,
    ManualOfferRequest request, {
    required String idempotencyKey,
  }) => _api.post(
    '${_base(storeId)}/waitlists/$waitlistId/offers',
    body: request.toJson(),
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<List<AdminSlotOffer>> listSlotOffers(String storeId, {SlotOfferStatus? status, DateTime? date}) async {
    final result = await _api.get('${_base(storeId)}/slot-offers', query: {'status': status?.code, 'date': _ymd(date)});
    return result.list.map(adminSlotOfferFromJson).toList();
  }

  @override
  Future<void> revokeOffer(String storeId, String offerId, {required String reason, required String idempotencyKey}) =>
      _api.post('${_base(storeId)}/slot-offers/$offerId/revoke', body: {'reason': reason}, idempotencyKey: idempotencyKey);

  @override
  Future<void> offerNext(String storeId, String offerId, {required String idempotencyKey}) =>
      _api.post('${_base(storeId)}/slot-offers/$offerId/offer-next', idempotencyKey: idempotencyKey);

  Json get _sessions => asJson(_local.getJson(_sessionsKey));

  @override
  String? sessionIdFor(String referenceId) => strOrNull(_sessions[referenceId]);

  @override
  Future<void> rememberSession(String referenceId, String sessionId) =>
      _local.setJson(_sessionsKey, {..._sessions, referenceId: sessionId});

  @override
  Future<void> forgetSession(String referenceId) => _local.setJson(_sessionsKey, {..._sessions}..remove(referenceId));
}

import '../../../core/domain/named_ref.dart';
import '../../../core/domain/statuses.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../../../core/utils/date_time_format.dart';
import '../../store/data/store_reference_cache.dart';
import '../domain/waitlist_entities.dart';
import '../domain/waitlist_repository.dart';

WaitlistEntry waitlistFromJson(Json json) {
  final offer = json['activeOffer'];
  return WaitlistEntry(
    id: str(json['id']),
    storeId: strOrNull(json['storeId']),
    store: NamedRef.fromJson(json['store']),
    serviceId: strOrNull(json['serviceId']),
    service: NamedRef.fromJson(json['service']),
    preferredStaffId: strOrNull(json['preferredStaffId']),
    preferredStaff: NamedRef.fromJson(json['preferredStaff']),
    staffPreferenceType: StaffPreferenceType.parse(json['staffPreferenceType']),
    desiredDate: str(json['desiredDate']),
    acceptableStartTime: normalizeHm(strOrNull(json['acceptableStartTime'])),
    acceptableEndTime: normalizeHm(strOrNull(json['acceptableEndTime'])),
    status: WaitlistStatus.parse(json['status']),
    sequenceNumber: intOrNull(json['sequenceNumber']),
    activeOffer: offer is Map
        ? ActiveOffer(
            id: str(offer['id']),
            status: SlotOfferStatus.parse(offer['status']),
            startAt: timeOrNull(offer['startAt']),
            expiresAt: timeOrNull(offer['expiresAt']),
          )
        : null,
    resultingReservationId: strOrNull(json['resultingReservationId']),
    createdAt: timeOrNull(json['createdAt']),
  );
}

SlotOffer slotOfferFromJson(Json json) {
  final remaining = intOrNull(json['remainingSeconds']);
  final expiresAt = timeOrNull(json['expiresAt']);
  return SlotOffer(
    id: str(json['id']),
    waitlistId: strOrNull(json['waitlistId']),
    store: NamedRef.fromJson(json['store']),
    service: NamedRef.fromJson(json['service']),
    staff: NamedRef.fromJson(json['staff']),
    startAt: timeOf(json['startAt']),
    serviceEndAt: timeOrNull(json['serviceEndAt']),
    status: SlotOfferStatus.parse(json['status']),
    deadline: remaining != null ? DateTime.now().add(Duration(seconds: remaining)) : (expiresAt ?? DateTime.now()),
    resultingReservationId: strOrNull(json['resultingReservationId']),
  );
}

class WaitlistRemoteDataSource {
  const WaitlistRemoteDataSource(this._api, this._refs);

  final ApiClient _api;
  final StoreReferenceCache _refs;

  /// 목록 응답에는 매장·서비스 ID만 있으므로 이름을 채운다.
  Future<WaitlistEntry> _named(WaitlistEntry w) async {
    final storeId = w.effectiveStoreId;
    if (storeId == null || (w.store != null && w.service != null)) return w;
    final serviceId = w.service?.id ?? w.serviceId;
    final storeName = w.store == null ? await _refs.storeName(storeId) : null;
    final serviceName = w.service == null && serviceId != null ? await _refs.serviceName(storeId, serviceId) : null;
    return w.withNames(
      store: storeName == null ? null : NamedRef(id: storeId, name: storeName),
      service: serviceName == null ? null : NamedRef(id: serviceId!, name: serviceName),
    );
  }

  Future<WaitlistEntry> create(NewWaitlist request, String key) async =>
      waitlistFromJson((await _api.post('/waitlists', body: request.toJson(), idempotencyKey: key)).json);

  Future<List<WaitlistEntry>> listMine(String? status) async => Future.wait(
    (await _api.get('/me/waitlists', query: {'status': status})).list.map(waitlistFromJson).map(_named),
  );

  Future<WaitlistEntry> get(String id) async => waitlistFromJson((await _api.get('/waitlists/$id')).json);

  Future<void> update(String id, WaitlistUpdate update) => _api.put('/waitlists/$id', body: update.toJson());

  Future<void> cancel(String id, String reason, String key) =>
      _api.post('/waitlists/$id/cancel', body: {'reason': reason}, idempotencyKey: key);

  Future<List<SlotOffer>> listOffers(String? status) async =>
      (await _api.get('/me/slot-offers', query: {'status': status})).list.map(slotOfferFromJson).toList();

  Future<SlotOffer> getOffer(String id) async => slotOfferFromJson((await _api.get('/slot-offers/$id')).json);

  Future<SlotOfferAcceptance> accept(String id, String key) async {
    final json = (await _api.post('/slot-offers/$id/accept', idempotencyKey: key)).json;
    return SlotOfferAcceptance(
      reservationId: str(asJson(json['reservation'])['id']),
      waitlistId: strOrNull(asJson(json['waitlist'])['id']),
    );
  }

  Future<SlotOfferDecline> decline(String id, bool keepWaitlistActive, String key) async {
    final json = (await _api.post(
      '/slot-offers/$id/decline',
      body: {'keepWaitlistActive': keepWaitlistActive},
      idempotencyKey: key,
    )).json;
    final waitlist = asJson(json['waitlist']);
    return SlotOfferDecline(
      waitlistId: strOrNull(waitlist['id']),
      waitlistStatus: WaitlistStatus.parse(waitlist['status']),
    );
  }
}

class WaitlistRepositoryImpl implements WaitlistRepository {
  const WaitlistRepositoryImpl(this._remote);

  final WaitlistRemoteDataSource _remote;

  @override
  Future<WaitlistEntry> create(NewWaitlist request, {required String idempotencyKey}) =>
      _remote.create(request, idempotencyKey);

  @override
  Future<List<WaitlistEntry>> listMine({WaitlistStatus? status}) => _remote.listMine(status?.code);

  @override
  Future<WaitlistEntry> get(String waitlistId) => _remote.get(waitlistId);

  @override
  Future<void> update(String waitlistId, WaitlistUpdate update) => _remote.update(waitlistId, update);

  @override
  Future<void> cancel(String waitlistId, {required String reason, required String idempotencyKey}) =>
      _remote.cancel(waitlistId, reason, idempotencyKey);

  @override
  Future<List<SlotOffer>> listOffers({SlotOfferStatus? status}) => _remote.listOffers(status?.code);

  @override
  Future<SlotOffer> getOffer(String offerId) => _remote.getOffer(offerId);

  @override
  Future<SlotOfferAcceptance> acceptOffer(String offerId, {required String idempotencyKey}) =>
      _remote.accept(offerId, idempotencyKey);

  @override
  Future<SlotOfferDecline> declineOffer(
    String offerId, {
    required bool keepWaitlistActive,
    required String idempotencyKey,
  }) => _remote.decline(offerId, keepWaitlistActive, idempotencyKey);
}

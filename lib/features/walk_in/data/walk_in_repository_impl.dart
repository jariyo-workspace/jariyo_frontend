import '../../../core/domain/named_ref.dart';
import '../../../core/domain/statuses.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../../../core/utils/date_time_format.dart';
import '../../store/data/store_reference_cache.dart';
import '../domain/walk_in_entities.dart';
import '../domain/walk_in_repository.dart';

WalkIn walkInFromJson(Json json) => WalkIn(
  id: str(json['id']),
  storeId: strOrNull(json['storeId']),
  store: NamedRef.fromJson(json['store']),
  serviceId: strOrNull(json['serviceId']),
  service: NamedRef.fromJson(json['service']),
  queueNumber: intOf(json['queueNumber']),
  status: WalkInStatus.parse(json['status']),
  waitingAhead: intOf(json['waitingAhead']),
  estimatedWaitMinutes: intOf(json['estimatedWaitMinutes']),
  calledAt: timeOrNull(json['calledAt']),
  callExpiresAt: timeOrNull(json['callExpiresAt']),
  createdAt: timeOrNull(json['createdAt']),
);

class WalkInRemoteDataSource {
  const WalkInRemoteDataSource(this._api, this._refs);

  final ApiClient _api;
  final StoreReferenceCache _refs;

  /// 목록 응답에는 매장·서비스 ID만 있으므로 이름을 채운다.
  Future<WalkIn> _named(WalkIn w) async {
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

  Future<WalkIn> register(NewWalkIn request, String key) async =>
      walkInFromJson((await _api.post('/walk-ins', body: request.toJson(), idempotencyKey: key)).json);

  Future<List<WalkIn>> listMine(String? status, String? date) async => Future.wait(
    (await _api.get('/me/walk-ins', query: {'status': status, 'date': date})).list.map(walkInFromJson).map(_named),
  );

  Future<WalkIn> get(String id) async => walkInFromJson((await _api.get('/walk-ins/$id')).json);

  Future<void> cancel(String id, String reason, String key) =>
      _api.post('/walk-ins/$id/cancel', body: {'reason': reason}, idempotencyKey: key);

  Future<WalkIn> respondCall(String id, CallResponse response, String key) async => walkInFromJson(
    (await _api.post('/walk-ins/$id/respond-call', body: {'response': response.code}, idempotencyKey: key)).json,
  );
}

class WalkInRepositoryImpl implements WalkInRepository {
  const WalkInRepositoryImpl(this._remote);

  final WalkInRemoteDataSource _remote;

  @override
  Future<WalkIn> register(NewWalkIn request, {required String idempotencyKey}) =>
      _remote.register(request, idempotencyKey);

  @override
  Future<List<WalkIn>> listMine({WalkInStatus? status, DateTime? date}) =>
      _remote.listMine(status?.code, date == null ? null : formatYmd(date));

  @override
  Future<WalkIn> get(String walkInId) => _remote.get(walkInId);

  @override
  Future<void> cancel(String walkInId, {required String reason, required String idempotencyKey}) =>
      _remote.cancel(walkInId, reason, idempotencyKey);

  @override
  Future<WalkIn> respondCall(String walkInId, CallResponse response, {required String idempotencyKey}) =>
      _remote.respondCall(walkInId, response, idempotencyKey);
}

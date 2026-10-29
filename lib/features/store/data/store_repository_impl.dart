import '../../../core/domain/paged.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/common_mappers.dart';
import '../../../core/network/json.dart';
import '../../../core/storage/key_value_store.dart';
import '../../../core/utils/date_time_format.dart';
import '../domain/store_entities.dart';
import '../domain/store_repository.dart';
import 'store_mappers.dart';

class StoreRemoteDataSource {
  const StoreRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Paged<StoreSummary>> searchStores(StoreSearchQuery query, String? cursor) async {
    final result = await _api.get(
      '/stores',
      auth: false,
      query: {
        'query': query.query.trim(),
        'category': query.category,
        'openNow': query.openNow ? true : null,
        'availableToday': query.availableToday ? true : null,
        'cursor': cursor,
        'limit': 20,
      },
    );
    return pagedFrom(result, storeSummaryFromJson);
  }

  Future<StoreDetail> getStore(String storeId) async =>
      storeDetailFromJson((await _api.get('/stores/$storeId', auth: false)).json);

  Future<List<ServiceItem>> getServices(String storeId, bool activeOnly) async {
    final result = await _api.get('/stores/$storeId/services', auth: false, query: {'activeOnly': activeOnly});
    return result.list.map(serviceItemFromJson).toList();
  }

  Future<List<StaffOption>> getServiceStaff(String storeId, String serviceId, String? date) async {
    final result = await _api.get('/stores/$storeId/services/$serviceId/staff', auth: false, query: {'date': date});
    return result.list.map(staffOptionFromJson).toList();
  }

  Future<List<AvailabilityDay>> getAvailability(Map<String, Object?> query, String storeId) async {
    final result = await _api.get('/stores/$storeId/availability', auth: false, query: query);
    return asJsonList(result.json['dates']).map(availabilityDayFromJson).toList();
  }

  Future<WalkInAvailability> getWalkInAvailability(String storeId, String? serviceId, String? staffId) async {
    final result = await _api.get(
      '/stores/$storeId/walk-in-status',
      auth: false,
      query: {'serviceId': serviceId, 'staffId': staffId},
    );
    return walkInAvailabilityFromJson(result.json);
  }
}

class StoreRepositoryImpl implements StoreRepository {
  const StoreRepositoryImpl(this._remote, this._local);

  static const _searchesKey = 'store.recentSearches';
  static const _storesKey = 'store.recentStores';

  final StoreRemoteDataSource _remote;
  final KeyValueStore _local;

  @override
  Future<Paged<StoreSummary>> searchStores(StoreSearchQuery query, {String? cursor}) =>
      _remote.searchStores(query, cursor);

  @override
  Future<StoreDetail> getStore(String storeId) => _remote.getStore(storeId);

  @override
  Future<List<ServiceItem>> getServices(String storeId, {bool activeOnly = true}) =>
      _remote.getServices(storeId, activeOnly);

  @override
  Future<List<StaffOption>> getServiceStaff(String storeId, String serviceId, {String? date}) =>
      _remote.getServiceStaff(storeId, serviceId, date);

  @override
  Future<List<AvailabilityDay>> getAvailability({
    required String storeId,
    required String serviceId,
    String? staffId,
    required DateTime from,
    required DateTime to,
    int partySize = 1,
  }) => _remote.getAvailability({
    'serviceId': serviceId,
    'staffId': staffId,
    'from': formatYmd(from),
    'to': formatYmd(to),
    'partySize': partySize,
  }, storeId);

  @override
  Future<WalkInAvailability> getWalkInAvailability(String storeId, {String? serviceId, String? staffId}) =>
      _remote.getWalkInAvailability(storeId, serviceId, staffId);

  @override
  List<String> recentSearches() => _local.getStringList(_searchesKey);

  @override
  Future<void> saveRecentSearches(List<String> searches) => _local.setStringList(_searchesKey, searches);

  @override
  List<RecentStore> recentStores() => asJsonList(_local.getJson(_storesKey)).map(recentStoreFromJson).toList();

  @override
  Future<void> saveRecentStores(List<RecentStore> stores) =>
      _local.setJson(_storesKey, stores.map(recentStoreToJson).toList());
}

import '../../../core/domain/paged.dart';
import 'store_entities.dart';

abstract interface class StoreRepository {
  Future<Paged<StoreSummary>> searchStores(StoreSearchQuery query, {String? cursor});

  Future<StoreDetail> getStore(String storeId);

  Future<List<ServiceItem>> getServices(String storeId, {bool activeOnly = true});

  Future<List<StaffOption>> getServiceStaff(String storeId, String serviceId, {String? date});

  Future<List<AvailabilityDay>> getAvailability({
    required String storeId,
    required String serviceId,
    String? staffId,
    required DateTime from,
    required DateTime to,
    int partySize = 1,
  });

  Future<WalkInAvailability> getWalkInAvailability(String storeId, {String? serviceId, String? staffId});

  List<String> recentSearches();

  Future<void> saveRecentSearches(List<String> searches);

  List<RecentStore> recentStores();

  Future<void> saveRecentStores(List<RecentStore> stores);
}

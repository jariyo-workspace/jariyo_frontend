import '../../../core/domain/paged.dart';
import '../../../core/utils/date_time_format.dart';
import 'store_entities.dart';
import 'store_repository.dart';

/// 매장 검색. 서버가 지원하지 않는 필터도 응답 필드가 있으면 클라이언트에서 한 번 더 거른다.
class SearchStores {
  const SearchStores(this._repository);

  final StoreRepository _repository;

  Future<Paged<StoreSummary>> call(StoreSearchQuery query, {String? cursor}) async {
    final page = await _repository.searchStores(query, cursor: cursor);
    final keyword = query.query.trim().toLowerCase();
    final today = storeToday();
    final items = page.items.where((store) {
      if (keyword.isNotEmpty) {
        final haystack = '${store.name} ${store.address} ${store.description} ${store.category ?? ''}'.toLowerCase();
        if (!haystack.contains(keyword)) return false;
      }
      if (query.category != null && store.category != null && store.category != query.category) return false;
      if (query.openNow && store.openNow == false) return false;
      if (query.availableToday && store.nextAvailableAt != null) {
        final local = toStoreTime(store.nextAvailableAt!);
        if (DateTime.utc(local.year, local.month, local.day) != today) return false;
      }
      return true;
    }).toList();
    return Paged(items: items, cursor: page.cursor, hasNext: page.hasNext);
  }
}

class GetStoreDetail {
  const GetStoreDetail(this._repository);

  final StoreRepository _repository;

  Future<StoreDetail> call(String storeId) => _repository.getStore(storeId);
}

class GetStoreServices {
  const GetStoreServices(this._repository);

  final StoreRepository _repository;

  Future<List<ServiceItem>> call(String storeId, {bool activeOnly = true}) =>
      _repository.getServices(storeId, activeOnly: activeOnly);
}

class GetServiceStaff {
  const GetServiceStaff(this._repository);

  final StoreRepository _repository;

  Future<List<StaffOption>> call(String storeId, String serviceId) => _repository.getServiceStaff(storeId, serviceId);
}

class GetAvailability {
  const GetAvailability(this._repository);

  final StoreRepository _repository;

  Future<List<AvailabilityDay>> call({
    required String storeId,
    required String serviceId,
    String? staffId,
    required DateTime from,
    required DateTime to,
    int partySize = 1,
  }) => _repository.getAvailability(
    storeId: storeId,
    serviceId: serviceId,
    staffId: staffId,
    from: from,
    to: to,
    partySize: partySize,
  );
}

class GetWalkInAvailability {
  const GetWalkInAvailability(this._repository);

  final StoreRepository _repository;

  Future<WalkInAvailability> call(String storeId, {String? serviceId, String? staffId}) =>
      _repository.getWalkInAvailability(storeId, serviceId: serviceId, staffId: staffId);
}

/// 최근 검색어 (최대 10개, 최신순)
class RecentSearches {
  const RecentSearches(this._repository);

  static const _limit = 10;
  final StoreRepository _repository;

  List<String> get() => _repository.recentSearches();

  Future<void> add(String keyword) async {
    final value = keyword.trim();
    if (value.isEmpty) return;
    final next = [value, ..._repository.recentSearches().where((k) => k != value)].take(_limit).toList();
    await _repository.saveRecentSearches(next);
  }

  Future<void> remove(String keyword) =>
      _repository.saveRecentSearches(_repository.recentSearches().where((k) => k != keyword).toList());

  Future<void> clear() => _repository.saveRecentSearches(const []);
}

/// 최근 본 매장 (최대 10개, 최신순)
class RecentStores {
  const RecentStores(this._repository);

  static const _limit = 10;
  final StoreRepository _repository;

  List<RecentStore> get() => _repository.recentStores();

  Future<void> remember({required String id, required String name, String? address, String? serviceName}) async {
    final previous = _repository.recentStores().where((s) => s.id == id).firstOrNull;
    final entry = RecentStore(
      id: id,
      name: name,
      address: address ?? previous?.address,
      lastServiceName: serviceName ?? previous?.lastServiceName,
      viewedAt: DateTime.now(),
    );
    final next = [entry, ..._repository.recentStores().where((s) => s.id != id)].take(_limit).toList();
    await _repository.saveRecentStores(next);
  }
}

/// 실시간 예약 필터. 매장마다 서비스별 가능 시간을 조회해 조건 안의 가장 빠른 시간을 찾는다.
///
/// 목록 API가 가능 시간 필터를 지원하지 않으므로, 검색 결과 매장에 한해 클라이언트에서 확인한다.
class FindAvailableTimes {
  const FindAvailableTimes(this._repository);

  static const _servicesPerStore = 3;
  final StoreRepository _repository;

  Future<Map<String, AvailabilityMatch>> call(List<StoreSummary> stores, AvailabilityFilter filter) async {
    final entries = await Future.wait(stores.map((store) async => MapEntry(store.id, await _earliest(store.id, filter))));
    return {
      for (final entry in entries)
        if (entry.value != null) entry.key: entry.value!,
    };
  }

  Future<AvailabilityMatch?> _earliest(String storeId, AvailabilityFilter filter) async {
    final List<ServiceItem> services;
    try {
      services = (await _repository.getServices(storeId)).where((s) => s.isBookable).take(_servicesPerStore).toList();
    } on Exception {
      return null;
    }
    final now = DateTime.now();
    final matches = await Future.wait(
      services.map((service) async {
        try {
          final days = await _repository.getAvailability(
            storeId: storeId,
            serviceId: service.id,
            from: filter.date,
            to: filter.date,
            partySize: filter.partySize,
          );
          final slot = days
              .expand((d) => d.slots)
              .where(
                (s) {
                  final local = toStoreTime(s.startAt);
                  return s.status == SlotStatus.available &&
                      s.startAt.isAfter(now) &&
                      DateTime.utc(local.year, local.month, local.day) == filter.date &&
                      filter.dayPart.contains(local);
                },
              )
              .fold<TimeSlot?>(null, (best, s) => best == null || s.startAt.isBefore(best.startAt) ? s : best);
          return slot == null
              ? null
              : AvailabilityMatch(startAt: slot.startAt, serviceName: service.name, serviceId: service.id);
        } on Exception {
          return null;
        }
      }),
    );
    return matches
        .whereType<AvailabilityMatch>()
        .fold<AvailabilityMatch?>(null, (best, m) => best == null || m.startAt.isBefore(best.startAt) ? m : best);
  }
}

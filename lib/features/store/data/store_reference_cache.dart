import '../../../core/error/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';

/// 목록 응답이 ID만 줄 때 매장·서비스 이름을 채우기 위한 조회 캐시.
class StoreReferenceCache {
  StoreReferenceCache(this._api);

  final ApiClient _api;
  final _storeNames = <String, Future<String?>>{};
  final _serviceNames = <String, Future<Map<String, String>>>{};

  Future<String?> storeName(String storeId) => _storeNames.putIfAbsent(storeId, () async {
    try {
      return strOrNull((await _api.get('/stores/$storeId', auth: false)).json['name']);
    } on AppFailure {
      _storeNames.remove(storeId);
      return null;
    }
  });

  Future<String?> serviceName(String storeId, String serviceId) async {
    final names = await _serviceNames.putIfAbsent(storeId, () async {
      try {
        final list = (await _api.get('/stores/$storeId/services', auth: false, query: {'activeOnly': false})).list;
        return {for (final s in list) str(s['id']): str(s['name'])};
      } on AppFailure {
        _serviceNames.remove(storeId);
        return const <String, String>{};
      }
    });
    return names[serviceId];
  }
}

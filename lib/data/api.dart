import 'api_client.dart';
import 'models.dart';

List<Map<String, dynamic>> _items(dynamic data) =>
    data is List ? data.whereType<Map<String, dynamic>>().toList() : const [];

Map<String, dynamic> _obj(dynamic data) => data is Map<String, dynamic> ? data : const {};

/// 앱에서 사용하는 엔드포인트.
class Api {
  static Future<void> signIn(String email, String password) async {
    final r = await ApiClient.post('/auth/sign-in', body: {'email': email, 'password': password});
    final token = _obj(r.data)['accessToken']?.toString();
    if (token == null) throw NetworkException();
    Session.accessToken = token;
    Session.saveRefreshFromHeaders(r.headers);
  }

  /// 결과와 관계없이 로컬 세션은 호출부에서 지운다.
  static Future<void> signOut(String? refreshToken) async {
    if (refreshToken == null) return;
    try {
      await ApiClient.post('/auth/sign-out', cookie: 'jariyo_refresh=$refreshToken');
    } catch (_) {}
  }

  static Future<List<StoreSummary>> stores() async {
    final r = await ApiClient.get('/stores');
    return _items(r.data).map(StoreSummary.fromJson).toList();
  }

  static Future<StoreDetail> store(String storeId) async {
    final r = await ApiClient.get('/stores/$storeId');
    return StoreDetail.fromJson(_obj(r.data));
  }

  static Future<List<ServiceItem>> services(String storeId) async {
    final r = await ApiClient.get('/stores/$storeId/services', query: {'activeOnly': 'false'});
    return _items(r.data).map(ServiceItem.fromJson).toList();
  }

  static Future<List<StaffItem>> staff(String storeId, String serviceId) async {
    final r = await ApiClient.get('/stores/$storeId/services/$serviceId/staff');
    return _items(r.data).map(StaffItem.fromJson).toList();
  }

  static Future<List<Slot>> availability(String storeId, String serviceId, String date, String? staffId) async {
    final r = await ApiClient.get('/stores/$storeId/availability', query: {
      'serviceId': serviceId,
      'from': date,
      'to': date,
      'partySize': '1',
      'staffId': ?staffId,
    });
    return [
      for (final d in _items(_obj(r.data)['dates'])) ..._items(d['slots']).map(Slot.fromJson),
    ];
  }

  static Future<String> createReservation({
    required String idempotencyKey,
    required String storeId,
    required String serviceId,
    required String staffId,
    required String startAt,
    required String? customerNote,
  }) async {
    final r = await ApiClient.post(
      '/reservations',
      auth: true,
      idempotencyKey: idempotencyKey,
      body: {
        'storeId': storeId,
        'serviceId': serviceId,
        'staffId': staffId,
        'startAt': startAt,
        'partySize': 1,
        'customerNote': customerNote,
      },
    );
    return _obj(r.data)['id'].toString();
  }

  static Future<ReservationPage> myReservations({String? status, String? cursor}) async {
    final r = await ApiClient.get('/me/reservations', auth: true, query: {
      'limit': '10',
      'status': ?status,
      'cursor': ?cursor,
    });
    final page = r.page ?? const {};
    return ReservationPage(
      _items(r.data).map(ReservationSummary.fromJson).toList(),
      page['cursor']?.toString(),
      page['hasNext'] == true,
    );
  }

  static Future<ReservationDetail> reservation(String id) async {
    final r = await ApiClient.get('/reservations/$id', auth: true);
    return ReservationDetail.fromJson(_obj(r.data));
  }

  static Future<List<HistoryItem>> history(String id) async {
    final r = await ApiClient.get('/reservations/$id/history', auth: true);
    return _items(r.data).map(HistoryItem.fromJson).toList();
  }

  static Future<void> cancelReservation(String id, String reason, String idempotencyKey) async {
    await ApiClient.post('/reservations/$id/cancel',
        auth: true, idempotencyKey: idempotencyKey, body: {'reason': reason});
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';

/// 서버 오류 응답(4xx). 5xx·네트워크 실패·타임아웃은 [NetworkException].
class ApiException implements Exception {
  final int status;
  final String code;
  final String message;

  ApiException(this.status, this.code, this.message);

  @override
  String toString() => 'ApiException($status, $code, $message)';
}

class NetworkException implements Exception {}

/// 세션이 끝나 로그인으로 이동한 경우. 호출부는 아무것도 하지 않는다.
class SessionExpiredException implements Exception {}

class ApiResponse {
  final dynamic data;
  final Map<String, dynamic>? page;
  final Map<String, String> headers;

  ApiResponse(this.data, this.page, this.headers);
}

/// 메모리에만 보관하는 세션. 앱은 항상 로그인에서 시작한다.
class Session {
  static String? accessToken;
  static String? refreshToken;

  static bool get isSignedIn => accessToken != null;

  static void clear() {
    accessToken = null;
    refreshToken = null;
  }

  static void saveRefreshFromHeaders(Map<String, String> headers) {
    final setCookie = headers['set-cookie'] ?? '';
    final match = RegExp(r'jariyo_refresh=([^;,\s]+)').firstMatch(setCookie);
    if (match != null) refreshToken = match.group(1);
  }
}

class ApiClient {
  static final http.Client _http = http.Client();

  /// 세션 만료 시 호출된다(로그인 화면으로 이동).
  static void Function()? onSessionExpired;

  static Future<bool>? _refreshing;

  static Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    return query == null || query.isEmpty ? uri : uri.replace(queryParameters: query);
  }

  static Future<ApiResponse> get(String path, {Map<String, String>? query, bool auth = false}) =>
      _send('GET', path, query: query, auth: auth);

  static Future<ApiResponse> post(
    String path, {
    Object? body,
    bool auth = false,
    String? idempotencyKey,
    String? cookie,
  }) =>
      _send('POST', path, body: body, auth: auth, idempotencyKey: idempotencyKey, cookie: cookie);

  static Future<ApiResponse> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool auth = false,
    String? idempotencyKey,
    String? cookie,
    bool retried = false,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (idempotencyKey != null) headers['Idempotency-Key'] = idempotencyKey;
    if (cookie != null) headers['Cookie'] = cookie;
    final usedToken = Session.accessToken;
    if (auth) {
      if (usedToken == null) throw _expire();
      headers['Authorization'] = 'Bearer $usedToken';
    }

    final response = await _raw(method, _uri(path, query), headers, body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _parseSuccess(response);
    }
    final error = _parseError(response);

    if (auth && response.statusCode == 401) {
      final refreshable = error.code == 'ACCESS_TOKEN_EXPIRED' || error.code == 'INVALID_ACCESS_TOKEN';
      if (refreshable && !retried) {
        // 다른 요청이 이미 토큰을 갱신했다면 재발급 없이 다시 보낸다.
        final ok = Session.accessToken != null && Session.accessToken != usedToken ? true : await _refresh();
        if (!ok) throw _expire();
        return _send(method, path,
            query: query, body: body, auth: auth, idempotencyKey: idempotencyKey, cookie: cookie, retried: true);
      }
      throw _expire();
    }
    throw error;
  }

  static Future<http.Response> _raw(
    String method,
    Uri uri,
    Map<String, String> headers,
    Object? body,
  ) async {
    try {
      final future = method == 'GET'
          ? _http.get(uri, headers: headers)
          : _http.post(uri, headers: headers, body: body == null ? null : jsonEncode(body));
      final response = await future.timeout(AppConfig.requestTimeout);
      if (response.statusCode >= 500) throw NetworkException();
      return response;
    } on NetworkException {
      rethrow;
    } catch (_) {
      throw NetworkException();
    }
  }

  static ApiResponse _parseSuccess(http.Response response) {
    if (response.bodyBytes.isEmpty) return ApiResponse(null, null, response.headers);
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is Map<String, dynamic>) {
        final page = json['page'];
        return ApiResponse(json['data'], page is Map<String, dynamic> ? page : null, response.headers);
      }
      return ApiResponse(json, null, response.headers);
    } catch (_) {
      return ApiResponse(null, null, response.headers);
    }
  }

  static ApiException _parseError(http.Response response) {
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      final error = json is Map<String, dynamic> ? json['error'] : null;
      if (error is Map<String, dynamic>) {
        return ApiException(
          response.statusCode,
          (error['code'] ?? 'UNKNOWN').toString(),
          (error['message'] ?? '').toString(),
        );
      }
    } catch (_) {}
    return ApiException(response.statusCode, 'UNKNOWN', '');
  }

  /// 재발급은 동시에 1건만 보낸다.
  static Future<bool> _refresh() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  static Future<bool> _doRefresh() async {
    final refresh = Session.refreshToken;
    if (refresh == null) return false;
    try {
      final response = await _raw(
        'POST',
        _uri('/auth/refresh'),
        {'Accept': 'application/json', 'Cookie': 'jariyo_refresh=$refresh'},
        null,
      );
      if (response.statusCode != 200) return false;
      final parsed = _parseSuccess(response);
      final token = parsed.data is Map ? parsed.data['accessToken'] as String? : null;
      if (token == null) return false;
      Session.accessToken = token;
      Session.saveRefreshFromHeaders(response.headers);
      return true;
    } catch (_) {
      return false;
    }
  }

  static SessionExpiredException _expire() {
    final wasSignedIn = Session.accessToken != null || Session.refreshToken != null;
    Session.clear();
    if (wasSignedIn) onSessionExpired?.call();
    return SessionExpiredException();
  }
}

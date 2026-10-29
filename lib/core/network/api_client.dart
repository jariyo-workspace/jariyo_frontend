import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../error/app_failure.dart';
import '../storage/token_storage.dart';
import 'json.dart';

class PageInfo {
  const PageInfo({this.cursor, this.hasNext = false});

  factory PageInfo.fromJson(Json json) =>
      PageInfo(cursor: strOrNull(json['cursor']), hasNext: boolOf(json['hasNext']));

  final String? cursor;
  final bool hasNext;
}

/// 성공 응답의 `data`와 `page`.
class ApiResult {
  const ApiResult(this.data, {this.page});

  final Object? data;
  final PageInfo? page;

  Json get json => asJson(data);
  List<Json> get list => asJsonList(data);
}

/// 자리요 REST API 호출 규칙(공통 응답 구조, 인증, 멱등성, 토큰 재발급)을 한곳에서 처리한다.
class ApiClient {
  ApiClient({
    required http.Client httpClient,
    required this._baseUrl,
    required this._tokens,
    this._timeout = const Duration(seconds: 15),
  }) : _http = httpClient;

  static const refreshCookieName = 'jariyo_refresh';
  static const _refreshableCodes = {
    'ACCESS_TOKEN_EXPIRED',
    'INVALID_ACCESS_TOKEN',
    'AUTHENTICATION_REQUIRED',
    'AUTH-401',
  };

  final http.Client _http;
  final String _baseUrl;
  final TokenStorage _tokens;
  final Duration _timeout;
  Completer<_RefreshOutcome>? _refreshing;

  /// 재발급까지 실패해 세션이 끝났을 때 호출된다.
  void Function()? onSessionExpired;

  String get baseUrl => _baseUrl;
  TokenStorage get tokens => _tokens;

  Future<ApiResult> get(String path, {Map<String, Object?>? query, bool auth = true}) =>
      _send('GET', path, query: query, auth: auth);

  Future<ApiResult> post(
    String path, {
    Object? body,
    String? idempotencyKey,
    bool auth = true,
    bool withRefreshCookie = false,
  }) => _send(
    'POST',
    path,
    body: body,
    idempotencyKey: idempotencyKey,
    auth: auth,
    withRefreshCookie: withRefreshCookie,
  );

  Future<ApiResult> put(String path, {Object? body, String? idempotencyKey}) =>
      _send('PUT', path, body: body, idempotencyKey: idempotencyKey);

  Future<ApiResult> delete(String path, {String? idempotencyKey}) =>
      _send('DELETE', path, idempotencyKey: idempotencyKey);

  Uri uri(String path, [Map<String, Object?>? query]) {
    final base = Uri.parse('$_baseUrl$path');
    final params = cleanQuery(query);
    return params == null ? base : base.replace(queryParameters: params);
  }

  /// 인증 헤더를 포함한 공통 헤더. 실시간 스트림처럼 직접 요청을 만드는 곳에서 사용한다.
  Map<String, String> authHeaders() => {
    if (_tokens.accessToken != null) 'Authorization': 'Bearer ${_tokens.accessToken}',
  };

  Future<ApiResult> _send(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    String? idempotencyKey,
    bool auth = true,
    bool withRefreshCookie = false,
    bool retried = false,
  }) async {
    final request = http.Request(method, uri(path, query));
    request.headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    if (auth) request.headers.addAll(authHeaders());
    if (idempotencyKey != null) request.headers['Idempotency-Key'] = idempotencyKey;
    if (withRefreshCookie && _tokens.refreshToken != null) {
      request.headers['Cookie'] = '$refreshCookieName=${_tokens.refreshToken}';
    }

    final http.Response response;
    try {
      response = await _execute(request);
    } catch (_) {
      // 쓰기 요청은 서버가 처리했는지 알 수 없으므로 새 요청을 바로 만들지 않도록 구분한다.
      throw method == 'GET' ? const AppFailure.network() : const AppFailure.unknownOutcome();
    }

    await _captureRefreshCookie(response);
    final decoded = _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final envelope = asJson(decoded);
      final page = envelope['page'] is Map ? PageInfo.fromJson(asJson(envelope['page'])) : null;
      return ApiResult(envelope['data'], page: page);
    }

    final failure = AppFailure.fromResponse(response.statusCode, decoded);
    final hadSession = auth && _tokens.accessToken != null;
    if (response.statusCode == 401 && hadSession) {
      if (!retried && _tokens.refreshToken != null && _refreshableCodes.contains(failure.code)) {
        final outcome = await _refreshOnce();
        switch (outcome) {
          case _RefreshOutcome.refreshed:
            return _send(
              method,
              path,
              query: query,
              body: body,
              idempotencyKey: idempotencyKey,
              auth: auth,
              withRefreshCookie: withRefreshCookie,
              retried: true,
            );
          case _RefreshOutcome.unreachable:
            throw method == 'GET' ? const AppFailure.network() : const AppFailure.unknownOutcome();
          case _RefreshOutcome.rejected:
            break;
        }
      }
      await _expireSession();
      throw const AppFailure.sessionExpired();
    }
    throw failure;
  }

  Future<http.Response> _execute(http.BaseRequest request) async {
    final streamed = await _http.send(request).timeout(_timeout);
    return http.Response.fromStream(streamed).timeout(_timeout);
  }

  Object? _decode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  Future<void> _captureRefreshCookie(http.Response response) async {
    final header = response.headers['set-cookie'];
    if (header == null) return;
    final match = RegExp('$refreshCookieName=([^;,\\s]*)').firstMatch(header);
    final value = match?.group(1);
    if (value != null && value.isNotEmpty) await _tokens.saveRefreshToken(value);
  }

  /// 동시에 여러 요청이 만료되어도 재발급은 한 번만 수행한다.
  Future<_RefreshOutcome> _refreshOnce() {
    final pending = _refreshing;
    if (pending != null) return pending.future;
    final completer = Completer<_RefreshOutcome>();
    _refreshing = completer;
    _refresh()
        .then(completer.complete, onError: (_) => completer.complete(_RefreshOutcome.rejected))
        .whenComplete(() => _refreshing = null);
    return completer.future;
  }

  Future<_RefreshOutcome> _refresh() async {
    final refreshToken = _tokens.refreshToken;
    if (refreshToken == null) return _RefreshOutcome.rejected;
    final request = http.Request('POST', uri('/auth/refresh'))
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Cookie': '$refreshCookieName=$refreshToken',
      })
      ..body = jsonEncode({'refreshToken': refreshToken});

    final http.Response response;
    try {
      response = await _execute(request);
    } catch (_) {
      return _RefreshOutcome.unreachable;
    }
    if (response.statusCode >= 500) return _RefreshOutcome.unreachable;
    if (response.statusCode < 200 || response.statusCode >= 300) return _RefreshOutcome.rejected;

    await _captureRefreshCookie(response);
    final data = asJson(asJson(_decode(response.body))['data']);
    final accessToken = strOrNull(data['accessToken']);
    if (accessToken == null) return _RefreshOutcome.rejected;
    final rotated = strOrNull(data['refreshToken']);
    if (rotated != null) await _tokens.saveRefreshToken(rotated);
    await _tokens.saveAccessToken(accessToken);
    return _RefreshOutcome.refreshed;
  }

  Future<void> _expireSession() async {
    await _tokens.clear();
    onSessionExpired?.call();
  }
}

enum _RefreshOutcome { refreshed, rejected, unreachable }

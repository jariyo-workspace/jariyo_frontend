import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jariyo_frontend/core/error/app_failure.dart';
import 'package:jariyo_frontend/core/network/api_client.dart';
import 'package:jariyo_frontend/core/storage/key_value_store.dart';
import 'package:jariyo_frontend/core/storage/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(int status, Object body, {Map<String, String> headers = const {}}) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8', ...headers});

Future<TokenStorage> _tokens({String? access, String? refresh}) async {
  SharedPreferences.setMockInitialValues({
    'auth.accessToken': ?access,
    'auth.refreshToken': ?refresh,
  });
  return TokenStorage(KeyValueStore(await SharedPreferences.getInstance()));
}

void main() {
  test('성공 응답의 data와 page를 꺼낸다', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'http://api/v1/me/reservations?limit=20');
      expect(request.headers['Authorization'], 'Bearer a1');
      return _json(200, {
        'success': true,
        'data': [
          {'id': 'r1'},
        ],
        'page': {'cursor': 'c2', 'hasNext': true},
      });
    });
    final api = ApiClient(httpClient: client, baseUrl: 'http://api/v1', tokens: await _tokens(access: 'a1'));

    final result = await api.get('/me/reservations', query: {'limit': 20, 'cursor': null});

    expect(result.list.single['id'], 'r1');
    expect(result.page?.cursor, 'c2');
    expect(result.page?.hasNext, isTrue);
  });

  test('오류 응답은 서버 code와 message를 그대로 전달한다', () async {
    final client = MockClient(
      (_) async => _json(409, {
        'success': false,
        'error': {'code': 'RESERVATION_SLOT_ALREADY_TAKEN', 'message': '이미 다른 예약이 해당 시간을 선점했습니다.'},
      }),
    );
    final api = ApiClient(httpClient: client, baseUrl: 'http://api/v1', tokens: await _tokens(access: 'a1'));

    await expectLater(
      api.post('/reservations', body: {}, idempotencyKey: 'k'),
      throwsA(
        isA<AppFailure>()
            .having((f) => f.code, 'code', 'RESERVATION_SLOT_ALREADY_TAKEN')
            .having((f) => f.kind, 'kind', FailureKind.conflict),
      ),
    );
  });

  test('Access Token이 만료되면 쿠키로 재발급한 뒤 같은 멱등성 키로 원래 요청을 재시도한다', () async {
    final seenKeys = <String?>[];
    var calls = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        expect(request.headers['Cookie'], 'jariyo_refresh=r1');
        return _json(
          200,
          {
            'data': {'accessToken': 'a2', 'expiresIn': 3600},
          },
          headers: {'set-cookie': 'jariyo_refresh=r2; Path=/api/v1/auth; HttpOnly'},
        );
      }
      calls++;
      seenKeys.add(request.headers['Idempotency-Key']);
      if (request.headers['Authorization'] == 'Bearer a1') {
        return _json(401, {
          'error': {'code': 'ACCESS_TOKEN_EXPIRED', 'message': '만료'},
        });
      }
      return _json(201, {
        'data': {'id': 'res_1'},
      });
    });
    final tokens = await _tokens(access: 'a1', refresh: 'r1');
    final api = ApiClient(httpClient: client, baseUrl: 'http://api/v1', tokens: tokens);

    final result = await api.post('/reservations', body: {'a': 1}, idempotencyKey: 'key-1');

    expect(result.json['id'], 'res_1');
    expect(calls, 2);
    expect(seenKeys, ['key-1', 'key-1']);
    expect(tokens.accessToken, 'a2');
    expect(tokens.refreshToken, 'r2', reason: '재발급 시 회전된 Refresh Token을 저장해야 한다');
  });

  test('재발급이 거절되면 세션을 정리하고 만료를 알린다', () async {
    var expired = false;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        return _json(401, {
          'error': {'code': 'REFRESH_TOKEN_EXPIRED', 'message': '만료'},
        });
      }
      return _json(401, {
        'error': {'code': 'ACCESS_TOKEN_EXPIRED', 'message': '만료'},
      });
    });
    final tokens = await _tokens(access: 'a1', refresh: 'r1');
    final api = ApiClient(httpClient: client, baseUrl: 'http://api/v1', tokens: tokens)
      ..onSessionExpired = () => expired = true;

    await expectLater(
      api.get('/me'),
      throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.sessionExpired)),
    );
    expect(expired, isTrue);
    expect(tokens.hasSession, isFalse);
  });

  test('쓰기 요청이 전송 중 실패하면 결과 불명확으로 구분한다', () async {
    final client = MockClient((_) async => throw http.ClientException('connection reset'));
    final api = ApiClient(httpClient: client, baseUrl: 'http://api/v1', tokens: await _tokens(access: 'a1'));

    await expectLater(
      api.post('/reservations', body: {}, idempotencyKey: 'k'),
      throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.unknownOutcome)),
    );
    await expectLater(
      api.get('/stores'),
      throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.network)),
    );
  });

  test('5xx는 현재 정보가 유지된다는 일시 장애 문구로 바꾼다', () async {
    final client = MockClient(
      (_) async => _json(500, {
        'error': {'code': 'COMMON-500', 'message': '서버 오류가 발생했습니다.'},
      }),
    );
    final api = ApiClient(httpClient: client, baseUrl: 'http://api/v1', tokens: await _tokens());

    await expectLater(
      api.get('/stores', auth: false),
      throwsA(isA<AppFailure>().having((f) => f.message, 'message', AppFailure.serverMessage)),
    );
  });
}

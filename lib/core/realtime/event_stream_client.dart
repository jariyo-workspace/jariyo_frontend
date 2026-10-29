import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../network/api_client.dart';
import '../network/json.dart';
import 'refresh_bus.dart';

class ServerEvent {
  const ServerEvent({required this.type, required this.data, this.id});

  final String type;
  final String? id;
  final Json data;
}

/// Server-Sent Events 구독.
///
/// 실시간 이벤트는 "다시 조회하라"는 신호로만 사용한다. 연결이 끊기면 지수 백오프로 재연결하고,
/// 그동안 각 화면은 주기적 재조회로 핵심 기능을 유지한다.
class RealtimeConnection {
  RealtimeConnection({required this._api, required this._path, required this._onEvent, this._onReconnected});

  final ApiClient _api;
  final String _path;
  final void Function(ServerEvent event) _onEvent;
  final void Function()? _onReconnected;

  http.Client? _client;
  StreamSubscription<String>? _subscription;
  Timer? _retryTimer;
  int _failures = 0;
  bool _closed = false;

  void open() {
    _closed = false;
    _connect();
  }

  Future<void> _connect() async {
    if (_closed) return;
    final client = http.Client();
    _client = client;
    final request = http.Request('GET', _api.uri(_path))
      ..headers.addAll({'Accept': 'text/event-stream', 'Cache-Control': 'no-cache', ..._api.authHeaders()});
    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        await response.stream.drain<void>();
        throw StateError('stream status ${response.statusCode}');
      }
      if (_failures > 0) _onReconnected?.call();
      _failures = 0;
      var eventType = 'message';
      String? eventId;
      final buffer = StringBuffer();
      _subscription = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (line.isEmpty) {
                if (buffer.isNotEmpty) _dispatch(eventType, eventId, buffer.toString());
                eventType = 'message';
                eventId = null;
                buffer.clear();
              } else if (line.startsWith('event:')) {
                eventType = line.substring(6).trim();
              } else if (line.startsWith('id:')) {
                eventId = line.substring(3).trim();
              } else if (line.startsWith('data:')) {
                if (buffer.isNotEmpty) buffer.write('\n');
                buffer.write(line.substring(5).trimLeft());
              }
            },
            onError: (_) => _scheduleRetry(),
            onDone: _scheduleRetry,
            cancelOnError: true,
          );
    } catch (_) {
      _scheduleRetry();
    }
  }

  void _dispatch(String eventType, String? eventId, String payload) {
    Json json = {};
    try {
      json = asJson(jsonDecode(payload));
    } on FormatException {
      json = {};
    }
    final type = strOrNull(json['type']) ?? eventType;
    _onEvent(ServerEvent(type: type, id: strOrNull(json['eventId']) ?? eventId, data: asJson(json['data'])));
  }

  void _scheduleRetry() {
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
    if (_closed) return;
    _failures++;
    final seconds = (5 * (1 << (_failures - 1).clamp(0, 6))).clamp(5, 300);
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: seconds), _connect);
  }

  void close() {
    _closed = true;
    _retryTimer?.cancel();
    _subscription?.cancel();
    _client?.close();
    _client = null;
  }
}

/// 이벤트 종류를 화면 무효화 주제로 옮긴다.
Set<RefreshTopic> topicsForEvent(String type) => switch (type) {
  'RESERVATION_UPDATED' => {RefreshTopic.reservationDetail, RefreshTopic.myReservations, RefreshTopic.home},
  'WAITLIST_UPDATED' => RefreshBus.afterWaitlistChanged,
  'SLOT_OFFER_CREATED' || 'SLOT_OFFER_EXPIRED' => {
    RefreshTopic.slotOffers,
    RefreshTopic.waitlists,
    RefreshTopic.home,
    RefreshTopic.notifications,
  },
  'WALK_IN_UPDATED' || 'WALK_IN_CALLED' => {RefreshTopic.walkIns, RefreshTopic.home, RefreshTopic.adminWalkIns},
  'NOTIFICATION_CREATED' => {RefreshTopic.notifications},
  'RESERVATION_CREATED' || 'RESERVATION_CANCELLED' || 'CUSTOMER_CHECKED_IN' => {
    RefreshTopic.adminReservations,
    RefreshTopic.adminDashboard,
  },
  'WALK_IN_CREATED' => {RefreshTopic.adminWalkIns, RefreshTopic.adminDashboard},
  'SERVICE_STARTED' || 'SERVICE_COMPLETED' => RefreshBus.afterServiceSessionChanged,
  'FAILED_JOB_CREATED' => {RefreshTopic.adminFailedJobs, RefreshTopic.adminDashboard},
  _ => const {},
};

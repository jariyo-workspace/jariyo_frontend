import '../network/api_client.dart';
import 'event_stream_client.dart';
import 'refresh_bus.dart';

/// 고객·운영자 이벤트 스트림을 관리한다.
class RealtimeService {
  RealtimeService({required this._api, required this._bus});

  final ApiClient _api;
  final RefreshBus _bus;
  RealtimeConnection? _customer;
  RealtimeConnection? _operator;
  String? _operatorStoreId;

  /// 즉시 주의가 필요한 이벤트(호출, 빈자리 제안)를 앱 계층에 전달한다.
  void Function(ServerEvent event)? onAttention;

  void connectCustomer() {
    _customer?.close();
    _customer = RealtimeConnection(
      api: _api,
      path: '/me/events/stream',
      onEvent: _handle,
      onReconnected: () => _bus.emit(RefreshTopic.values.toSet()),
    )..open();
  }

  void connectOperator(String storeId) {
    if (_operatorStoreId == storeId && _operator != null) return;
    _operator?.close();
    _operatorStoreId = storeId;
    _operator = RealtimeConnection(
      api: _api,
      path: '/admin/stores/$storeId/events/stream',
      onEvent: _handle,
      onReconnected: () => _bus.emit(RefreshTopic.values.toSet()),
    )..open();
  }

  void disconnectOperator() {
    _operator?.close();
    _operator = null;
    _operatorStoreId = null;
  }

  void disconnectAll() {
    _customer?.close();
    _customer = null;
    disconnectOperator();
  }

  void _handle(ServerEvent event) {
    _bus.emit(topicsForEvent(event.type));
    if (event.type == 'WALK_IN_CALLED' || event.type == 'SLOT_OFFER_CREATED') {
      onAttention?.call(event);
    }
  }
}

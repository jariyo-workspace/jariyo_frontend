import '../../../core/domain/paged.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/common_mappers.dart';
import '../../../core/network/json.dart';
import '../domain/notification_entities.dart';
import '../domain/notification_repository.dart';

AppNotification _notificationFromJson(Json json) => AppNotification(
  id: str(json['id']),
  type: str(json['type']),
  title: str(json['title']),
  body: str(json['body']),
  referenceType: strOrNull(json['referenceType']),
  referenceId: strOrNull(json['referenceId']),
  read: boolOf(json['read']),
  createdAt: timeOf(json['createdAt']),
);

class NotificationRepositoryImpl implements NotificationRepository {
  const NotificationRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<Paged<AppNotification>> list({bool? read, String? cursor}) async => pagedFrom(
    await _api.get('/me/notifications', query: {'read': read, 'cursor': cursor, 'limit': 30}),
    _notificationFromJson,
  );

  @override
  Future<void> markRead(String notificationId) => _api.post('/notifications/$notificationId/read');

  @override
  Future<void> markAllRead() => _api.post('/me/notifications/read-all');

  @override
  Future<NotificationSettings> getSettings() async {
    final json = (await _api.get('/me/notification-settings')).json;
    return NotificationSettings(
      reservation: boolOf(json['reservationNotifications'], true),
      waitlist: boolOf(json['waitlistNotifications'], true),
      walkIn: boolOf(json['walkInNotifications'], true),
      marketing: boolOf(json['marketingNotifications']),
    );
  }

  @override
  Future<void> updateSettings(NotificationSettings settings) => _api.put(
    '/me/notification-settings',
    body: {
      'reservationNotifications': settings.reservation,
      'waitlistNotifications': settings.waitlist,
      'walkInNotifications': settings.walkIn,
      'marketingNotifications': settings.marketing,
    },
  );
}

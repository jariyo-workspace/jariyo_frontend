import '../../../core/domain/paged.dart';
import 'notification_entities.dart';

abstract interface class NotificationRepository {
  Future<Paged<AppNotification>> list({bool? read, String? cursor});

  Future<void> markRead(String notificationId);

  Future<void> markAllRead();

  Future<NotificationSettings> getSettings();

  Future<void> updateSettings(NotificationSettings settings);
}

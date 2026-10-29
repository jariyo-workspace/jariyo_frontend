import '../../../core/domain/paged.dart';
import 'notification_entities.dart';
import 'notification_repository.dart';

class GetNotifications {
  const GetNotifications(this._repository);

  final NotificationRepository _repository;

  Future<Paged<AppNotification>> call({bool? read, String? cursor}) => _repository.list(read: read, cursor: cursor);
}

class MarkNotificationRead {
  const MarkNotificationRead(this._repository);

  final NotificationRepository _repository;

  Future<void> call(String notificationId) => _repository.markRead(notificationId);
}

class MarkAllNotificationsRead {
  const MarkAllNotificationsRead(this._repository);

  final NotificationRepository _repository;

  Future<void> call() => _repository.markAllRead();
}

class GetNotificationSettings {
  const GetNotificationSettings(this._repository);

  final NotificationRepository _repository;

  Future<NotificationSettings> call() => _repository.getSettings();
}

class UpdateNotificationSettings {
  const UpdateNotificationSettings(this._repository);

  final NotificationRepository _repository;

  Future<void> call(NotificationSettings settings) => _repository.updateSettings(settings);
}

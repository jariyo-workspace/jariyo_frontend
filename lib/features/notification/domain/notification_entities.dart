class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    this.referenceType,
    this.referenceId,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String? referenceType;
  final String? referenceId;
  final bool read;
  final DateTime createdAt;

  /// 빈자리 제안과 현장 호출은 일반 알림보다 강하게 표시한다.
  bool get isImportant =>
      referenceType == 'SLOT_OFFER' || type.startsWith('SLOT_OFFER_CREATED') || type.startsWith('WALK_IN_CALLED');

  AppNotification markRead() => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    read: true,
    createdAt: createdAt,
    referenceType: referenceType,
    referenceId: referenceId,
  );
}

class NotificationSettings {
  const NotificationSettings({
    this.reservation = true,
    this.waitlist = true,
    this.walkIn = true,
    this.marketing = false,
  });

  final bool reservation;
  final bool waitlist;
  final bool walkIn;
  final bool marketing;

  NotificationSettings copyWith({bool? reservation, bool? waitlist, bool? walkIn, bool? marketing}) =>
      NotificationSettings(
        reservation: reservation ?? this.reservation,
        waitlist: waitlist ?? this.waitlist,
        walkIn: walkIn ?? this.walkIn,
        marketing: marketing ?? this.marketing,
      );
}

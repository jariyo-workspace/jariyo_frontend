import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/paged.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../../core/presentation/view_model.dart';
import '../../../core/realtime/refresh_bus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_time_format.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/view_model_scope.dart';
import '../../reservation/presentation/reservation_detail_screen.dart';
import '../../waitlist/presentation/slot_offer_screen.dart';
import '../../waitlist/presentation/waitlist_detail_screen.dart';
import '../../walk_in/presentation/walk_in_detail_screen.dart';
import '../domain/notification_entities.dart';
import '../domain/notification_repository.dart';
import '../domain/notification_usecases.dart';
import 'notification_settings_screen.dart';

class NotificationViewModel extends LoadableViewModel<Paged<AppNotification>> {
  NotificationViewModel(NotificationRepository repository, RefreshBus bus)
    : _list = GetNotifications(repository),
      _markRead = MarkNotificationRead(repository),
      _markAll = MarkAllNotificationsRead(repository) {
    listenTopics(bus, {RefreshTopic.notifications}, refresh);
  }

  final GetNotifications _list;
  final MarkNotificationRead _markRead;
  final MarkAllNotificationsRead _markAll;
  bool loadingMore = false;

  @override
  Future<Paged<AppNotification>> fetch() => _list();

  Future<void> loadMore() async {
    final current = data;
    if (current == null || !current.hasNext || loadingMore) return;
    loadingMore = true;
    notify();
    try {
      final next = await _list(cursor: current.cursor);
      data = Paged(items: [...current.items, ...next.items], cursor: next.cursor, hasNext: next.hasNext);
    } on AppFailure catch (failure) {
      AppMessenger.showFailure(failure);
    } finally {
      loadingMore = false;
      notify();
    }
  }

  void _replace(AppNotification updated) {
    final current = data;
    if (current == null) return;
    data = Paged(
      items: [for (final n in current.items) n.id == updated.id ? updated : n],
      cursor: current.cursor,
      hasNext: current.hasNext,
    );
    notify();
  }

  /// 읽음 처리는 화면 이동을 막지 않는 부분 갱신으로 처리한다.
  void markRead(AppNotification notification) {
    if (notification.read) return;
    _replace(notification.markRead());
    _markRead(notification.id).catchError((Object _) => _replace(notification));
  }

  Future<void> markAllRead() => runAction('readAll', () async {
    await _markAll();
    final current = data;
    if (current != null) {
      data = Paged(items: current.items.map((n) => n.markRead()).toList(), cursor: current.cursor, hasNext: current.hasNext);
    }
  });
}

/// C-19 알림함
class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  IconData _icon(AppNotification n) => switch (n.referenceType) {
    'RESERVATION' => Icons.event_available,
    'WAITLIST_ENTRY' => Icons.hourglass_empty,
    'SLOT_OFFER' => Icons.local_fire_department_outlined,
    'WALK_IN_ENTRY' => Icons.campaign_outlined,
    _ => Icons.notifications_none,
  };

  /// 이미 만료된 알림이어도 연결된 상세 화면에서 최신 상태를 보여준다.
  void _open(BuildContext context, NotificationViewModel vm, AppNotification n) {
    vm.markRead(n);
    final id = n.referenceId;
    if (id == null) return;
    final Widget? page = switch (n.referenceType) {
      'RESERVATION' => ReservationDetailScreen(reservationId: id),
      'WAITLIST_ENTRY' => WaitlistDetailScreen(waitlistId: id),
      'SLOT_OFFER' => SlotOfferScreen(offerId: id),
      'WALK_IN_ENTRY' => WalkInDetailScreen(walkInId: id),
      _ => null,
    };
    if (page != null) pushPage<void>(context, page);
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<NotificationViewModel>(
      create: () => NotificationViewModel(GetIt.I<NotificationRepository>(), GetIt.I<RefreshBus>()),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(
          title: const Text('알림'),
          actions: [
            TextButton(
              onPressed: vm.data == null || vm.isBusy('readAll') ? null : vm.markAllRead,
              child: const Text('모두 읽음'),
            ),
            IconButton(
              tooltip: '알림 설정',
              onPressed: () => pushPage<void>(context, const NotificationSettingsScreen()),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        body: LoadableBody<Paged<AppNotification>>(
          vm: vm,
          builder: (context, page) {
            if (page.items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  EmptyView(icon: Icons.notifications_none, title: '새 알림이 없어요.'),
                ],
              );
            }
            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.extentAfter < 300) vm.loadMore();
                return false;
              },
              child: ListView.separated(
                itemCount: page.items.length + (vm.loadingMore ? 1 : 0),
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index >= page.items.length) {
                    return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                  }
                  final n = page.items[index];
                  final strong = n.isImportant && !n.read;
                  return Semantics(
                    label: '${n.read ? '읽음' : '읽지 않음'}${n.isImportant ? ', 중요' : ''}',
                    child: Container(
                      color: strong
                          ? AppColors.attention.withAlpha(20)
                          : (n.read ? Colors.transparent : AppColors.primary.withAlpha(10)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: (strong ? AppColors.attention : AppColors.primary).withAlpha(30),
                          child: Icon(_icon(n), color: strong ? AppColors.attention : AppColors.primary),
                        ),
                        title: Row(
                          children: [
                            if (!n.read)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(Icons.circle, size: 8, color: AppColors.danger),
                              ),
                            Expanded(
                              child: Text(
                                n.title,
                                style: TextStyle(fontWeight: n.read ? FontWeight.w500 : FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (n.body.isNotEmpty) Text(n.body),
                            const SizedBox(height: 2),
                            Text(formatRelative(n.createdAt), style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        onTap: () => _open(context, vm, n),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

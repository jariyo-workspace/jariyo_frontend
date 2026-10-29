import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../core/presentation/view_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/view_model_scope.dart';
import '../domain/notification_entities.dart';
import '../domain/notification_repository.dart';
import '../domain/notification_usecases.dart';

class NotificationSettingsViewModel extends LoadableViewModel<NotificationSettings> {
  NotificationSettingsViewModel(NotificationRepository repository)
    : _get = GetNotificationSettings(repository),
      _update = UpdateNotificationSettings(repository);

  final GetNotificationSettings _get;
  final UpdateNotificationSettings _update;

  @override
  Future<NotificationSettings> fetch() => _get();

  /// 바로 반영하고, 저장에 실패하면 이전 값으로 되돌린다.
  Future<void> change(NotificationSettings next) async {
    final previous = data;
    data = next;
    notify();
    final ok = await runAction('save', () => _update(next));
    if (!ok) {
      data = previous;
      notify();
    }
  }
}

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<NotificationSettingsViewModel>(
      create: () => NotificationSettingsViewModel(GetIt.I<NotificationRepository>()),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: const Text('알림 설정')),
        body: LoadableBody<NotificationSettings>(
          vm: vm,
          pullToRefresh: false,
          builder: (context, s) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SectionTitle('서비스 알림'),
              const Text(
                '예약과 대기 진행에 필요한 알림이에요. 끄면 빈자리 제안이나 호출을 놓칠 수 있어요.',
                style: TextStyle(color: AppColors.lightText),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('예약 관련 알림'),
                      subtitle: const Text('예약 확정, 예약 임박, 예약 변경·취소'),
                      value: s.reservation,
                      onChanged: (v) => vm.change(s.copyWith(reservation: v)),
                    ),
                    SwitchListTile(
                      title: const Text('빈자리 알림'),
                      subtitle: const Text('예약 대기 중 빈자리 제안, 제안 만료'),
                      value: s.waitlist,
                      onChanged: (v) => vm.change(s.copyWith(waitlist: v)),
                    ),
                    SwitchListTile(
                      title: const Text('현장 대기 알림'),
                      subtitle: const Text('대기 순서 임박, 입장 호출'),
                      value: s.walkIn,
                      onChanged: (v) => vm.change(s.copyWith(walkIn: v)),
                    ),
                  ],
                ),
              ),
              const SectionTitle('마케팅 알림'),
              Card(
                child: SwitchListTile(
                  title: const Text('이벤트·혜택 알림'),
                  subtitle: const Text('매장 소식과 혜택 정보를 받아요. (선택)'),
                  value: s.marketing,
                  onChanged: (v) => vm.change(s.copyWith(marketing: v)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

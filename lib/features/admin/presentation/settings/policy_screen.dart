import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/presentation/view_model.dart';
import '../../../../core/realtime/refresh_bus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_time_format.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/view_model_scope.dart';
import '../../../store/domain/store_entities.dart';
import '../../domain/admin_repositories.dart';
import '../../domain/admin_settings_usecases.dart';
import '../admin_common.dart';

class PolicyViewModel extends LoadableViewModel<StorePolicy> {
  PolicyViewModel(this.storeId, StoreSettingsRepository repository, this._bus) : _manage = ManagePolicy(repository);

  final String storeId;
  final RefreshBus _bus;
  final ManagePolicy _manage;
  late StorePolicy draft;

  @override
  Future<StorePolicy> fetch() async {
    final policy = await _manage.load(storeId);
    draft = policy;
    return policy;
  }

  void update(StorePolicy value) {
    draft = value;
    notify();
  }

  Future<bool> save() => runAction('save', () async {
    data = await _manage.save(storeId, draft);
    draft = data!;
    _bus.emit({RefreshTopic.adminSettings, RefreshTopic.storeDetail, RefreshTopic.availability});
    AppMessenger.show('운영 정책을 저장했어요.');
  });
}

/// A-14 매장 운영 정책. 숫자를 그대로 나열하지 않고 문장으로 보여준다.
class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key, required this.ctx});

  final OperatorContext ctx;

  Future<int?> _ask(BuildContext context, String title, int? current, String unit) async {
    final controller = TextEditingController(text: current?.toString() ?? '');
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(suffixText: unit),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(controller.text)), child: const Text('확인')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<PolicyViewModel>(
      create: () => PolicyViewModel(ctx.storeId, GetIt.I<StoreSettingsRepository>(), GetIt.I<RefreshBus>()),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: const Text('운영 정책')),
        body: LoadableBody<StorePolicy>(
          vm: vm,
          pullToRefresh: false,
          builder: (context, _) {
            final p = vm.draft;
            Widget sentence(String before, String value, String after, Future<void> Function() onTap) => _SentenceTile(
              before: before,
              value: value,
              after: after,
              onTap: onTap,
            );
            String minutes(int? v) => v == null ? '-' : formatMinutes(v);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SectionTitle('예약'),
                sentence('오늘부터 ', '${p.bookingOpenDays ?? '-'}일', ' 뒤까지 예약을 받을게요.', () async {
                  final v = await _ask(context, '예약 오픈 기간', p.bookingOpenDays, '일');
                  if (v != null) vm.update(p.copyWith(bookingOpenDays: v));
                }),
                sentence('예약 시작 ', minutes(p.minimumBookingNoticeMinutes), ' 전까지 예약을 받을게요.', () async {
                  final v = await _ask(context, '최소 예약 가능 시간', p.minimumBookingNoticeMinutes, '분');
                  if (v != null) vm.update(p.copyWith(minimumBookingNoticeMinutes: v));
                }),
                sentence('예약 시작 ', minutes(p.cancellationDeadlineMinutes), ' 전까지 고객이 직접 취소할 수 있어요.', () async {
                  final v = await _ask(context, '고객 취소 가능 시점', p.cancellationDeadlineMinutes, '분');
                  if (v != null) vm.update(p.copyWith(cancellationDeadlineMinutes: v));
                }),
                sentence('예약 확인 단계에서 ', minutes(p.reservationHoldMinutes), ' 동안 자리를 잡아 둘게요.', () async {
                  final v = await _ask(context, '예약 임시 확보 시간', p.reservationHoldMinutes, '분');
                  if (v != null && v > 0) vm.update(p.copyWith(reservationHoldMinutes: v));
                }),
                const SectionTitle('방문'),
                sentence('예약 시작 ', minutes(p.checkInOpenBeforeMinutes), ' 전부터 체크인할 수 있어요.', () async {
                  final v = await _ask(context, '체크인 가능 시점', p.checkInOpenBeforeMinutes, '분');
                  if (v != null) vm.update(p.copyWith(checkInOpenBeforeMinutes: v));
                }),
                sentence('', minutes(p.lateToleranceMinutes), '까지 늦어도 기다려 드려요.', () async {
                  final v = await _ask(context, '지각 허용 시간', p.lateToleranceMinutes, '분');
                  if (v != null) vm.update(p.copyWith(lateToleranceMinutes: v));
                }),
                sentence('예약 시작 후 ', minutes(p.noShowAfterMinutes), '이 지나도 오지 않으면 노쇼 후보로 표시해요.', () async {
                  final v = await _ask(context, '노쇼 판단 시간', p.noShowAfterMinutes, '분');
                  if (v != null) vm.update(p.copyWith(noShowAfterMinutes: v));
                }),
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: SwitchListTile(
                    title: const Text('노쇼 후보를 자동으로 노쇼 처리할게요.'),
                    value: p.autoNoShowEnabled,
                    onChanged: (v) => vm.update(p.copyWith(autoNoShowEnabled: v)),
                  ),
                ),
                const SectionTitle('대기'),
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: SwitchListTile(
                    title: const Text('예약이 마감되면 예약 대기를 받을게요.'),
                    value: p.waitlistEnabled,
                    onChanged: (v) => vm.update(p.copyWith(waitlistEnabled: v)),
                  ),
                ),
                if (p.waitlistEnabled)
                  sentence('빈자리 제안은 ', minutes(p.slotOfferExpirationMinutes), ' 안에 응답해야 해요.', () async {
                    final v = await _ask(context, '빈자리 제안 유효 시간', p.slotOfferExpirationMinutes, '분');
                    if (v != null && v > 0) vm.update(p.copyWith(slotOfferExpirationMinutes: v));
                  }),
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: SwitchListTile(
                    title: const Text('매장에서 현장 대기를 받을게요.'),
                    value: p.walkInEnabled,
                    onChanged: (v) => vm.update(p.copyWith(walkInEnabled: v)),
                  ),
                ),
                if (p.walkInEnabled)
                  sentence('현장 호출 후 ', minutes(p.walkInCallTimeoutMinutes), ' 안에 응답해야 해요.', () async {
                    final v = await _ask(context, '현장 호출 응답 시간', p.walkInCallTimeoutMinutes, '분');
                    if (v != null && v > 0) vm.update(p.copyWith(walkInCallTimeoutMinutes: v));
                  }),
                const SizedBox(height: 80),
              ],
            );
          },
        ),
        bottomNavigationBar: vm.data == null
            ? null
            : BottomActionBar(
                children: [AppButton(label: '정책 저장', loading: vm.isBusy('save'), onPressed: vm.save)],
              ),
      ),
    );
  }
}

class _SentenceTile extends StatelessWidget {
  const _SentenceTile({required this.before, required this.value, required this.after, required this.onTap});

  final String before;
  final String value;
  final String after;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 15, color: AppColors.text, height: 1.5),
                    children: [
                      TextSpan(text: before),
                      TextSpan(
                        text: value,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      TextSpan(text: after),
                    ],
                  ),
                ),
              ),
              const Icon(Icons.edit_outlined, size: 18, color: AppColors.lightText),
            ],
          ),
        ),
      ),
    );
  }
}

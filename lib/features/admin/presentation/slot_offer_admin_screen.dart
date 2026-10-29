import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/statuses.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../../core/network/idempotency.dart';
import '../../../core/presentation/view_model.dart';
import '../../../core/realtime/refresh_bus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_time_format.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/countdown.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/view_model_scope.dart';
import '../domain/admin_entities.dart';
import '../domain/admin_operation_usecases.dart';
import '../domain/admin_repositories.dart';
import 'admin_common.dart';

class SlotOfferAdminViewModel extends LoadableViewModel<List<AdminSlotOffer>> {
  SlotOfferAdminViewModel(this.storeId, AdminOperationRepository repository, this._bus)
    : _list = GetStoreSlotOffers(repository),
      _manage = ManageSlotOffer(repository) {
    listenTopics(_bus, {RefreshTopic.adminSlotOffers}, refresh);
    startPolling(const Duration(seconds: 20), refresh);
  }

  final String storeId;
  final RefreshBus _bus;
  final GetStoreSlotOffers _list;
  final ManageSlotOffer _manage;
  final _keys = <String, IdempotencyKeyHolder>{};

  SlotOfferStatus status = SlotOfferStatus.pending;

  @override
  Future<List<AdminSlotOffer>> fetch() => _list(storeId, status: status);

  void setStatus(SlotOfferStatus value) {
    status = value;
    load();
  }

  Future<bool> _command(String action, String offerId, Future<void> Function(String key) task, String success) {
    final busy = '$action:$offerId';
    final holder = _keys.putIfAbsent(busy, IdempotencyKeyHolder.new);
    final key = holder.keyFor({'offer': offerId, 'action': action});
    return runAction(
      busy,
      () async {
        await task(key);
        holder.settle();
        _bus.emit({RefreshTopic.adminSlotOffers, RefreshTopic.adminWaitlists, RefreshTopic.adminDashboard});
        AppMessenger.show(success);
        await refresh();
      },
      onFailure: (failure) {
        if (failure.kind != FailureKind.unknownOutcome) holder.settle();
        refresh();
        return false;
      },
    );
  }

  Future<bool> revoke(String offerId, String reason) =>
      _command('revoke', offerId, (key) => _manage.revoke(storeId, offerId, reason: reason, idempotencyKey: key), '제안을 취소했어요.');

  Future<bool> offerNext(String offerId) =>
      _command('next', offerId, (key) => _manage.offerNext(storeId, offerId, idempotencyKey: key), '다음 대기 고객에게 제안했어요.');
}

/// A-09 빈자리 제안 관리
class SlotOfferAdminScreen extends StatelessWidget {
  const SlotOfferAdminScreen({super.key, required this.ctx});

  final OperatorContext ctx;

  @override
  Widget build(BuildContext context) {
    const statuses = [
      SlotOfferStatus.pending,
      SlotOfferStatus.accepted,
      SlotOfferStatus.declined,
      SlotOfferStatus.expired,
      SlotOfferStatus.revoked,
    ];
    return ViewModelScope<SlotOfferAdminViewModel>(
      create: () => SlotOfferAdminViewModel(ctx.storeId, GetIt.I<AdminOperationRepository>(), GetIt.I<RefreshBus>()),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: const Text('빈자리 제안 관리')),
        body: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  for (final s in statuses) ...[
                    ChoiceChip(label: Text(s.label), selected: vm.status == s, onSelected: (_) => vm.setStatus(s)),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: NoticeBox(message: '알림 발송에 실패한 제안은 "처리 실패" 메뉴에서 다시 처리할 수 있어요.'),
            ),
            Expanded(
              child: LoadableBody<List<AdminSlotOffer>>(
                vm: vm,
                builder: (context, offers) {
                  if (offers.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 80),
                        EmptyView(icon: Icons.local_fire_department_outlined, title: '${vm.status.label} 상태의 제안이 없어요.'),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: offers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _OfferCard(offer: offers[index], vm: vm),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer, required this.vm});

  final AdminSlotOffer offer;
  final SlotOfferAdminViewModel vm;

  @override
  Widget build(BuildContext context) {
    final o = offer;
    final pending = o.status == SlotOfferStatus.pending;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(o.customerName ?? '대기 고객', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                StatusBadge(label: o.status.label, tone: o.status.tone),
              ],
            ),
            const SizedBox(height: 6),
            if (o.startAt != null) InfoRow(label: '제안 시간', value: formatDateTime(o.startAt!)),
            if (o.serviceName != null || o.staffName != null)
              InfoRow(label: '서비스', value: [o.serviceName, o.staffName].whereType<String>().join(' · ')),
            if (o.waitlistCondition != null) InfoRow(label: '대기 조건', value: o.waitlistCondition!),
            if (o.sourceDescription != null) InfoRow(label: '생성 원인', value: o.sourceDescription!),
            if (pending && o.expiresAt != null)
              Row(
                children: [
                  const SizedBox(width: 96, child: Text('남은 시간', style: TextStyle(color: AppColors.lightText))),
                  CountdownText(
                    expiresAt: o.expiresAt!,
                    onExpired: vm.refresh,
                    style: const TextStyle(color: AppColors.attention, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            if (pending || o.status == SlotOfferStatus.declined || o.status == SlotOfferStatus.expired) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  if (pending)
                    AppButton(
                      label: '제안 취소',
                      expand: false,
                      variant: AppButtonVariant.secondary,
                      loading: vm.isBusy('revoke:${o.id}'),
                      onPressed: () async {
                        final reason = await showReasonDialog(
                          context,
                          title: '제안을 취소할까요?',
                          message: '고객에게 제안 취소가 안내되고, 대기는 유지돼요.',
                          presets: const ['슬롯이 더 이상 제공 가능하지 않음', '매장 일정 변경'],
                          confirmLabel: '제안 취소',
                          destructive: true,
                        );
                        if (reason != null) await vm.revoke(o.id, reason);
                      },
                    ),
                  if (!pending)
                    AppButton(
                      label: '다음 고객에게 제안',
                      expand: false,
                      loading: vm.isBusy('next:${o.id}'),
                      onPressed: () async {
                        final ok = await showConfirmDialog(
                          context,
                          title: '다음 대기 고객에게 제안할까요?',
                          message: '같은 시간을 조건이 맞는 다음 대기 고객에게 제안해요.',
                          confirmLabel: '제안하기',
                        );
                        if (ok) await vm.offerNext(o.id);
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

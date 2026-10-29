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
import '../../store/domain/store_entities.dart';
import '../domain/admin_entities.dart';
import '../domain/admin_operation_usecases.dart';
import '../domain/admin_repositories.dart';
import '../domain/admin_settings_usecases.dart';
import 'admin_common.dart';

class AdminWaitlistViewModel extends LoadableViewModel<List<AdminWaitlist>> {
  AdminWaitlistViewModel(this.storeId, AdminOperationRepository repository, StoreSettingsRepository settings, this._bus)
    : _list = GetStoreWaitlists(repository),
      _detail = GetStoreWaitlist(repository),
      _offer = CreateManualOffer(repository),
      _services = GetManagedServices(settings),
      _staff = GetStaffMembers(settings) {
    listenTopics(_bus, {RefreshTopic.adminWaitlists, RefreshTopic.adminSlotOffers}, refresh);
    startPolling(const Duration(seconds: 30), refresh);
  }

  final String storeId;
  final RefreshBus _bus;
  final GetStoreWaitlists _list;
  final GetStoreWaitlist _detail;
  final CreateManualOffer _offer;
  final GetManagedServices _services;
  final GetStaffMembers _staff;
  final _offerKeys = IdempotencyKeyHolder();

  DateTime date = storeToday();
  WaitlistStatus? status;
  String? serviceId;
  String? staffId;
  List<ServiceItem> services = [];
  List<StaffMember> staff = [];

  @override
  Future<List<AdminWaitlist>> fetch() async {
    if (services.isEmpty) {
      try {
        final results = await Future.wait<Object>([_services(storeId), _staff(storeId)]);
        services = results[0] as List<ServiceItem>;
        staff = results[1] as List<StaffMember>;
      } on AppFailure {
        // 필터 목록 없이도 대기 목록은 볼 수 있다.
      }
    }
    return _list(storeId, date: date, serviceId: serviceId, staffId: staffId, status: status);
  }

  void setFilters({DateTime? date, WaitlistStatus? status, bool clearStatus = false, String? serviceId, String? staffId}) {
    this.date = date ?? this.date;
    if (clearStatus) {
      this.status = null;
    } else if (status != null) {
      this.status = status;
    }
    this.serviceId = serviceId ?? this.serviceId;
    this.staffId = staffId ?? this.staffId;
    load();
  }

  void clearServiceStaff({bool service = false, bool staff = false}) {
    if (service) serviceId = null;
    if (staff) staffId = null;
    load();
  }

  Future<AdminWaitlist> detail(AdminWaitlist item) async {
    try {
      return await _detail(storeId, item.id);
    } on AppFailure {
      return item;
    }
  }

  Future<bool> offer(String waitlistId, ManualOfferRequest request) {
    final key = _offerKeys.keyFor({'waitlist': waitlistId, ...request.toJson()});
    return runAction(
      'offer',
      () async {
        await _offer(storeId, waitlistId, request, idempotencyKey: key);
        _offerKeys.settle();
        _bus.emit({RefreshTopic.adminWaitlists, RefreshTopic.adminSlotOffers, RefreshTopic.adminDashboard});
        AppMessenger.show('빈자리를 제안했어요. 고객의 응답을 기다려요.');
        await refresh();
      },
      onFailure: (failure) {
        if (failure.kind != FailureKind.unknownOutcome) _offerKeys.settle();
        if (failure.isStateConflict) refresh();
        return false;
      },
    );
  }
}

/// A-08 예약 대기 관리
class AdminWaitlistScreen extends StatelessWidget {
  const AdminWaitlistScreen({super.key, required this.ctx});

  final OperatorContext ctx;

  Future<void> _openDetail(BuildContext context, AdminWaitlistViewModel vm, AdminWaitlist item) async {
    final detail = await vm.detail(item);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(detail.customerName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                  StatusBadge(label: detail.status.label, tone: detail.status.tone),
                ],
              ),
              const SizedBox(height: 12),
              InfoRow(label: '희망 날짜', value: formatYmdLabel(detail.desiredDate)),
              InfoRow(label: '가능 시간', value: detail.timeRangeLabel),
              InfoRow(label: '서비스', value: detail.serviceName),
              InfoRow(label: '선호 직원', value: detail.preferredStaffName ?? '직원 무관'),
              if (detail.staffPreferenceType != null) InfoRow(label: '직원 조건', value: detail.staffPreferenceType!.label),
              if (detail.partySize != null) InfoRow(label: '인원', value: '${detail.partySize}명'),
              if (detail.sequenceNumber != null) InfoRow(label: '신청 순서', value: '${detail.sequenceNumber}번'),
              if (detail.pendingOffer)
                InfoRow(
                  label: '진행 중 제안',
                  value: detail.pendingOfferStartAt == null ? '응답 대기 중' : '${formatDateTime(detail.pendingOfferStartAt!)} 응답 대기',
                ),
              const SizedBox(height: 16),
              const NoticeBox(message: '빈자리는 자동으로 제안돼요. 예외 상황에서만 직접 제안해 주세요.'),
              const SizedBox(height: 12),
              AppButton(
                label: '빈자리 직접 제안',
                onPressed: detail.status == WaitlistStatus.waiting && !detail.pendingOffer
                    ? () {
                        Navigator.pop(sheetContext);
                        _manualOffer(context, vm, detail);
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _manualOffer(BuildContext context, AdminWaitlistViewModel vm, AdminWaitlist item) async {
    final staff = await pickStaff(context, ctx.storeId, title: '빈자리를 제공할 직원', preferName: item.preferredStaffName);
    if (staff == null || !context.mounted) return;
    final hm = await pickHm(context, initial: item.acceptableStartTime, helpText: '제안할 시작 시간');
    if (hm == null || !context.mounted) return;
    final date = parseYmd(item.desiredDate) ?? storeToday();
    final parts = hm.split(':');
    final startAt = storeIso(date, int.parse(parts[0]), int.parse(parts[1]));
    final minutes = await showChoiceSheet<int>(
      context,
      title: '응답 제한 시간',
      options: const [(3, '3분', null), (5, '5분', null), (10, '10분', null), (30, '30분', null)],
      selected: 3,
    );
    if (minutes == null || !context.mounted) return;
    final ok = await showConfirmDialog(
      context,
      title: '빈자리를 제안할까요?',
      message:
          '${item.customerName} 고객에게 ${formatDateTime(DateTime.parse(startAt))} (${staff.displayName})을 제안해요.\n'
          '$minutes분 안에 응답하지 않으면 제안이 만료돼요.',
      confirmLabel: '제안하기',
    );
    if (ok) await vm.offer(item.id, ManualOfferRequest(staffId: staff.id, startAt: startAt, expiresInMinutes: minutes));
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<AdminWaitlistViewModel>(
      create: () => AdminWaitlistViewModel(
        ctx.storeId,
        GetIt.I<AdminOperationRepository>(),
        GetIt.I<StoreSettingsRepository>(),
        GetIt.I<RefreshBus>(),
      ),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: const Text('예약 대기 관리')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DateNavigator(date: vm.date, onChanged: (d) => vm.setFilters(date: d)),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  DropdownButton<WaitlistStatus?>(
                    value: vm.status,
                    hint: const Text('전체 상태'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('전체 상태')),
                      for (final s in WaitlistStatus.values.where((s) => s != WaitlistStatus.unknown))
                        DropdownMenuItem(value: s, child: Text(s.label)),
                    ],
                    onChanged: (s) => s == null ? vm.setFilters(clearStatus: true) : vm.setFilters(status: s),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String?>(
                    value: vm.serviceId,
                    hint: const Text('전체 서비스'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('전체 서비스')),
                      for (final s in vm.services) DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ],
                    onChanged: (id) => id == null ? vm.clearServiceStaff(service: true) : vm.setFilters(serviceId: id),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String?>(
                    value: vm.staffId,
                    hint: const Text('전체 직원'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('전체 직원')),
                      for (final s in vm.staff) DropdownMenuItem(value: s.id, child: Text(s.displayName)),
                    ],
                    onChanged: (id) => id == null ? vm.clearServiceStaff(staff: true) : vm.setFilters(staffId: id),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: LoadableBody<List<AdminWaitlist>>(
                vm: vm,
                builder: (context, items) {
                  if (items.isEmpty) {
                    return ListView(
                      children: const [SizedBox(height: 80), EmptyView(icon: Icons.hourglass_empty, title: '이 날짜의 예약 대기가 없어요.')],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final w = items[index];
                      return Card(
                        child: ListTile(
                          onTap: () => _openDetail(context, vm, w),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.waiting.withAlpha(30),
                            child: Text('${w.sequenceNumber ?? '-'}', style: const TextStyle(color: AppColors.waiting)),
                          ),
                          title: Row(
                            children: [
                              Expanded(child: Text(w.customerName, style: const TextStyle(fontWeight: FontWeight.w700))),
                              StatusBadge(label: w.status.label, tone: w.status.tone),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${formatYmdLabel(w.desiredDate)} · ${w.timeRangeLabel}'),
                              Text('${w.serviceName} · ${w.preferredStaffName ?? '직원 무관'}'),
                              if (w.pendingOffer && w.pendingOfferExpiresAt != null)
                                CountdownText(
                                  expiresAt: w.pendingOfferExpiresAt!,
                                  suffix: ' 후 제안 만료',
                                  onExpired: vm.refresh,
                                  style: const TextStyle(color: AppColors.attention, fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
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

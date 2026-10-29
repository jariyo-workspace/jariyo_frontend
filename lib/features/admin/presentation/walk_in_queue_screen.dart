import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../store/domain/store_repository.dart';
import '../../store/domain/store_usecases.dart';
import '../domain/admin_entities.dart';
import '../domain/admin_operation_usecases.dart';
import '../domain/admin_repositories.dart';
import 'admin_common.dart';

class WalkInQueueViewModel extends LoadableViewModel<List<AdminWalkIn>> {
  WalkInQueueViewModel(this.storeId, AdminOperationRepository repository, this._bus)
    : _list = GetWalkInQueue(repository),
      _call = CallWalkIn(repository),
      _manage = ManageWalkIn(repository),
      _start = StartService(repository),
      _complete = CompleteService(repository),
      _register = RegisterGuestWalkIn(repository) {
    listenTopics(_bus, {RefreshTopic.adminWalkIns}, refresh);
    startPolling(const Duration(seconds: 15), refresh);
  }

  final String storeId;
  final RefreshBus _bus;
  final GetWalkInQueue _list;
  final CallWalkIn _call;
  final ManageWalkIn _manage;
  final StartService _start;
  final CompleteService _complete;
  final RegisterGuestWalkIn _register;
  final _keys = <String, IdempotencyKeyHolder>{};

  /// 목록 응답에 없는 호출 만료 시각을 호출 응답에서 보관한다.
  final _callExpiry = <String, DateTime>{};

  @override
  Future<List<AdminWalkIn>> fetch() async {
    final items = await _list(storeId, date: storeToday());
    return [
      for (final w in items) w.callExpiresAt == null && _callExpiry[w.id] != null ? w.withCallExpiresAt(_callExpiry[w.id]) : w,
    ];
  }

  Map<WalkInGroup, List<AdminWalkIn>> get groups => groupWalkIns(data ?? const []);

  bool canComplete(String walkInId) => _complete.canComplete(walkInId);

  /// 상태 변경 후에는 대기열 순서 전체를 다시 불러온다.
  Future<bool> _command(String action, String walkInId, Object request, Future<void> Function(String key) task, {String? success}) {
    final busyKey = '$action:$walkInId';
    final holder = _keys.putIfAbsent(busyKey, IdempotencyKeyHolder.new);
    final key = holder.keyFor(request);
    return runAction(
      busyKey,
      () async {
        await task(key);
        holder.settle();
        _bus.emit({...RefreshBus.afterWalkInChanged, ...RefreshBus.afterServiceSessionChanged});
        if (success != null) AppMessenger.show(success);
        await refresh();
      },
      onFailure: (failure) {
        if (failure.kind != FailureKind.unknownOutcome) holder.settle();
        if (failure.code == 'WALK_IN_ALREADY_CALLED' || failure.isStateConflict || failure.kind == FailureKind.unknownOutcome) {
          AppMessenger.show(failure.kind == FailureKind.unknownOutcome ? '처리 결과를 다시 확인할게요.' : failure.message);
          refresh();
          return true;
        }
        return false;
      },
    );
  }

  bool busy(String action, String walkInId) => isBusy('$action:$walkInId');

  Future<bool> call(String id, int timeoutMinutes, {bool recall = false}) => _command(
    recall ? 'recall' : 'call',
    id,
    {'timeout': timeoutMinutes},
    (key) async {
      final expires = await _call(storeId, id, timeoutMinutes: timeoutMinutes, recall: recall, idempotencyKey: key);
      // 백엔드 호출 응답에 만료 시각이 없으면 호출 시각과 응답 제한 시간으로 계산한다.
      _callExpiry[id] = expires ?? DateTime.now().add(Duration(minutes: timeoutMinutes));
    },
    success: recall ? '다시 호출했어요.' : '고객을 호출했어요.',
  );

  Future<bool> checkIn(String id) =>
      _command('checkIn', id, {}, (key) => _manage.checkIn(storeId, id, idempotencyKey: key), success: '입장을 확인했어요.');

  Future<bool> skip(String id, String reason) => _command(
    'skip',
    id,
    {'reason': reason},
    (key) => _manage.skip(storeId, id, reason: reason, idempotencyKey: key),
    success: '순서를 보류했어요.',
  );

  Future<bool> cancel(String id, String reason) => _command(
    'cancel',
    id,
    {'reason': reason},
    (key) => _manage.cancel(storeId, id, reason: reason, idempotencyKey: key),
    success: '대기를 취소했어요.',
  );

  Future<bool> restore(String id) =>
      _command('restore', id, {}, (key) => _manage.restore(storeId, id, idempotencyKey: key), success: '대기열로 복귀했어요.');

  Future<bool> noShow(String id, String reason) => _command(
    'noShow',
    id,
    {'reason': reason},
    (key) => _manage.markNoShow(storeId, id, reason: reason, idempotencyKey: key),
    success: '응답 없음으로 처리했어요.',
  );

  Future<bool> reorder(String id, String? beforeId, String reasonCode, String reason) => _command(
    'reorder',
    id,
    {'before': beforeId, 'code': reasonCode, 'reason': reason},
    (key) => _manage.reorder(storeId, id, beforeWalkInId: beforeId, reasonCode: reasonCode, reason: reason, idempotencyKey: key),
    success: '대기 순서를 변경했어요.',
  );

  Future<bool> startService(String id, String staffId) => _command(
    'start',
    id,
    {'staff': staffId},
    (key) => _start.walkIn(storeId, id, staffId: staffId, idempotencyKey: key),
    success: '서비스를 시작했어요.',
  );

  Future<bool> completeService(String id, String? note) => _command(
    'complete',
    id,
    {},
    (key) => _complete(storeId, id, note: note, idempotencyKey: key),
    success: '서비스를 완료했어요.',
  );

  final _registerKeys = IdempotencyKeyHolder();

  Future<bool> registerGuest(GuestWalkInRequest request) {
    final key = _registerKeys.keyFor(request.toJson());
    return runAction(
      'register',
      () async {
        await _register(storeId, request, idempotencyKey: key);
        _registerKeys.settle();
        _bus.emit(RefreshBus.afterWalkInChanged);
        AppMessenger.show('현장 대기를 등록했어요.');
        await refresh();
      },
      onFailure: (failure) {
        if (failure.kind != FailureKind.unknownOutcome) _registerKeys.settle();
        return false;
      },
    );
  }
}

/// A-06 현장 대기열 + A-07 고객 호출
class WalkInQueueScreen extends StatelessWidget {
  const WalkInQueueScreen({super.key, required this.ctx});

  final OperatorContext ctx;

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<WalkInQueueViewModel>(
      create: () => WalkInQueueViewModel(ctx.storeId, GetIt.I<AdminOperationRepository>(), GetIt.I<RefreshBus>()),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(
          title: const Text('현장 대기열'),
          actions: [IconButton(tooltip: '새로고침', onPressed: vm.refresh, icon: const Icon(Icons.refresh))],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _registerGuest(context, vm),
          icon: const Icon(Icons.person_add_alt),
          label: const Text('대기 등록'),
        ),
        body: LoadableBody<List<AdminWalkIn>>(
          vm: vm,
          staleMessage: '대기열을 새로 불러오지 못했어요.',
          builder: (context, items) {
            final groups = vm.groups;
            if (groups.values.every((g) => g.isEmpty)) {
              return ListView(
                children: const [
                  SizedBox(height: 100),
                  EmptyView(icon: Icons.groups_outlined, title: '지금 대기 중인 고객이 없어요.'),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                for (final group in WalkInGroup.values)
                  if (groups[group]!.isNotEmpty) ...[
                    SectionTitle('${group.label} ${groups[group]!.length}'),
                    for (final w in groups[group]!)
                      _WalkInCard(walkIn: w, vm: vm, ctx: ctx, emphasize: group == WalkInGroup.needsCall),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _registerGuest(BuildContext context, WalkInQueueViewModel vm) async {
    final request = await showModalBottomSheet<GuestWalkInRequest>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _GuestWalkInSheet(storeId: ctx.storeId),
    );
    if (request != null) await vm.registerGuest(request);
  }
}

class _WalkInCard extends StatelessWidget {
  const _WalkInCard({required this.walkIn, required this.vm, required this.ctx, this.emphasize = false});

  final AdminWalkIn walkIn;
  final WalkInQueueViewModel vm;
  final OperatorContext ctx;
  final bool emphasize;

  Future<void> _callPanel(BuildContext context, {bool recall = false}) async {
    final timeout = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (_) => _CallPanel(walkIn: walkIn, recall: recall),
    );
    if (timeout == null) return;
    HapticFeedback.mediumImpact();
    await vm.call(walkIn.id, timeout, recall: recall);
  }

  Future<String?> _reason(BuildContext context, String title, List<String> presets, {String? message, bool destructive = false}) =>
      showReasonDialog(context, title: title, message: message, presets: presets, confirmLabel: '확인', destructive: destructive);

  Future<void> _reorder(BuildContext context) async {
    final waiting = (vm.data ?? const <AdminWalkIn>[])
        .where((w) => w.status == WalkInStatus.waiting && w.id != walkIn.id)
        .toList()
      ..sort((a, b) => a.queueNumber.compareTo(b.queueNumber));
    final before = await showChoiceSheet<String>(
      context,
      title: '${walkIn.queueNumber}번 고객을 어디로 옮길까요?',
      options: [
        for (final w in waiting) (w.id, '${w.queueNumber}번 ${w.customerName} 앞으로', null),
        ('__last', '맨 뒤로', null),
      ],
    );
    if (before == null || !context.mounted) return;
    const codes = {
      '고객 요청': 'CUSTOMER_REQUEST',
      '직원 배정 변경': 'STAFF_ASSIGNMENT_CHANGED',
      '서비스 소요 시간 차이': 'SERVICE_DURATION_DIFFERENCE',
      '운영상 조정': 'OPERATIONAL_ADJUSTMENT',
    };
    final reason = await showReasonDialog(
      context,
      title: '순서 변경 사유',
      message: '순서 변경은 운영 이력에 기록돼요.',
      presets: codes.keys.toList(),
      confirmLabel: '순서 변경',
    );
    if (reason == null) return;
    await vm.reorder(walkIn.id, before == '__last' ? null : before, codes[reason] ?? 'OTHER', reason);
  }

  @override
  Widget build(BuildContext context) {
    final w = walkIn;
    final actions = <Widget>[];
    void add(String label, VoidCallback onPressed, {bool primary = false, bool busy = false, bool danger = false}) {
      actions.add(
        AppButton(
          label: label,
          expand: false,
          loading: busy,
          loadingLabel: label,
          variant: primary
              ? AppButtonVariant.primary
              : (danger ? AppButtonVariant.text : AppButtonVariant.secondary),
          onPressed: onPressed,
        ),
      );
    }

    switch (w.status) {
      case WalkInStatus.waiting:
        add('호출하기', () => _callPanel(context), primary: true, busy: vm.busy('call', w.id));
        add('순서 보류', () async {
          final r = await _reason(context, '순서를 보류할까요?', const ['고객이 잠시 자리를 비움', '고객 요청']);
          if (r != null) await vm.skip(w.id, r);
        }, busy: vm.busy('skip', w.id));
        add('순서 변경', () => _reorder(context), busy: vm.busy('reorder', w.id));
        add('대기 취소', () async {
          final r = await _reason(
            context,
            '대기를 취소할까요?',
            const ['고객 요청으로 접수 취소', '연락 두절'],
            message: '취소하면 되돌릴 수 없어요.',
            destructive: true,
          );
          if (r != null) await vm.cancel(w.id, r);
        }, danger: true, busy: vm.busy('cancel', w.id));
      case WalkInStatus.called:
        add('입장 확인', () => vm.checkIn(w.id), primary: true, busy: vm.busy('checkIn', w.id));
        add('다시 호출', () => _callPanel(context, recall: true), busy: vm.busy('recall', w.id));
        add('잠시 보류', () async {
          final r = await _reason(context, '순서를 보류할까요?', const ['호출에 응답하지 않음', '고객이 잠시 자리를 비움']);
          if (r != null) await vm.skip(w.id, r);
        }, busy: vm.busy('skip', w.id));
        add('응답 없음', () async {
          final r = await _reason(
            context,
            '응답 없음으로 처리할까요?',
            const ['호출 응답 시간 초과'],
            message: '고객이 매장에 오지 않았는지 다시 확인해 주세요.\n처리 후에는 되돌릴 수 없어요.',
            destructive: true,
          );
          if (r != null) await vm.noShow(w.id, r);
        }, danger: true, busy: vm.busy('noShow', w.id));
      case WalkInStatus.skipped:
        add('대기열 복귀', () => vm.restore(w.id), primary: true, busy: vm.busy('restore', w.id));
        add('호출하기', () => _callPanel(context), busy: vm.busy('call', w.id));
        add('대기 취소', () async {
          final r = await _reason(context, '대기를 취소할까요?', const ['고객 요청으로 접수 취소'], destructive: true);
          if (r != null) await vm.cancel(w.id, r);
        }, danger: true, busy: vm.busy('cancel', w.id));
      case WalkInStatus.checkedIn:
        add('서비스 시작', () async {
          final staff = await pickStaff(context, ctx.storeId, title: '서비스를 진행할 직원', preferName: w.preferredStaffName);
          if (staff != null) await vm.startService(w.id, staff.id);
        }, primary: true, busy: vm.busy('start', w.id));
        add('대기 취소', () async {
          final r = await _reason(context, '대기를 취소할까요?', const ['고객 요청으로 접수 취소'], destructive: true);
          if (r != null) await vm.cancel(w.id, r);
        }, danger: true, busy: vm.busy('cancel', w.id));
      case WalkInStatus.inService:
        if (vm.canComplete(w.id)) {
          add('서비스 완료', () async {
            final note = await showReasonDialog(
              context,
              title: '서비스를 완료할까요?',
              hint: '완료 메모',
              presets: const ['정상 완료'],
              confirmLabel: '서비스 완료',
              maxLength: 1000,
            );
            if (note != null) await vm.completeService(w.id, note);
          }, primary: true, busy: vm.busy('complete', w.id));
        }
      default:
        break;
    }

    final color = AppColors.forTone(w.status.tone);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: emphasize ? AppColors.primary : AppColors.border, width: emphasize ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: color.withAlpha(24), borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: Text('${w.queueNumber}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w.customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(
                        [w.serviceName, if (w.preferredStaffName != null) '희망 ${w.preferredStaffName}'].join(' · '),
                        style: const TextStyle(color: AppColors.lightText),
                      ),
                      Text(
                        [
                          if (w.createdAt != null) '등록 ${formatTime(w.createdAt!)}',
                          '대기 ${formatMinutes(w.waitingMinutes)}',
                          if (w.status == WalkInStatus.waiting) '예상 ${formatMinutes(w.estimatedWaitMinutes)}',
                        ].join(' · '),
                        style: const TextStyle(color: AppColors.lightText, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                StatusBadge(label: w.status.label, tone: w.status.tone),
              ],
            ),
            if (w.status == WalkInStatus.called && w.callExpiresAt != null) ...[
              const SizedBox(height: 8),
              CountdownBuilder(
                expiresAt: w.callExpiresAt!,
                onExpired: vm.refresh,
                builder: (context, remaining) => NoticeBox(
                  icon: Icons.timer_outlined,
                  color: remaining.isNegative ? AppColors.danger : AppColors.attention,
                  message: remaining.isNegative
                      ? '응답 시간이 지났어요. 다시 호출하거나 보류해 주세요.'
                      : '응답 대기 ${formatCountdown(remaining)} 남음',
                ),
              ),
            ],
            if (w.status == WalkInStatus.inService && !vm.canComplete(w.id)) ...[
              const SizedBox(height: 8),
              const Text(
                '이 기기에서 시작한 서비스가 아니에요. 서비스를 시작한 기기에서 완료해 주세요.',
                style: TextStyle(color: AppColors.lightText, fontSize: 13),
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

/// A-07 고객 호출 패널
class _CallPanel extends StatefulWidget {
  const _CallPanel({required this.walkIn, required this.recall});

  final AdminWalkIn walkIn;
  final bool recall;

  @override
  State<_CallPanel> createState() => _CallPanelState();
}

class _CallPanelState extends State<_CallPanel> {
  int _timeout = 3;

  @override
  Widget build(BuildContext context) {
    final w = widget.walkIn;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.recall ? '다시 호출' : '고객 호출', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            InfoRow(label: '대기 번호', value: '${w.queueNumber}번', emphasize: true),
            InfoRow(label: '고객명', value: w.customerName),
            InfoRow(label: '서비스', value: w.serviceName),
            const InfoRow(label: '연락 방식', value: '앱 알림 (비회원은 직접 안내)'),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(child: Text('응답 제한 시간')),
                NumberStepper(value: _timeout, min: 1, max: 60, unit: '분', onChanged: (v) => setState(() => _timeout = v)),
              ],
            ),
            const SizedBox(height: 12),
            AppButton(label: widget.recall ? '다시 호출하기' : '호출하기', icon: Icons.campaign, onPressed: () => Navigator.pop(context, _timeout)),
          ],
        ),
      ),
    );
  }
}

/// 비회원 현장 대기 대리 등록
class _GuestWalkInSheet extends StatefulWidget {
  const _GuestWalkInSheet({required this.storeId});

  final String storeId;

  @override
  State<_GuestWalkInSheet> createState() => _GuestWalkInSheetState();
}

class _GuestWalkInSheetState extends State<_GuestWalkInSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  List<ServiceItem> _services = [];
  List<StaffOption> _staff = [];
  ServiceItem? _service;
  StaffOption? _preferred;
  int _partySize = 1;

  @override
  void initState() {
    super.initState();
    GetStoreServices(GetIt.I<StoreRepository>())(widget.storeId)
        .then((s) {
          if (mounted) setState(() => _services = s.where((x) => x.isActive).toList());
        })
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _selectService(ServiceItem service) async {
    setState(() {
      _service = service;
      _preferred = null;
      _staff = [];
    });
    try {
      final staff = await GetServiceStaff(GetIt.I<StoreRepository>())(widget.storeId, service.id);
      if (mounted) setState(() => _staff = staff.where((s) => s.bookingEnabled).toList());
    } on AppFailure {
      // 희망 직원 없이도 등록할 수 있다.
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _name.text.trim().isNotEmpty && _phone.text.length >= 10 && _service != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('현장 대기 대리 등록', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: '고객 이름'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phone,
              decoration: const InputDecoration(labelText: '연락처 (숫자만)'),
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 11,
              onChanged: (_) => setState(() {}),
            ),
            const Text('서비스', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _services)
                  ChoiceChip(label: Text(s.name), selected: _service?.id == s.id, onSelected: (_) => _selectService(s)),
              ],
            ),
            if (_staff.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('희망 직원', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(label: const Text('누구나'), selected: _preferred == null, onSelected: (_) => setState(() => _preferred = null)),
                  for (final s in _staff)
                    ChoiceChip(
                      label: Text(s.displayName),
                      selected: _preferred?.id == s.id,
                      onSelected: (_) => setState(() => _preferred = s),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('인원')),
                NumberStepper(value: _partySize, unit: '명', onChanged: (v) => setState(() => _partySize = v)),
              ],
            ),
            const SizedBox(height: 12),
            AppButton(
              label: '대기 등록',
              onPressed: valid
                  ? () => Navigator.pop(
                      context,
                      GuestWalkInRequest(
                        guestName: _name.text.trim(),
                        guestPhoneNumber: _phone.text,
                        serviceId: _service!.id,
                        preferredStaffId: _preferred?.id,
                        partySize: _partySize,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

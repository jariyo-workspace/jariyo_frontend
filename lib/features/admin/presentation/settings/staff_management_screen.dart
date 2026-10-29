import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/domain/paged.dart';
import '../../../../core/domain/statuses.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/presentation/view_model.dart';
import '../../../../core/realtime/refresh_bus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_time_format.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/dialogs.dart';
import '../../../../core/widgets/view_model_scope.dart';
import '../../domain/admin_entities.dart';
import '../../domain/admin_operation_usecases.dart';
import '../../domain/admin_repositories.dart';
import '../../domain/admin_settings_usecases.dart';
import '../admin_common.dart';
import 'exceptions_screen.dart';
import 'schedule_screen.dart';

class StaffListData {
  const StaffListData({required this.staff, this.todayCounts = const {}});

  final List<StaffMember> staff;
  final Map<String, int> todayCounts;
}

class StaffListViewModel extends LoadableViewModel<StaffListData> {
  StaffListViewModel(this.storeId, StoreSettingsRepository settings, AdminOperationRepository operations, this._bus)
    : _list = GetStaffMembers(settings),
      _manage = ManageStaff(settings),
      _reservations = GetStoreReservations(operations) {
    listenTopics(_bus, {RefreshTopic.adminSettings}, refresh);
  }

  final String storeId;
  final RefreshBus _bus;
  final GetStaffMembers _list;
  final ManageStaff _manage;
  final GetStoreReservations _reservations;

  @override
  Future<StaffListData> fetch() async {
    final staff = await _list(storeId);
    final counts = <String, int>{};
    try {
      final today = storeToday();
      for (final r in await _reservations(storeId, from: today, to: today)) {
        if (r.status == ReservationStatus.cancelled) continue;
        counts[r.staffName] = (counts[r.staffName] ?? 0) + 1;
      }
    } on AppFailure {
      // 오늘 예약 수 없이도 직원 목록을 보여준다.
    }
    return StaffListData(staff: staff, todayCounts: counts);
  }

  Future<bool> add({required String email, required StoreRole role, required String displayName}) => runAction(
    'add',
    () async {
      await _manage.add(storeId, email: email, role: role, displayName: displayName);
      _bus.emit({RefreshTopic.adminSettings});
      AppMessenger.show('직원을 추가했어요.');
      await refresh();
    },
    onFailure: (failure) {
      if (failure.code == 'USER_NOT_FOUND') {
        AppMessenger.show('가입된 사용자만 직원으로 추가할 수 있어요. 이메일을 확인해 주세요.');
        return true;
      }
      return false;
    },
  );
}

/// A-11 직원 관리
class StaffManagementScreen extends StatelessWidget {
  const StaffManagementScreen({super.key, required this.ctx});

  final OperatorContext ctx;

  Future<void> _add(BuildContext context, StaffListViewModel vm) async {
    final result = await showDialog<(String, StoreRole, String)>(context: context, builder: (_) => const _AddStaffDialog());
    if (result != null) await vm.add(email: result.$1, role: result.$2, displayName: result.$3);
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<StaffListViewModel>(
      create: () => StaffListViewModel(
        ctx.storeId,
        GetIt.I<StoreSettingsRepository>(),
        GetIt.I<AdminOperationRepository>(),
        GetIt.I<RefreshBus>(),
      ),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: const Text('직원 관리')),
        floatingActionButton: ctx.isOwner
            ? FloatingActionButton.extended(
                onPressed: () => _add(context, vm),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('직원 추가'),
              )
            : null,
        body: LoadableBody<StaffListData>(
          vm: vm,
          builder: (context, data) {
            if (data.staff.isEmpty) return const EmptyView(title: '등록된 직원이 없어요.');
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (!ctx.isOwner)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: NoticeBox(message: '직원 추가, 역할 변경과 비활성화는 매장 소유자만 할 수 있어요.'),
                  ),
                for (final s in data.staff)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: (s.isActive ? AppColors.primary : AppColors.lightText).withAlpha(30),
                        child: Text(s.displayName.isEmpty ? '?' : s.displayName.characters.first),
                      ),
                      title: Row(
                        children: [
                          Text(s.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Text(s.role.label, style: const TextStyle(color: AppColors.lightText, fontSize: 13)),
                        ],
                      ),
                      subtitle: Text(
                        [
                          s.status.label,
                          s.bookingEnabled ? '예약 가능' : '예약 불가',
                          '오늘 예약 ${data.todayCounts[s.displayName] ?? 0}건',
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => pushPage<void>(context, StaffDetailScreen(ctx: ctx, staffId: s.id)),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AddStaffDialog extends StatefulWidget {
  const _AddStaffDialog();

  @override
  State<_AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<_AddStaffDialog> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  StoreRole _role = StoreRole.staff;

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _email.text.contains('@') && _name.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('직원 추가'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const NoticeBox(message: '자리요에 가입된 사용자의 이메일로 직원을 연결해요.'),
            const SizedBox(height: 8),
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: '이메일'),
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: '표시 이름'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<StoreRole>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: '역할'),
              items: [for (final r in StoreRole.values) DropdownMenuItem(value: r, child: Text(r.label))],
              onChanged: (r) => setState(() => _role = r ?? StoreRole.staff),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
          onPressed: valid ? () => Navigator.pop(context, (_email.text.trim(), _role, _name.text.trim())) : null,
          child: const Text('추가'),
        ),
      ],
    );
  }
}

class StaffDetailData {
  const StaffDetailData({required this.member, required this.assignments});

  final StaffMember member;
  final List<StaffServiceAssignment> assignments;
}

class StaffDetailViewModel extends LoadableViewModel<StaffDetailData> {
  StaffDetailViewModel(this.storeId, this.staffId, StoreSettingsRepository repository, this._bus)
    : _get = GetStaffMember(repository),
      _manage = ManageStaff(repository);

  final String storeId;
  final String staffId;
  final RefreshBus _bus;
  final GetStaffMember _get;
  final ManageStaff _manage;
  List<StaffServiceAssignment> editing = [];

  @override
  Future<StaffDetailData> fetch() async {
    final results = await Future.wait<Object>([_get(storeId, staffId), _manage.assignments(storeId, staffId)]);
    final data = StaffDetailData(
      member: results[0] as StaffMember,
      assignments: results[1] as List<StaffServiceAssignment>,
    );
    editing = [...data.assignments];
    return data;
  }

  void toggleService(String serviceId, bool active) {
    editing = [for (final a in editing) a.serviceId == serviceId ? a.copyWith(active: active) : a];
    notify();
  }

  void setDuration(String serviceId, int? minutes) {
    editing = [
      for (final a in editing)
        a.serviceId == serviceId ? a.copyWith(customDurationMinutes: minutes, clearDuration: minutes == null) : a,
    ];
    notify();
  }

  Future<UpdateResult?> _write(String action, Future<UpdateResult> Function() task) async {
    UpdateResult? result;
    await runAction(action, () async {
      result = await task();
      if (result!.updated) {
        _bus.emit({RefreshTopic.adminSettings, RefreshTopic.storeDetail});
        await refresh();
      }
    });
    return result;
  }

  Future<UpdateResult?> updateInfo({
    required String displayName,
    required StoreRole role,
    required bool bookingEnabled,
    required MemberStatus status,
  }) => _write(
    'info',
    () => _manage.update(storeId, staffId, displayName: displayName, role: role, bookingEnabled: bookingEnabled, status: status),
  );

  Future<UpdateResult?> saveAssignments() => _write('services', () => _manage.replaceAssignments(storeId, staffId, editing));

  Future<UpdateResult?> deactivate() async {
    UpdateResult? result;
    await runAction(
      'deactivate',
      () async {
        result = await _manage.deactivate(storeId, staffId);
        if (result!.updated) {
          _bus.emit({RefreshTopic.adminSettings});
          await refresh();
        }
      },
      onFailure: (failure) {
        if (failure.code == 'STAFF_HAS_FUTURE_RESERVATIONS') {
          result = const UpdateResult(updated: false);
          return true;
        }
        return false;
      },
    );
    return result;
  }
}

class StaffDetailScreen extends StatelessWidget {
  const StaffDetailScreen({super.key, required this.ctx, required this.staffId});

  final OperatorContext ctx;
  final String staffId;

  static const _futureReservationWarning = '예정된 예약이 있는 직원이에요.\n먼저 예약을 다른 직원에게 배정해 주세요.';

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<StaffDetailViewModel>(
      create: () => StaffDetailViewModel(ctx.storeId, staffId, GetIt.I<StoreSettingsRepository>(), GetIt.I<RefreshBus>()),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: Text(vm.data?.member.displayName ?? '직원 상세')),
        body: LoadableBody<StaffDetailData>(
          vm: vm,
          builder: (context, data) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _InfoEditor(
                key: ValueKey(data.member),
                member: data.member,
                canChangeRole: ctx.isOwner,
                busy: vm.isBusy('info'),
                onSave: (name, role, booking, status) async {
                  final result = await vm.updateInfo(displayName: name, role: role, bookingEnabled: booking, status: status);
                  if (result != null && context.mounted) {
                    await handleUpdateResult(context, ctx.storeId, result, successMessage: '직원 정보를 저장했어요.');
                  }
                },
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: '담당 서비스',
                trailing: TextButton(
                  onPressed: vm.isBusy('services')
                      ? null
                      : () async {
                          final result = await vm.saveAssignments();
                          if (result != null && context.mounted) {
                            await handleUpdateResult(context, ctx.storeId, result, successMessage: '담당 서비스를 저장했어요.');
                          }
                        },
                  child: const Text('저장'),
                ),
                child: Column(
                  children: [
                    if (vm.editing.isEmpty) const Text('등록된 서비스가 없어요.', style: TextStyle(color: AppColors.lightText)),
                    for (final a in vm.editing)
                      Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: a.active,
                              onChanged: (v) => vm.toggleService(a.serviceId, v ?? false),
                              title: Text(a.serviceName),
                              subtitle: Text('기본 ${formatMinutes(a.defaultDurationMinutes ?? 0)}'),
                            ),
                          ),
                          if (a.active)
                            SizedBox(
                              width: 96,
                              child: TextFormField(
                                initialValue: a.customDurationMinutes?.toString() ?? '',
                                decoration: const InputDecoration(isDense: true, labelText: '개별 소요', suffixText: '분'),
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                onChanged: (v) => vm.setDuration(a.serviceId, int.tryParse(v)),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.schedule),
                      title: const Text('근무 일정'),
                      subtitle: const Text('요일별 반복 근무시간과 휴게시간'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => pushPage<void>(context, StaffScheduleScreen(ctx: ctx, staff: data.member)),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.beach_access_outlined),
                      title: const Text('휴가 및 예외 일정'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => pushPage<void>(context, ExceptionsScreen(ctx: ctx, initialStaff: data.member)),
                    ),
                  ],
                ),
              ),
              if (ctx.isOwner && data.member.isActive) ...[
                const SizedBox(height: 16),
                AppButton(
                  label: '직원 비활성화',
                  variant: AppButtonVariant.danger,
                  loading: vm.isBusy('deactivate'),
                  onPressed: () async {
                    final ok = await showConfirmDialog(
                      context,
                      title: '${data.member.displayName} 직원을 비활성화할까요?',
                      message: '비활성화하면 더 이상 예약을 받을 수 없어요.\n예정된 예약이 있으면 비활성화할 수 없어요.',
                      confirmLabel: '비활성화',
                      destructive: true,
                    );
                    if (!ok || !context.mounted) return;
                    final result = await vm.deactivate();
                    if (result == null || !context.mounted) return;
                    if (result.updated) {
                      AppMessenger.show('직원을 비활성화했어요.');
                    } else {
                      await showConflictDialog(
                        context,
                        ctx.storeId,
                        result,
                        title: '비활성화할 수 없어요',
                        message: _futureReservationWarning,
                      );
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoEditor extends StatefulWidget {
  const _InfoEditor({super.key, required this.member, required this.canChangeRole, required this.busy, required this.onSave});

  final StaffMember member;
  final bool canChangeRole;
  final bool busy;
  final Future<void> Function(String name, StoreRole role, bool booking, MemberStatus status) onSave;

  @override
  State<_InfoEditor> createState() => _InfoEditorState();
}

class _InfoEditorState extends State<_InfoEditor> {
  late final _name = TextEditingController(text: widget.member.displayName);
  late StoreRole _role = widget.member.role;
  late bool _booking = widget.member.bookingEnabled;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '기본 정보',
      child: Column(
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: '표시 이름'), maxLength: 100),
          DropdownButtonFormField<StoreRole>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: '역할'),
            items: [for (final r in StoreRole.values) DropdownMenuItem(value: r, child: Text(r.label))],
            onChanged: widget.canChangeRole ? (r) => setState(() => _role = r ?? _role) : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('예약 가능'),
            subtitle: const Text('끄면 고객 예약 화면에서 선택할 수 없어요.'),
            value: _booking,
            onChanged: (v) => setState(() => _booking = v),
          ),
          InfoRow(label: '근무 상태', value: widget.member.status.label),
          const SizedBox(height: 8),
          AppButton(
            label: '정보 저장',
            loading: widget.busy,
            onPressed: _name.text.trim().isEmpty
                ? null
                : () => widget.onSave(_name.text.trim(), _role, _booking, widget.member.status),
          ),
        ],
      ),
    );
  }
}

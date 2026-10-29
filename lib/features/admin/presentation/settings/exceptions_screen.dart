import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/domain/paged.dart';
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
import '../../domain/admin_repositories.dart';
import '../../domain/admin_settings_usecases.dart';
import '../admin_common.dart';

class ExceptionsViewModel extends LoadableViewModel<List<ScheduleException>> {
  ExceptionsViewModel(this.storeId, StoreSettingsRepository repository, this._bus, {this.staff})
    : _manage = ManageExceptions(repository),
      _staffList = GetStaffMembers(repository);

  final String storeId;
  final RefreshBus _bus;
  final ManageExceptions _manage;
  final GetStaffMembers _staffList;

  /// null이면 매장 전체 일정
  StaffMember? staff;
  List<StaffMember> staffOptions = [];

  @override
  Future<List<ScheduleException>> fetch() async {
    if (staffOptions.isEmpty) {
      try {
        staffOptions = (await _staffList(storeId)).where((s) => s.isActive).toList();
      } on AppFailure {
        staffOptions = [];
      }
    }
    final items = staff == null ? await _manage.store(storeId) : await _manage.staff(storeId, staff!.id);
    return items..sort((a, b) => a.targetDate.compareTo(b.targetDate));
  }

  void setTarget(StaffMember? value) {
    staff = value;
    load();
  }

  Future<UpdateResult?> _write(String action, Future<UpdateResult> Function() task) async {
    UpdateResult? result;
    await runAction(action, () async {
      result = await task();
      if (result!.updated) {
        _bus.emit({RefreshTopic.adminSettings, RefreshTopic.availability, RefreshTopic.storeDetail});
        await refresh();
      }
    });
    return result;
  }

  Future<UpdateResult?> create(ExceptionInput input) => _write(
    'create',
    () => staff == null ? _manage.createForStore(storeId, input) : _manage.createForStaff(storeId, staff!.id, input),
  );

  Future<UpdateResult?> delete(String id) => _write(
    'delete:$id',
    () => staff == null ? _manage.deleteForStore(storeId, id) : _manage.deleteForStaff(storeId, staff!.id, id),
  );
}

/// A-13 휴무 및 예외 일정. 충돌 예약은 자동 취소하지 않고 관리자가 개별 처리한다.
class ExceptionsScreen extends StatelessWidget {
  const ExceptionsScreen({super.key, required this.ctx, this.initialStaff});

  final OperatorContext ctx;
  final StaffMember? initialStaff;

  static const _conflictMessage =
      '이 일정과 겹치는 예약이 있어 등록하지 않았어요.\n예약은 자동으로 취소되지 않아요. 아래 예약을 먼저 변경하거나 취소한 뒤 다시 등록해 주세요.';

  Future<void> _add(BuildContext context, ExceptionsViewModel vm) async {
    final input = await showModalBottomSheet<ExceptionInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ExceptionForm(forStaff: vm.staff != null),
    );
    if (input == null || !context.mounted) return;
    final result = await vm.create(input);
    if (result == null || !context.mounted) return;
    if (result.updated) {
      AppMessenger.show('일정을 등록했어요.');
    } else {
      await showConflictDialog(context, ctx.storeId, result, title: '기존 예약과 충돌해요', message: _conflictMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<ExceptionsViewModel>(
      create: () => ExceptionsViewModel(
        ctx.storeId,
        GetIt.I<StoreSettingsRepository>(),
        GetIt.I<RefreshBus>(),
        staff: initialStaff,
      ),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: const Text('휴무 및 예외 일정')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _add(context, vm),
          icon: const Icon(Icons.add),
          label: const Text('일정 추가'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: DropdownButtonFormField<String?>(
                initialValue: vm.staff?.id,
                decoration: const InputDecoration(labelText: '대상'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('매장 전체')),
                  for (final s in vm.staffOptions) DropdownMenuItem(value: s.id, child: Text('${s.displayName} 직원')),
                  if (vm.staff != null && vm.staffOptions.every((s) => s.id != vm.staff!.id))
                    DropdownMenuItem(value: vm.staff!.id, child: Text('${vm.staff!.displayName} 직원')),
                ],
                onChanged: (id) => vm.setTarget(
                  id == null ? null : (vm.staffOptions.where((s) => s.id == id).firstOrNull ?? vm.staff),
                ),
              ),
            ),
            Expanded(
              child: LoadableBody<List<ScheduleException>>(
                vm: vm,
                builder: (context, items) {
                  if (items.isEmpty) {
                    return ListView(
                      children: const [SizedBox(height: 80), EmptyView(icon: Icons.event_available, title: '등록된 예외 일정이 없어요.')],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final e = items[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.event_busy, color: AppColors.danger),
                          title: Text('${formatYmdLabel(e.targetDate)} · ${e.typeLabel}'),
                          subtitle: Text([e.timeLabel, if (e.reason != null) e.reason!].join(' · ')),
                          trailing: IconButton(
                            tooltip: '삭제',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: vm.isBusy('delete:${e.id}')
                                ? null
                                : () async {
                                    final ok = await showConfirmDialog(
                                      context,
                                      title: '이 일정을 삭제할까요?',
                                      message: '${formatYmdLabel(e.targetDate)} ${e.typeLabel} 일정이 삭제되고 원래 일정으로 돌아가요.',
                                      confirmLabel: '삭제',
                                      destructive: true,
                                    );
                                    if (!ok || !context.mounted) return;
                                    final result = await vm.delete(e.id);
                                    if (result != null && context.mounted) {
                                      await handleUpdateResult(context, ctx.storeId, result, successMessage: '일정을 삭제했어요.');
                                    }
                                  },
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

class _ExceptionForm extends StatefulWidget {
  const _ExceptionForm({required this.forStaff});

  final bool forStaff;

  @override
  State<_ExceptionForm> createState() => _ExceptionFormState();
}

class _ExceptionFormState extends State<_ExceptionForm> {
  late String _type = widget.forStaff ? StaffExceptionType.dayOff.code : StoreExceptionType.closedAllDay.code;
  DateTime _date = storeToday().add(const Duration(days: 1));
  String _start = '10:00';
  String _end = '12:00';
  final _reason = TextEditingController();

  List<(String, String, bool)> get _types => widget.forStaff
      ? [for (final t in StaffExceptionType.values) (t.code, t.label, t.needsTime)]
      : [for (final t in StoreExceptionType.values) (t.code, t.label, t.needsTime)];

  bool get _needsTime => _types.firstWhere((t) => t.$1 == _type).$3;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('예외 일정 추가', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (code, label, _) in _types)
                  ChoiceChip(label: Text(label), selected: _type == code, onSelected: (_) => setState(() => _type = code)),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(formatCalendarDate(_date)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: storeToday(),
                  lastDate: storeToday().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _date = DateTime.utc(picked.year, picked.month, picked.day));
              },
            ),
            if (_needsTime)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final v = await pickHm(context, initial: _start, helpText: '시작 시간');
                        if (v != null) setState(() => _start = v);
                      },
                      child: Text('시작 ${formatHm(_start)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final v = await pickHm(context, initial: _end, helpText: '종료 시간');
                        if (v != null) setState(() => _end = v);
                      },
                      child: Text('종료 ${formatHm(_end)}'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            TextField(controller: _reason, decoration: const InputDecoration(labelText: '사유'), maxLength: 500),
            const NoticeBox(message: '기존 예약과 겹치면 등록하지 않고 충돌 예약을 보여드려요. 예약은 자동으로 취소되지 않아요.'),
            const SizedBox(height: 12),
            AppButton(
              label: '등록',
              onPressed: _needsTime && _start.compareTo(_end) >= 0
                  ? null
                  : () => Navigator.pop(
                      context,
                      ExceptionInput(
                        targetDate: formatYmd(_date),
                        typeCode: _type,
                        startTime: _needsTime ? _start : null,
                        endTime: _needsTime ? _end : null,
                        reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/domain/paged.dart';
import '../../../../core/presentation/view_model.dart';
import '../../../../core/realtime/refresh_bus.dart';
import '../../../../core/utils/date_time_format.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/view_model_scope.dart';
import '../../../store/domain/store_entities.dart';
import '../../domain/admin_entities.dart';
import '../../domain/admin_repositories.dart';
import '../../domain/admin_settings_usecases.dart';
import '../admin_common.dart';
import 'period_editor.dart';

class StaffScheduleViewModel extends LoadableViewModel<List<StaffScheduleEntry>> {
  StaffScheduleViewModel(this.storeId, this.staffId, StoreSettingsRepository repository, this._bus)
    : _manage = ManageStaffSchedule(repository);

  final String storeId;
  final String staffId;
  final RefreshBus _bus;
  final ManageStaffSchedule _manage;

  Map<String, List<(String, String)>> days = {};
  DateTime validFrom = storeToday();
  DateTime? validUntil;

  @override
  Future<List<StaffScheduleEntry>> fetch() async {
    final entries = await _manage.entries(storeId, staffId);
    days = {for (final w in toWeeklySchedules(entries)) w.dayOfWeek: [...w.periods]};
    final from = entries.map((e) => parseYmd(e.validFrom)).whereType<DateTime>().toList()..sort();
    if (from.isNotEmpty && from.first.isAfter(storeToday())) validFrom = from.first;
    validUntil = entries.map((e) => parseYmd(e.validUntil)).whereType<DateTime>().firstOrNull;
    return entries;
  }

  void setDay(String day, List<(String, String)> periods) {
    days = {...days, day: periods};
    notify();
  }

  void setRange({DateTime? from, DateTime? until, bool clearUntil = false}) {
    validFrom = from ?? validFrom;
    validUntil = clearUntil ? null : (until ?? validUntil);
    notify();
  }

  Future<UpdateResult?> save() async {
    UpdateResult? result;
    await runAction('save', () async {
      result = await _manage.save(
        storeId,
        staffId,
        [for (final d in dayOfWeekCodes) WeeklySchedule(dayOfWeek: d, periods: days[d] ?? const [])],
        validFrom: formatYmd(validFrom),
        validUntil: validUntil == null ? null : formatYmd(validUntil!),
      );
      if (result!.updated) {
        _bus.emit({RefreshTopic.adminSettings, RefreshTopic.availability});
        await refresh();
      }
    });
    return result;
  }
}

/// A-12 근무 일정 관리 (직원별 반복 근무시간)
class StaffScheduleScreen extends StatelessWidget {
  const StaffScheduleScreen({super.key, required this.ctx, required this.staff});

  final OperatorContext ctx;
  final StaffMember staff;

  Future<DateTime?> _pick(BuildContext context, DateTime initial) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    return picked == null ? null : DateTime.utc(picked.year, picked.month, picked.day);
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<StaffScheduleViewModel>(
      create: () => StaffScheduleViewModel(ctx.storeId, staff.id, GetIt.I<StoreSettingsRepository>(), GetIt.I<RefreshBus>()),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: Text('${staff.displayName} 근무 일정')),
        body: LoadableBody<List<StaffScheduleEntry>>(
          vm: vm,
          pullToRefresh: false,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const NoticeBox(message: '목록 전체를 한 번에 저장해요. 근무 시간이 없는 요일은 휴무로 처리돼요.'),
              const SizedBox(height: 12),
              SectionCard(
                title: '적용 기간',
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('적용 시작일'),
                      trailing: Text(formatCalendarDate(vm.validFrom)),
                      onTap: () async {
                        final d = await _pick(context, vm.validFrom);
                        if (d != null) vm.setRange(from: d);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('적용 종료일'),
                      subtitle: vm.validUntil == null ? const Text('종료일 없음') : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (vm.validUntil != null) Text(formatCalendarDate(vm.validUntil!)),
                          if (vm.validUntil != null)
                            IconButton(
                              tooltip: '종료일 없애기',
                              onPressed: () => vm.setRange(clearUntil: true),
                              icon: const Icon(Icons.close),
                            ),
                        ],
                      ),
                      onTap: () async {
                        final d = await _pick(context, vm.validUntil ?? vm.validFrom.add(const Duration(days: 30)));
                        if (d != null) vm.setRange(until: d);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < dayOfWeekCodes.length; i++)
                DayPeriodEditor(
                  dayLabel: dayOfWeekLabels[i],
                  periods: vm.days[dayOfWeekCodes[i]] ?? const [],
                  onChanged: (p) => vm.setDay(dayOfWeekCodes[i], p),
                ),
            ],
          ),
        ),
        bottomNavigationBar: BottomActionBar(
          children: [
            AppButton(
              label: '근무 일정 저장',
              loading: vm.isBusy('save'),
              onPressed: () async {
                final result = await vm.save();
                if (result != null && context.mounted) {
                  await handleUpdateResult(
                    context,
                    ctx.storeId,
                    result,
                    successMessage: '근무 일정을 저장했어요.',
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

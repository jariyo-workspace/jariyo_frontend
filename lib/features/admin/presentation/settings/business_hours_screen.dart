import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/domain/paged.dart';
import '../../../../core/presentation/view_model.dart';
import '../../../../core/realtime/refresh_bus.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/view_model_scope.dart';
import '../../../store/domain/store_entities.dart';
import '../../domain/admin_repositories.dart';
import '../../domain/admin_settings_usecases.dart';
import '../admin_common.dart';
import 'period_editor.dart';

class BusinessHoursViewModel extends LoadableViewModel<List<BusinessDay>> {
  BusinessHoursViewModel(this.storeId, StoreSettingsRepository repository, this._bus)
    : _manage = ManageBusinessHours(repository);

  final String storeId;
  final RefreshBus _bus;
  final ManageBusinessHours _manage;
  List<BusinessDay> editing = [];

  @override
  Future<List<BusinessDay>> fetch() async {
    final days = await _manage.load(storeId);
    editing = [...days];
    return days;
  }

  void setDay(String code, List<(String, String)> periods) {
    editing = [
      for (final d in editing)
        d.dayOfWeek == code
            ? BusinessDay(
                dayOfWeek: code,
                isClosed: periods.isEmpty,
                periods: [for (final (s, e) in periods) TimePeriod(start: s, end: e)],
              )
            : d,
    ];
    notify();
  }

  Future<UpdateResult?> save() async {
    UpdateResult? result;
    await runAction('save', () async {
      result = await _manage.save(storeId, editing);
      if (result!.updated) {
        _bus.emit({RefreshTopic.adminSettings, RefreshTopic.storeDetail, RefreshTopic.availability});
        await refresh();
      }
    });
    return result;
  }
}

/// 매장 영업시간. 전체 교체 요청이며 운영하지 않는 요일은 휴무로 저장한다.
class BusinessHoursScreen extends StatelessWidget {
  const BusinessHoursScreen({super.key, required this.ctx});

  final OperatorContext ctx;

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<BusinessHoursViewModel>(
      create: () => BusinessHoursViewModel(ctx.storeId, GetIt.I<StoreSettingsRepository>(), GetIt.I<RefreshBus>()),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: const Text('영업시간')),
        body: LoadableBody<List<BusinessDay>>(
          vm: vm,
          pullToRefresh: false,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final day in vm.editing)
                DayPeriodEditor(
                  dayLabel: dayOfWeekLabel(day.dayOfWeek),
                  periods: day.isClosed ? const [] : [for (final p in day.periods) (p.start, p.end)],
                  defaultPeriod: ('10:00', '20:00'),
                  onChanged: (p) => vm.setDay(day.dayOfWeek, p),
                ),
            ],
          ),
        ),
        bottomNavigationBar: BottomActionBar(
          children: [
            AppButton(
              label: '영업시간 저장',
              loading: vm.isBusy('save'),
              onPressed: () async {
                final result = await vm.save();
                if (result != null && context.mounted) {
                  await handleUpdateResult(context, ctx.storeId, result, successMessage: '영업시간을 저장했어요.');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

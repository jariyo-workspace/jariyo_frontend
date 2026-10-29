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
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/view_model_scope.dart';
import '../../store/domain/store_entities.dart';
import '../../store/domain/store_repository.dart';
import '../../store/domain/store_usecases.dart';
import '../domain/waitlist_entities.dart';
import '../domain/waitlist_repository.dart';
import '../domain/waitlist_usecases.dart';
import 'waitlist_detail_screen.dart';

class WaitlistApplyViewModel extends ViewModel {
  WaitlistApplyViewModel({
    required this.storeId,
    required this.serviceId,
    required WaitlistRepository repository,
    required StoreRepository storeRepository,
    required this._bus,
    this.existing,
    String? staffId,
    String? staffName,
    DateTime? date,
    String? startTime,
    String? endTime,
    this.partySize = 1,
  }) : _apply = ApplyWaitlist(repository),
       _update = UpdateWaitlist(repository),
       _myWaitlists = GetMyWaitlists(repository),
       _getStaff = GetServiceStaff(storeRepository) {
    final entry = existing;
    if (entry != null) {
      this.date = parseYmd(entry.desiredDate) ?? storeToday();
      this.startTime = entry.acceptableStartTime;
      this.endTime = entry.acceptableEndTime;
      preference = entry.staffPreferenceType;
      this.staffId = entry.preferredStaff?.id ?? entry.preferredStaffId;
      this.staffName = entry.preferredStaff?.name;
    } else {
      this.date = date ?? storeToday();
      this.startTime = startTime ?? '10:00';
      this.endTime = endTime ?? '18:00';
      this.staffId = staffId;
      this.staffName = staffName;
      preference = staffId == null ? StaffPreferenceType.anyStaff : StaffPreferenceType.specificPreferred;
    }
  }

  final String storeId;
  final String serviceId;
  final WaitlistEntry? existing;
  final RefreshBus _bus;
  final ApplyWaitlist _apply;
  final UpdateWaitlist _update;
  final GetMyWaitlists _myWaitlists;
  final GetServiceStaff _getStaff;
  final _keys = IdempotencyKeyHolder();

  late DateTime date;
  late String startTime;
  late String endTime;
  late StaffPreferenceType preference;
  String? staffId;
  String? staffName;
  int partySize;
  List<StaffOption> staffOptions = [];
  String? timeError;
  String? dateError;

  bool get editing => existing != null;

  bool get submitting => isBusy('submit');

  Future<void> loadStaff() async {
    try {
      staffOptions = (await _getStaff(storeId, serviceId)).where((s) => s.bookingEnabled).toList();
      notify();
    } on AppFailure {
      // 직원 목록을 불러오지 못하면 "직원 무관"만 선택할 수 있다.
    }
  }

  void setDate(DateTime value) {
    date = value;
    dateError = null;
    notify();
  }

  void setTimes({String? start, String? end}) {
    startTime = start ?? startTime;
    endTime = end ?? endTime;
    timeError = null;
    notify();
  }

  void setStaff(StaffOption? staff) {
    staffId = staff?.id;
    staffName = staff?.displayName;
    if (staff == null) {
      preference = StaffPreferenceType.anyStaff;
    } else if (preference == StaffPreferenceType.anyStaff) {
      preference = StaffPreferenceType.specificPreferred;
    }
    notify();
  }

  void setOthersAllowed(bool allowed) {
    if (staffId == null) return;
    preference = allowed ? StaffPreferenceType.specificPreferred : StaffPreferenceType.specificOnly;
    notify();
  }

  String get summary => describeWaitlistCondition(
    desiredDate: formatYmd(date),
    startTime: startTime,
    endTime: endTime,
    preference: preference,
    staffName: staffName,
  );

  /// 성공 시 이동할 대기 ID
  Future<String?> submit() async {
    if (startTime.compareTo(endTime) >= 0) {
      timeError = '가능한 종료 시간은 시작 시간보다 늦어야 해요.';
      notify();
      return null;
    }
    String? resultId;
    if (editing) {
      await runAction(
        'submit',
        () async {
          await _update(
            existing!.id,
            WaitlistUpdate(
              preferredStaffId: preference == StaffPreferenceType.anyStaff ? null : staffId,
              staffPreferenceType: preference,
              acceptableStartTime: startTime,
              acceptableEndTime: endTime,
            ),
          );
          _bus.emit(RefreshBus.afterWaitlistChanged);
          AppMessenger.show('대기 조건을 변경했어요.');
          resultId = existing!.id;
        },
        onFailure: _handleFailure,
      );
      return resultId;
    }
    final request = NewWaitlist(
      storeId: storeId,
      serviceId: serviceId,
      preferredStaffId: preference == StaffPreferenceType.anyStaff ? null : staffId,
      staffPreferenceType: preference,
      desiredDate: formatYmd(date),
      acceptableStartTime: startTime,
      acceptableEndTime: endTime,
      partySize: partySize,
    );
    final key = _keys.keyFor(request.toJson());
    await runAction(
      'submit',
      () async {
        final entry = await _apply(request, idempotencyKey: key);
        _keys.settle();
        _bus.emit(RefreshBus.afterWaitlistChanged);
        AppMessenger.show('예약 대기를 신청했어요.');
        resultId = entry.id;
      },
      onFailure: (failure) {
        if (failure.kind != FailureKind.unknownOutcome) _keys.settle();
        if (failure.code == 'WAITLIST_DUPLICATED') {
          _openExisting(failure);
          return true;
        }
        return _handleFailure(failure);
      },
    );
    return resultId;
  }

  String? duplicatedId;

  Future<void> _openExisting(AppFailure failure) async {
    try {
      final mine = await _myWaitlists();
      duplicatedId = mine
          .where((w) => w.status.isActive && (w.serviceId ?? w.service?.id) == serviceId && w.desiredDate == formatYmd(date))
          .firstOrNull
          ?.id;
    } on AppFailure {
      duplicatedId = null;
    }
    AppMessenger.show('이미 같은 조건으로 대기 중이에요.');
    notify();
  }

  bool _handleFailure(AppFailure failure) {
    switch (failure.code) {
      case 'INVALID_WAITLIST_TIME_RANGE':
        timeError = failure.message;
      case 'WAITLIST_DATE_OUT_OF_RANGE':
        dateError = '${failure.message} 다른 날짜를 선택해 주세요.';
      case 'WAITLIST_NOT_ENABLED':
        AppMessenger.show('이 매장은 예약 대기를 운영하지 않아요.');
      case 'WAITLIST_NOT_EDITABLE':
        AppMessenger.show('지금은 대기 조건을 변경할 수 없어요.');
      default:
        return false;
    }
    notify();
    return true;
  }
}

/// C-11 예약 대기 신청 (기존 대기를 넘기면 조건 수정)
class WaitlistApplyScreen extends StatelessWidget {
  const WaitlistApplyScreen({
    super.key,
    required this.storeId,
    required this.storeName,
    required this.serviceId,
    required this.serviceName,
    this.staffId,
    this.staffName,
    this.date,
    this.startTime,
    this.endTime,
    this.partySize = 1,
    this.existing,
  });

  WaitlistApplyScreen.edit({super.key, required WaitlistEntry entry})
    : storeId = entry.effectiveStoreId ?? '',
      storeName = entry.store?.name ?? '',
      serviceId = entry.service?.id ?? entry.serviceId ?? '',
      serviceName = entry.service?.name ?? '',
      staffId = null,
      staffName = null,
      date = null,
      startTime = null,
      endTime = null,
      partySize = 1,
      existing = entry;

  final String storeId;
  final String storeName;
  final String serviceId;
  final String serviceName;
  final String? staffId;
  final String? staffName;
  final DateTime? date;
  final String? startTime;
  final String? endTime;
  final int partySize;
  final WaitlistEntry? existing;

  Future<void> _pickDate(BuildContext context, WaitlistApplyViewModel vm) async {
    final today = storeToday();
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.date.isBefore(today) ? today : vm.date,
      firstDate: today,
      lastDate: today.add(const Duration(days: 90)),
      helpText: '희망 날짜',
    );
    if (picked != null) vm.setDate(DateTime.utc(picked.year, picked.month, picked.day));
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<WaitlistApplyViewModel>(
      create: () => WaitlistApplyViewModel(
        storeId: storeId,
        serviceId: serviceId,
        repository: GetIt.I<WaitlistRepository>(),
        storeRepository: GetIt.I<StoreRepository>(),
        bus: GetIt.I<RefreshBus>(),
        existing: existing,
        staffId: staffId,
        staffName: staffName,
        date: date,
        startTime: startTime,
        endTime: endTime,
        partySize: partySize,
      ),
      onReady: (vm) => vm.loadStaff(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: Text(vm.editing ? '대기 조건 수정' : '예약 대기 신청')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SectionCard(
              child: Column(
                children: [
                  InfoRow(label: '매장', value: storeName),
                  InfoRow(label: '서비스', value: serviceName),
                ],
              ),
            ),
            const SectionTitle('희망 날짜'),
            ListTile(
              tileColor: Colors.white,
              enabled: !vm.editing,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: vm.dateError == null ? AppColors.border : AppColors.danger),
              ),
              leading: const Icon(Icons.calendar_today),
              title: Text(formatCalendarDate(vm.date)),
              subtitle: vm.editing ? const Text('희망 날짜는 변경할 수 없어요.') : null,
              trailing: vm.editing ? null : const Icon(Icons.edit_calendar),
              onTap: vm.editing ? null : () => _pickDate(context, vm),
            ),
            if (vm.dateError != null) _ErrorText(vm.dateError!),
            const SectionTitle('가능한 시간'),
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    label: '시작',
                    value: vm.startTime,
                    onTap: () async {
                      final value = await pickHm(context, initial: vm.startTime, helpText: '가능한 시작 시간');
                      if (value != null) vm.setTimes(start: value);
                    },
                  ),
                ),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('~')),
                Expanded(
                  child: _TimeField(
                    label: '종료',
                    value: vm.endTime,
                    onTap: () async {
                      final value = await pickHm(context, initial: vm.endTime, helpText: '가능한 종료 시간');
                      if (value != null) vm.setTimes(end: value);
                    },
                  ),
                ),
              ],
            ),
            if (vm.timeError != null) _ErrorText(vm.timeError!),
            const SectionTitle('선호 직원'),
            Card(
              child: Column(
                children: [
                  RadioGroup<String?>(
                    groupValue: vm.staffId,
                    onChanged: (value) =>
                        vm.setStaff(value == null ? null : vm.staffOptions.where((s) => s.id == value).firstOrNull),
                    child: Column(
                      children: [
                        const RadioListTile<String?>(value: null, title: Text('직원 무관')),
                        for (final staff in vm.staffOptions)
                          RadioListTile<String?>(value: staff.id, title: Text(staff.displayName)),
                        if (vm.staffId != null && vm.staffOptions.every((s) => s.id != vm.staffId))
                          RadioListTile<String?>(value: vm.staffId, title: Text(vm.staffName ?? '선택한 직원')),
                      ],
                    ),
                  ),
                  if (vm.staffId != null) ...[
                    const Divider(),
                    SwitchListTile(
                      value: vm.preference == StaffPreferenceType.specificPreferred,
                      onChanged: vm.setOthersAllowed,
                      title: const Text('다른 직원도 가능해요'),
                      subtitle: Text(vm.preference.label),
                    ),
                  ],
                ],
              ),
            ),
            if (!vm.editing) ...[
              const SectionTitle('인원'),
              Align(
                alignment: Alignment.centerLeft,
                child: NumberStepper(value: vm.partySize, unit: '명', onChanged: (v) {
                  vm.partySize = v;
                  vm.notify();
                }),
              ),
            ],
            const SectionTitle('대기 만료'),
            const Text(
              '희망 날짜의 가능한 시간이 지나면 대기가 자동으로 종료돼요.',
              style: TextStyle(color: AppColors.lightText),
            ),
            const SizedBox(height: 20),
            SectionCard(
              title: '조건 요약',
              child: Text(vm.summary, style: const TextStyle(fontSize: 15, height: 1.6)),
            ),
            const SizedBox(height: 12),
            const NoticeBox(message: '대기 신청은 예약 확정이 아니에요.\n빈자리가 생기면 제한 시간 동안 예약 기회를 드려요.'),
            if (vm.duplicatedId != null) ...[
              const SizedBox(height: 12),
              AppButton(
                label: '기존 대기 보기',
                variant: AppButtonVariant.secondary,
                onPressed: () => replacePage<void>(context, WaitlistDetailScreen(waitlistId: vm.duplicatedId!)),
              ),
            ],
          ],
        ),
        bottomNavigationBar: BottomActionBar(
          children: [
            AppButton(
              label: vm.editing ? '조건 저장' : '예약 대기 신청',
              loading: vm.submitting,
              loadingLabel: vm.editing ? '저장하고 있어요' : '대기를 신청하고 있어요',
              onPressed: () async {
                final id = await vm.submit();
                if (id == null || !context.mounted) return;
                if (vm.editing) {
                  Navigator.pop(context);
                } else {
                  replacePage<void>(context, WaitlistDetailScreen(waitlistId: id));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label 시간 ${formatHm(value)}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.schedule)),
          child: Text(formatHm(value)),
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(text, style: const TextStyle(color: AppColors.danger)),
  );
}

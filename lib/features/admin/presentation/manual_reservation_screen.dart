import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../../core/network/idempotency.dart';
import '../../../core/presentation/view_model.dart';
import '../../../core/realtime/refresh_bus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_time_format.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/view_model_scope.dart';
import '../../store/domain/store_entities.dart';
import '../../store/domain/store_repository.dart';
import '../../store/domain/store_usecases.dart';
import '../domain/admin_entities.dart';
import '../domain/admin_operation_usecases.dart';
import '../domain/admin_repositories.dart';

class ManualReservationViewModel extends LoadableViewModel<List<ServiceItem>> {
  ManualReservationViewModel({
    required this.storeId,
    required StoreRepository stores,
    required AdminOperationRepository operations,
    required this._bus,
    this.initialStaffName,
    DateTime? initialDate,
    this.initialTime,
  }) : _services = GetStoreServices(stores),
       _staff = GetServiceStaff(stores),
       _availability = GetAvailability(stores),
       _create = CreateManualReservation(operations),
       date = initialDate ?? storeToday();

  final String storeId;
  final RefreshBus _bus;
  final GetStoreServices _services;
  final GetServiceStaff _staff;
  final GetAvailability _availability;
  final CreateManualReservation _create;
  final _keys = IdempotencyKeyHolder();
  final String? initialStaffName;
  final String? initialTime;

  ServiceItem? service;
  StaffOption? staff;
  List<StaffOption> staffOptions = [];
  DateTime date;
  List<TimeOption> options = [];
  bool slotsLoading = false;
  TimeSlot? slot;
  int partySize = 1;
  bool sendNotification = true;

  /// 선택한 시간에 충돌이 있으면 원인을 표시하고 저장을 막는다.
  String? conflictMessage;

  @override
  Future<List<ServiceItem>> fetch() async => (await _services(storeId)).where((s) => s.isActive).toList();

  Future<void> selectService(ServiceItem value) async {
    service = value;
    staff = null;
    slot = null;
    options = [];
    notify();
    try {
      staffOptions = (await _staff(storeId, value.id)).where((s) => s.bookingEnabled).toList();
      staff = staffOptions.where((s) => s.displayName == initialStaffName).firstOrNull ?? staffOptions.firstOrNull;
    } on AppFailure catch (failure) {
      AppMessenger.showFailure(failure);
    }
    await loadSlots();
  }

  Future<void> selectStaff(StaffOption value) async {
    staff = value;
    slot = null;
    await loadSlots();
  }

  Future<void> setDate(DateTime value) async {
    date = value;
    slot = null;
    await loadSlots();
  }

  Future<void> loadSlots() async {
    final s = service;
    final member = staff;
    if (s == null || member == null) return;
    slotsLoading = true;
    conflictMessage = null;
    notify();
    try {
      final days = await _availability(
        storeId: storeId,
        serviceId: s.id,
        staffId: member.id,
        from: date,
        to: date,
        partySize: partySize,
      );
      options = days.expand((d) => d.timeOptions).toList();
      if (slot == null && initialTime != null) {
        final wanted = options.where((o) {
          final t = toStoreTime(o.startAt);
          return hmOf(t.hour, t.minute) == initialTime;
        }).firstOrNull;
        if (wanted != null) selectOption(wanted);
      }
    } on AppFailure catch (failure) {
      options = [];
      AppMessenger.showFailure(failure);
    } finally {
      slotsLoading = false;
      notify();
    }
  }

  void selectOption(TimeOption option) {
    final available = option.availableFor(staff!.id) ?? option.firstAvailable;
    if (available == null) {
      slot = null;
      conflictMessage = '${staff!.displayName}에게 같은 시간의 예약이 있어요.';
    } else {
      slot = available;
      conflictMessage = null;
    }
    notify();
  }

  bool get canSave => slot != null && service != null && conflictMessage == null && !isBusy('save');

  Future<bool> save({required String guestName, required String guestPhone, required String note}) async {
    final request = ManualReservationRequest(
      guestName: guestName.trim(),
      guestPhoneNumber: guestPhone,
      serviceId: service!.id,
      staffId: slot!.staffId,
      startAt: slot!.startAtRaw,
      partySize: partySize,
      storeNote: note.trim().isEmpty ? null : note.trim(),
      sendNotification: sendNotification,
    );
    final key = _keys.keyFor(request.toJson());
    return runAction(
      'save',
      () async {
        await _create(storeId, request, idempotencyKey: key);
        _keys.settle();
        _bus.emit(RefreshBus.afterAdminReservationChanged);
        AppMessenger.show('예약을 등록했어요.');
      },
      onFailure: (failure) {
        if (failure.kind != FailureKind.unknownOutcome) _keys.settle();
        if (failure.code == 'RESERVATION_SLOT_ALREADY_TAKEN' || failure.code == 'STAFF_NOT_AVAILABLE') {
          // 저장하지 않고 가능한 시간 재선택을 유도한다.
          slot = null;
          conflictMessage = '${staff?.displayName ?? '직원'}에게 같은 시간의 예약이 있어요. 다른 시간을 선택해 주세요.';
          loadSlots();
          return true;
        }
        return false;
      },
    );
  }
}

/// A-05 수동 예약 등록 (전화·방문 예약)
class ManualReservationScreen extends StatefulWidget {
  const ManualReservationScreen({
    super.key,
    required this.storeId,
    this.initialStaffName,
    this.initialDate,
    this.initialTime,
  });

  final String storeId;
  final String? initialStaffName;
  final DateTime? initialDate;
  final String? initialTime;

  @override
  State<ManualReservationScreen> createState() => _ManualReservationScreenState();
}

class _ManualReservationScreenState extends State<ManualReservationScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  String? _nameError;
  String? _phoneError;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save(ManualReservationViewModel vm) async {
    setState(() {
      _nameError = _name.text.trim().isEmpty ? '고객 이름을 입력해 주세요.' : null;
      _phoneError = RegExp(r'^01\d{8,9}$').hasMatch(_phone.text) ? null : '휴대폰 번호를 숫자만 입력해 주세요.';
    });
    if (_nameError != null || _phoneError != null) return;
    final ok = await vm.save(guestName: _name.text, guestPhone: _phone.text, note: _note.text);
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<ManualReservationViewModel>(
      create: () => ManualReservationViewModel(
        storeId: widget.storeId,
        stores: GetIt.I<StoreRepository>(),
        operations: GetIt.I<AdminOperationRepository>(),
        bus: GetIt.I<RefreshBus>(),
        initialStaffName: widget.initialStaffName,
        initialDate: widget.initialDate,
        initialTime: widget.initialTime,
      ),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: const Text('수동 예약 등록')),
        body: LoadableBody<List<ServiceItem>>(
          vm: vm,
          pullToRefresh: false,
          builder: (context, services) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SectionTitle('고객 정보'),
              const FieldLabel('이름'),
              AppTextField(controller: _name, hint: '고객 이름', error: _nameError),
              const SizedBox(height: 12),
              const FieldLabel('연락처'),
              AppTextField(
                controller: _phone,
                hint: '01012345678',
                error: _phoneError,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 11,
              ),
              const SectionTitle('서비스'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in services)
                    ChoiceChip(
                      label: Text('${s.name} · ${formatMinutes(s.durationMinutes)}'),
                      selected: vm.service?.id == s.id,
                      onSelected: (_) => vm.selectService(s),
                    ),
                ],
              ),
              if (vm.service != null) ...[
                const SectionTitle('담당 직원'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in vm.staffOptions)
                      ChoiceChip(label: Text(s.displayName), selected: vm.staff?.id == s.id, onSelected: (_) => vm.selectStaff(s)),
                  ],
                ),
                const SectionTitle('날짜'),
                ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  leading: const Icon(Icons.calendar_today),
                  title: Text(formatCalendarDate(vm.date)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: vm.date,
                      firstDate: storeToday(),
                      lastDate: storeToday().add(const Duration(days: 180)),
                    );
                    if (picked != null) vm.setDate(DateTime.utc(picked.year, picked.month, picked.day));
                  },
                ),
                const SectionTitle('시간'),
                if (vm.slotsLoading)
                  const LinearProgressIndicator()
                else if (vm.options.isEmpty)
                  const Text('선택한 날짜에 근무 시간이 없어요.', style: TextStyle(color: AppColors.lightText))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final o in vm.options)
                        ChoiceChip(
                          label: Text(formatTime(o.startAt)),
                          selected: vm.slot?.startAt == o.startAt,
                          avatar: o.status == SlotStatus.available ? null : const Icon(Icons.block, size: 16),
                          onSelected: (_) => vm.selectOption(o),
                        ),
                    ],
                  ),
                if (vm.conflictMessage != null) ...[
                  const SizedBox(height: 8),
                  NoticeBox(message: vm.conflictMessage!, icon: Icons.event_busy, color: AppColors.danger),
                ],
              ],
              const SectionTitle('인원'),
              Align(
                alignment: Alignment.centerLeft,
                child: NumberStepper(
                  value: vm.partySize,
                  unit: '명',
                  onChanged: (v) {
                    vm.partySize = v;
                    vm.loadSlots();
                  },
                ),
              ),
              const SectionTitle('요청사항'),
              AppTextField(controller: _note, hint: '고객 요청사항이나 메모 (선택)', maxLines: 3, maxLength: 1000),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: vm.sendNotification,
                onChanged: (v) {
                  vm.sendNotification = v;
                  vm.notify();
                },
                title: const Text('고객에게 예약 알림 보내기'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        bottomNavigationBar: BottomActionBar(
          children: [
            AppButton(
              label: '예약 등록',
              loading: vm.isBusy('save'),
              loadingLabel: '예약을 등록하고 있어요',
              onPressed: vm.canSave ? () => _save(vm) : null,
            ),
          ],
        ),
      ),
    );
  }
}

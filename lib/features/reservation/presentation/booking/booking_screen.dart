import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/presentation/view_model.dart';
import '../../../../core/realtime/refresh_bus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_time_format.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/view_model_scope.dart';
import '../../../store/domain/store_entities.dart';
import '../../../store/domain/store_repository.dart';
import '../../../store/domain/store_usecases.dart';
import '../../../waitlist/presentation/waitlist_apply_screen.dart';
import 'booking_confirm_screen.dart';
import 'booking_flow.dart';

class BookingViewModel extends ViewModel {
  BookingViewModel(this.flow, StoreRepository repository, RefreshBus bus)
    : _getServices = GetStoreServices(repository),
      _getStaff = GetServiceStaff(repository),
      _getAvailability = GetAvailability(repository) {
    final openDays = flow.store.policy.bookingOpenDays ?? 14;
    from = storeToday();
    to = from.add(Duration(days: min(max(openDays, 1), 14) - 1));
    selectedDate = from;
    listenTopics(bus, {RefreshTopic.availability}, () => loadAvailability(silent: true));
  }

  final BookingFlow flow;
  final GetStoreServices _getServices;
  final GetServiceStaff _getStaff;
  final GetAvailability _getAvailability;

  List<ServiceItem>? services;
  AppFailure? servicesError;
  List<StaffOption> staff = [];
  bool staffLoading = false;
  List<AvailabilityDay>? days;
  bool slotsLoading = false;
  AppFailure? slotsError;
  late final DateTime from;
  late final DateTime to;
  late DateTime selectedDate;

  /// 동시 예약 충돌 후 보여줄 안내
  String? conflictMessage;

  Future<void> init({String? serviceId, String? staffId}) async {
    try {
      // 비활성 서비스도 "선택할 수 없음"으로 보여주기 위해 전체를 조회한다.
      services = await _getServices(flow.store.id, activeOnly: false);
      servicesError = null;
    } on AppFailure catch (failure) {
      servicesError = failure;
    }
    notify();
    final initial =
        services?.where((s) => s.id == (serviceId ?? flow.service?.id) && s.isBookable).firstOrNull ??
        (services?.where((s) => s.isBookable).length == 1 ? services!.firstWhere((s) => s.isBookable) : null);
    if (initial != null) await selectService(initial, staffId: staffId ?? flow.staff?.id);
  }

  Future<void> selectService(ServiceItem service, {String? staffId}) async {
    flow.selectService(service);
    staff = [];
    days = null;
    staffLoading = true;
    conflictMessage = null;
    notify();
    try {
      staff = (await _getStaff(flow.store.id, service.id)).where((s) => s.bookingEnabled).toList();
    } on AppFailure {
      staff = [];
    }
    staffLoading = false;
    flow.selectStaff(staff.where((s) => s.id == staffId).firstOrNull);
    notify();
    await loadAvailability();
  }

  Future<void> selectStaff(StaffOption? value) async {
    if (flow.staff?.id == value?.id) return;
    flow.selectStaff(value);
    conflictMessage = null;
    notify();
    await loadAvailability();
  }

  void setPartySize(int value) {
    flow.partySize = value;
    flow.clearSlot();
    conflictMessage = null;
    notify();
    loadAvailability();
  }

  Future<void> loadAvailability({bool silent = false}) async {
    final service = flow.service;
    if (service == null) return;
    if (!silent) {
      slotsLoading = true;
      slotsError = null;
      notify();
    }
    try {
      days = await _getAvailability(
        storeId: flow.store.id,
        serviceId: service.id,
        staffId: flow.staff?.id,
        from: from,
        to: to,
        partySize: flow.partySize,
      );
      slotsError = null;
      final slot = flow.slot;
      // 다시 조회한 결과에 선택한 시간이 더 이상 없으면 선택을 해제한다.
      if (slot != null &&
          !days!.any(
            (d) => d.slots.any(
              (s) => s.startAtRaw == slot.startAtRaw && s.staffId == slot.staffId && s.status == SlotStatus.available,
            ),
          )) {
        flow.clearSlot();
      }
      if (!silent && flow.slot == null) {
        final first = earliest;
        if (first != null) selectedDate = _dateOf(first.startAt);
      }
    } on AppFailure catch (failure) {
      if (!silent || days == null) slotsError = failure;
    } finally {
      slotsLoading = false;
      notify();
    }
  }

  List<DateTime> get dates => [for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) d];

  AvailabilityDay? dayFor(DateTime date) => days?.where((d) => d.date == date).firstOrNull;

  TimeOption? get earliest {
    for (final day in days ?? const <AvailabilityDay>[]) {
      final option = day.timeOptions.where((o) => o.status == SlotStatus.available).firstOrNull;
      if (option != null) return option;
    }
    return null;
  }

  DateTime _dateOf(DateTime instant) {
    final local = toStoreTime(instant);
    return DateTime.utc(local.year, local.month, local.day);
  }

  void selectDate(DateTime date) {
    selectedDate = date;
    notify();
  }

  void selectOption(TimeOption option) {
    final staffId = flow.staff?.id;
    flow.selectSlot(staffId == null ? option.firstAvailable : option.availableFor(staffId));
    conflictMessage = null;
    notify();
  }

  void jumpToEarliest() {
    final option = earliest;
    if (option == null) return;
    selectedDate = _dateOf(option.startAt);
    selectOption(option);
  }

  DateTime? get nextAvailableDate {
    for (final day in days ?? const <AvailabilityDay>[]) {
      if (day.date.isAfter(selectedDate) && day.hasAvailable) return day.date;
    }
    return null;
  }

  String? staffNameFor(String staffId) => staff.where((s) => s.id == staffId).firstOrNull?.displayName;

  Future<void> handleSlotTaken() async {
    conflictMessage = '방금 다른 고객이 이 시간을 예약했어요.\n다른 가능한 시간을 선택해 주세요.';
    flow.clearSlot();
    notify();
    await loadAvailability(silent: true);
  }
}

/// 예약 선택 (C-05 서비스 · C-06 직원 · C-07 날짜와 시간)
///
/// 한 화면에서 위에서 아래로 차례대로 고르고, 하단에는 선택 내용과 다음 버튼을 고정한다.
class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.flow, this.initialServiceId, this.initialStaffId});

  final BookingFlow flow;
  final String? initialServiceId;
  final String? initialStaffId;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _staffKey = GlobalKey();
  final _timeKey = GlobalKey();

  BookingFlow get flow => widget.flow;

  void _scrollTo(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      }
    });
  }

  void _openWaitlist(BookingViewModel vm, {TimeOption? around}) {
    final service = flow.service!;
    String? start;
    String? end;
    if (around != null) {
      final local = toStoreTime(around.startAt);
      final endLocal = local.add(Duration(minutes: max(flow.durationMinutes, 30)));
      start = hmOf(local.hour, local.minute);
      end = hmOf(endLocal.hour, endLocal.minute);
    }
    pushPage<void>(
      context,
      WaitlistApplyScreen(
        storeId: flow.store.id,
        storeName: flow.store.name,
        serviceId: service.id,
        serviceName: service.name,
        staffId: flow.staff?.id,
        staffName: flow.staff?.displayName,
        date: vm.selectedDate,
        startTime: start,
        endTime: end,
        partySize: flow.partySize,
      ),
    );
  }

  Future<void> _next(BookingViewModel vm) async {
    final result = await pushPage<BookingConfirmResult>(context, BookingConfirmScreen(flow: flow));
    if (result == BookingConfirmResult.slotTaken) {
      await vm.handleSlotTaken();
      _scrollTo(_timeKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<BookingViewModel>(
      create: () => BookingViewModel(flow, GetIt.I<StoreRepository>(), GetIt.I<RefreshBus>()),
      onReady: (vm) => vm.init(serviceId: widget.initialServiceId, staffId: widget.initialStaffId),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('예약하기'),
              Text(flow.store.name, style: AppText.caption),
            ],
          ),
        ),
        body: _body(vm),
        bottomNavigationBar: _bottomBar(vm),
      ),
    );
  }

  Widget _body(BookingViewModel vm) {
    if (vm.services == null) {
      return vm.servicesError != null ? ErrorView(failure: vm.servicesError!, onRetry: vm.init) : const LoadingView();
    }
    final services = vm.services!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 8, AppSpace.page, 32),
      children: [
        const _StepTitle(step: 1, title: '어떤 서비스를 받으시나요?'),
        if (services.isEmpty)
          const NoticeBox(message: '예약할 수 있는 서비스가 없어요. 매장에 직접 문의해 주세요.')
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < services.length; i++) ...[
                  if (i > 0) const Divider(indent: 20, endIndent: 20),
                  _ServiceOption(
                    service: services[i],
                    selected: flow.service?.id == services[i].id,
                    onTap: services[i].isBookable
                        ? () async {
                            await vm.selectService(services[i]);
                            _scrollTo(_staffKey);
                          }
                        : null,
                  ),
                ],
              ],
            ),
          ),
        if (flow.service != null) ...[
          _StepTitle(key: _staffKey, step: 2, title: '담당 직원을 골라 주세요'),
          if (vm.staffLoading)
            const LinearProgressIndicator()
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  _StaffChip(
                    label: '누구나',
                    caption: '가장 빠른 직원',
                    selected: flow.staff == null,
                    onTap: () => vm.selectStaff(null),
                  ),
                  for (final s in vm.staff)
                    _StaffChip(
                      label: s.displayName,
                      caption: s.customDurationMinutes == null ? null : '약 ${formatMinutes(s.customDurationMinutes!)}',
                      selected: flow.staff?.id == s.id,
                      onTap: () => vm.selectStaff(s),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.page, 8, 8, 8),
              child: Row(
                children: [
                  const Expanded(child: Text('인원', style: AppText.bodyStrong)),
                  NumberStepper(
                    value: flow.partySize,
                    max: max(flow.service!.capacity, 1),
                    unit: '명',
                    onChanged: vm.setPartySize,
                  ),
                ],
              ),
            ),
          ),
          _StepTitle(key: _timeKey, step: 3, title: '언제 방문하시나요?'),
          _TimeSection(vm: vm, flow: flow, onWaitlist: (o) => _openWaitlist(vm, around: o)),
        ],
      ],
    );
  }

  Widget _bottomBar(BookingViewModel vm) {
    final slot = flow.slot;
    final service = flow.service;
    final staffName = slot == null ? null : (flow.staff?.displayName ?? vm.staffNameFor(slot.staffId));
    return BottomActionBar(
      children: [
        if (slot != null && service != null)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatDateTime(slot.startAt), style: AppText.bodyStrong),
                    Text(
                      [service.name, ?staffName, '${flow.partySize}명', '약 ${formatMinutes(flow.durationMinutes)}'].join(' · '),
                      style: AppText.sub,
                    ),
                  ],
                ),
              ),
            ],
          ),
        AppButton(
          label: slot == null ? (service == null ? '서비스를 골라 주세요' : '시간을 골라 주세요') : '다음',
          onPressed: slot == null ? null : () => _next(vm),
        ),
      ],
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({super.key, required this.step, required this.title});

  final int step;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 24, 0, 12),
    child: Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: Text('$step', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: AppText.section)),
      ],
    ),
  );
}

class _ServiceOption extends StatelessWidget {
  const _ServiceOption({required this.service, required this.selected, this.onTap});

  final ServiceItem service;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final reason = !service.isActive ? '지금은 예약을 받지 않아요' : '담당할 수 있는 직원이 없어요';
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.page, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Opacity(
                  opacity: enabled ? 1 : 0.45,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(service.name, style: AppText.bodyStrong),
                      const SizedBox(height: 2),
                      Text(
                        enabled
                            ? [
                                '약 ${formatMinutes(service.durationMinutes)}',
                                if (service.description.isNotEmpty) service.description,
                              ].join(' · ')
                            : reason,
                        style: AppText.sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? AppColors.primary : AppColors.border,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffChip extends StatelessWidget {
  const _StaffChip({required this.label, required this.selected, required this.onTap, this.caption});

  final String label;
  final String? caption;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minWidth: 88),
              height: 112,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: selected ? Colors.white.withAlpha(40) : AppColors.primarySoft,
                    child: label == '누구나'
                        ? Icon(Icons.groups_rounded, color: selected ? Colors.white : AppColors.primary)
                        : Text(
                            label.characters.first,
                            style: TextStyle(
                              color: selected ? Colors.white : AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (caption != null)
                    Text(
                      caption!,
                      style: TextStyle(fontSize: 12, color: selected ? Colors.white70 : AppColors.mutedText),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeSection extends StatelessWidget {
  const _TimeSection({required this.vm, required this.flow, required this.onWaitlist});

  final BookingViewModel vm;
  final BookingFlow flow;
  final void Function(TimeOption? option) onWaitlist;

  @override
  Widget build(BuildContext context) {
    if (vm.slotsLoading && vm.days == null) {
      return const Padding(padding: EdgeInsets.all(32), child: LoadingView(message: '예약 가능한 시간을 확인하고 있어요'));
    }
    if (vm.slotsError != null && vm.days == null) {
      return ErrorView(failure: vm.slotsError!, onRetry: vm.loadAvailability);
    }
    final options = vm.dayFor(vm.selectedDate)?.timeOptions ?? const <TimeOption>[];
    final morning = options.where((o) => o.isMorning).toList();
    final afternoon = options.where((o) => !o.isMorning).toList();
    final hasAvailable = options.any((o) => o.status == SlotStatus.available);
    final earliest = vm.earliest;
    final waitlistEnabled = flow.store.offersWaitlist;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (vm.conflictMessage != null) ...[
          NoticeBox(message: vm.conflictMessage!, icon: Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(height: 12),
        ],
        if (earliest != null && flow.slot == null) ...[
          Material(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: vm.jumpToEarliest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('가장 빠른 예약 가능 시간', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                          Text(formatDateTime(earliest.startAt), style: AppText.bodyStrong),
                        ],
                      ),
                    ),
                    const Text('바로 선택', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: vm.dates.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final date = vm.dates[index];
              final selected = date == vm.selectedDate;
              final available = vm.dayFor(date)?.hasAvailable ?? false;
              final today = date == storeToday();
              return Semantics(
                button: true,
                selected: selected,
                label: '${formatCalendarDate(date)}, ${available ? '예약 가능' : '예약 마감'}',
                child: Material(
                  color: selected ? AppColors.text : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => vm.selectDate(date),
                    child: SizedBox(
                      width: 60,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            today ? '오늘' : weekdayShort(date),
                            style: TextStyle(color: selected ? Colors.white70 : AppColors.mutedText, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              color: selected ? Colors.white : (available ? AppColors.text : AppColors.mutedText),
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: available ? (selected ? Colors.white : AppColors.positive) : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        if (vm.slotsLoading) const LinearProgressIndicator(minHeight: 2),
        if (!hasAvailable)
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('이 날은 예약이 마감되었어요', style: AppText.bodyStrong),
                const SizedBox(height: 4),
                Text(
                  waitlistEnabled ? '원하는 시간대를 등록하면 빈자리가 생겼을 때 알려드릴게요.' : '다른 날짜를 골라 주세요.',
                  style: AppText.sub,
                ),
                const SizedBox(height: 16),
                if (waitlistEnabled) AppButton(label: '예약 대기 신청', onPressed: () => onWaitlist(null)),
                if (vm.nextAvailableDate != null) ...[
                  const SizedBox(height: 8),
                  AppButton(
                    label: '다음 가능한 날짜 보기',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => vm.selectDate(vm.nextAvailableDate!),
                  ),
                ],
              ],
            ),
          ),
        if (morning.isNotEmpty) ...[
          const _PeriodLabel('오전'),
          _SlotGrid(options: morning, flow: flow, vm: vm, onWaitlist: onWaitlist),
        ],
        if (afternoon.isNotEmpty) ...[
          const _PeriodLabel('오후'),
          _SlotGrid(options: afternoon, flow: flow, vm: vm, onWaitlist: onWaitlist),
        ],
        if (hasAvailable && waitlistEnabled)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Center(
              child: TextButton(onPressed: () => onWaitlist(null), child: const Text('원하는 시간이 없나요? 예약 대기 신청')),
            ),
          ),
      ],
    );
  }
}

class _PeriodLabel extends StatelessWidget {
  const _PeriodLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 0, 8),
    child: Text(text, style: const TextStyle(color: AppColors.lightText, fontWeight: FontWeight.w600)),
  );
}

class _SlotGrid extends StatelessWidget {
  const _SlotGrid({required this.options, required this.flow, required this.vm, required this.onWaitlist});

  final List<TimeOption> options;
  final BookingFlow flow;
  final BookingViewModel vm;
  final void Function(TimeOption option) onWaitlist;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final columns = (constraints.maxWidth / 104).floor().clamp(3, 6);
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final option in options) SizedBox(width: width, child: _button(option))],
        );
      },
    );
  }

  Widget _button(TimeOption option) {
    final selected = flow.slot != null && flow.slot!.startAt == option.startAt;
    final time = formatTime(option.startAt).replaceFirst(RegExp('^(오전|오후) '), '');
    final (sub, fg, bg, onTap) = switch (option.status) {
      SlotStatus.available => (
        selected ? '선택됨' : '예약 가능',
        selected ? Colors.white : AppColors.text,
        selected ? AppColors.primary : Colors.white,
        () => vm.selectOption(option),
      ),
      SlotStatus.waitlistAvailable => ('대기 가능', AppColors.attention, Colors.white, () => onWaitlist(option)),
      SlotStatus.unavailable => ('마감', AppColors.mutedText, const Color(0xffE9ECEF), null),
    };
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: '${formatTime(option.startAt)}, $sub',
      child: ExcludeSemantics(
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(
              height: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      color: fg,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      decoration: option.status == SlotStatus.unavailable ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(sub, style: TextStyle(color: selected ? Colors.white70 : fg.withAlpha(200), fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

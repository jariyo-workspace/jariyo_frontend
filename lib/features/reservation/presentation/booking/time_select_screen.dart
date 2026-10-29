import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

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

class _TimeViewModel extends LoadableViewModel<List<AvailabilityDay>> {
  _TimeViewModel(this._getAvailability, this.flow, RefreshBus bus) {
    final openDays = flow.store.policy.bookingOpenDays ?? 14;
    final days = min(max(openDays, 1), 14);
    from = storeToday();
    to = from.add(Duration(days: days - 1));
    selectedDate = from;
    listenTopics(bus, {RefreshTopic.availability}, refresh);
  }

  final GetAvailability _getAvailability;
  final BookingFlow flow;
  late final DateTime from;
  late final DateTime to;
  late DateTime selectedDate;

  /// 동시 예약 충돌 후 보여줄 안내
  String? conflictMessage;

  @override
  Future<List<AvailabilityDay>> fetch() => _getAvailability(
    storeId: flow.store.id,
    serviceId: flow.service!.id,
    staffId: flow.staff?.id,
    from: from,
    to: to,
    partySize: flow.partySize,
  );

  @override
  Future<void> load({bool silent = false}) async {
    await super.load(silent: silent);
    final slot = flow.slot;
    // 다시 조회한 결과에 선택한 시간이 더 이상 없으면 선택을 해제한다.
    if (slot != null && data != null) {
      final stillAvailable = data!.any(
        (d) => d.slots.any(
          (s) => s.startAtRaw == slot.startAtRaw && s.staffId == slot.staffId && s.status == SlotStatus.available,
        ),
      );
      if (!stillAvailable) flow.clearSlot();
    }
    if (!silent && slot == null) {
      final first = earliest;
      if (first != null) selectedDate = _dateOf(first.startAt);
    }
    notify();
  }

  List<DateTime> get dates => [for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) d];

  AvailabilityDay? dayFor(DateTime date) => data?.where((d) => d.date == date).firstOrNull;

  TimeOption? get earliest {
    for (final day in data ?? const <AvailabilityDay>[]) {
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
    final slot = staffId == null ? option.firstAvailable : option.availableFor(staffId);
    flow.selectSlot(slot);
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
    for (final day in data ?? const <AvailabilityDay>[]) {
      if (day.date.isAfter(selectedDate) && day.hasAvailable) return day.date;
    }
    return null;
  }

  Future<void> handleSlotTaken() async {
    conflictMessage = '방금 다른 고객이 이 시간을 예약했어요.\n다른 가능한 시간을 선택해 주세요.';
    flow.clearSlot();
    notify();
    await refresh();
  }
}

/// C-07 날짜 및 시간 선택
class TimeSelectScreen extends StatelessWidget {
  const TimeSelectScreen({super.key, required this.flow});

  final BookingFlow flow;

  void _openWaitlist(BuildContext context, _TimeViewModel vm, {TimeOption? around}) {
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

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<_TimeViewModel>(
      create: () => _TimeViewModel(GetAvailability(GetIt.I<StoreRepository>()), flow, GetIt.I<RefreshBus>()),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: const Text('날짜 및 시간 선택')),
        body: LoadableBody<List<AvailabilityDay>>(
          vm: vm,
          loadingMessage: '예약 가능한 시간을 확인하고 있어요',
          staleMessage: '예약 가능한 시간을 새로 불러오지 못했어요.',
          builder: (context, days) => _content(context, vm),
        ),
        bottomNavigationBar: vm.data == null
            ? null
            : BottomActionBar(
                children: [
                  if (flow.slot != null)
                    Text(
                      '${formatDateTime(flow.slot!.startAt)} 선택됨',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  AppButton(
                    label: '다음',
                    onPressed: flow.slot == null
                        ? null
                        : () async {
                            final result = await pushPage<BookingConfirmResult>(
                              context,
                              BookingConfirmScreen(flow: flow),
                            );
                            if (result == BookingConfirmResult.slotTaken) await vm.handleSlotTaken();
                          },
                  ),
                ],
              ),
      ),
    );
  }

  Widget _content(BuildContext context, _TimeViewModel vm) {
    final day = vm.dayFor(vm.selectedDate);
    final options = day?.timeOptions ?? const <TimeOption>[];
    final morning = options.where((o) => o.isMorning).toList();
    final afternoon = options.where((o) => !o.isMorning).toList();
    final hasAvailable = options.any((o) => o.status == SlotStatus.available);
    final earliest = vm.earliest;
    final waitlistEnabled = flow.store.offersWaitlist;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        SectionCard(
          child: Column(
            children: [
              InfoRow(label: '서비스', value: '${flow.service!.name} · 약 ${formatMinutes(flow.durationMinutes)}'),
              InfoRow(label: '직원', value: flow.staff?.displayName ?? '가능한 직원 누구나'),
            ],
          ),
        ),
        if (vm.conflictMessage != null) ...[
          const SizedBox(height: 12),
          NoticeBox(message: vm.conflictMessage!, icon: Icons.error_outline, color: AppColors.danger),
          if (waitlistEnabled)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => _openWaitlist(context, vm), child: const Text('예약 대기 신청')),
            ),
        ],
        if (earliest != null) ...[
          const SizedBox(height: 12),
          Material(
            color: AppColors.positive.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
            child: ListTile(
              leading: const Icon(Icons.bolt, color: AppColors.positive),
              title: const Text('가장 빠른 예약 가능 시간'),
              subtitle: Text(formatDateTime(earliest.startAt)),
              trailing: const Text('선택', style: TextStyle(color: AppColors.positive, fontWeight: FontWeight.w600)),
              onTap: vm.jumpToEarliest,
            ),
          ),
        ],
        const SectionTitle('날짜'),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: vm.dates.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final date = vm.dates[index];
              final selected = date == vm.selectedDate;
              final available = vm.dayFor(date)?.hasAvailable ?? false;
              return Semantics(
                button: true,
                selected: selected,
                label: '${formatCalendarDate(date)}, ${available ? '예약 가능' : '예약 마감'}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => vm.selectDate(date),
                  child: Container(
                    width: 58,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? AppColors.primary : AppColors.border),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          weekdayShort(date),
                          style: TextStyle(color: selected ? Colors.white : AppColors.lightText, fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            color: selected ? Colors.white : AppColors.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          available ? '가능' : '마감',
                          style: TextStyle(
                            fontSize: 11,
                            color: selected ? Colors.white : (available ? AppColors.positive : AppColors.lightText),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SectionTitle(formatCalendarDate(vm.selectedDate)),
        if (!hasAvailable)
          _NoSlots(
            waitlistEnabled: waitlistEnabled,
            onWaitlist: () => _openWaitlist(context, vm),
            onNextDate: vm.nextAvailableDate == null ? null : () => vm.selectDate(vm.nextAvailableDate!),
          ),
        if (morning.isNotEmpty) ...[
          const _PeriodLabel('오전'),
          _SlotGrid(options: morning, flow: flow, vm: vm, onWaitlist: (o) => _openWaitlist(context, vm, around: o)),
        ],
        if (afternoon.isNotEmpty) ...[
          const _PeriodLabel('오후'),
          _SlotGrid(options: afternoon, flow: flow, vm: vm, onWaitlist: (o) => _openWaitlist(context, vm, around: o)),
        ],
        if (hasAvailable && waitlistEnabled) ...[
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => _openWaitlist(context, vm),
              child: const Text('원하는 시간이 없나요? 예약 대기 신청'),
            ),
          ),
        ],
      ],
    );
  }
}

class _PeriodLabel extends StatelessWidget {
  const _PeriodLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 8),
    child: Text(text, style: const TextStyle(color: AppColors.lightText, fontWeight: FontWeight.w600)),
  );
}

class _NoSlots extends StatelessWidget {
  const _NoSlots({required this.waitlistEnabled, required this.onWaitlist, required this.onNextDate});

  final bool waitlistEnabled;
  final VoidCallback onWaitlist;
  final VoidCallback? onNextDate;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            waitlistEnabled
                ? '선택한 날짜에 예약 가능한 시간이 없어요.\n원하는 시간대를 등록하면 빈자리가 생겼을 때 알려드릴게요.'
                : '선택한 날짜에 예약 가능한 시간이 없어요.',
            style: const TextStyle(height: 1.5),
          ),
          const SizedBox(height: 12),
          if (waitlistEnabled) AppButton(label: '예약 대기 신청', onPressed: onWaitlist),
          if (onNextDate != null) ...[
            const SizedBox(height: 8),
            AppButton(label: '다른 날짜 보기', variant: AppButtonVariant.secondary, onPressed: onNextDate),
          ],
        ],
      ),
    );
  }
}

class _SlotGrid extends StatelessWidget {
  const _SlotGrid({required this.options, required this.flow, required this.vm, required this.onWaitlist});

  final List<TimeOption> options;
  final BookingFlow flow;
  final _TimeViewModel vm;
  final void Function(TimeOption option) onWaitlist;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options) _button(option),
      ],
    );
  }

  Widget _button(TimeOption option) {
    final selected = flow.slot != null && flow.slot!.startAt == option.startAt;
    final time = formatTime(option.startAt);
    final (label, sub, color, onTap) = switch (option.status) {
      SlotStatus.available => (
        time,
        selected ? '선택됨' : '예약 가능',
        selected ? Colors.white : AppColors.primary,
        () => vm.selectOption(option),
      ),
      SlotStatus.waitlistAvailable => (time, '대기 가능', AppColors.attention, () => onWaitlist(option)),
      SlotStatus.unavailable => (time, '마감', AppColors.lightText.withAlpha(120), null),
    };
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: '$time, $sub',
      child: ExcludeSemantics(
        child: SizedBox(
          width: 100,
          height: 56,
          child: Material(
            color: selected ? AppColors.primary : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: selected ? AppColors.primary : color.withAlpha(onTap == null ? 60 : 160)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      decoration: option.status == SlotStatus.unavailable ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(sub, style: TextStyle(color: color, fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

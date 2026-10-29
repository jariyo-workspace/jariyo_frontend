import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/statuses.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../../core/presentation/view_model.dart';
import '../../../core/realtime/refresh_bus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_time_format.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/view_model_scope.dart';
import '../domain/admin_entities.dart';
import '../domain/admin_operation_usecases.dart';
import '../domain/admin_repositories.dart';
import '../domain/admin_settings_usecases.dart';
import 'admin_common.dart';
import 'admin_reservation_detail_screen.dart';
import 'manual_reservation_screen.dart';

enum CalendarMode { day, week }

class CalendarViewModel extends LoadableViewModel<List<AdminReservation>> {
  CalendarViewModel(this.storeId, AdminOperationRepository repository, StoreSettingsRepository settings, RefreshBus bus)
    : _list = GetStoreReservations(repository),
      _staff = GetStaffMembers(settings) {
    listenTopics(bus, {RefreshTopic.adminReservations}, refresh);
    startPolling(const Duration(seconds: 60), refresh);
  }

  final String storeId;
  final GetStoreReservations _list;
  final GetStaffMembers _staff;

  DateTime date = storeToday();
  CalendarMode mode = CalendarMode.day;
  StaffMember? staffFilter;
  ReservationStatus? statusFilter;
  String customerQuery = '';
  List<StaffMember> staff = [];
  String? selectedId;

  DateTime get weekStart => date.subtract(Duration(days: date.weekday - 1));

  @override
  Future<List<AdminReservation>> fetch() async {
    if (staff.isEmpty) {
      try {
        staff = (await _staff(storeId)).where((s) => s.isActive).toList();
      } on AppFailure {
        staff = [];
      }
    }
    final from = mode == CalendarMode.day ? date : weekStart;
    final to = mode == CalendarMode.day ? date : weekStart.add(const Duration(days: 6));
    return _list(
      storeId,
      from: from,
      to: to,
      staffId: staffFilter?.id,
      status: statusFilter,
      customerQuery: customerQuery.trim().isEmpty ? null : customerQuery.trim(),
    );
  }

  void setDate(DateTime value) {
    date = value;
    selectedId = null;
    load();
  }

  void setMode(CalendarMode value) {
    mode = value;
    load();
  }

  void setStaffFilter(StaffMember? value) {
    staffFilter = value;
    load();
  }

  void setStatusFilter(ReservationStatus? value) {
    statusFilter = value;
    load();
  }

  void search(String value) {
    customerQuery = value;
    load();
  }

  void select(String? id) {
    selectedId = id;
    notify();
  }

  /// 직원별 열. 목록 응답은 직원 이름만 주므로 이름으로 묶는다.
  List<String> get columns {
    final names = <String>[
      if (staffFilter != null)
        staffFilter!.displayName
      else
        ...staff.where((s) => s.bookingEnabled).map((s) => s.displayName),
    ];
    for (final r in data ?? const <AdminReservation>[]) {
      if (!names.contains(r.staffName)) names.add(r.staffName);
    }
    return names;
  }
}

/// A-03 예약 캘린더
class ReservationCalendarScreen extends StatelessWidget {
  const ReservationCalendarScreen({super.key, required this.ctx});

  final OperatorContext ctx;

  void _open(BuildContext context, CalendarViewModel vm, AdminReservation r) {
    if (MediaQuery.sizeOf(context).width >= 1100) {
      vm.select(r.id);
    } else {
      pushPage<void>(context, AdminReservationDetailScreen(storeId: ctx.storeId, reservationId: r.id));
    }
  }

  void _create(BuildContext context, {String? staffName, DateTime? date, String? time}) {
    pushPage<void>(
      context,
      ManualReservationScreen(storeId: ctx.storeId, initialStaffName: staffName, initialDate: date, initialTime: time),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<CalendarViewModel>(
      create: () => CalendarViewModel(
        ctx.storeId,
        GetIt.I<AdminOperationRepository>(),
        GetIt.I<StoreSettingsRepository>(),
        GetIt.I<RefreshBus>(),
      ),
      onReady: (vm) => vm.load(),
      builder: (context, vm) {
        final wide = MediaQuery.sizeOf(context).width >= 1100;
        final calendar = Column(
          children: [
            _Toolbar(vm: vm),
            const Divider(height: 1),
            Expanded(
              child: LoadableBody<List<AdminReservation>>(
                vm: vm,
                pullToRefresh: false,
                builder: (context, items) => vm.mode == CalendarMode.day
                    ? _DayView(
                        vm: vm,
                        items: items,
                        onOpen: (r) => _open(context, vm, r),
                        onEmptySlot: (staff, time) => _create(context, staffName: staff, date: vm.date, time: time),
                      )
                    : _WeekView(
                        vm: vm,
                        items: items,
                        onOpen: (r) => _open(context, vm, r),
                        onDay: (d) {
                          vm.date = d;
                          vm.setMode(CalendarMode.day);
                        },
                      ),
              ),
            ),
          ],
        );
        return Scaffold(
          appBar: AppBar(
            title: const Text('예약 관리'),
            actions: [
              IconButton(tooltip: '새로고침', onPressed: vm.refresh, icon: const Icon(Icons.refresh)),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _create(context, date: vm.date),
            icon: const Icon(Icons.add),
            label: const Text('수동 예약'),
          ),
          body: wide && vm.selectedId != null
              ? Row(
                  children: [
                    Expanded(flex: 3, child: calendar),
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: 400,
                      child: Column(
                        children: [
                          ListTile(
                            title: const Text('예약 상세', style: TextStyle(fontWeight: FontWeight.w700)),
                            trailing: IconButton(
                              tooltip: '닫기',
                              onPressed: () => vm.select(null),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                          Expanded(
                            child: AdminReservationDetailView(storeId: ctx.storeId, reservationId: vm.selectedId!),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : calendar,
        );
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.vm});

  final CalendarViewModel vm;

  @override
  Widget build(BuildContext context) {
    final weekLabel =
        '${formatShortCalendarDate(vm.weekStart)} – ${formatShortCalendarDate(vm.weekStart.add(const Duration(days: 6)))}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Column(
        children: [
          Row(
            children: [
              SegmentedButton<CalendarMode>(
                segments: const [
                  ButtonSegment(value: CalendarMode.day, label: Text('일간')),
                  ButtonSegment(value: CalendarMode.week, label: Text('주간')),
                ],
                selected: {vm.mode},
                onSelectionChanged: (s) => vm.setMode(s.first),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DateNavigator(
                  date: vm.date,
                  stepDays: vm.mode == CalendarMode.day ? 1 : 7,
                  label: vm.mode == CalendarMode.week ? weekLabel : null,
                  onChanged: vm.setDate,
                ),
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                DropdownButton<String?>(
                  value: vm.staffFilter?.id,
                  hint: const Text('전체 직원'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('전체 직원')),
                    for (final s in vm.staff) DropdownMenuItem(value: s.id, child: Text(s.displayName)),
                  ],
                  onChanged: (id) => vm.setStaffFilter(vm.staff.where((s) => s.id == id).firstOrNull),
                ),
                const SizedBox(width: 12),
                DropdownButton<ReservationStatus?>(
                  value: vm.statusFilter,
                  hint: const Text('전체 상태'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('전체 상태')),
                    for (final s in ReservationStatus.values.where((s) => s != ReservationStatus.unknown))
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: vm.setStatusFilter,
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 180,
                  child: TextField(
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '고객명 검색',
                      prefixIcon: Icon(Icons.search, size: 20),
                    ),
                    onSubmitted: vm.search,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayView extends StatelessWidget {
  const _DayView({required this.vm, required this.items, required this.onOpen, required this.onEmptySlot});

  final CalendarViewModel vm;
  final List<AdminReservation> items;
  final void Function(AdminReservation) onOpen;
  final void Function(String staffName, String time) onEmptySlot;

  static const _pxPerMinute = 1.4;
  static const _columnWidth = 180.0;
  static const _timeColumnWidth = 56.0;

  @override
  Widget build(BuildContext context) {
    final columns = vm.columns;
    if (columns.isEmpty) {
      return const EmptyView(title: '예약을 받을 수 있는 직원이 없어요.', message: '매장 관리에서 직원을 추가해 주세요.');
    }
    var startHour = 9;
    var endHour = 21;
    for (final r in items) {
      startHour = min(startHour, toStoreTime(r.startAt).hour);
      endHour = max(endHour, toStoreTime(r.serviceEndAt).hour + 1);
    }
    final totalMinutes = (endHour - startHour) * 60;
    final height = totalMinutes * _pxPerMinute;
    final now = storeNow();
    final isToday = vm.date == storeToday();
    final nowOffset = ((now.hour - startHour) * 60 + now.minute) * _pxPerMinute;

    double offsetOf(DateTime instant) {
      final t = toStoreTime(instant);
      return ((t.hour - startHour) * 60 + t.minute) * _pxPerMinute;
    }

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(width: _timeColumnWidth),
                for (final name in columns)
                  Container(
                    width: _columnWidth,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            SizedBox(
              height: height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _timeColumnWidth,
                    child: Stack(
                      children: [
                        for (var h = startHour; h < endHour; h++)
                          Positioned(
                            top: (h - startHour) * 60 * _pxPerMinute,
                            left: 4,
                            child: Text(
                              formatClock(h, 0),
                              style: const TextStyle(fontSize: 11, color: AppColors.lightText),
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (final name in columns)
                    SizedBox(
                      width: _columnWidth,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) {
                          final minutes = (details.localPosition.dy / _pxPerMinute).floor();
                          final slot = (minutes ~/ 30) * 30;
                          final hour = startHour + slot ~/ 60;
                          onEmptySlot(name, hmOf(hour, slot % 60));
                        },
                        child: Stack(
                          children: [
                            for (var h = startHour; h < endHour; h++)
                              Positioned(
                                top: (h - startHour) * 60 * _pxPerMinute,
                                left: 0,
                                right: 0,
                                child: const Divider(height: 1),
                              ),
                            Positioned.fill(
                              child: Container(
                                decoration: const BoxDecoration(
                                  border: Border(left: BorderSide(color: AppColors.border)),
                                ),
                              ),
                            ),
                            for (final r in items.where((r) => r.staffName == name))
                              Positioned(
                                top: offsetOf(r.startAt),
                                left: 4,
                                right: 4,
                                height: max(36, (offsetOf(r.serviceEndAt) - offsetOf(r.startAt))),
                                child: _Block(reservation: r, selected: vm.selectedId == r.id, onTap: () => onOpen(r)),
                              ),
                            if (isToday && nowOffset > 0 && nowOffset < height)
                              Positioned(
                                top: nowOffset,
                                left: 0,
                                right: 0,
                                child: Container(height: 2, color: AppColors.danger),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.reservation, required this.onTap, this.selected = false});

  final AdminReservation reservation;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final color = AppColors.forTone(r.status.tone);
    return Semantics(
      button: true,
      label: '${r.customerName} ${r.serviceName} ${formatTime(r.startAt)} ${r.status.label} ${r.checkInStatus.label}',
      child: Material(
        color: color.withAlpha(selected ? 60 : 28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color, width: selected ? 2 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          // 짧은 예약 블록은 높이에 맞춰 아래 줄을 잘라 보여준다.
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              maxHeight: double.infinity,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r.customerName} · ${r.serviceName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    Text(
                      '${formatTime(r.startAt)}–${formatTime(r.serviceEndAt)} · ${r.status.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: color),
                    ),
                    Text(
                      r.checkInStatus.label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: const TextStyle(fontSize: 11, color: AppColors.lightText),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView({required this.vm, required this.items, required this.onOpen, required this.onDay});

  final CalendarViewModel vm;
  final List<AdminReservation> items;
  final void Function(AdminReservation) onOpen;
  final void Function(DateTime) onDay;

  @override
  Widget build(BuildContext context) {
    final days = [for (var i = 0; i < 7; i++) vm.weekStart.add(Duration(days: i))];
    final today = storeToday();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final day in days)
            SizedBox(
              width: 170,
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    onTap: () => onDay(day),
                    title: Text(
                      formatShortCalendarDate(day),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: day == today ? AppColors.primary : AppColors.text,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height - 260,
                    child: ListView(
                      padding: const EdgeInsets.all(4),
                      children: [
                        for (final r in items.where((r) {
                          final t = toStoreTime(r.startAt);
                          return DateTime.utc(t.year, t.month, t.day) == day;
                        }))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: SizedBox(
                              height: 64,
                              child: _Block(reservation: r, selected: vm.selectedId == r.id, onTap: () => onOpen(r)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

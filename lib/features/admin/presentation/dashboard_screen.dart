import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/statuses.dart';
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
import 'admin_common.dart';
import 'admin_reservation_detail_screen.dart';
import 'operator_shell.dart';

class DashboardData {
  const DashboardData({required this.dashboard, this.reservations = const [], this.walkIns = const []});

  final TodayDashboard dashboard;
  final List<AdminReservation> reservations;
  final List<AdminWalkIn> walkIns;
}

class DashboardViewModel extends LoadableViewModel<DashboardData> {
  DashboardViewModel(this.storeId, AdminOperationRepository repository, RefreshBus bus)
    : _dashboard = GetTodayDashboard(repository),
      _reservations = GetStoreReservations(repository),
      _walkIns = GetWalkInQueue(repository) {
    listenTopics(
      bus,
      {RefreshTopic.adminDashboard, RefreshTopic.adminReservations, RefreshTopic.adminWalkIns},
      refresh,
    );
    startPolling(const Duration(seconds: 30), refresh);
  }

  final String storeId;
  final GetTodayDashboard _dashboard;
  final GetStoreReservations _reservations;
  final GetWalkInQueue _walkIns;

  @override
  Future<DashboardData> fetch() async {
    final today = storeToday();
    final results = await Future.wait<Object?>([
      _dashboard(storeId),
      _reservations(storeId, from: today, to: today).then<Object?>((v) => v, onError: (Object e) => e),
      _walkIns(storeId, date: today).then<Object?>((v) => v, onError: (Object e) => e),
    ]);
    return DashboardData(
      dashboard: results[0] as TodayDashboard,
      reservations: results[1] is List<AdminReservation> ? results[1] as List<AdminReservation> : const [],
      walkIns: results[2] is List<AdminWalkIn> ? results[2] as List<AdminWalkIn> : const [],
    );
  }
}

/// A-02 오늘의 운영 홈
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.ctx, required this.onNavigate});

  final OperatorContext ctx;
  final void Function(int section) onNavigate;

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<DashboardViewModel>(
      create: () => DashboardViewModel(ctx.storeId, GetIt.I<AdminOperationRepository>(), GetIt.I<RefreshBus>()),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: Text('오늘의 운영 · ${formatCalendarDate(storeToday())}')),
        body: LoadableBody<DashboardData>(
          vm: vm,
          loadingMessage: '오늘 운영 현황을 불러오고 있어요',
          builder: (context, data) => _body(context, data),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, DashboardData data) {
    final s = data.dashboard.summary;
    final urgent = _urgentAlerts(data);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (urgent.isNotEmpty) ...[
          for (final alert in urgent) ...[_AlertCard(alert: alert, onTap: () => _openAlert(context, alert)), const SizedBox(height: 8)],
          const SizedBox(height: 8),
        ],
        ResponsiveGrid(
          children: [
            MetricTile(
              label: '오늘 예약',
              value: '${s.reservationCount}',
              icon: Icons.event,
              onTap: () => onNavigate(OperatorSection.reservations),
            ),
            MetricTile(
              label: '현재 현장 대기',
              value: '${s.waitingWalkInCount}',
              icon: Icons.groups,
              onTap: () => onNavigate(OperatorSection.walkIns),
            ),
            MetricTile(label: '체크인 고객', value: '${s.checkedInCount}', icon: Icons.how_to_reg, color: AppColors.positive),
            MetricTile(label: '진행 중 서비스', value: '${s.inServiceCount}', icon: Icons.content_cut, color: AppColors.positive),
            MetricTile(
              label: '노쇼 후보',
              value: '${s.noShowCandidateCount}',
              icon: Icons.person_off_outlined,
              color: s.noShowCandidateCount > 0 ? AppColors.danger : AppColors.lightText,
              onTap: () => onNavigate(OperatorSection.reservations),
            ),
            MetricTile(
              label: '빈자리 제안 대기',
              value: '${s.pendingSlotOfferCount}',
              icon: Icons.local_fire_department_outlined,
              color: s.pendingSlotOfferCount > 0 ? AppColors.attention : AppColors.lightText,
              onTap: () => onNavigate(OperatorSection.slotOffers),
            ),
          ],
        ),
        const SectionTitle('시간순 운영 목록'),
        ..._timeline(context, data),
      ],
    );
  }

  /// 서버 경고와 화면에서 확인한 긴급 상태(호출 시간이 지난 고객)를 합친다.
  List<DashboardAlert> _urgentAlerts(DashboardData data) {
    final now = DateTime.now();
    return [
      ...data.dashboard.alerts,
      for (final w in data.walkIns.where((w) => w.status == WalkInStatus.called))
        if (w.callExpiresAt != null && w.callExpiresAt!.isBefore(now))
          DashboardAlert(type: 'WALK_IN_CALL_EXPIRED', referenceId: w.id, message: '현장 대기 ${w.queueNumber}번 고객의 호출 응답 시간이 지났어요.'),
    ];
  }

  void _openAlert(BuildContext context, DashboardAlert alert) {
    switch (alert.type) {
      case 'NO_SHOW_CANDIDATE':
        pushPage<void>(context, AdminReservationDetailScreen(storeId: ctx.storeId, reservationId: alert.referenceId));
      case 'PENDING_SLOT_OFFER':
        onNavigate(OperatorSection.slotOffers);
      case 'WALK_IN_CALL_EXPIRED':
        onNavigate(OperatorSection.walkIns);
      case 'FAILED_JOB':
        onNavigate(OperatorSection.failedJobs);
    }
  }

  List<Widget> _timeline(BuildContext context, DashboardData data) {
    final entries = <(DateTime, Widget)>[];
    for (final r in data.reservations.where((r) => r.status != ReservationStatus.cancelled)) {
      entries.add((
        r.startAt,
        _TimelineCard(
          leading: formatTime(r.startAt),
          title: '${r.customerName} · ${r.serviceName} · ${r.staffName}',
          kind: '예약',
          badge: StatusBadge(label: r.checkInStatus.label, tone: r.checkInStatus.tone),
          onTap: () => pushPage<void>(context, AdminReservationDetailScreen(storeId: ctx.storeId, reservationId: r.id)),
        ),
      ));
    }
    final now = DateTime.now();
    for (final w in data.walkIns.where((w) => w.status.isActive)) {
      entries.add((
        w.createdAt ?? now.subtract(Duration(minutes: w.waitingMinutes)),
        _TimelineCard(
          leading: '${w.queueNumber}번',
          title: '${w.customerName} · ${w.serviceName}',
          kind: '현장 대기',
          subtitle: w.status == WalkInStatus.waiting ? '대기 ${formatMinutes(w.waitingMinutes)}째' : null,
          badge: StatusBadge(label: w.status.label, tone: w.status.tone),
          onTap: () => onNavigate(OperatorSection.walkIns),
        ),
      ));
    }
    if (entries.isEmpty && data.dashboard.timeline.isEmpty) {
      return const [EmptyView(icon: Icons.event_note, title: '오늘 예정된 예약과 대기가 없어요.')];
    }
    entries.sort((a, b) => a.$1.compareTo(b.$1));
    return [
      for (final item in data.dashboard.timeline)
        _TimelineCard(
          leading: item.scheduledAt == null ? '-' : formatTime(item.scheduledAt!),
          title: item.label,
          kind: item.type == 'WALK_IN' ? '현장 대기' : '예약',
        ),
      for (final (_, widget) in entries) widget,
    ];
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.onTap});

  final DashboardAlert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = alert.type == 'PENDING_SLOT_OFFER' ? AppColors.attention : AppColors.danger;
    return Material(
      color: color.withAlpha(20),
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withAlpha(80))),
        leading: Icon(Icons.warning_amber_rounded, color: color),
        title: Text(alert.message, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        trailing: Icon(Icons.chevron_right, color: color),
        onTap: onTap,
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.leading,
    required this.title,
    required this.kind,
    this.subtitle,
    this.badge,
    this.onTap,
  });

  final String leading;
  final String title;
  final String kind;
  final String? subtitle;
  final Widget? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: SizedBox(
          width: 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(leading, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(kind, style: const TextStyle(color: AppColors.lightText, fontSize: 12)),
            ],
          ),
        ),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: badge,
      ),
    );
  }
}

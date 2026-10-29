import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../app/session_controller.dart';
import '../../../core/domain/statuses.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/dialogs.dart';
import '../../my_page/presentation/my_page_screen.dart';
import '../../store/domain/store_repository.dart';
import '../../store/domain/store_usecases.dart';
import 'admin_common.dart';
import 'admin_waitlist_screen.dart';
import 'dashboard_screen.dart';
import 'insights/analytics_screen.dart';
import 'insights/audit_log_screen.dart';
import 'insights/failed_jobs_screen.dart';
import 'reservation_calendar_screen.dart';
import 'settings/settings_hub_screen.dart';
import 'slot_offer_admin_screen.dart';
import 'walk_in_queue_screen.dart';

class _Section {
  const _Section(this.label, this.icon, this.builder, {this.managerOnly = false});

  final String label;
  final IconData icon;
  final Widget Function(OperatorContext ctx, void Function(int) go) builder;
  final bool managerOnly;
}

final _sections = <_Section>[
  _Section('오늘', Icons.dashboard_outlined, (ctx, go) => DashboardScreen(ctx: ctx, onNavigate: go)),
  _Section('예약', Icons.calendar_month_outlined, (ctx, go) => ReservationCalendarScreen(ctx: ctx)),
  _Section('현장 대기', Icons.groups_outlined, (ctx, go) => WalkInQueueScreen(ctx: ctx)),
  _Section('예약 대기', Icons.hourglass_empty, (ctx, go) => AdminWaitlistScreen(ctx: ctx)),
  _Section('빈자리 제안', Icons.local_fire_department_outlined, (ctx, go) => SlotOfferAdminScreen(ctx: ctx)),
  _Section('매장 관리', Icons.storefront_outlined, (ctx, go) => SettingsHubScreen(ctx: ctx), managerOnly: true),
  _Section('통계', Icons.insights_outlined, (ctx, go) => AnalyticsScreen(ctx: ctx), managerOnly: true),
  _Section('운영 이력', Icons.history, (ctx, go) => AuditLogScreen(ctx: ctx)),
  _Section('처리 실패', Icons.report_problem_outlined, (ctx, go) => FailedJobsScreen(ctx: ctx), managerOnly: true),
];

/// 운영자 화면 섹션 번호
abstract final class OperatorSection {
  static const today = 0;
  static const reservations = 1;
  static const walkIns = 2;
  static const waitlists = 3;
  static const slotOffers = 4;
  static const failedJobs = 8;
}

/// 매장 운영자 화면.
///
/// 태블릿·데스크톱은 좌측 내비게이션 레일, 모바일은 현장 처리 위주의 하단 탭으로 구성한다.
class OperatorShell extends StatefulWidget {
  const OperatorShell({super.key, required this.storeId});

  final String storeId;

  @override
  State<OperatorShell> createState() => _OperatorShellState();
}

class _OperatorShellState extends State<OperatorShell> {
  final _session = GetIt.I<SessionController>();
  int _index = 0;
  String? _storeName;

  // 모바일 하단 탭에 노출하는 우선 기능: 오늘 · 예약 · 현장 대기 · 더보기
  static const _mobileTabs = [OperatorSection.today, OperatorSection.reservations, OperatorSection.walkIns];

  @override
  void initState() {
    super.initState();
    GetStoreDetail(GetIt.I<StoreRepository>())(widget.storeId)
        .then((store) {
          if (mounted) setState(() => _storeName = store.name);
        })
        .catchError((Object _) {});
  }

  OperatorContext get _ctx => OperatorContext(
    storeId: widget.storeId,
    role: _session.profile?.membershipFor(widget.storeId)?.role ?? StoreRole.staff,
    storeName: _storeName,
  );

  List<int> get _visible => [
    for (var i = 0; i < _sections.length; i++)
      if (!_sections[i].managerOnly || _ctx.canManageSettings) i,
  ];

  void _go(int index) => setState(() => _index = index);

  Future<void> _switchStore() async {
    await pickOperatorStore(context, _session);
  }

  Future<void> _toCustomer() async {
    final ok = await showConfirmDialog(
      context,
      title: '고객 화면으로 전환할까요?',
      message: '매장 운영 화면을 닫고 고객용 화면으로 이동해요.',
      confirmLabel: '전환',
    );
    if (ok) await _session.enterCustomer();
  }

  Widget _storeHeader({bool compact = false}) {
    return PopupMenuButton<String>(
      tooltip: '매장 메뉴',
      onSelected: (value) {
        switch (value) {
          case 'switch':
            _switchStore();
          case 'customer':
            _toCustomer();
          case 'signOut':
            _session.signOut();
        }
      },
      itemBuilder: (context) => [
        if ((_session.profile?.activeMemberships.length ?? 0) > 1)
          const PopupMenuItem(value: 'switch', child: Text('다른 매장 선택')),
        const PopupMenuItem(value: 'customer', child: Text('고객 화면으로 전환')),
        const PopupMenuItem(value: 'signOut', child: Text('로그아웃')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront, color: AppColors.primary),
            if (!compact) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  _storeName ?? '매장',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(' · ${_ctx.role.label}', style: const TextStyle(color: AppColors.lightText)),
            ],
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctx = _ctx;
    final visible = _visible;
    if (!visible.contains(_index)) _index = 0;
    final content = KeyedSubtree(key: ValueKey(_index), child: _sections[_index].builder(ctx, _go));

    if (isWideLayout(context)) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 1200,
              selectedIndex: visible.indexOf(_index),
              onDestinationSelected: (i) => _go(visible[i]),
              leading: _storeHeader(compact: MediaQuery.sizeOf(context).width < 1200),
              destinations: [
                for (final i in visible)
                  NavigationRailDestination(icon: Icon(_sections[i].icon), label: Text(_sections[i].label)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        ),
      );
    }

    final tabIndex = _mobileTabs.contains(_index) ? _mobileTabs.indexOf(_index) : _mobileTabs.length;
    return Scaffold(
      body: content,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabIndex,
        onDestinationSelected: (i) {
          if (i < _mobileTabs.length) {
            _go(_mobileTabs[i]);
          } else {
            _openMore(visible);
          }
        },
        destinations: [
          for (final i in _mobileTabs)
            NavigationDestination(icon: Icon(_sections[i].icon), label: _sections[i].label),
          const NavigationDestination(icon: Icon(Icons.menu), label: '더보기'),
        ],
      ),
    );
  }

  void _openMore(List<int> visible) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: _storeHeader()),
            const Divider(),
            for (final i in visible.where((i) => !_mobileTabs.contains(i)))
              ListTile(
                leading: Icon(_sections[i].icon),
                title: Text(_sections[i].label),
                selected: _index == i,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _go(i);
                },
              ),
          ],
        ),
      ),
    );
  }
}

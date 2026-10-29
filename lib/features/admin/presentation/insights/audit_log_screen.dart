import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/domain/paged.dart';
import '../../../../core/domain/statuses.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/presentation/view_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_time_format.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/view_model_scope.dart';
import '../../domain/admin_entities.dart';
import '../../domain/admin_insights_usecases.dart';
import '../../domain/admin_repositories.dart';
import '../admin_common.dart';
import '../admin_reservation_detail_screen.dart';

class AuditLogViewModel extends LoadableViewModel<Paged<AuditLogEntry>> {
  AuditLogViewModel(this.storeId, AdminInsightsRepository repository) : _get = GetAuditLogs(repository);

  final String storeId;
  final GetAuditLogs _get;
  DateTime date = storeToday();
  String? action;
  String? targetType;
  String targetId = '';
  String keyword = '';
  bool loadingMore = false;

  /// 매장 현지 날짜 하루 범위
  (DateTime, DateTime) get _range {
    final start = DateTime.parse(storeIso(date, 0, 0));
    return (start, start.add(const Duration(days: 1)));
  }

  @override
  Future<Paged<AuditLogEntry>> fetch() {
    final (from, to) = _range;
    return _get(
      storeId,
      action: action,
      targetType: targetType,
      targetId: targetId.trim().isEmpty ? null : targetId.trim(),
      from: from,
      to: to,
    );
  }

  /// 직원·고객명 필터는 서버 필터가 없어 수행자 이름과 사유에서 찾는다.
  List<AuditLogEntry> get visible {
    final items = data?.items ?? const <AuditLogEntry>[];
    final k = keyword.trim();
    if (k.isEmpty) return items;
    return items.where((e) => '${e.actorName ?? ''} ${e.reason ?? ''}'.contains(k)).toList();
  }

  void apply({DateTime? date, String? action, bool clearAction = false, String? targetType, bool clearTarget = false}) {
    this.date = date ?? this.date;
    this.action = clearAction ? null : (action ?? this.action);
    this.targetType = clearTarget ? null : (targetType ?? this.targetType);
    load();
  }

  Future<void> loadMore() async {
    final current = data;
    if (current == null || !current.hasNext || loadingMore) return;
    loadingMore = true;
    notify();
    try {
      final (from, to) = _range;
      final next = await _get(storeId, action: action, targetType: targetType, from: from, to: to, cursor: current.cursor);
      data = Paged(items: [...current.items, ...next.items], cursor: next.cursor, hasNext: next.hasNext);
    } on AppFailure catch (failure) {
      AppMessenger.showFailure(failure);
    } finally {
      loadingMore = false;
      notify();
    }
  }
}

/// A-16 운영 이력
class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({super.key, required this.ctx});

  final OperatorContext ctx;

  static const _actions = [
    'RESERVATION_CANCELLED',
    'RESERVATION_RESCHEDULED',
    'RESERVATION_MARKED_NO_SHOW',
    'WALK_IN_REORDERED',
    'WALK_IN_SKIPPED',
    'STORE_POLICY_UPDATED',
    'STAFF_UPDATED',
  ];

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<AuditLogViewModel>(
      create: () => AuditLogViewModel(ctx.storeId, GetIt.I<AdminInsightsRepository>()),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: const Text('운영 이력')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DateNavigator(date: vm.date, onChanged: (d) => vm.apply(date: d)),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  DropdownButton<String?>(
                    value: vm.action,
                    hint: const Text('전체 작업'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('전체 작업')),
                      for (final a in _actions) DropdownMenuItem(value: a, child: Text(auditActionLabel(a))),
                    ],
                    onChanged: (a) => a == null ? vm.apply(clearAction: true) : vm.apply(action: a),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String?>(
                    value: vm.targetType,
                    hint: const Text('전체 대상'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('전체 대상')),
                      for (final t in const ['RESERVATION', 'WALK_IN_ENTRY', 'WAITLIST_ENTRY', 'STORE', 'STORE_MEMBER', 'SERVICE'])
                        DropdownMenuItem(value: t, child: Text(targetTypeLabel(t))),
                    ],
                    onChanged: (t) => t == null ? vm.apply(clearTarget: true) : vm.apply(targetType: t),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      decoration: const InputDecoration(isDense: true, hintText: '예약 번호'),
                      onSubmitted: (v) {
                        vm.targetId = v;
                        vm.load();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      decoration: const InputDecoration(isDense: true, hintText: '직원·고객명'),
                      onChanged: (v) {
                        vm.keyword = v;
                        vm.notify();
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: LoadableBody<Paged<AuditLogEntry>>(
                vm: vm,
                builder: (context, _) {
                  final items = vm.visible;
                  if (items.isEmpty) {
                    return ListView(children: const [SizedBox(height: 80), EmptyView(icon: Icons.history, title: '기록된 이력이 없어요.')]);
                  }
                  return NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.extentAfter < 300) vm.loadMore();
                      return false;
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final e = items[index];
                        return ListTile(
                          leading: Text(formatTime(e.occurredAt), style: const TextStyle(fontWeight: FontWeight.w600)),
                          title: Text(auditActionLabel(e.action)),
                          subtitle: Text(
                            [
                              '${actorLabel(e.actorType)} ${e.actorName ?? ''}'.trim(),
                              '${targetTypeLabel(e.targetType)} ${e.targetId == null ? '' : e.targetId!.substring(0, e.targetId!.length.clamp(0, 8))}',
                              if (e.reason != null) '사유: ${e.reason}',
                            ].join(' · '),
                          ),
                          trailing: e.targetType == 'RESERVATION' && e.targetId != null
                              ? const Icon(Icons.chevron_right, color: AppColors.lightText)
                              : null,
                          onTap: e.targetType == 'RESERVATION' && e.targetId != null
                              ? () => pushPage<void>(
                                  context,
                                  AdminReservationDetailScreen(storeId: ctx.storeId, reservationId: e.targetId!),
                                )
                              : null,
                        );
                      },
                    ),
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

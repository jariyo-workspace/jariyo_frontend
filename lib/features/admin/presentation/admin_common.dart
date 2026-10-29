import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/paged.dart';
import '../../../core/domain/statuses.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_time_format.dart';
import '../../../core/widgets/dialogs.dart';
import '../domain/admin_entities.dart';
import '../domain/admin_repositories.dart';
import '../domain/admin_settings_usecases.dart';
import 'admin_reservation_detail_screen.dart';

/// 운영 화면 공통 정보
class OperatorContext {
  const OperatorContext({required this.storeId, required this.role, this.storeName});

  final String storeId;
  final StoreRole role;
  final String? storeName;

  bool get canManageSettings => role.atLeast(StoreRole.manager);

  bool get isOwner => role == StoreRole.owner;
}

/// 운영자 화면이 넓은 화면(태블릿·데스크톱)인지
bool isWideLayout(BuildContext context) => MediaQuery.sizeOf(context).width >= 840;

/// 직원 선택. [preferName]과 이름이 같은 직원을 미리 선택한다.
Future<StaffMember?> pickStaff(
  BuildContext context,
  String storeId, {
  String title = '담당 직원을 선택해 주세요',
  String? preferName,
}) async {
  List<StaffMember> staff;
  try {
    staff = (await GetStaffMembers(GetIt.I<StoreSettingsRepository>())(storeId))
        .where((s) => s.isActive && s.bookingEnabled)
        .toList();
  } on AppFailure catch (failure) {
    AppMessenger.showFailure(failure);
    return null;
  }
  if (!context.mounted) return null;
  if (staff.isEmpty) {
    AppMessenger.show('배정할 수 있는 직원이 없어요.');
    return null;
  }
  final preferred = staff.where((s) => s.displayName == preferName).firstOrNull;
  final id = await showChoiceSheet<String>(
    context,
    title: title,
    selected: preferred?.id,
    options: [for (final s in staff) (s.id, s.displayName, s.role.label)],
  );
  return staff.where((s) => s.id == id).firstOrNull;
}

/// `{updated: false, conflicts}` 응답을 보여준다. 저장되지 않았음을 분명히 안내한다.
Future<void> showConflictDialog(
  BuildContext context,
  String storeId,
  UpdateResult result, {
  String title = '저장하지 못했어요',
  String? message,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message ?? '변경 내용과 충돌하는 기존 예약 ${result.conflicts.length}건이 있어요.\n변경 내용은 저장되지 않았어요. 예약을 먼저 조정해 주세요.',
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final conflict in result.conflicts)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.event_busy, color: AppColors.danger),
                      title: Text(formatDateTime(conflict.startAt)),
                      trailing: const Text('예약 확인'),
                      onTap: () {
                        Navigator.pop(dialogContext);
                        pushPage<void>(
                          context,
                          AdminReservationDetailScreen(storeId: storeId, reservationId: conflict.reservationId),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('변경 취소'))],
    ),
  );
}

/// 설정 저장 결과 처리. 충돌이면 false.
Future<bool> handleUpdateResult(BuildContext context, String storeId, UpdateResult result, {String? successMessage}) async {
  if (result.updated) {
    if (successMessage != null) AppMessenger.show(successMessage);
    return true;
  }
  if (context.mounted) await showConflictDialog(context, storeId, result);
  return false;
}

/// 날짜 이동 막대 (이전 · 날짜 · 다음 · 오늘)
class DateNavigator extends StatelessWidget {
  const DateNavigator({super.key, required this.date, required this.onChanged, this.stepDays = 1, this.label});

  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  final int stepDays;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: '이전',
          onPressed: () => onChanged(date.subtract(Duration(days: stepDays))),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2024),
                lastDate: DateTime(2030),
              );
              if (picked != null) onChanged(DateTime.utc(picked.year, picked.month, picked.day));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                label ?? formatCalendarDate(date),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: '다음',
          onPressed: () => onChanged(date.add(Duration(days: stepDays))),
          icon: const Icon(Icons.chevron_right),
        ),
        TextButton(onPressed: () => onChanged(storeToday()), child: const Text('오늘')),
      ],
    );
  }
}

/// 요약 수치 카드
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color = AppColors.primary,
    this.onTap,
    this.caption,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color color;
  final VoidCallback? onTap;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[Icon(icon, size: 18, color: color), const SizedBox(width: 6)],
                  Expanded(
                    child: Text(label, style: const TextStyle(color: AppColors.lightText, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
              if (caption != null) Text(caption!, style: const TextStyle(color: AppColors.lightText, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 넓은 화면에서 여러 열로 배치하는 그리드
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({super.key, required this.children, this.minItemWidth = 160, this.spacing = 10});

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / minItemWidth).floor().clamp(2, 6);
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final child in children) SizedBox(width: width, child: child)],
        );
      },
    );
  }
}

/// 감사 로그 작업 유형 표시
String auditActionLabel(String action) => switch (action) {
  'WALK_IN_REORDERED' => '대기 순서 변경',
  'WALK_IN_CALLED' => '현장 고객 호출',
  'WALK_IN_SKIPPED' => '현장 대기 보류',
  'WALK_IN_CANCELLED' => '현장 대기 취소',
  'RESERVATION_CANCELLED' => '예약 취소',
  'RESERVATION_RESCHEDULED' => '예약 시간 변경',
  'RESERVATION_NO_SHOW' || 'RESERVATION_MARKED_NO_SHOW' => '노쇼 처리',
  'RESERVATION_CHECKED_IN' => '체크인 처리',
  'STORE_POLICY_UPDATED' => '운영 정책 변경',
  'STORE_UPDATED' => '매장 정보 변경',
  'SERVICE_CREATED' => '서비스 추가',
  'SERVICE_UPDATED' => '서비스 수정',
  'SERVICE_DEACTIVATED' => '서비스 비활성화',
  'SERVICE_ACTIVATED' => '서비스 활성화',
  'STAFF_ADDED' => '직원 추가',
  'STAFF_UPDATED' => '직원 정보 변경',
  'STAFF_DEACTIVATED' => '직원 비활성화',
  'STAFF_SCHEDULES_REPLACED' => '근무시간 변경',
  'BUSINESS_HOURS_REPLACED' => '영업시간 변경',
  'FAILED_JOB_RETRIED' => '실패 작업 재처리',
  'FAILED_JOB_IGNORED' => '실패 작업 무시',
  _ => action.replaceAll('_', ' ').toLowerCase(),
};

String targetTypeLabel(String? type) => switch (type) {
  'RESERVATION' => '예약',
  'WALK_IN_ENTRY' => '현장 대기',
  'WAITLIST_ENTRY' => '예약 대기',
  'SLOT_OFFER' => '빈자리 제안',
  'STORE' => '매장',
  'STORE_MEMBER' => '직원',
  'SERVICE' => '서비스',
  _ => type ?? '-',
};

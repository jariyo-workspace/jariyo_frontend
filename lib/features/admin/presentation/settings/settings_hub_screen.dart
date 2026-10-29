import 'package:flutter/material.dart';

import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../admin_common.dart';
import 'business_hours_screen.dart';
import 'exceptions_screen.dart';
import 'policy_screen.dart';
import 'service_management_screen.dart';
import 'staff_management_screen.dart';
import 'store_info_screen.dart';

/// 매장 관리 메뉴 (서비스·직원·근무시간·휴무·정책·매장 정보)
class SettingsHubScreen extends StatelessWidget {
  const SettingsHubScreen({super.key, required this.ctx});

  final OperatorContext ctx;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String, Widget)>[
      (Icons.design_services_outlined, '서비스', '서비스 항목과 소요 시간', ServiceManagementScreen(ctx: ctx)),
      (Icons.badge_outlined, '직원', '직원과 담당 서비스, 근무 일정', StaffManagementScreen(ctx: ctx)),
      (Icons.schedule, '영업시간', '요일별 영업시간', BusinessHoursScreen(ctx: ctx)),
      (Icons.event_busy_outlined, '휴무 및 예외 일정', '임시 휴무, 직원 휴가, 예약 차단', ExceptionsScreen(ctx: ctx)),
      (Icons.rule_outlined, '운영 정책', '예약·취소·대기 정책', PolicyScreen(ctx: ctx)),
      (Icons.store_outlined, '매장 정보', '매장명, 소개, 연락처, 주소', StoreInfoScreen(ctx: ctx)),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('매장 관리')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!isWideLayout(context))
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: NoticeBox(message: '복잡한 정책과 직원 일정 설정은 태블릿이나 PC에서 더 편하게 할 수 있어요.'),
            ),
          ResponsiveGrid(
            minItemWidth: 260,
            children: [
              for (final (icon, title, subtitle, page) in items)
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withAlpha(20),
                      child: Icon(icon, color: AppColors.primary),
                    ),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(subtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => pushPage<void>(context, page),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

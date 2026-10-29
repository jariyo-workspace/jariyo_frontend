import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/presentation/view_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_time_format.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/view_model_scope.dart';
import '../../../store/domain/store_entities.dart';
import '../../../store/domain/store_repository.dart';
import '../../../store/domain/store_usecases.dart';
import 'booking_flow.dart';
import 'time_select_screen.dart';

class _StaffViewModel extends LoadableViewModel<List<StaffOption>> {
  _StaffViewModel(this._getStaff, this._storeId, this._serviceId);

  final GetServiceStaff _getStaff;
  final String _storeId;
  final String _serviceId;

  @override
  Future<List<StaffOption>> fetch() => _getStaff(_storeId, _serviceId);
}

/// C-06 직원 선택. "가능한 직원 누구나" 또는 특정 직원.
class StaffSelectScreen extends StatelessWidget {
  const StaffSelectScreen({super.key, required this.flow});

  final BookingFlow flow;

  void _next(BuildContext context, StaffOption? staff) {
    flow.selectStaff(staff);
    pushPage<void>(context, TimeSelectScreen(flow: flow));
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<_StaffViewModel>(
      create: () => _StaffViewModel(GetServiceStaff(GetIt.I<StoreRepository>()), flow.store.id, flow.service!.id),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: const Text('직원 선택')),
        body: LoadableBody<List<StaffOption>>(
          vm: vm,
          builder: (context, staff) {
            final bookable = staff.where((s) => s.bookingEnabled).toList();
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _SelectionSummary(flow: flow),
                const SizedBox(height: 16),
                if (bookable.isEmpty)
                  const NoticeBox(message: '지금은 예약을 받을 수 있는 직원이 없어요. 매장에 문의해 주세요.')
                else ...[
                  _StaffTile(
                    title: '가능한 직원 누구나',
                    subtitle: '가장 빠른 시간에 가능한 직원이 배정돼요.',
                    icon: Icons.groups_outlined,
                    selected: flow.slot != null && flow.staff == null,
                    onTap: () => _next(context, null),
                  ),
                  const SizedBox(height: 8),
                  const NoticeBox(message: '직원을 선택하지 않으면 예약 가능한 직원 중 한 명이 자동으로 배정될 수 있어요.'),
                  const SectionTitle('직원 선택'),
                  for (final member in staff) ...[
                    _StaffTile(
                      title: member.displayName,
                      subtitle: !member.bookingEnabled
                          ? '현재 예약을 받지 않아요'
                          : [
                              if (member.nextAvailableAt != null) '가장 빠른 예약 ${formatRelative(member.nextAvailableAt!)}',
                              if (member.customDurationMinutes != null)
                                '소요 ${formatMinutes(member.customDurationMinutes!)}',
                            ].join(' · '),
                      initial: member.displayName.isEmpty ? '?' : member.displayName.characters.first,
                      selected: flow.staff?.id == member.id,
                      onTap: member.bookingEnabled ? () => _next(context, member) : null,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SelectionSummary extends StatelessWidget {
  const _SelectionSummary({required this.flow});

  final BookingFlow flow;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        children: [
          InfoRow(label: '매장', value: flow.store.name),
          InfoRow(label: '서비스', value: '${flow.service!.name} · 약 ${formatMinutes(flow.service!.durationMinutes)}'),
        ],
      ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  const _StaffTile({
    required this.title,
    required this.subtitle,
    this.icon,
    this.initial,
    this.selected = false,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData? icon;
  final String? initial;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
      ),
      child: ListTile(
        enabled: enabled,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withAlpha(enabled ? 30 : 12),
          child: icon != null
              ? Icon(icon, color: AppColors.primary)
              : Text(initial ?? '', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: enabled ? const Icon(Icons.chevron_right) : null,
      ),
    );
  }
}

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
import 'staff_select_screen.dart';

class _ServicesViewModel extends LoadableViewModel<List<ServiceItem>> {
  _ServicesViewModel(this._getServices, this._storeId);

  final GetStoreServices _getServices;
  final String _storeId;

  // 비활성 서비스도 "선택할 수 없음"으로 보여주기 위해 전체를 조회한다.
  @override
  Future<List<ServiceItem>> fetch() => _getServices(_storeId, activeOnly: false);
}

/// C-05 서비스 선택. 한 번에 하나의 서비스만 선택한다.
class ServiceSelectScreen extends StatelessWidget {
  const ServiceSelectScreen({super.key, required this.flow});

  final BookingFlow flow;

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<_ServicesViewModel>(
      create: () => _ServicesViewModel(GetStoreServices(GetIt.I<StoreRepository>()), flow.store.id),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: const Text('서비스 선택')),
        body: LoadableBody<List<ServiceItem>>(
          vm: vm,
          loadingMessage: '서비스를 불러오고 있어요',
          builder: (context, services) {
            if (services.isEmpty) {
              return const EmptyView(title: '예약할 수 있는 서비스가 없어요.', message: '매장에 직접 문의해 주세요.');
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: services.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Text(
                    flow.store.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
                  );
                }
                final service = services[index - 1];
                return ServiceCard(
                  service: service,
                  selected: flow.service?.id == service.id,
                  onTap: service.isBookable
                      ? () {
                          flow.selectService(service);
                          pushPage<void>(context, StaffSelectScreen(flow: flow));
                        }
                      : null,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class ServiceCard extends StatelessWidget {
  const ServiceCard({super.key, required this.service, this.selected = false, this.onTap});

  final ServiceItem service;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final unavailableReason = !service.isActive ? '현재 예약을 받지 않는 서비스예요' : '담당 가능한 직원이 없어요';
    return Semantics(
      button: true,
      enabled: enabled,
      label: '${service.name}, 예상 ${formatMinutes(service.durationMinutes)}${enabled ? '' : ', 선택 불가'}',
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(service.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                      if (enabled) const Icon(Icons.chevron_right, color: AppColors.lightText),
                    ],
                  ),
                  if (service.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(service.description, style: const TextStyle(color: AppColors.lightText)),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _Meta(icon: Icons.schedule, text: '약 ${formatMinutes(service.durationMinutes)}'),
                      _Meta(icon: Icons.person_outline, text: '담당 직원 ${service.availableStaffCount}명'),
                    ],
                  ),
                  if (!enabled) ...[
                    const SizedBox(height: 8),
                    Text(unavailableReason, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: AppColors.lightText),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(color: AppColors.lightText, fontSize: 13)),
    ],
  );
}

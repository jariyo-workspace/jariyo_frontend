import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/domain/paged.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/presentation/view_model.dart';
import '../../../../core/realtime/refresh_bus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_time_format.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/dialogs.dart';
import '../../../../core/widgets/view_model_scope.dart';
import '../../../store/domain/store_entities.dart';
import '../../domain/admin_entities.dart';
import '../../domain/admin_repositories.dart';
import '../../domain/admin_settings_usecases.dart';
import '../admin_common.dart';
import 'staff_management_screen.dart';

class ServiceManagementViewModel extends LoadableViewModel<List<ServiceItem>> {
  ServiceManagementViewModel(this.storeId, StoreSettingsRepository repository, this._bus)
    : _list = GetManagedServices(repository),
      _manage = ManageService(repository) {
    listenTopics(_bus, {RefreshTopic.adminSettings}, refresh);
  }

  final String storeId;
  final RefreshBus _bus;
  final GetManagedServices _list;
  final ManageService _manage;

  @override
  Future<List<ServiceItem>> fetch() async =>
      (await _list(storeId))..sort((a, b) => a.isActive == b.isActive ? a.name.compareTo(b.name) : (a.isActive ? -1 : 1));

  void _changed() => _bus.emit({RefreshTopic.adminSettings, RefreshTopic.storeDetail});

  Future<bool> save(ServiceInput input, {String? serviceId}) => runAction('save', () async {
    if (serviceId == null) {
      await _manage.create(storeId, input);
      AppMessenger.show('서비스를 추가했어요.');
    } else {
      await _manage.update(storeId, serviceId, input);
      AppMessenger.show('서비스를 수정했어요.');
    }
    _changed();
    await refresh();
  });

  Future<void> activate(String serviceId) => runAction('toggle:$serviceId', () async {
    await _manage.activate(storeId, serviceId);
    _changed();
    AppMessenger.show('서비스를 다시 예약받아요.');
    await refresh();
  });

  Future<UpdateResult?> deactivate(String serviceId) async {
    UpdateResult? result;
    await runAction('toggle:$serviceId', () async {
      result = await _manage.deactivate(storeId, serviceId);
      if (result!.updated) {
        _changed();
        await refresh();
      }
    });
    return result;
  }
}

/// A-10 서비스 관리. 삭제 대신 비활성화를 기본으로 한다.
class ServiceManagementScreen extends StatelessWidget {
  const ServiceManagementScreen({super.key, required this.ctx});

  final OperatorContext ctx;

  Future<void> _edit(BuildContext context, ServiceManagementViewModel vm, [ServiceItem? service]) async {
    final input = await showDialog<ServiceInput>(context: context, builder: (_) => _ServiceDialog(service: service));
    if (input != null) await vm.save(input, serviceId: service?.id);
  }

  Future<void> _deactivate(BuildContext context, ServiceManagementViewModel vm, ServiceItem service) async {
    final ok = await showConfirmDialog(
      context,
      title: '${service.name}을(를) 비활성화할까요?',
      message: '비활성화하면 새 예약을 받지 않아요. 기존 예약이 있는 서비스는 삭제하지 않고 비활성화로 관리해요.\n언제든 다시 활성화할 수 있어요.',
      confirmLabel: '비활성화',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final result = await vm.deactivate(service.id);
    if (result != null && context.mounted) {
      await handleUpdateResult(context, ctx.storeId, result, successMessage: '서비스를 비활성화했어요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<ServiceManagementViewModel>(
      create: () => ServiceManagementViewModel(ctx.storeId, GetIt.I<StoreSettingsRepository>(), GetIt.I<RefreshBus>()),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: const Text('서비스 관리')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(context, vm),
          icon: const Icon(Icons.add),
          label: const Text('서비스 추가'),
        ),
        body: LoadableBody<List<ServiceItem>>(
          vm: vm,
          builder: (context, services) {
            if (services.isEmpty) {
              return const EmptyView(title: '등록된 서비스가 없어요.', message: '서비스를 추가하면 고객이 예약할 수 있어요.');
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: services.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final s = services[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(s.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                            Text(
                              s.isActive ? '활성' : '비활성',
                              style: TextStyle(
                                color: s.isActive ? AppColors.positive : AppColors.lightText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        if (s.description.isNotEmpty) Text(s.description, style: const TextStyle(color: AppColors.lightText)),
                        const SizedBox(height: 6),
                        Text(
                          '기본 ${formatMinutes(s.durationMinutes)} · 정리 ${formatMinutes(s.cleanupMinutes)} · 동시 ${s.capacity}명 · 담당 직원 ${s.availableStaffCount}명',
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            AppButton(
                              label: '수정',
                              expand: false,
                              variant: AppButtonVariant.secondary,
                              onPressed: () => _edit(context, vm, s),
                            ),
                            AppButton(
                              label: '담당 직원 설정',
                              expand: false,
                              variant: AppButtonVariant.secondary,
                              onPressed: () => pushPage<void>(context, StaffManagementScreen(ctx: ctx)),
                            ),
                            AppButton(
                              label: s.isActive ? '비활성화' : '활성화',
                              expand: false,
                              variant: AppButtonVariant.text,
                              loading: vm.isBusy('toggle:${s.id}'),
                              onPressed: () => s.isActive ? _deactivate(context, vm, s) : vm.activate(s.id),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ServiceDialog extends StatefulWidget {
  const _ServiceDialog({this.service});

  final ServiceItem? service;

  @override
  State<_ServiceDialog> createState() => _ServiceDialogState();
}

class _ServiceDialogState extends State<_ServiceDialog> {
  late final _name = TextEditingController(text: widget.service?.name);
  late final _description = TextEditingController(text: widget.service?.description);
  late final _duration = TextEditingController(text: '${widget.service?.durationMinutes ?? 30}');
  late final _cleanup = TextEditingController(text: '${widget.service?.cleanupMinutes ?? 0}');
  late final _capacity = TextEditingController(text: '${widget.service?.capacity ?? 1}');
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _description, _duration, _cleanup, _capacity]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final duration = int.tryParse(_duration.text) ?? 0;
    final cleanup = int.tryParse(_cleanup.text) ?? -1;
    final capacity = int.tryParse(_capacity.text) ?? 0;
    if (_name.text.trim().isEmpty) return setState(() => _error = '서비스명을 입력해 주세요.');
    if (duration <= 0) return setState(() => _error = '소요 시간은 1분 이상이어야 해요.');
    if (cleanup < 0) return setState(() => _error = '정리 시간은 0분 이상이어야 해요.');
    if (capacity <= 0) return setState(() => _error = '동시 인원은 1명 이상이어야 해요.');
    Navigator.pop(
      context,
      ServiceInput(
        name: _name.text.trim(),
        description: _description.text.trim(),
        durationMinutes: duration,
        cleanupMinutes: cleanup,
        capacity: capacity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label, [String? suffix]) => InputDecoration(labelText: label, suffixText: suffix);
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return AlertDialog(
      title: Text(widget.service == null ? '서비스 추가' : '서비스 수정'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _name, decoration: deco('서비스명'), maxLength: 120),
              TextField(controller: _description, decoration: deco('설명'), maxLength: 1000, maxLines: 2),
              Row(
                children: [
                  Expanded(
                    child: TextField(controller: _duration, decoration: deco('기본 소요', '분'), keyboardType: TextInputType.number, inputFormatters: digits),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(controller: _cleanup, decoration: deco('정리 시간', '분'), keyboardType: TextInputType.number, inputFormatters: digits),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(controller: _capacity, decoration: deco('동시 인원', '명'), keyboardType: TextInputType.number, inputFormatters: digits),
                  ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(onPressed: _submit, child: const Text('저장')),
      ],
    );
  }
}

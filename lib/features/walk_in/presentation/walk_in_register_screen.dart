import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../app/session_controller.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../../core/network/idempotency.dart';
import '../../../core/presentation/view_model.dart';
import '../../../core/realtime/refresh_bus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_time_format.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/view_model_scope.dart';
import '../../store/domain/store_entities.dart';
import '../../store/domain/store_repository.dart';
import '../../store/domain/store_usecases.dart';
import '../domain/walk_in_entities.dart';
import '../domain/walk_in_repository.dart';
import '../domain/walk_in_usecases.dart';
import 'walk_in_detail_screen.dart';

class WalkInRegisterData {
  const WalkInRegisterData({required this.store, required this.services});

  final StoreDetail store;
  final List<ServiceItem> services;
}

class WalkInRegisterViewModel extends LoadableViewModel<WalkInRegisterData> {
  WalkInRegisterViewModel(this.storeId, StoreRepository stores, WalkInRepository walkIns, this._bus)
    : _getStore = GetStoreDetail(stores),
      _getServices = GetStoreServices(stores),
      _getStaff = GetServiceStaff(stores),
      _getStatus = GetWalkInAvailability(stores),
      _register = RegisterWalkIn(walkIns),
      _mine = GetMyWalkIns(walkIns);

  final String storeId;
  final RefreshBus _bus;
  final GetStoreDetail _getStore;
  final GetStoreServices _getServices;
  final GetServiceStaff _getStaff;
  final GetWalkInAvailability _getStatus;
  final RegisterWalkIn _register;
  final GetMyWalkIns _mine;
  final _keys = IdempotencyKeyHolder();

  ServiceItem? service;
  StaffOption? staff;
  int partySize = 1;
  List<StaffOption> staffOptions = [];
  WalkInAvailability? status;
  bool statusLoading = false;
  String? existingWalkInId;

  @override
  Future<WalkInRegisterData> fetch() async {
    final results = await Future.wait<Object>([_getStore(storeId), _getServices(storeId)]);
    final services = (results[1] as List<ServiceItem>).where((s) => s.isActive).toList();
    await _loadStatus();
    return WalkInRegisterData(store: results[0] as StoreDetail, services: services);
  }

  Future<void> _loadStatus() async {
    statusLoading = true;
    notify();
    try {
      status = await _getStatus(storeId, serviceId: service?.id, staffId: staff?.id);
    } on AppFailure {
      status = null;
    } finally {
      statusLoading = false;
      notify();
    }
  }

  Future<void> selectService(ServiceItem value) async {
    service = value;
    staff = null;
    staffOptions = [];
    notify();
    try {
      staffOptions = (await _getStaff(storeId, value.id)).where((s) => s.bookingEnabled).toList();
    } on AppFailure {
      staffOptions = [];
    }
    await _loadStatus();
  }

  Future<void> selectStaff(StaffOption? value) async {
    staff = value;
    notify();
    await _loadStatus();
  }

  void setPartySize(int value) {
    partySize = value;
    notify();
  }

  bool get acceptingEntries => status?.acceptingEntries ?? true;

  bool get canSubmit => service != null && acceptingEntries && !isBusy('register');

  Future<String?> submit() async {
    final request = NewWalkIn(storeId: storeId, serviceId: service!.id, preferredStaffId: staff?.id, partySize: partySize);
    final key = _keys.keyFor(request.toJson());
    String? walkInId;
    await runAction(
      'register',
      () async {
        final walkIn = await _register(request, idempotencyKey: key);
        _keys.settle();
        _bus.emit(RefreshBus.afterWalkInChanged);
        walkInId = walkIn.id;
      },
      onFailure: (failure) {
        if (failure.kind != FailureKind.unknownOutcome) _keys.settle();
        switch (failure.code) {
          case 'WALK_IN_ALREADY_REGISTERED':
            _findExisting();
            return true;
          case 'WALK_IN_REGISTRATION_CLOSED':
            AppMessenger.show('오늘 현장 대기가 마감되었어요.\n예약 가능한 시간을 확인해 보세요.');
            _loadStatus();
            return true;
          case 'WALK_IN_NOT_ENABLED':
            AppMessenger.show('이 매장은 현장 대기를 운영하지 않아요.');
            return true;
        }
        if (failure.kind == FailureKind.unknownOutcome) {
          // 결과가 불명확하면 새로 등록하지 않고 내 대기 목록에서 결과를 확인한다.
          _findExisting(message: '등록 결과를 바로 확인하지 못했어요. 내 대기에서 결과를 확인해 주세요.');
          return true;
        }
        return false;
      },
    );
    return walkInId;
  }

  Future<void> _findExisting({String message = '이미 이 매장에 현장 대기 중이에요.'}) async {
    try {
      final mine = await _mine();
      existingWalkInId = mine.where((w) => w.status.isActive && w.effectiveStoreId == storeId).firstOrNull?.id ??
          mine.where((w) => w.status.isActive).firstOrNull?.id;
    } on AppFailure {
      existingWalkInId = null;
    }
    AppMessenger.show(message);
    notify();
  }
}

/// C-14 현장 대기 등록
class WalkInRegisterScreen extends StatelessWidget {
  const WalkInRegisterScreen({super.key, required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context) {
    final profile = GetIt.I<SessionController>().profile;
    return ViewModelScope<WalkInRegisterViewModel>(
      create: () => WalkInRegisterViewModel(
        storeId,
        GetIt.I<StoreRepository>(),
        GetIt.I<WalkInRepository>(),
        GetIt.I<RefreshBus>(),
      ),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: const Text('현장 대기 등록')),
        body: LoadableBody<WalkInRegisterData>(
          vm: vm,
          builder: (context, data) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(data.store.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _ExpectationCard(vm: vm),
              const SectionTitle('서비스'),
              if (data.services.isEmpty)
                const Text('현장 대기로 이용할 수 있는 서비스가 없어요.', style: TextStyle(color: AppColors.lightText))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final service in data.services)
                      ChoiceChip(
                        label: Text('${service.name} · ${formatMinutes(service.durationMinutes)}'),
                        selected: vm.service?.id == service.id,
                        onSelected: (_) => vm.selectService(service),
                      ),
                  ],
                ),
              if (vm.service != null) ...[
                const SectionTitle('희망 직원'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(label: const Text('누구나'), selected: vm.staff == null, onSelected: (_) => vm.selectStaff(null)),
                    for (final s in vm.staffOptions)
                      ChoiceChip(label: Text(s.displayName), selected: vm.staff?.id == s.id, onSelected: (_) => vm.selectStaff(s)),
                  ],
                ),
              ],
              const SectionTitle('인원'),
              Align(
                alignment: Alignment.centerLeft,
                child: NumberStepper(value: vm.partySize, unit: '명', onChanged: vm.setPartySize),
              ),
              const SectionTitle('고객 정보'),
              SectionCard(
                child: Column(
                  children: [
                    InfoRow(label: '이름', value: profile?.displayName ?? '-'),
                    InfoRow(label: '연락처', value: profile?.phoneNumber ?? '-'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const NoticeBox(
                icon: Icons.campaign_outlined,
                message: '호출 후 일정 시간 안에 응답하지 않으면 순서가 넘어갈 수 있어요.',
              ),
              if (vm.existingWalkInId != null) ...[
                const SizedBox(height: 12),
                AppButton(
                  label: '내 현장 대기 보기',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => replacePage<void>(context, WalkInDetailScreen(walkInId: vm.existingWalkInId!)),
                ),
              ],
            ],
          ),
        ),
        bottomNavigationBar: vm.data == null
            ? null
            : BottomActionBar(
                children: [
                  if (vm.service == null)
                    const Text('서비스를 선택해 주세요.', style: TextStyle(color: AppColors.lightText)),
                  AppButton(
                    label: vm.acceptingEntries ? '현장 대기 등록' : '현장 대기 마감',
                    loading: vm.isBusy('register'),
                    loadingLabel: '대기를 등록하고 있어요',
                    onPressed: vm.canSubmit
                        ? () async {
                            final id = await vm.submit();
                            if (id != null && context.mounted) {
                              AppMessenger.show('현장 대기를 등록했어요.');
                              replacePage<void>(context, WalkInDetailScreen(walkInId: id));
                            }
                          }
                        : null,
                  ),
                ],
              ),
      ),
    );
  }
}

class _ExpectationCard extends StatelessWidget {
  const _ExpectationCard({required this.vm});

  final WalkInRegisterViewModel vm;

  @override
  Widget build(BuildContext context) {
    final status = vm.status;
    if (status == null) {
      return vm.statusLoading
          ? const LinearProgressIndicator()
          : const NoticeBox(message: '현재 대기 현황을 불러오지 못했어요. 등록은 가능해요.');
    }
    if (!status.acceptingEntries) {
      return const NoticeBox(
        icon: Icons.do_not_disturb_on_outlined,
        color: AppColors.danger,
        message: '오늘 현장 대기가 마감되었어요.\n예약 가능한 시간을 확인해 보세요.',
      );
    }
    return SectionCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _Figure(label: '현재 대기', value: '${status.waitingCount}팀')),
              Expanded(child: _Figure(label: '예상 대기', value: '약 ${formatMinutes(status.estimatedWaitMinutes)}')),
              if (status.lastEntryAt != null) Expanded(child: _Figure(label: '접수 마감', value: formatHm(status.lastEntryAt))),
            ],
          ),
          if (vm.statusLoading) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: const TextStyle(color: AppColors.lightText, fontSize: 13)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
    ],
  );
}

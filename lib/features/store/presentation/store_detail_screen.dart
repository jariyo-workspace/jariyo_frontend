import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../app/session_controller.dart';
import '../../../core/domain/statuses.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../../core/presentation/view_model.dart';
import '../../../core/realtime/refresh_bus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_time_format.dart';
import '../../../core/utils/external_links.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/view_model_scope.dart';
import '../../reservation/domain/reservation_entities.dart';
import '../../reservation/domain/reservation_repository.dart';
import '../../reservation/domain/reservation_usecases.dart';
import '../../reservation/presentation/booking/booking_flow.dart';
import '../../reservation/presentation/booking/service_select_screen.dart';
import '../../reservation/presentation/booking/staff_select_screen.dart';
import '../../walk_in/presentation/walk_in_register_screen.dart';
import '../domain/store_entities.dart';
import '../domain/store_repository.dart';
import '../domain/store_usecases.dart';

class StoreDetailData {
  const StoreDetailData({required this.store, this.services = const [], this.staff = const [], this.walkIn});

  final StoreDetail store;
  final List<ServiceItem> services;
  final List<StaffOption> staff;
  final WalkInAvailability? walkIn;
}

class StoreDetailViewModel extends LoadableViewModel<StoreDetailData> {
  StoreDetailViewModel(this.storeId, StoreRepository repository, RefreshBus bus)
    : _getStore = GetStoreDetail(repository),
      _getServices = GetStoreServices(repository),
      _getStaff = GetServiceStaff(repository),
      _getWalkIn = GetWalkInAvailability(repository),
      _recent = RecentStores(repository) {
    listenTopics(bus, {RefreshTopic.storeDetail, RefreshTopic.walkIns}, refresh);
  }

  final String storeId;
  final GetStoreDetail _getStore;
  final GetStoreServices _getServices;
  final GetServiceStaff _getStaff;
  final GetWalkInAvailability _getWalkIn;
  final RecentStores _recent;

  @override
  Future<StoreDetailData> fetch() async {
    final results = await Future.wait<Object?>([
      _getStore(storeId),
      _getServices(storeId),
      _getWalkIn(storeId).then<Object?>((v) => v, onError: (_) => null),
    ]);
    final store = results[0] as StoreDetail;
    final services = results[1] as List<ServiceItem>;
    // 매장 직원 목록은 서비스별 담당 직원을 모아 만든다.
    final staffLists = await Future.wait(
      services.where((s) => s.isActive).map((s) => _getStaff(storeId, s.id).catchError((_) => <StaffOption>[])),
    );
    final staff = <String, StaffOption>{};
    for (final member in staffLists.expand((l) => l)) {
      staff.putIfAbsent(member.id, () => member);
    }
    _recent.remember(id: store.id, name: store.name, address: store.address);
    return StoreDetailData(
      store: store,
      services: services,
      staff: staff.values.toList()..sort((a, b) => a.displayName.compareTo(b.displayName)),
      walkIn: results[2] as WalkInAvailability?,
    );
  }
}

/// C-04 매장 상세
class StoreDetailScreen extends StatelessWidget {
  const StoreDetailScreen({super.key, required this.storeId});

  final String storeId;

  bool _requireSignIn(StoreDetail store, {bool walkIn = false}) {
    final session = GetIt.I<SessionController>();
    if (session.isSignedIn) return false;
    // 비회원은 로그인 후 이어서 진행할 수 있도록 선택 정보를 보관한다.
    BookingDrafts(GetIt.I<ReservationRepository>()).save(
      BookingDraft(storeId: store.id, storeName: store.name, walkIn: walkIn),
    );
    AppMessenger.show('예약과 대기는 로그인 후 이용할 수 있어요.');
    session.requestSignIn();
    return true;
  }

  void _startBooking(BuildContext context, StoreDetail store, {ServiceItem? service}) {
    if (_requireSignIn(store)) return;
    final flow = BookingFlow(store: store, drafts: BookingDrafts(GetIt.I<ReservationRepository>()));
    if (service != null) {
      flow.selectService(service);
      pushPage<void>(context, StaffSelectScreen(flow: flow));
    } else {
      pushPage<void>(context, ServiceSelectScreen(flow: flow));
    }
  }

  void _startWalkIn(BuildContext context, StoreDetail store) {
    if (_requireSignIn(store, walkIn: true)) return;
    pushPage<void>(context, WalkInRegisterScreen(storeId: store.id));
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<StoreDetailViewModel>(
      create: () => StoreDetailViewModel(storeId, GetIt.I<StoreRepository>(), GetIt.I<RefreshBus>()),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: Text(vm.data?.store.name ?? '매장 상세')),
        body: LoadableBody<StoreDetailData>(
          vm: vm,
          loadingMessage: '매장 정보를 불러오고 있어요',
          builder: (context, data) => _body(context, data),
        ),
        bottomNavigationBar: vm.data == null ? null : _bottom(context, vm.data!),
      ),
    );
  }

  Widget _body(BuildContext context, StoreDetailData data) {
    final store = data.store;
    final today = store.today;
    final todayCode = today?.dayOfWeek;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          height: 140,
          decoration: const BoxDecoration(
            image: DecorationImage(image: AssetImage('assets/images/background.png'), fit: BoxFit.cover),
          ),
          alignment: Alignment.bottomLeft,
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(100)),
            child: Text(
              !store.isActive ? store.status.label : (store.isOpenNow ? '지금 영업 중' : '영업 시간이 아니에요'),
              style: TextStyle(
                color: !store.isActive
                    ? AppColors.danger
                    : (store.isOpenNow ? AppColors.positive : AppColors.lightText),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(store.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text)),
              if (store.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(store.description, style: const TextStyle(color: AppColors.lightText, height: 1.4)),
              ],
              const SizedBox(height: 12),
              _LinkRow(icon: Icons.place_outlined, text: store.address, onTap: () => openMap(store.address, name: store.name)),
              _LinkRow(icon: Icons.call_outlined, text: store.phoneNumber, onTap: () => callPhone(store.phoneNumber)),
              if (today != null) _LinkRow(icon: Icons.schedule, text: '오늘 ${today.hoursLabel}'),
              if (store.status == StoreStatus.temporarilyClosed) ...[
                const SizedBox(height: 12),
                const NoticeBox(
                  icon: Icons.event_busy,
                  color: AppColors.danger,
                  message: '매장이 임시 휴무 중이에요. 지금은 예약과 현장 대기를 받을 수 없어요.',
                ),
              ],
              if (store.offersWalkIn && data.walkIn != null) ...[
                const SectionTitle('현장 대기'),
                _WalkInStatusCard(status: data.walkIn!),
              ],
              const SectionTitle('서비스'),
              if (data.services.isEmpty)
                const Text('등록된 서비스가 없어요.', style: TextStyle(color: AppColors.lightText))
              else
                for (final service in data.services) ...[
                  ServiceCard(
                    service: service,
                    onTap: store.canBook && service.isBookable
                        ? () => _startBooking(context, store, service: service)
                        : null,
                  ),
                  const SizedBox(height: 8),
                ],
              if (data.staff.isNotEmpty) ...[
                const SectionTitle('직원'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final member in data.staff)
                      Chip(
                        avatar: CircleAvatar(
                          backgroundColor: AppColors.primary.withAlpha(30),
                          child: Text(
                            member.displayName.isEmpty ? '?' : member.displayName.characters.first,
                            style: const TextStyle(fontSize: 12, color: AppColors.primary),
                          ),
                        ),
                        label: Text(member.bookingEnabled ? member.displayName : '${member.displayName} (예약 불가)'),
                      ),
                  ],
                ),
              ],
              const SectionTitle('영업시간'),
              SectionCard(
                child: Column(
                  children: [
                    if (store.businessHours.isEmpty)
                      const Text('영업시간 정보가 없어요.', style: TextStyle(color: AppColors.lightText)),
                    for (final day in store.businessHours)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 72,
                              child: Text(
                                dayOfWeekLabel(day.dayOfWeek),
                                style: TextStyle(
                                  fontWeight: day.dayOfWeek == todayCode ? FontWeight.w700 : FontWeight.w400,
                                  color: day.dayOfWeek == todayCode ? AppColors.primary : AppColors.text,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                day.hoursLabel,
                                style: TextStyle(color: day.isClosed ? AppColors.danger : AppColors.text),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SectionTitle('예약 및 취소 정책'),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final sentence in store.policy.customerSentences)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text('• $sentence', style: const TextStyle(height: 1.4)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget? _bottom(BuildContext context, StoreDetailData data) {
    final store = data.store;
    final walkInOpen = data.walkIn?.acceptingEntries ?? true;
    final buttons = <Widget>[
      AppButton(label: '예약하기', onPressed: store.canBook ? () => _startBooking(context, store) : null),
      if (store.offersWalkIn)
        AppButton(
          label: walkInOpen ? '현장 대기 등록' : '현장 대기 마감',
          variant: AppButtonVariant.secondary,
          onPressed: store.isActive && walkInOpen ? () => _startWalkIn(context, store) : null,
        ),
    ];
    return BottomActionBar(
      children: [
        if (buttons.length == 1)
          buttons.first
        else
          Row(
            children: [
              Expanded(child: buttons[0]),
              const SizedBox(width: 8),
              Expanded(child: buttons[1]),
            ],
          ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.text, this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.lightText),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: onTap == null ? AppColors.text : AppColors.primary,
                  decoration: onTap == null ? null : TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalkInStatusCard extends StatelessWidget {
  const _WalkInStatusCard({required this.status});

  final WalkInAvailability status;

  @override
  Widget build(BuildContext context) {
    if (!status.acceptingEntries) {
      return const NoticeBox(
        icon: Icons.do_not_disturb_on_outlined,
        message: '오늘 현장 대기가 마감되었어요.\n예약 가능한 시간을 확인해 보세요.',
      );
    }
    return SectionCard(
      child: Row(
        children: [
          Expanded(child: _Figure(label: '현재 대기', value: '${status.waitingCount}팀')),
          Expanded(child: _Figure(label: '예상 대기', value: '약 ${formatMinutes(status.estimatedWaitMinutes)}')),
          if (status.lastEntryAt != null) Expanded(child: _Figure(label: '접수 마감', value: formatHm(status.lastEntryAt))),
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
      Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
    ],
  );
}

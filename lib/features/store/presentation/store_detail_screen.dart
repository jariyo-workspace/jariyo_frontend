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
import '../../reservation/presentation/booking/booking_screen.dart';
import '../../walk_in/presentation/walk_in_register_screen.dart';
import '../domain/store_entities.dart';
import '../domain/store_repository.dart';
import '../domain/store_usecases.dart';
import 'store_search_screen.dart';

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
    pushPage<void>(
      context,
      BookingScreen(
        flow: BookingFlow(store: store, drafts: BookingDrafts(GetIt.I<ReservationRepository>())),
        initialServiceId: service?.id,
      ),
    );
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
        appBar: AppBar(),
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
    final (statusLabel, statusTone) = !store.isActive
        ? (store.status.label, StatusTone.negative)
        : store.isOpenNow
        ? ('영업 중', StatusTone.positive)
        : ('영업 전·종료', StatusTone.neutral);
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 0, AppSpace.page, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusBadge(label: statusLabel, tone: statusTone),
                  const SizedBox(height: 8),
                  Text(store.name, style: AppText.display),
                  if (today != null) ...[
                    const SizedBox(height: 4),
                    Text('오늘 ${today.hoursLabel}', style: AppText.sub),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            StoreAvatar(name: store.name, size: 64),
          ],
        ),
        if (store.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(store.description, style: AppText.body),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            _ActionTile(icon: Icons.call_rounded, label: '전화', onTap: () => callPhone(store.phoneNumber)),
            const SizedBox(width: 8),
            _ActionTile(
              icon: Icons.map_rounded,
              label: '길찾기',
              onTap: () => openMap(store.address, name: store.name),
            ),
          ],
        ),
        if (store.status == StoreStatus.temporarilyClosed) ...[
          const SizedBox(height: 12),
          const NoticeBox(
            icon: Icons.event_busy_rounded,
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
          const NoticeBox(message: '등록된 서비스가 없어요.')
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < data.services.length; i++) ...[
                  if (i > 0) const Divider(indent: 20, endIndent: 20),
                  _ServiceRow(
                    service: data.services[i],
                    onTap: store.canBook && data.services[i].isBookable
                        ? () => _startBooking(context, store, service: data.services[i])
                        : null,
                  ),
                ],
              ],
            ),
          ),
        if (data.staff.isNotEmpty) ...[
          const SectionTitle('직원'),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: data.staff.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final member = data.staff[index];
                return Container(
                  width: 84,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primarySoft,
                        child: Text(
                          member.displayName.isEmpty ? '?' : member.displayName.characters.first,
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        member.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                      if (!member.bookingEnabled) const Text('예약 불가', style: AppText.caption),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
        const SectionTitle('매장 정보'),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoRow(label: '주소', value: store.address),
              InfoRow(label: '전화', value: store.phoneNumber),
              const Divider(height: 24),
              for (final day in store.businessHours)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        dayOfWeekLabel(day.dayOfWeek),
                        style: TextStyle(
                          fontWeight: day.dayOfWeek == todayCode ? FontWeight.w700 : FontWeight.w400,
                          color: day.dayOfWeek == todayCode ? AppColors.primary : AppColors.lightText,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        day.hoursLabel,
                        style: TextStyle(
                          color: day.isClosed ? AppColors.danger : AppColors.text,
                          fontWeight: day.dayOfWeek == todayCode ? FontWeight.w700 : FontWeight.w500,
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
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Icon(Icons.check_rounded, size: 16, color: AppColors.primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(sentence, style: AppText.body)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget? _bottom(BuildContext context, StoreDetailData data) {
    final store = data.store;
    final walkInOpen = data.walkIn?.acceptingEntries ?? true;
    final book = AppButton(label: '예약하기', onPressed: store.canBook ? () => _startBooking(context, store) : null);
    if (!store.offersWalkIn) return BottomActionBar(children: [book]);
    return BottomActionBar(
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: AppButton(
                label: walkInOpen ? '현장 대기' : '대기 마감',
                variant: AppButtonVariant.secondary,
                onPressed: store.isActive && walkInOpen ? () => _startWalkIn(context, store) : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: book),
          ],
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: AppColors.text),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.service, this.onTap});

  final ServiceItem service;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.page, vertical: 16),
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.name, style: AppText.bodyStrong),
                    const SizedBox(height: 2),
                    Text(
                      !service.isActive
                          ? '지금은 예약을 받지 않아요'
                          : [
                              '약 ${formatMinutes(service.durationMinutes)}',
                              if (service.description.isNotEmpty) service.description,
                            ].join(' · '),
                      style: AppText.sub,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (enabled)
                const Text(
                  '예약',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
            ],
          ),
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
        icon: Icons.do_not_disturb_on_rounded,
        message: '오늘 현장 대기가 마감되었어요.\n예약 가능한 시간을 확인해 보세요.',
      );
    }
    return SectionCard(
      child: Row(
        children: [
          Expanded(
            child: _Figure(label: '지금 대기', value: '${status.waitingCount}팀'),
          ),
          Expanded(
            child: _Figure(label: '예상 대기', value: formatMinutes(status.estimatedWaitMinutes)),
          ),
          if (status.lastEntryAt != null)
            Expanded(
              child: _Figure(label: '접수 마감', value: formatHm(status.lastEntryAt)),
            ),
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
      Text(label, style: AppText.caption),
      const SizedBox(height: 4),
      Text(value, style: AppText.section),
    ],
  );
}

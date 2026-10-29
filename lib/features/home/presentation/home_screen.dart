import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get_it/get_it.dart';

import '../../../app/session_controller.dart';
import '../../../core/domain/statuses.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../../core/presentation/view_model.dart';
import '../../../core/realtime/refresh_bus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/countdown.dart';
import '../../../core/widgets/view_model_scope.dart';
import '../../notification/presentation/notification_screen.dart';
import '../../reservation/domain/reservation_repository.dart';
import '../../store/domain/store_entities.dart';
import '../../store/domain/store_repository.dart';
import '../../store/presentation/store_detail_screen.dart';
import '../../waitlist/domain/waitlist_repository.dart';
import '../../walk_in/domain/walk_in_repository.dart';
import '../../walk_in/presentation/walk_in_call_screen.dart';
import '../../walk_in/presentation/walk_in_detail_screen.dart';
import '../domain/home_entities.dart';
import '../domain/home_repository.dart';
import '../domain/home_usecases.dart';
import 'activity_cards.dart';

class HomeViewModel extends LoadableViewModel<HomeSummary> {
  HomeViewModel(this._getHome, RefreshBus bus) {
    listenTopics(
      bus,
      {
        RefreshTopic.home,
        RefreshTopic.myReservations,
        RefreshTopic.waitlists,
        RefreshTopic.walkIns,
        RefreshTopic.slotOffers,
      },
      refresh,
    );
    startPolling(const Duration(seconds: 30), refresh);
  }

  final GetCustomerHome _getHome;

  @override
  Future<HomeSummary> fetch() => _getHome();
}

/// C-02 고객 홈
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenSearch,
    required this.onOpenActivity,
    required this.onScanQr,
    this.onScanCheckIn,
  });

  final VoidCallback onOpenSearch;
  final VoidCallback onOpenActivity;
  final VoidCallback onScanQr;
  final VoidCallback? onScanCheckIn;

  @override
  Widget build(BuildContext context) {
    final session = GetIt.I<SessionController>();
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', width: 26),
            const SizedBox(width: 8),
            const Text('Jariyo', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 22)),
          ],
        ),
        actions: [
          if (session.isSignedIn)
            IconButton(
              tooltip: '알림',
              onPressed: () => pushPage<void>(context, const NotificationScreen()),
              icon: SvgPicture.asset(
                'assets/icons/notification.svg',
                colorFilter: const ColorFilter.mode(AppColors.text, BlendMode.srcIn),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: session.isSignedIn ? _signedIn(context, session) : _guest(context, session),
    );
  }

  Widget _searchBox() => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onOpenSearch,
      borderRadius: BorderRadius.circular(16),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: AppColors.mutedText),
            SizedBox(width: 10),
            Text('어떤 매장을 찾으세요?', style: TextStyle(color: AppColors.mutedText, fontSize: 16)),
          ],
        ),
      ),
    ),
  );

  Widget _quickActions() => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          _QuickAction(icon: Icons.storefront_rounded, label: '매장 찾기', onTap: onOpenSearch),
          _QuickAction(icon: Icons.qr_code_scanner_rounded, label: '현장 대기', onTap: onScanQr),
          if (onScanCheckIn != null)
            _QuickAction(icon: Icons.how_to_reg_rounded, label: 'QR 체크인', onTap: onScanCheckIn!),
          _QuickAction(icon: Icons.confirmation_number_rounded, label: '내 예약', onTap: onOpenActivity),
        ],
      ),
    ),
  );

  Widget _guest(BuildContext context, SessionController session) {
    final recent = GetIt.I<StoreRepository>().recentStores();
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.page, 8, AppSpace.page, 32),
      children: [
        const Text('예약도 대기도\n한자리에서', style: AppText.display),
        const SizedBox(height: 20),
        _searchBox(),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(AppSpace.page),
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '로그인하고 예약과 대기를\n한눈에 확인해 보세요',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, height: 1.4),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary),
                onPressed: session.requestSignIn,
                child: const Text('로그인'),
              ),
            ],
          ),
        ),
        if (recent.isNotEmpty) ...[const SectionTitle('최근 본 매장'), _RecentStores(stores: recent)],
      ],
    );
  }

  Widget _signedIn(BuildContext context, SessionController session) {
    return ViewModelScope<HomeViewModel>(
      create: () => HomeViewModel(
        GetCustomerHome(
          home: GetIt.I<HomeRepository>(),
          reservations: GetIt.I<ReservationRepository>(),
          waitlists: GetIt.I<WaitlistRepository>(),
          walkIns: GetIt.I<WalkInRepository>(),
          stores: GetIt.I<StoreRepository>(),
        ),
        GetIt.I<RefreshBus>(),
      ),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => LoadableBody<HomeSummary>(
        vm: vm,
        builder: (context, home) {
          final waits = [
            for (final offer in home.pendingOffers) OfferCard(offer: offer, onExpired: vm.refresh),
            for (final walkIn in home.activeWalkIns) WalkInCard(walkIn: walkIn),
            for (final entry in home.activeWaitlists) WaitlistCard(entry: entry),
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.page, 8, AppSpace.page, 32),
            children: [
              Text('${session.profile?.displayName ?? ''}님,\n오늘은 어디로 가볼까요?', style: AppText.display),
              const SizedBox(height: 20),
              _searchBox(),
              if (home.priorityAction != null) ...[
                const SizedBox(height: 12),
                _PriorityCard(action: home.priorityAction!, onExpired: vm.refresh),
              ],
              const SizedBox(height: 12),
              _quickActions(),
              if (waits.isNotEmpty) ...[
                const SectionTitle('지금 기다리는 중'),
                for (final card in waits) ...[card, const SizedBox(height: 8)],
              ],
              if (home.upcomingReservations.isNotEmpty) ...[
                SectionTitle(
                  '다가오는 예약',
                  trailing: TextButton(onPressed: onOpenActivity, child: const Text('전체 보기')),
                ),
                for (final r in home.upcomingReservations.take(3)) ...[
                  ReservationCard(reservation: r),
                  const SizedBox(height: 8),
                ],
              ],
              if (home.isEmpty) ...[
                const SizedBox(height: 12),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('아직 예약 내역이 없어요', style: AppText.bodyStrong),
                      const SizedBox(height: 4),
                      const Text('원하는 매장을 찾아 예약해 보세요.', style: AppText.sub),
                      const SizedBox(height: 16),
                      AppButton(label: '매장 찾아보기', onPressed: onOpenSearch),
                    ],
                  ),
                ),
              ],
              if (home.recentStores.isNotEmpty) ...[
                const SectionTitle('최근 이용한 매장'),
                _RecentStores(stores: home.recentStores),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            IconTile(icon: icon, size: 48),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
          ],
        ),
      ),
    ),
  );
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({required this.action, required this.onExpired});

  final PriorityAction action;
  final VoidCallback onExpired;

  StatusTone get _tone => switch (action.type) {
    PriorityActionType.walkInCalled || PriorityActionType.slotOffer => StatusTone.attention,
    PriorityActionType.checkInAvailable => StatusTone.active,
    PriorityActionType.reservation => StatusTone.active,
    PriorityActionType.walkIn || PriorityActionType.waitlist => StatusTone.waiting,
  };

  void _open(BuildContext context) {
    final id = action.referenceId;
    switch (action.type) {
      case PriorityActionType.slotOffer:
        openSlotOffer(context, id);
      case PriorityActionType.walkInCalled:
        pushPage<void>(context, WalkInCallScreen(walkInId: id));
      case PriorityActionType.checkInAvailable:
      case PriorityActionType.reservation:
        openReservation(context, id);
      case PriorityActionType.waitlist:
        openWaitlist(context, id);
      case PriorityActionType.walkIn:
        pushPage<void>(context, WalkInDetailScreen(walkInId: id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forTone(_tone);
    return Semantics(
      liveRegion: true,
      button: true,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.page, AppSpace.page, 16, AppSpace.page),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.title,
                        style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
                      ),
                      if (action.subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(action.subtitle!, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                      if (action.expiresAt != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(36),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: CountdownText(
                            expiresAt: action.expiresAt!,
                            suffix: action.type == PriorityActionType.walkInCalled ? ' 안에 응답해 주세요' : ' 안에 수락해 주세요',
                            onExpired: onExpired,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    action.actionLabel ?? '확인',
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentStores extends StatelessWidget {
  const _RecentStores({required this.stores});

  final List<RecentStore> stores;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: stores.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final store = stores[index];
          return SizedBox(
            width: 160,
            child: Card(
              child: InkWell(
                onTap: () => pushPage<void>(context, StoreDetailScreen(storeId: store.id)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconTile(icon: Icons.storefront_rounded, size: 36),
                      const Spacer(),
                      Text(store.name, style: AppText.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        store.lastServiceName ?? '다시 예약하기',
                        style: AppText.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

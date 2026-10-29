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
  const HomeScreen({super.key, required this.onOpenSearch, required this.onOpenActivity, required this.onScanQr});

  final VoidCallback onOpenSearch;
  final VoidCallback onOpenActivity;
  final VoidCallback onScanQr;

  @override
  Widget build(BuildContext context) {
    final session = GetIt.I<SessionController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jariyo'),
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
        ],
      ),
      body: session.isSignedIn ? _signedIn(context, session) : _guest(context, session),
    );
  }

  Widget _searchBox() => InkWell(
    onTap: onOpenSearch,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.search, color: AppColors.lightText),
          SizedBox(width: 8),
          Text('매장명, 업종, 지역으로 검색', style: TextStyle(color: AppColors.lightText)),
        ],
      ),
    ),
  );

  Widget _guest(BuildContext context, SessionController session) {
    final recent = GetIt.I<StoreRepository>().recentStores();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('예약도 대기도 한자리에서', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        _searchBox(),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('로그인하면 예약과 대기 현황을 한눈에 볼 수 있어요.', style: TextStyle(height: 1.5)),
              const SizedBox(height: 12),
              AppButton(label: '로그인', onPressed: session.requestSignIn),
            ],
          ),
        ),
        if (recent.isNotEmpty) ...[const SectionTitle('최근 본 매장'), for (final s in recent.take(5)) _RecentStoreTile(store: s)],
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
        builder: (context, home) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '안녕하세요, ${session.profile?.displayName ?? ''}님',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text),
            ),
            const SizedBox(height: 16),
            _searchBox(),
            if (home.priorityAction != null) ...[
              const SizedBox(height: 16),
              _PriorityCard(action: home.priorityAction!, onExpired: vm.refresh),
            ],
            const SizedBox(height: 16),
            _QuickMenu(onBook: onOpenSearch, onWalkIn: onScanQr, onActivity: onOpenActivity, onRecent: onOpenSearch),
            if (home.isEmpty) ...[
              const SizedBox(height: 24),
              EmptyView(
                icon: Icons.event_note,
                title: '아직 예약 내역이 없어요.',
                message: '원하는 매장을 찾아 예약해 보세요.',
                actionLabel: '매장 찾아보기',
                onAction: onOpenSearch,
              ),
            ],
            if (home.pendingOffers.isNotEmpty || home.activeWalkIns.isNotEmpty || home.activeWaitlists.isNotEmpty) ...[
              const SectionTitle('현재 대기 상태'),
              for (final offer in home.pendingOffers) ...[OfferCard(offer: offer, onExpired: vm.refresh), const SizedBox(height: 8)],
              for (final walkIn in home.activeWalkIns) ...[WalkInCard(walkIn: walkIn), const SizedBox(height: 8)],
              for (final entry in home.activeWaitlists) ...[WaitlistCard(entry: entry), const SizedBox(height: 8)],
            ],
            if (home.upcomingReservations.isNotEmpty) ...[
              SectionTitle(
                '다가오는 예약',
                trailing: TextButton(onPressed: onOpenActivity, child: const Text('전체 보기')),
              ),
              for (final r in home.upcomingReservations.take(3)) ...[ReservationCard(reservation: r), const SizedBox(height: 8)],
            ],
            if (home.recentStores.isNotEmpty) ...[
              const SectionTitle('최근 이용 매장'),
              for (final store in home.recentStores) _RecentStoreTile(store: store),
            ],
          ],
        ),
      ),
    );
  }
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({required this.action, required this.onExpired});

  final PriorityAction action;
  final VoidCallback onExpired;

  StatusTone get _tone => switch (action.type) {
    PriorityActionType.walkInCalled || PriorityActionType.slotOffer => StatusTone.attention,
    PriorityActionType.checkInAvailable => StatusTone.active,
    PriorityActionType.reservation => StatusTone.positive,
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
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withAlpha(60), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppColors.iconForTone(_tone), color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    action.title,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            if (action.subtitle != null) ...[
              const SizedBox(height: 8),
              Text(action.subtitle!, style: const TextStyle(color: Colors.white, fontSize: 15)),
            ],
            if (action.expiresAt != null) ...[
              const SizedBox(height: 6),
              CountdownText(
                expiresAt: action.expiresAt!,
                suffix: action.type == PriorityActionType.walkInCalled ? ' 안에 응답해 주세요' : ' 안에 수락해 주세요',
                onExpired: onExpired,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: color),
              onPressed: () => _open(context),
              child: Text(action.actionLabel ?? '확인하기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickMenu extends StatelessWidget {
  const _QuickMenu({required this.onBook, required this.onWalkIn, required this.onActivity, required this.onRecent});

  final VoidCallback onBook;
  final VoidCallback onWalkIn;
  final VoidCallback onActivity;
  final VoidCallback onRecent;

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label, VoidCallback onTap) => Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withAlpha(20),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
    return Row(
      children: [
        item(Icons.event_available, '예약하기', onBook),
        item(Icons.qr_code_scanner, '현장 대기', onWalkIn),
        item(Icons.confirmation_number_outlined, '내 예약', onActivity),
        item(Icons.history, '최근 본 매장', onRecent),
      ],
    );
  }
}

class _RecentStoreTile extends StatelessWidget {
  const _RecentStoreTile({required this.store});

  final RecentStore store;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(store.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(store.lastServiceName ?? store.address ?? ''),
        trailing: TextButton(
          onPressed: () => pushPage<void>(context, StoreDetailScreen(storeId: store.id)),
          child: const Text('다시 예약'),
        ),
        onTap: () => pushPage<void>(context, StoreDetailScreen(storeId: store.id)),
      ),
    );
  }
}

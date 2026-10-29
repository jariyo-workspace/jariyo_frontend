import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../../core/presentation/view_model.dart';
import '../../../core/realtime/refresh_bus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/view_model_scope.dart';
import '../../reservation/domain/reservation_repository.dart';
import '../../store/presentation/store_search_screen.dart';
import '../../waitlist/domain/waitlist_repository.dart';
import '../../walk_in/domain/walk_in_repository.dart';
import '../domain/home_entities.dart';
import '../domain/home_usecases.dart';
import 'activity_cards.dart';

class MyActivityViewModel extends LoadableViewModel<MyActivity> {
  MyActivityViewModel(this._getActivity, RefreshBus bus) {
    listenTopics(
      bus,
      {RefreshTopic.myReservations, RefreshTopic.waitlists, RefreshTopic.walkIns, RefreshTopic.slotOffers},
      refresh,
    );
    startPolling(const Duration(seconds: 30), refresh);
  }

  final GetMyActivity _getActivity;
  bool loadingMore = false;

  @override
  Future<MyActivity> fetch() => _getActivity();

  Future<void> loadMorePast() async {
    final current = data;
    if (current == null || !current.pastHasNext || loadingMore) return;
    loadingMore = true;
    notify();
    try {
      data = await _getActivity.loadMorePast(current);
    } on AppFailure catch (failure) {
      AppMessenger.showFailure(failure);
    } finally {
      loadingMore = false;
      notify();
    }
  }
}

/// C-18 내 예약·대기: 이용 중 / 예정 / 대기 / 지난 내역
class MyActivityScreen extends StatelessWidget {
  const MyActivityScreen({super.key, this.standalone = false, this.initialTab = 1, this.onFindStore});

  /// 탭 바깥에서 단독 화면으로 열렸는지 (뒤로가기 표시)
  final bool standalone;
  final int initialTab;
  final VoidCallback? onFindStore;

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<MyActivityViewModel>(
      create: () => MyActivityViewModel(
        GetMyActivity(
          reservations: GetIt.I<ReservationRepository>(),
          waitlists: GetIt.I<WaitlistRepository>(),
          walkIns: GetIt.I<WalkInRepository>(),
        ),
        GetIt.I<RefreshBus>(),
      ),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => DefaultTabController(
        length: 4,
        initialIndex: initialTab,
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: standalone,
            title: const Text('내 예약'),
            bottom: TabBar(
              labelColor: AppColors.primary,
              tabs: [
                Tab(text: '이용 중${_count(vm.data?.inUse.length)}'),
                Tab(text: '예정${_count(vm.data?.upcoming.length)}'),
                Tab(text: '대기${_count(vm.data?.waiting.length)}'),
                const Tab(text: '지난 내역'),
              ],
            ),
          ),
          body: LoadableBody<MyActivity>(
            vm: vm,
            pullToRefresh: false,
            builder: (context, activity) => TabBarView(
              children: [
                _list(context, vm, activity.inUse, '지금 이용 중인 서비스가 없어요.'),
                _list(context, vm, activity.upcoming, '아직 예약 내역이 없어요.', message: '원하는 매장을 찾아 예약해 보세요.'),
                _list(context, vm, activity.waiting, '진행 중인 대기가 없어요.'),
                _past(context, vm, activity),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _count(int? value) => value == null || value == 0 ? '' : ' $value';

  void _findStore(BuildContext context) {
    if (onFindStore != null) {
      onFindStore!();
    } else {
      pushPage<void>(context, const StoreSearchScreen(showBack: true));
    }
  }

  Widget _list(
    BuildContext context,
    MyActivityViewModel vm,
    List<ActivityItem> items,
    String emptyTitle, {
    String? message,
  }) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: vm.refresh,
        child: ListView(
          children: [
            const SizedBox(height: 80),
            EmptyView(
              title: emptyTitle,
              message: message,
              actionLabel: '매장 찾아보기',
              onAction: () => _findStore(context),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: vm.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) => ActivityTile(item: items[index], onExpired: vm.refresh),
      ),
    );
  }

  Widget _past(BuildContext context, MyActivityViewModel vm, MyActivity activity) {
    if (activity.past.isEmpty && activity.finishedWaits.isEmpty) {
      return _list(context, vm, const [], '지난 이용 내역이 없어요.');
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 300) vm.loadMorePast();
        return false;
      },
      child: RefreshIndicator(
        onRefresh: vm.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final r in activity.past) ...[ReservationCard(reservation: r), const SizedBox(height: 8)],
            if (vm.loadingMore) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
            if (activity.pastHasNext && !vm.loadingMore)
              TextButton(onPressed: vm.loadMorePast, child: const Text('더 보기')),
            if (activity.finishedWaits.isNotEmpty) ...[
              const SectionTitle('지난 대기'),
              for (final item in activity.finishedWaits) ...[ActivityTile(item: item), const SizedBox(height: 8)],
            ],
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../core/domain/statuses.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../../core/presentation/view_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_time_format.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/view_model_scope.dart';
import '../domain/store_entities.dart';
import '../domain/store_repository.dart';
import '../domain/store_usecases.dart';
import 'store_detail_screen.dart';

class StoreSearchViewModel extends ViewModel {
  StoreSearchViewModel(StoreRepository repository)
    : _search = SearchStores(repository),
      recentSearches = RecentSearches(repository),
      recentStores = RecentStores(repository);

  final SearchStores _search;
  final RecentSearches recentSearches;
  final RecentStores recentStores;

  StoreSearchQuery query = const StoreSearchQuery();
  List<StoreSummary> results = [];
  String? _cursor;
  bool hasNext = false;
  bool loading = false;
  bool loadingMore = false;
  AppFailure? error;
  int _generation = 0;

  Set<String> get categories => results.map((s) => s.category).whereType<String>().toSet();

  Future<void> search({String? keyword, bool remember = false}) async {
    if (keyword != null) query = query.copyWith(query: keyword);
    if (remember) await recentSearches.add(query.query);
    final generation = ++_generation;
    loading = true;
    error = null;
    _cursor = null;
    notify();
    try {
      final page = await _search(query);
      if (generation != _generation) return;
      results = page.items;
      _cursor = page.cursor;
      hasNext = page.hasNext;
    } on AppFailure catch (failure) {
      if (generation == _generation) error = failure;
    } finally {
      if (generation == _generation) {
        loading = false;
        notify();
      }
    }
  }

  Future<void> loadMore() async {
    if (!hasNext || loadingMore || loading) return;
    loadingMore = true;
    notify();
    try {
      final page = await _search(query, cursor: _cursor);
      results = [...results, ...page.items];
      _cursor = page.cursor;
      hasNext = page.hasNext;
    } on AppFailure catch (failure) {
      AppMessenger.showFailure(failure);
    } finally {
      loadingMore = false;
      notify();
    }
  }

  void toggleOpenNow() {
    query = query.copyWith(openNow: !query.openNow);
    search();
  }

  void toggleAvailableToday() {
    query = query.copyWith(availableToday: !query.availableToday);
    search();
  }

  void selectCategory(String? category) {
    query = category == null ? query.copyWith(clearCategory: true) : query.copyWith(category: category);
    search();
  }

  Future<void> removeRecent(String keyword) async {
    await recentSearches.remove(keyword);
    notify();
  }

  Future<void> clearRecent() async {
    await recentSearches.clear();
    notify();
  }
}

/// C-03 매장 검색
class StoreSearchScreen extends StatefulWidget {
  const StoreSearchScreen({super.key, this.showBack = false});

  final bool showBack;

  @override
  State<StoreSearchScreen> createState() => _StoreSearchScreenState();
}

class _StoreSearchScreenState extends State<StoreSearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<StoreSearchViewModel>(
      create: () => StoreSearchViewModel(GetIt.I<StoreRepository>()),
      onReady: (vm) => vm.search(),
      builder: (context, vm) {
        final showSuggestions = _focus.hasFocus && _controller.text.isEmpty;
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: widget.showBack,
            title: const Text('매장 탐색'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  textInputAction: TextInputAction.search,
                  onTapOutside: (_) => _focus.unfocus(),
                  decoration: InputDecoration(
                    hintText: '매장명, 업종, 지역으로 검색',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '검색어 지우기',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _controller.clear();
                              vm.search(keyword: '');
                              setState(() {});
                            },
                          ),
                  ),
                  onChanged: (value) {
                    setState(() {});
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 350), () => vm.search(keyword: value));
                  },
                  onSubmitted: (value) {
                    _debounce?.cancel();
                    vm.search(keyword: value, remember: true);
                  },
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  children: [
                    FilterChip(label: const Text('영업 중'), selected: vm.query.openNow, onSelected: (_) => vm.toggleOpenNow()),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('오늘 예약 가능'),
                      selected: vm.query.availableToday,
                      onSelected: (_) => vm.toggleAvailableToday(),
                    ),
                    for (final category in vm.categories) ...[
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text(category),
                        selected: vm.query.category == category,
                        onSelected: (selected) => vm.selectCategory(selected ? category : null),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(child: showSuggestions ? _suggestions(vm) : _results(vm)),
            ],
          ),
        );
      },
    );
  }

  Widget _suggestions(StoreSearchViewModel vm) {
    final searches = vm.recentSearches.get();
    final stores = vm.recentStores.get();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionTitle(
          '최근 검색어',
          trailing: searches.isEmpty ? null : TextButton(onPressed: vm.clearRecent, child: const Text('전체 삭제')),
        ),
        if (searches.isEmpty)
          const Text('최근 검색어가 없어요.', style: TextStyle(color: AppColors.lightText))
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final keyword in searches)
                InputChip(
                  label: Text(keyword),
                  onPressed: () {
                    _controller.text = keyword;
                    _focus.unfocus();
                    vm.search(keyword: keyword, remember: true);
                  },
                  onDeleted: () => vm.removeRecent(keyword),
                ),
            ],
          ),
        const SectionTitle('최근 본 매장'),
        if (stores.isEmpty)
          const Text('최근 본 매장이 없어요.', style: TextStyle(color: AppColors.lightText))
        else
          for (final store in stores)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history),
              title: Text(store.name),
              subtitle: store.address == null ? null : Text(store.address!),
              onTap: () => pushPage<void>(context, StoreDetailScreen(storeId: store.id)),
            ),
      ],
    );
  }

  Widget _results(StoreSearchViewModel vm) {
    if (vm.loading && vm.results.isEmpty) return const LoadingView();
    if (vm.error != null) return ErrorView(failure: vm.error!, onRetry: vm.search);
    if (vm.results.isEmpty) {
      return const EmptyView(
        icon: Icons.search_off,
        title: '검색 결과가 없어요.',
        message: '다른 매장명이나 지역으로 검색해 보세요.',
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 300) vm.loadMore();
        return false;
      },
      child: RefreshIndicator(
        onRefresh: vm.search,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: vm.results.length + (vm.loadingMore ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index >= vm.results.length) {
              return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
            }
            final store = vm.results[index];
            return StoreCard(store: store, onTap: () => pushPage<void>(context, StoreDetailScreen(storeId: store.id)));
          },
        ),
      ),
    );
  }
}

class StoreCard extends StatelessWidget {
  const StoreCard({super.key, required this.store, required this.onTap});

  final StoreSummary store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final closed = store.status != StoreStatus.active;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StoreAvatar(name: store.name),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(store.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                        if (closed)
                          StatusBadge(label: store.status.label, tone: StatusTone.negative)
                        else if (store.openNow != null)
                          StatusBadge(
                            label: store.openNow! ? '영업 중' : '영업 전/종료',
                            tone: store.openNow! ? StatusTone.positive : StatusTone.neutral,
                          ),
                      ],
                    ),
                    if (store.category != null)
                      Text(store.category!, style: const TextStyle(color: AppColors.lightText, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(store.address, style: const TextStyle(color: AppColors.lightText)),
                    if (store.todayHours != null)
                      Text('오늘 ${store.todayHours!.label}', style: const TextStyle(color: AppColors.lightText, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (store.nextAvailableAt != null)
                          _Tag(icon: Icons.bolt, text: '가장 빠른 예약 ${formatRelative(store.nextAvailableAt!)}', color: AppColors.positive),
                        if (store.walkInEnabled == true) const _Tag(icon: Icons.directions_walk, text: '현장 대기 가능'),
                        if (store.waitlistEnabled == true) const _Tag(icon: Icons.hourglass_empty, text: '예약 대기 가능'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text, this.color = AppColors.primary});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 2),
      Text(text, style: TextStyle(fontSize: 12, color: color)),
    ],
  );
}

class StoreAvatar extends StatelessWidget {
  const StoreAvatar({super.key, required this.name, this.size = 52});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: AppColors.primary.withAlpha(24), borderRadius: BorderRadius.circular(12)),
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '?' : name.characters.first,
        style: TextStyle(color: AppColors.primary, fontSize: size * 0.4, fontWeight: FontWeight.w700),
      ),
    );
  }
}

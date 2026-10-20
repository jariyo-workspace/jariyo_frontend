import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/models.dart';
import '../app_nav.dart';
import '../widgets/common.dart';

class StoresScreen extends StatefulWidget {
  const StoresScreen({super.key});

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  List<StoreSummary>? _stores;
  bool _loading = true;
  bool _failed = false;
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final stores = await Api.stores();
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _stores = stores;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _loading = false;
        // 이미 카드가 있으면 유지하고 스낵바로만 알린다.
        if (_stores == null) _failed = true;
      });
      if (_stores != null) showAppSnackBar(context, S.networkError, icon: Icons.wifi_off, iconColor: Colors.white);
    }
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
      child: Row(
        children: [
          const Text(S.titleStores, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(width: 8),
          if (_stores != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(9999)),
              child: Text(S.storesCount(_stores!.length),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.onPrimary)),
            ),
          const Spacer(),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            iconSize: 26,
            color: AppColors.text,
            tooltip: '새로고침',
          ),
        ],
      ),
    );
  }

  Widget _body() {
    final stores = _stores;
    if (stores == null) {
      if (_failed) return Center(child: SingleChildScrollView(child: NetworkErrorView(onRetry: _load)));
      return const Loader();
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: stores.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 160),
                Center(child: Text(S.storesEmpty, style: TextStyle(fontSize: 16, color: AppColors.textSub))),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: stores.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _StoreCard(store: stores[i]),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            if (_loading && _stores != null) const LinearProgressIndicator(minHeight: 2),
            Expanded(child: _body()),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: 0, isRoot: true),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final StoreSummary store;

  const _StoreCard({required this.store});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => AppNav.openStore(store.id),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Thumbnail(name: store.name),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(store.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(storeStatusStyle(store.status)),
                  ],
                ),
                const SizedBox(height: 6),
                if (store.address != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSub),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(store.address!, style: const TextStyle(fontSize: 14, color: AppColors.textSub)),
                      ),
                    ],
                  ),
                if (store.description != null && store.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(store.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, color: AppColors.textSub)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

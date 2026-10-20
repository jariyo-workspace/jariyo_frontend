import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../app_nav.dart';
import '../widgets/common.dart';

class MyReservationsScreen extends StatefulWidget {
  /// 예약 생성 직후 이 예약의 예약 상세를 예약 완료 영역과 함께 연다.
  final String? openBookedReservationId;

  const MyReservationsScreen({super.key, this.openBookedReservationId});

  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends State<MyReservationsScreen> {
  static const _filters = [
    (null, S.myAll),
    ('CONFIRMED', '예약 확정'),
    ('COMPLETED', '이용 완료'),
    ('CANCELLED', '취소됨'),
  ];

  String? _status;
  final List<ReservationSummary> _items = [];
  String? _cursor;
  bool _hasNext = false;
  bool _firstLoading = true;
  bool _firstFailed = false;
  bool _moreLoading = false;
  bool _moreFailed = false;
  int _seq = 0;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadFirst();
    final booked = widget.openBookedReservationId;
    if (booked != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openDetail(booked, justBooked: true);
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadFirst() async {
    final seq = ++_seq;
    setState(() {
      _items.clear();
      _cursor = null;
      _hasNext = false;
      _firstLoading = true;
      _firstFailed = false;
      _moreLoading = false;
      _moreFailed = false;
    });
    try {
      final page = await Api.myReservations(status: _status);
      if (!mounted || seq != _seq) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.cursor;
        _hasNext = page.hasNext;
        _firstLoading = false;
      });
    } on SessionExpiredException {
      return;
    } catch (_) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _firstLoading = false;
        _firstFailed = true;
      });
    }
  }

  /// 같은 커서로 다음 10건을 한 번만 로드한다.
  Future<void> _loadMore() async {
    if (_moreLoading || !_hasNext || _cursor == null || _firstLoading) return;
    final seq = _seq;
    setState(() {
      _moreLoading = true;
      _moreFailed = false;
    });
    try {
      final page = await Api.myReservations(status: _status, cursor: _cursor);
      if (!mounted || seq != _seq) return;
      final known = _items.map((e) => e.id).toSet();
      setState(() {
        _items.addAll(page.items.where((e) => !known.contains(e.id)));
        _cursor = page.cursor;
        _hasNext = page.hasNext;
        _moreLoading = false;
      });
    } on SessionExpiredException {
      return;
    } on ApiException catch (e) {
      if (!mounted || seq != _seq) return;
      if (e.status == 400 && e.code == 'COMMON-400') {
        _loadFirst();
        return;
      }
      setState(() {
        _moreLoading = false;
        _moreFailed = true;
      });
    } catch (_) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _moreLoading = false;
        _moreFailed = true;
      });
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients || _moreFailed) return;
    if (_scroll.position.extentAfter < 200) _loadMore();
  }

  void _selectFilter(String? status) {
    if (status == _status) return;
    _status = status;
    _loadFirst();
  }

  void _onStatusChanged(String id, String status) {
    if (!mounted) return;
    final index = _items.indexWhere((e) => e.id == id);
    if (index < 0) return;
    setState(() {
      if (_status != null && status != _status) {
        _items.removeAt(index);
      } else {
        _items[index] = _items[index].withStatus(status);
      }
    });
  }

  void _openDetail(String id, {bool justBooked = false}) {
    AppNav.openReservation(id, justBooked: justBooked, onStatusChanged: _onStatusChanged);
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(S.myLogoutTitle, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSub, minimumSize: const Size(64, 48)),
            child: const Text(S.myCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(64, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(S.myLogout),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final refresh = Session.refreshToken;
    Session.clear();
    Api.signOut(refresh);
    AppNav.toSignIn();
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
      child: Row(
        children: [
          const Expanded(
            child: Text(S.titleMyReservations,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.text)),
          ),
          IconButton(
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout),
            iconSize: 26,
            color: AppColors.text,
            tooltip: S.myLogout,
          ),
        ],
      ),
    );
  }

  Widget _chips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (final (status, label) in _filters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: _status == status,
                showCheckmark: false,
                onSelected: (_) => _selectFilter(status),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surface,
                labelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: _status == status ? FontWeight.w700 : FontWeight.w500,
                  color: _status == status ? AppColors.onPrimary : AppColors.text,
                ),
                side: BorderSide(color: _status == status ? AppColors.primary : AppColors.outline),
                shape: const StadiumBorder(),
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
            ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_firstLoading) return const Loader();
    if (_firstFailed) return Center(child: SingleChildScrollView(child: NetworkErrorView(onRetry: _loadFirst)));
    if (_items.isEmpty && !_hasNext) return _empty();
    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: _items.length + 2,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(S.myShown(_items.length), style: const TextStyle(fontSize: 14, color: AppColors.textSub)),
          );
        }
        if (i == _items.length + 1) return _footer();
        final r = _items[i - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ReservationCard(reservation: r, onTap: () => _openDetail(r.id)),
        );
      },
    );
  }

  Widget _footer() {
    if (_moreFailed) {
      return AppCard(padding: const EdgeInsets.all(8), child: NetworkErrorView(onRetry: _loadMore, compact: true));
    }
    if (_hasNext) {
      // 목록이 화면보다 짧아 스크롤이 생기지 않을 때도 다음 페이지를 불러온다.
      if (!_moreLoading) WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
      return const Padding(padding: EdgeInsets.all(16), child: Loader());
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Text(S.myAllLoaded, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.textSub)),
    );
  }

  Widget _empty() {
    if (_status != null) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.filter_alt_off_outlined, size: 40, color: AppColors.textSub),
          SizedBox(height: 16),
          Text(S.myFilterEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      children: [
        const SizedBox(height: 120),
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: AppColors.primaryContainer, shape: BoxShape.circle),
            child: const Icon(Icons.event_note_outlined, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 16),
        const Text(S.myEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
        const SizedBox(height: 4),
        const Text(S.myEmptySub, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.textSub)),
        const SizedBox(height: 20),
        Center(
          child: SizedBox(
            width: 200,
            child: PrimaryButton(label: S.myFindStores, icon: Icons.storefront_outlined, onPressed: AppNav.toStores),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            _chips(),
            const SizedBox(height: 12),
            Expanded(child: _body()),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: 1, isRoot: true),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  final ReservationSummary reservation;
  final VoidCallback onTap;

  const _ReservationCard({required this.reservation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Thumbnail(name: r.store.name, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(r.store.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(reservationStatusStyle(r.status)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${r.service.name} · ${r.staff.name}',
                    style: const TextStyle(fontSize: 14, color: AppColors.textSub)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSub),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(formatDateTime(r.startAt),
                          style: const TextStyle(fontSize: 14, color: AppColors.text)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

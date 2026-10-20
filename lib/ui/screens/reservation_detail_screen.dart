import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../app_nav.dart';
import '../widgets/common.dart';
import 'cancel_sheet.dart';

class ReservationDetailScreen extends StatefulWidget {
  final String reservationId;

  /// 예약 생성 직후 열린 경우 상태 영역 대신 예약 완료 영역을 표시한다.
  final bool justBooked;
  final void Function(String id, String status)? onStatusChanged;

  const ReservationDetailScreen({
    super.key,
    required this.reservationId,
    this.justBooked = false,
    this.onStatusChanged,
  });

  @override
  State<ReservationDetailScreen> createState() => _ReservationDetailScreenState();
}

class _ReservationDetailScreenState extends State<ReservationDetailScreen> {
  ReservationDetail? _detail;
  bool _loading = true;
  bool _failed = false;
  ApiException? _notFound;
  late bool _justBooked = widget.justBooked;

  List<HistoryItem>? _history;
  bool _historyLoading = true;
  bool _historyFailed = false;

  /// 취소 마감이 지나 실패한 경우 표시하는 안내(error.message).
  String? _deadlineMessage;

  int _seq = 0;
  int _historySeq = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll({bool reload = false}) async {
    if (reload) _justBooked = false;
    await Future.wait([_loadDetail(), _loadHistory()]);
  }

  Future<void> _loadDetail() async {
    final seq = ++_seq;
    setState(() {
      _loading = _detail == null;
      _failed = false;
    });
    try {
      final detail = await Api.reservation(widget.reservationId);
      if (!mounted || seq != _seq) return;
      final previous = _detail?.status;
      setState(() {
        _detail = detail;
        _loading = false;
      });
      if (previous != null && previous != detail.status) {
        widget.onStatusChanged?.call(detail.id, detail.status);
      }
    } on SessionExpiredException {
      return;
    } on ApiException catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        if (e.code == 'RESERVATION_NOT_FOUND' || e.code == 'RESERVATION_NOT_OWNED_BY_USER') {
          _notFound = e;
        } else {
          _failed = true;
        }
      });
    } catch (_) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _loadHistory() async {
    final seq = ++_historySeq;
    setState(() {
      _historyLoading = true;
      _historyFailed = false;
    });
    try {
      final history = await Api.history(widget.reservationId);
      if (!mounted || seq != _historySeq) return;
      setState(() {
        _history = history.reversed.toList(); // 최신순
        _historyLoading = false;
      });
    } on SessionExpiredException {
      return;
    } catch (_) {
      if (!mounted || seq != _historySeq) return;
      setState(() {
        _historyLoading = false;
        _historyFailed = true;
      });
    }
  }

  Future<void> _openCancel() async {
    final detail = _detail;
    if (detail == null) return;
    final result = await showModalBottomSheet<CancelResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CancelSheet(reservationId: detail.id),
    );
    if (!mounted || result == null) return;
    switch (result.kind) {
      case CancelResultKind.success:
        showAppSnackBar(context, S.rdCancelDone, icon: Icons.check_circle);
        _deadlineMessage = null;
      case CancelResultKind.conflict:
        showAppSnackBar(context, result.message ?? S.networkError, icon: Icons.error, iconColor: const Color(0xFFFFB4AB));
      case CancelResultKind.deadlinePassed:
        setState(() => _deadlineMessage = result.message);
    }
    _loadAll(reload: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.titleReservationDetail)),
      body: _body(),
      bottomNavigationBar: const AppBottomNav(current: 1),
    );
  }

  Widget _body() {
    if (_loading) return const Loader();
    if (_notFound != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_busy_outlined, size: 48, color: AppColors.textSub),
              const SizedBox(height: 16),
              Text(_notFound!.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 20),
              PrimaryButton(
                label: S.rdBackToMine,
                icon: Icons.event_note_outlined,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
      );
    }
    final d = _detail;
    if (_failed && d == null || d == null) {
      return Center(child: SingleChildScrollView(child: NetworkErrorView(onRetry: _loadDetail)));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        if (_failed) ...[
          AppCard(padding: const EdgeInsets.all(8), child: NetworkErrorView(onRetry: _loadDetail, compact: true)),
          const SizedBox(height: 16),
        ],
        _justBooked ? _bookedHero(d) : _statusArea(d),
        const SizedBox(height: 24),
        _storeCard(d),
        const SizedBox(height: 16),
        _infoCard(d),
        const SizedBox(height: 16),
        _noteCard(d),
        if (d.cancellationDeadlineAt != null) ...[
          const SizedBox(height: 16),
          _policyBox(d),
        ],
        const SizedBox(height: 24),
        const SectionTitle(S.rdHistory, icon: Icons.history),
        _historySection(),
        const SizedBox(height: 24),
        _actions(d),
      ],
    );
  }

  Widget _bookedHero(ReservationDetail d) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 160,
          height: 160,
          decoration: const BoxDecoration(color: Color(0xFFE3E8F6), shape: BoxShape.circle),
          child: Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: Color(0xFF1E56D6),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0x4D003FB1), offset: Offset(0, 8), blurRadius: 20)],
              ),
              child: const Icon(Icons.check, size: 52, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(S.rdConfirmed, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text)),
        const SizedBox(height: 4),
        const Text(S.rdBookedSub, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.textSub)),
        const SizedBox(height: 12),
        StatusBadge(reservationStatusStyle(d.status)),
        const SizedBox(height: 8),
        Text(formatDateTime(d.startAt),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
      ],
    );
  }

  Widget _statusArea(ReservationDetail d) {
    final text = switch (d.status) {
      'CONFIRMED' => S.rdConfirmed,
      'IN_SERVICE' => S.rdInService,
      'CANCELLED' => S.rdCancelled,
      _ => null,
    };
    return Column(
      children: [
        const SizedBox(height: 8),
        StatusBadge(reservationStatusStyle(d.status)),
        const SizedBox(height: 12),
        Text(formatDateTime(d.startAt),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.text)),
        if (text != null) ...[
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(fontSize: 15, color: AppColors.textSub)),
        ],
      ],
    );
  }

  Widget _storeCard(ReservationDetail d) {
    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: AppColors.textSub),
              const SizedBox(width: 6),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textSub))),
            ],
          ),
        );
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Thumbnail(name: d.store.name),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.store.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
                if (d.store.address != null) line(Icons.location_on_outlined, d.store.address!),
                if (d.store.phoneNumber != null) line(Icons.call_outlined, d.store.phoneNumber!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardTitle(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ],
        ),
      );

  Widget _infoRow(String label, Widget value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 15, color: AppColors.textSub)),
            const SizedBox(width: 16),
            Expanded(child: Align(alignment: Alignment.centerRight, child: value)),
          ],
        ),
      );

  Widget _valueText(String text) =>
      Text(text, textAlign: TextAlign.right, style: const TextStyle(fontSize: 15, color: AppColors.text));

  Widget _infoCard(ReservationDetail d) {
    final minutes = minutesBetween(d.startAt, d.serviceEndAt);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.event_note_outlined, S.rdInfoTitle),
          _infoRow(S.rdService, _valueText(d.service.name)),
          _infoRow(
            S.rdStaff,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Avatar(d.staff.name, size: 28),
                const SizedBox(width: 8),
                Flexible(child: _valueText(d.staff.name)),
              ],
            ),
          ),
          _infoRow(S.rdDateTime, _valueText(formatDateTime(d.startAt))),
          _infoRow(S.rdDuration, _valueText(minutes == null ? '-' : S.rdMinutes(minutes))),
          _infoRow(S.rdPartySize, _valueText(S.rdPeople(d.partySize))),
        ],
      ),
    );
  }

  Widget _noteCard(ReservationDetail d) {
    final note = d.customerNote?.trim();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.chat_outlined, S.rdNote),
          SizedBox(
            width: double.infinity,
            child: Text(
              note == null || note.isEmpty ? S.none : '"$note"',
              style: const TextStyle(fontSize: 15, color: AppColors.text, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _policyBox(ReservationDetail d) {
    return InfoBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.error, size: 22),
              SizedBox(width: 8),
              Text(S.rdPolicyTitle, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Bullet(S.rdPolicyText(formatDateTime(d.cancellationDeadlineAt))),
          ),
        ],
      ),
    );
  }

  Widget _historySection() {
    if (_historyLoading && _history == null) {
      return const AppCard(child: Padding(padding: EdgeInsets.all(8), child: Loader()));
    }
    if (_historyFailed) {
      return AppCard(padding: const EdgeInsets.all(8), child: NetworkErrorView(onRetry: _loadHistory, compact: true));
    }
    final history = _history ?? const [];
    if (history.isEmpty) {
      return const AppCard(
        child: Text(S.none, style: TextStyle(fontSize: 15, color: AppColors.textSub)),
      );
    }
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < history.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: i == 0 ? AppColors.primary : AppColors.outline,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(formatDateTime(history[i].occurredAt),
                            style: const TextStyle(fontSize: 13, color: AppColors.textSub)),
                        const SizedBox(height: 2),
                        Text(
                          history[i].previousStatus == null
                              ? reservationStatusLabel(history[i].nextStatus)
                              : '${reservationStatusLabel(history[i].previousStatus)} → ${reservationStatusLabel(history[i].nextStatus)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
                        ),
                        if (history[i].note != null && history[i].note!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(history[i].note!,
                                style: const TextStyle(fontSize: 14, color: AppColors.textSub)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _actions(ReservationDetail d) {
    final children = <Widget>[];
    if (_deadlineMessage != null) {
      children.add(MessageBanner(
        title: _deadlineMessage!.isNotEmpty ? _deadlineMessage! : S.rdDeadlinePassed,
        sub: d.store.phoneNumber,
      ));
      children.add(const SizedBox(height: 16));
    }
    if (d.canCancel) {
      children.add(Center(
        child: OutlinedButton.icon(
          onPressed: _openCancel,
          icon: const Icon(Icons.cancel_outlined),
          label: const Text(S.rdCancel),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: Color(0x33BA1A1A), width: 1.5),
            minimumSize: const Size(160, 52),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ));
    } else if (d.status == 'CONFIRMED' && _deadlineMessage == null) {
      children.add(MessageBanner(
        title: S.rdDeadlinePassed,
        sub: d.store.phoneNumber,
        icon: Icons.info,
        tone: BannerTone.warning,
      ));
    }
    if (d.status == 'COMPLETED' || d.status == 'CANCELLED' || d.status == 'EXPIRED') {
      children.add(PrimaryButton(
        label: S.rdRebook,
        icon: Icons.replay,
        onPressed: () => AppNav.openStore(d.store.id),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

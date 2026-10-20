import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../app_nav.dart';
import '../widgets/common.dart';
import 'confirm_sheet.dart';

/// 시간 버튼 하나. '가능한 직원 누구나'에서는 같은 시작 시각의 슬롯을 하나로 묶는다.
class TimeOption {
  final String startAt;
  final String serviceEndAt;
  final String staffId;
  final bool available;
  final int hour, minute;

  TimeOption(this.startAt, this.serviceEndAt, this.staffId, this.available)
      : hour = LocalDateTime.tryParse(startAt)?.hour ?? 0,
        minute = LocalDateTime.tryParse(startAt)?.minute ?? 0;
}

class StoreDetailScreen extends StatefulWidget {
  final String storeId;

  const StoreDetailScreen({super.key, required this.storeId});

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  // 매장 데이터
  StoreDetail? _store;
  List<ServiceItem>? _services;
  bool _loading = true;
  ApiException? _loadError;
  bool _loadFailed = false;

  // 선택
  ServiceItem? _service;
  StaffItem? _staff; // null = 가능한 직원 누구나
  late DateTime _today;
  late DateTime _lastDay;
  late DateTime _date;
  late DateTime _month;
  TimeOption? _time;
  final _note = TextEditingController();

  // 직원 목록
  List<StaffItem>? _staffList;
  bool _staffLoading = false;
  bool _staffFailed = false;
  int _staffSeq = 0;

  // 예약 가능 시간
  List<TimeOption>? _options;
  bool _slotsLoading = false;
  bool _slotsFailed = false;
  int _slotSeq = 0;

  // 상단 충돌 배너
  String? _bannerTitle;
  String? _bannerSub;

  // 같은 예약 내용의 재시도에는 같은 Idempotency-Key 를 쓴다.
  String? _idemKey;
  String? _idemSignature;

  final _scroll = ScrollController();

  bool get _active => _store?.status == 'ACTIVE';

  @override
  void initState() {
    super.initState();
    AppNav.activeStoreId = widget.storeId;
    _today = _todayFor(null);
    _date = _today;
    _month = DateTime(_today.year, _today.month);
    _lastDay = _today.add(const Duration(days: 14));
    _load();
  }

  @override
  void dispose() {
    if (AppNav.activeStoreId == widget.storeId) AppNav.activeStoreId = null;
    _note.dispose();
    _scroll.dispose();
    super.dispose();
  }

  static DateTime _todayFor(String? timezone) {
    var now = DateTime.now();
    if (timezone == 'Asia/Seoul') now = now.toUtc().add(const Duration(hours: 9));
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _loadFailed = false;
    });
    try {
      final results = await Future.wait([Api.store(widget.storeId), Api.services(widget.storeId)]);
      if (!mounted) return;
      final store = results[0] as StoreDetail;
      setState(() {
        _store = store;
        _services = results[1] as List<ServiceItem>;
        _loading = false;
        _today = _todayFor(store.timezone);
        _lastDay = DateTime(_today.year, _today.month, _today.day + (store.policy?.bookingOpenDays ?? 14));
        _date = _today;
        _month = DateTime(_today.year, _today.month);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (e.code == 'STORE_NOT_FOUND') {
          _loadError = e;
        } else {
          _loadFailed = true;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  // ---------- 선택 ----------

  void _selectService(ServiceItem service) {
    if (!_active || !service.selectable || _service?.id == service.id) return;
    setState(() {
      _service = service;
      _staff = null;
      _time = null;
      _staffList = null;
      _clearBanner();
    });
    _loadStaff();
    _loadSlots();
  }

  void _selectStaff(StaffItem? staff) {
    if (staff != null && !staff.bookingEnabled) return;
    if (staff?.id == _staff?.id) return;
    setState(() {
      _staff = staff;
      _time = null;
      _clearBanner();
    });
    _loadSlots();
  }

  void _selectDate(DateTime date) {
    if (date.isBefore(_today) || date.isAfter(_lastDay)) return;
    setState(() {
      _date = date;
      _month = DateTime(date.year, date.month);
      _time = null;
      _clearBanner();
    });
    _loadSlots();
  }

  void _selectTime(TimeOption option) {
    if (!option.available || !_active) return;
    setState(() {
      _time = option;
      _clearBanner();
    });
  }

  void _clearBanner() {
    _bannerTitle = null;
    _bannerSub = null;
  }

  Future<void> _loadStaff() async {
    final service = _service;
    if (service == null || !_active) return;
    final seq = ++_staffSeq;
    setState(() {
      _staffLoading = true;
      _staffFailed = false;
    });
    try {
      final list = await Api.staff(widget.storeId, service.id);
      if (!mounted || seq != _staffSeq) return;
      setState(() {
        _staffList = list;
        _staffLoading = false;
      });
    } catch (_) {
      if (!mounted || seq != _staffSeq) return;
      setState(() {
        _staffLoading = false;
        _staffFailed = true;
      });
    }
  }

  /// 조건이 연달아 바뀌면 마지막 조건의 결과만 표시한다.
  Future<void> _loadSlots() async {
    final service = _service;
    if (service == null || !_active) return;
    final staffId = _staff?.id;
    final seq = ++_slotSeq;
    setState(() {
      _slotsLoading = true;
      _slotsFailed = false;
    });
    try {
      final slots = await Api.availability(widget.storeId, service.id, isoDate(_date), staffId);
      if (!mounted || seq != _slotSeq) return;
      setState(() {
        _options = _toOptions(slots, groupByStart: staffId == null);
        _slotsLoading = false;
      });
    } catch (_) {
      if (!mounted || seq != _slotSeq) return;
      setState(() {
        _slotsLoading = false;
        _slotsFailed = true;
      });
    }
  }

  static List<TimeOption> _toOptions(List<Slot> slots, {required bool groupByStart}) {
    final options = <TimeOption>[];
    if (groupByStart) {
      final groups = <String, List<Slot>>{};
      for (final s in slots) {
        groups.putIfAbsent(s.startAt, () => []).add(s);
      }
      for (final entry in groups.entries) {
        // 서버 순서상 그 시각의 첫 (가능한) 슬롯의 직원을 담당 직원으로 정한다.
        final first = entry.value.firstWhere((s) => s.available, orElse: () => entry.value.first);
        options.add(TimeOption(first.startAt, first.serviceEndAt, first.staffId, first.available));
      }
    } else {
      for (final s in slots) {
        options.add(TimeOption(s.startAt, s.serviceEndAt, s.staffId, s.available));
      }
    }
    options.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    return options;
  }

  String _staffNameFor(TimeOption option) {
    if (_staff != null) return _staff!.displayName;
    final match = _staffList?.where((s) => s.id == option.staffId);
    if (match != null && match.isNotEmpty) return match.first.displayName;
    return S.anyStaff;
  }

  int get _stepCount => (_service != null ? 2 : 0) + (_time != null ? 1 : 0);

  String get _nextStepLabel {
    if (_service == null) return S.selectService;
    if (_time == null) return S.selectDateTime;
    return S.stepDone;
  }

  // ---------- 예약 ----------

  String _obtainKey(String signature) {
    if (_idemKey == null || _idemSignature != signature) {
      _idemKey = uuidV4();
      _idemSignature = signature;
    }
    return _idemKey!;
  }

  void _discardKey() {
    _idemKey = null;
    _idemSignature = null;
  }

  Future<void> _openConfirm() async {
    final store = _store, service = _service, time = _time;
    if (store == null || service == null || time == null || !_active) return;
    final trimmed = _note.text.trim();
    final note = trimmed.isEmpty ? null : trimmed;
    final staffName = _staffNameFor(time);
    final signature = [service.id, time.staffId, time.startAt, note ?? ''].join('|');

    final result = await showModalBottomSheet<ConfirmResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      builder: (_) => ConfirmSheet(
        store: store,
        serviceId: service.id,
        serviceName: service.name,
        staffId: time.staffId,
        staffName: staffName,
        startAt: time.startAt,
        serviceEndAt: time.serviceEndAt,
        note: note,
        obtainKey: () => _obtainKey(signature),
        discardKey: _discardKey,
      ),
    );
    if (!mounted || result == null) return;

    switch (result.kind) {
      case ConfirmResultKind.success:
        _discardKey();
        AppNav.afterBooked(result.reservationId!);
      case ConfirmResultKind.checkMine:
        AppNav.toMyReservations();
      case ConfirmResultKind.conflict:
        _discardKey();
        setState(() {
          _time = null;
          if (result.code == 'STAFF_NOT_AVAILABLE') {
            _bannerTitle = result.message?.isNotEmpty == true ? result.message : S.slotTaken;
            _bannerSub = null;
          } else {
            _bannerTitle = S.slotTaken;
            _bannerSub = S.slotTakenSub;
          }
        });
        _loadSlots();
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(S.titleStoreDetail),
        bottom: _store == null ? null : _StepBar(count: _stepCount, nextLabel: _nextStepLabel),
      ),
      body: _buildBody(),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_store != null) _bottomBar(),
          const AppBottomNav(current: 0),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Loader();
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storefront_outlined, size: 48, color: AppColors.textSub),
              const SizedBox(height: 16),
              Text(_loadError!.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 20),
              PrimaryButton(label: S.backToStores, icon: Icons.storefront_outlined, onPressed: AppNav.toStores),
            ],
          ),
        ),
      );
    }
    if (_loadFailed || _store == null) {
      return Center(child: SingleChildScrollView(child: NetworkErrorView(onRetry: _load)));
    }
    final store = _store!;
    return Column(
      children: [
        if (_bannerTitle != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: MessageBanner(title: _bannerTitle!, sub: _bannerSub),
          ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              _Hero(store: store),
              const SizedBox(height: 16),
              _infoCard(store),
              const SizedBox(height: 24),
              const SectionTitle(S.businessHours, icon: Icons.schedule),
              _hoursCard(store),
              if (store.policy != null) ...[
                const SizedBox(height: 24),
                const SectionTitle(S.policy, icon: Icons.info_outline),
                InfoBox(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: policyLines(store.policy!).map(Bullet.new).toList(),
                  ),
                ),
              ],
              if (!_active) ...[
                const SizedBox(height: 24),
                const MessageBanner(
                  title: S.notBookable,
                  icon: Icons.info,
                  tone: BannerTone.warning,
                ),
              ],
              const SizedBox(height: 24),
              const SectionTitle(S.selectService, number: 1),
              ..._serviceCards(),
              const SizedBox(height: 24),
              const SectionTitle(S.selectStaff, number: 2),
              _staffSection(),
              const SizedBox(height: 24),
              const SectionTitle(S.selectDateTime, number: 3),
              _dateTimeSection(),
              const SizedBox(height: 24),
              const SectionTitle(S.note, number: 4),
              _noteField(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoCard(StoreDetail store) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(store.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 8),
          if (store.address != null) _iconLine(Icons.location_on_outlined, store.address!),
          if (store.phoneNumber != null) _iconLine(Icons.call_outlined, store.phoneNumber!),
          if (store.description != null && store.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(store.description!, style: const TextStyle(fontSize: 14, color: AppColors.text, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _iconLine(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.textSub),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 15, color: AppColors.textSub))),
          ],
        ),
      );

  Widget _hoursCard(StoreDetail store) {
    const order = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
    return AppCard(
      child: Column(
        children: [
          for (final day in order)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(S.weekday[day]!, style: const TextStyle(fontSize: 14, color: AppColors.textSub)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _hoursText(store.businessHours.where((h) => h.dayOfWeek == day).firstOrNull),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 14, color: AppColors.text),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _hoursText(BusinessHour? h) {
    if (h == null || h.isClosed || h.periods.isEmpty) return S.closedDay;
    return h.periods.map((p) => '${trimSeconds(p.$1)} - ${trimSeconds(p.$2)}').join(', ');
  }

  List<Widget> _serviceCards() {
    final services = _services ?? const [];
    return [
      for (final s in services)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ServiceCard(
            service: s,
            selected: _service?.id == s.id,
            enabled: _active && s.selectable,
            onTap: () => _selectService(s),
          ),
        ),
    ];
  }

  Widget _placeholder(String text) => AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: AppColors.textSub)),
        ),
      );

  Widget _staffSection() {
    if (_service == null || !_active) return _placeholder(S.serviceFirst);
    return Column(
      children: [
        _StaffTile(
          name: S.anyStaff,
          hint: S.anyStaffHint,
          any: true,
          selected: _staff == null,
          enabled: true,
          onTap: () => _selectStaff(null),
        ),
        if (_staffLoading)
          const Padding(padding: EdgeInsets.all(20), child: Loader())
        else if (_staffFailed)
          NetworkErrorView(onRetry: _loadStaff, compact: true)
        else
          for (final st in _staffList ?? const <StaffItem>[])
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _StaffTile(
                name: st.displayName,
                hint: st.customDurationMinutes != null ? S.duration(st.customDurationMinutes!) : null,
                selected: _staff?.id == st.id,
                enabled: st.bookingEnabled,
                onTap: () => _selectStaff(st),
              ),
            ),
      ],
    );
  }

  Widget _dateTimeSection() {
    if (_service == null || !_active) return _placeholder(S.serviceFirst);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const _IconTile(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(S.selection,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSub, letterSpacing: 0.6)),
                    const SizedBox(height: 2),
                    Text(_service!.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(_staff?.displayName ?? S.anyStaff,
                              style: const TextStyle(fontSize: 14, color: AppColors.textSub)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: _MonthCalendar(
            month: _month,
            selected: _date,
            today: _today,
            lastDay: _lastDay,
            onSelect: _selectDate,
            onMonthChanged: (m) => setState(() => _month = m),
          ),
        ),
        const SizedBox(height: 20),
        _slotSection(),
      ],
    );
  }

  Widget _slotSection() {
    if (_slotsLoading) return const Padding(padding: EdgeInsets.all(24), child: Loader());
    if (_slotsFailed) return NetworkErrorView(onRetry: _loadSlots, compact: true);
    final options = _options ?? const <TimeOption>[];
    if (options.isEmpty) {
      final next = DateTime(_date.year, _date.month, _date.day + 1);
      return AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.event_busy_outlined, color: AppColors.textSub, size: 32),
            const SizedBox(height: 10),
            const Text(S.noSlots,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
            if (!next.isAfter(_lastDay)) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _selectDate(next),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  minimumSize: const Size(120, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(S.otherDate),
              ),
            ],
          ],
        ),
      );
    }
    final morning = options.where((o) => o.hour < 12).toList();
    final afternoon = options.where((o) => o.hour >= 12).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (morning.isNotEmpty) _slotGroup(S.morning, Icons.wb_sunny_outlined, morning),
        if (morning.isNotEmpty && afternoon.isNotEmpty) const SizedBox(height: 16),
        if (afternoon.isNotEmpty) _slotGroup(S.afternoon, Icons.wb_twilight, afternoon),
      ],
    );
  }

  Widget _slotGroup(String label, IconData icon, List<TimeOption> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.onAccentContainer),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSub)),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, c) {
          final width = (c.maxWidth - 24) / 3;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final o in options)
                SizedBox(
                  width: width,
                  child: _SlotButton(
                    label: formatTime(o.hour, o.minute),
                    available: o.available,
                    selected: _time?.startAt == o.startAt && _time?.staffId == o.staffId,
                    onTap: () => _selectTime(o),
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }

  Widget _noteField() {
    return TextField(
      controller: _note,
      maxLength: 200,
      minLines: 3,
      maxLines: 5,
      decoration: const InputDecoration(hintText: S.notePlaceholder),
      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => Text(
        '$currentLength / $maxLength',
        style: const TextStyle(fontSize: 12, color: AppColors.textSub),
      ),
    );
  }

  Widget _bottomBar() {
    final time = _time;
    final canBook = _active && _service != null && time != null;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Color(0x4DC3C5D7))),
        boxShadow: [BoxShadow(color: Color(0x0F000000), offset: Offset(0, -8), blurRadius: 12)],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (time != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.event_available_outlined, size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${_staffNameFor(time)} · ${formatDateTime(time.startAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          PrimaryButton(
            label: S.book,
            icon: Icons.calendar_month_outlined,
            pill: true,
            onPressed: canBook ? _openConfirm : null,
          ),
        ],
      ),
    );
  }
}

/// policySummary 의 정책 문구 3개.
List<String> policyLines(PolicySummary p) => [
      if (p.bookingOpenDays != null) S.policyBookingOpen(p.bookingOpenDays!),
      if (p.minimumBookingNoticeMinutes != null) S.policyMinNotice(formatMinutes(p.minimumBookingNoticeMinutes!)),
      if (p.cancellationDeadlineMinutes != null) S.policyCancel(formatMinutes(p.cancellationDeadlineMinutes!)),
    ];

class _StepBar extends StatelessWidget implements PreferredSizeWidget {
  final int count;
  final String nextLabel;

  const _StepBar({required this.count, required this.nextLabel});

  @override
  Size get preferredSize => const Size.fromHeight(28);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: Column(
        children: [
          Row(
            children: [
              Text(S.step(count),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent)),
              const Spacer(),
              Text(nextLabel,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSub)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: count / 3,
              minHeight: 4,
              backgroundColor: AppColors.surfaceVariant,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final StoreDetail store;

  const _Hero({required this.store});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 168,
      decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned(left: 20, top: 20, child: Icon(Icons.storefront, size: 34, color: Colors.white)),
          Positioned(
            right: 16,
            top: -8,
            child: Text(
              firstChar(store.name),
              style: TextStyle(fontSize: 96, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.18)),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: StatusBadge(storeStatusStyle(store.status), background: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(10)),
      child: const Icon(Icons.design_services, color: AppColors.primary, size: 24),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData? icon;
  final String text;

  const _Chip(this.text, {this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(9999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: AppColors.textSub), const SizedBox(width: 4)],
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSub)),
        ],
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  final bool selected;

  const _Radio(this.selected);

  @override
  Widget build(BuildContext context) => Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? AppColors.primary : AppColors.outline,
        size: 24,
      );
}

const _selectedFill = Color(0xFFF4F6FE);

class _ServiceCard extends StatelessWidget {
  final ServiceItem service;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ServiceCard({required this.service, required this.selected, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unavailable = !service.selectable;
    return Opacity(
      opacity: enabled || selected ? 1 : 0.5,
      child: AppCard(
        onTap: enabled ? onTap : null,
        borderColor: selected ? AppColors.primary : null,
        borderWidth: selected ? 2 : 1,
        color: selected ? _selectedFill : AppColors.surface,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _IconTile(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(service.name,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.text)),
                      ),
                      if (unavailable) const _Chip(S.unavailable),
                    ],
                  ),
                  if (service.description != null && service.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(service.description!, style: const TextStyle(fontSize: 14, color: AppColors.textSub)),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _Chip(S.duration(service.durationMinutes), icon: Icons.schedule),
                      _Chip(S.staffCount(service.availableStaffCount), icon: Icons.groups_outlined),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _Radio(selected),
          ],
        ),
      ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  final String name;
  final String? hint;
  final bool any;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _StaffTile({
    required this.name,
    this.hint,
    this.any = false,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Widget avatar = any
        ? Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.groups, color: Colors.white, size: 22),
          )
        : Avatar(name, size: 44);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: AppCard(
        onTap: enabled ? onTap : null,
        borderColor: selected ? AppColors.primary : null,
        borderWidth: selected ? 2 : 1,
        color: selected ? _selectedFill : AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 2),
              ),
              child: avatar,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
                      ),
                      if (!enabled) ...[const SizedBox(width: 8), const _Chip(S.unavailable)],
                    ],
                  ),
                  if (hint != null)
                    Text(hint!,
                        style: TextStyle(fontSize: 13, color: any ? AppColors.onAccentContainer : AppColors.textSub)),
                ],
              ),
            ),
            _Radio(selected),
          ],
        ),
      ),
    );
  }
}

class _SlotButton extends StatelessWidget {
  final String label;
  final bool available;
  final bool selected;
  final VoidCallback onTap;

  const _SlotButton({required this.label, required this.available, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.primary : (available ? AppColors.surfaceContainer : AppColors.surfaceVariant);
    final border = selected ? AppColors.primary : (available ? AppColors.primaryContainer : AppColors.outline);
    final fg = selected ? AppColors.onPrimary : AppColors.text;
    return Opacity(
      opacity: available ? 1 : 0.5,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: available ? onTap : null,
          child: SizedBox(
            height: 52,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: fg,
                      decoration: available ? null : TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final DateTime lastDay;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<DateTime> onMonthChanged;

  const _MonthCalendar({
    required this.month,
    required this.selected,
    required this.today,
    required this.lastDay,
    required this.onSelect,
    required this.onMonthChanged,
  });

  static const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final firstMonth = DateTime(today.year, today.month);
    final lastMonth = DateTime(lastDay.year, lastDay.month);
    final canPrev = month.isAfter(firstMonth);
    final canNext = month.isBefore(lastMonth);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = DateTime(month.year, month.month, 1).weekday % 7; // 일요일 시작

    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var d = 1; d <= daysInMonth; d++) _dayCell(DateTime(month.year, month.month, d)),
    ];

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: canPrev ? () => onMonthChanged(DateTime(month.year, month.month - 1)) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(S.calendarHeader(month.year, month.month),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
            ),
            IconButton(
              onPressed: canNext ? () => onMonthChanged(DateTime(month.year, month.month + 1)) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final w in _weekdays)
              Expanded(
                child: Center(
                  child: Text(w, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSub)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.0,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          children: cells,
        ),
      ],
    );
  }

  Widget _dayCell(DateTime day) {
    final inRange = !day.isBefore(today) && !day.isAfter(lastDay);
    final isSelected = _sameDay(day, selected);
    final isToday = _sameDay(day, today);
    return Opacity(
      opacity: inRange ? 1 : 0.3,
      child: Material(
        color: isSelected ? AppColors.primary : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isToday && !isSelected ? const BorderSide(color: AppColors.primary, width: 1.5) : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: inRange ? () => onSelect(day) : null,
          child: Center(
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? AppColors.onPrimary : (isToday ? AppColors.primary : AppColors.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

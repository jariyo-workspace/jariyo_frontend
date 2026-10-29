import 'package:flutter/material.dart';

import '../../../core/domain/statuses.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_time_format.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/countdown.dart';
import '../../reservation/domain/reservation_entities.dart';
import '../../reservation/presentation/reservation_detail_screen.dart';
import '../../waitlist/domain/waitlist_entities.dart';
import '../../waitlist/presentation/slot_offer_screen.dart';
import '../../waitlist/presentation/waitlist_detail_screen.dart';
import '../../walk_in/domain/walk_in_entities.dart';
import '../../walk_in/presentation/walk_in_call_screen.dart';
import '../../walk_in/presentation/walk_in_detail_screen.dart';
import '../domain/home_entities.dart';

void openReservation(BuildContext context, String id) => pushPage<void>(context, ReservationDetailScreen(reservationId: id));

void openWaitlist(BuildContext context, String id) => pushPage<void>(context, WaitlistDetailScreen(waitlistId: id));

void openSlotOffer(BuildContext context, String id) => pushPage<void>(context, SlotOfferScreen(offerId: id));

void openWalkIn(BuildContext context, WalkIn walkIn) => pushPage<void>(
  context,
  walkIn.status == WalkInStatus.called ? WalkInCallScreen(walkInId: walkIn.id) : WalkInDetailScreen(walkInId: walkIn.id),
);

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.icon,
    required this.title,
    required this.lines,
    required this.badge,
    required this.tone,
    required this.onTap,
    this.highlight = false,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final String badge;
  final StatusTone tone;
  final VoidCallback onTap;
  final bool highlight;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forTone(tone);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: highlight ? color : AppColors.border, width: highlight ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(backgroundColor: color.withAlpha(24), child: Icon(icon, color: color)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                        StatusBadge(label: badge, tone: tone),
                      ],
                    ),
                    const SizedBox(height: 4),
                    for (final line in lines.where((l) => l.isNotEmpty))
                      Text(line, style: const TextStyle(color: AppColors.lightText, height: 1.4)),
                    ?trailing,
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

class ReservationCard extends StatelessWidget {
  const ReservationCard({super.key, required this.reservation});

  final ReservationSummary reservation;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    return _ActivityCard(
      icon: Icons.event_available,
      title: r.storeName,
      badge: r.status.label,
      tone: r.status.tone,
      lines: [
        formatDateTime(r.startAt),
        if (!r.status.isPast) formatRelative(r.startAt),
        [r.serviceName, r.staffName].whereType<String>().join(' · '),
      ],
      onTap: () => openReservation(context, r.id),
    );
  }
}

class WaitlistCard extends StatelessWidget {
  const WaitlistCard({super.key, required this.entry});

  final WaitlistEntry entry;

  @override
  Widget build(BuildContext context) {
    return _ActivityCard(
      icon: Icons.hourglass_empty,
      title: entry.store?.name ?? '예약 대기',
      badge: entry.status.label,
      tone: entry.status.tone,
      highlight: entry.status == WaitlistStatus.offered,
      lines: [
        '희망 ${formatYmdLabel(entry.desiredDate)}',
        entry.timeRangeLabel,
        entry.service?.name ?? '',
      ],
      onTap: () => openWaitlist(context, entry.id),
    );
  }
}

class WalkInCard extends StatelessWidget {
  const WalkInCard({super.key, required this.walkIn});

  final WalkIn walkIn;

  @override
  Widget build(BuildContext context) {
    final w = walkIn;
    final called = w.status == WalkInStatus.called;
    return _ActivityCard(
      icon: called ? Icons.campaign : Icons.directions_walk,
      title: w.store?.name ?? '현장 대기',
      badge: w.status.label,
      tone: w.status.tone,
      highlight: called,
      lines: [
        '대기 ${w.queueNumber}번',
        if (w.status == WalkInStatus.waiting) '앞에 ${w.waitingAhead}팀 · 약 ${formatMinutes(w.estimatedWaitMinutes)} 예상',
        if (called) '지금 매장으로 입장해 주세요.',
      ],
      onTap: () => openWalkIn(context, w),
    );
  }
}

class OfferCard extends StatelessWidget {
  const OfferCard({super.key, required this.offer, this.onExpired});

  final SlotOffer offer;
  final VoidCallback? onExpired;

  @override
  Widget build(BuildContext context) {
    return _ActivityCard(
      icon: Icons.local_fire_department_outlined,
      title: '빈자리가 생겼어요',
      badge: '예약 가능',
      tone: StatusTone.attention,
      highlight: true,
      lines: [
        [offer.store?.name, offer.service?.name].whereType<String>().join(' · '),
        formatDateTime(offer.startAt),
      ],
      trailing: CountdownText(
        expiresAt: offer.deadline,
        suffix: ' 안에 수락해 주세요',
        onExpired: onExpired,
        style: const TextStyle(color: AppColors.attention, fontWeight: FontWeight.w700),
      ),
      onTap: () => openSlotOffer(context, offer.id),
    );
  }
}

class ActivityTile extends StatelessWidget {
  const ActivityTile({super.key, required this.item, this.onExpired});

  final ActivityItem item;
  final VoidCallback? onExpired;

  @override
  Widget build(BuildContext context) => switch (item) {
    ReservationActivity(:final reservation) => ReservationCard(reservation: reservation),
    WaitlistActivity(:final entry) => WaitlistCard(entry: entry),
    WalkInActivity(:final walkIn) => WalkInCard(walkIn: walkIn),
    OfferActivity(:final offer) => OfferCard(offer: offer, onExpired: onExpired),
  };
}

import 'package:flutter/material.dart';

import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_time_format.dart';
import '../../../../core/utils/external_links.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../domain/reservation_entities.dart';
import '../reservation_detail_screen.dart';

/// C-09 예약 완료
class BookingCompleteScreen extends StatelessWidget {
  const BookingCompleteScreen({super.key, required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    final shortId = reservation.id.length > 8 ? reservation.id.substring(0, 8).toUpperCase() : reservation.id;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('예약 완료')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: const Column(
              children: [
                Icon(Icons.check_circle, size: 72, color: AppColors.positive),
                SizedBox(height: 12),
                Text(
                  '예약이 확정되었어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatDateTime(reservation.startAt),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: AppColors.primary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          SectionCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 96, child: Text('예약 상태', style: TextStyle(color: AppColors.lightText))),
                    StatusBadge(label: reservation.status.label, tone: reservation.status.tone),
                  ],
                ),
                InfoRow(label: '매장', value: reservation.store.name),
                InfoRow(label: '서비스', value: reservation.service?.name ?? '-'),
                InfoRow(label: '날짜와 시간', value: formatDateTime(reservation.startAt)),
                InfoRow(label: '직원', value: reservation.staff?.name ?? '-'),
                InfoRow(label: '예약 번호', value: shortId),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const NoticeBox(icon: Icons.notifications_none, message: '예약 시간이 가까워지면 다시 알려드릴게요.'),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        children: [
          AppButton(
            label: '예약 상세 보기',
            onPressed: () => replacePage<void>(context, ReservationDetailScreen(reservationId: reservation.id)),
          ),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: '캘린더에 추가',
                  icon: Icons.event,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => addToCalendar(
                    title: '${reservation.store.name} · ${reservation.service?.name ?? '예약'}',
                    start: reservation.startAt,
                    end: reservation.serviceEndAt,
                    location: reservation.store.address,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: '홈으로',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

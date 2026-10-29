import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/presentation/view_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_time_format.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/view_model_scope.dart';
import '../../domain/admin_entities.dart';
import '../../domain/admin_insights_usecases.dart';
import '../../domain/admin_repositories.dart';
import '../admin_common.dart';

class AnalyticsViewModel extends LoadableViewModel<AnalyticsReport> {
  AnalyticsViewModel(this.storeId, AdminInsightsRepository repository) : _get = GetAnalyticsReport(repository);

  final String storeId;
  final GetAnalyticsReport _get;
  int days = 7;

  DateTime get to => storeToday();

  DateTime get from => to.subtract(Duration(days: days - 1));

  @override
  Future<AnalyticsReport> fetch() => _get(storeId, from: from, to: to);

  void setDays(int value) {
    days = value;
    load();
  }
}

String _pct(double rate) => '${(rate * 100).toStringAsFixed(rate * 100 < 10 ? 1 : 0)}%';

/// A-15 운영 통계. 관찰된 데이터만 설명하고 원인을 단정하지 않는다.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key, required this.ctx});

  final OperatorContext ctx;

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<AnalyticsViewModel>(
      create: () => AnalyticsViewModel(ctx.storeId, GetIt.I<AdminInsightsRepository>()),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: const Text('운영 통계')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 7, label: Text('7일')),
                      ButtonSegment(value: 30, label: Text('30일')),
                      ButtonSegment(value: 90, label: Text('90일')),
                    ],
                    selected: {vm.days},
                    onSelectionChanged: (s) => vm.setDays(s.first),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${formatShortCalendarDate(vm.from)} – ${formatShortCalendarDate(vm.to)}',
                      style: const TextStyle(color: AppColors.lightText),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LoadableBody<AnalyticsReport>(
                vm: vm,
                builder: (context, report) => _body(report),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(AnalyticsReport r) {
    final s = r.summary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        ResponsiveGrid(
          minItemWidth: 170,
          children: [
            MetricTile(label: '전체 예약', value: '${s.reservationCount}건'),
            MetricTile(label: '예약 완료율', value: _pct(s.completionRate)),
            MetricTile(label: '취소율', value: _pct(s.cancellationRate)),
            MetricTile(label: '노쇼율', value: _pct(s.noShowRate)),
            MetricTile(label: '현장 평균 대기', value: formatMinutes(s.averageWalkInWaitMinutes)),
            MetricTile(label: '대기 중 이탈률', value: _pct(s.walkInAbandonmentRate)),
            MetricTile(label: '취소 자리 재배정률', value: _pct(s.cancelledSlotRefillRate)),
            MetricTile(label: '빈자리 제안 수락률', value: _pct(s.waitlistOfferAcceptanceRate)),
          ],
        ),
        if (r.insights.isNotEmpty) ...[
          const SectionTitle('주요 관찰'),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in r.insights)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text('• $line', style: const TextStyle(height: 1.4))),
              ],
            ),
          ),
        ],
        const SectionTitle('일별 예약 수'),
        SectionCard(child: _DailyBars(daily: r.daily)),
        ExpansionTile(
          title: const Text('일별 데이터 표로 보기'),
          tilePadding: EdgeInsets.zero,
          children: [
            _Table(
              headers: const ['날짜', '예약', '완료', '취소', '노쇼'],
              rows: [
                for (final d in r.daily)
                  [formatYmdLabel(d.date), '${d.reservationCount}', '${d.completedCount}', '${d.cancelledCount}', '${d.noShowCount}'],
              ],
            ),
          ],
        ),
        const SectionTitle('직원별 비교'),
        _Table(
          headers: const ['직원', '예약', '완료', '취소', '노쇼', '현장 완료', '현장 평균'],
          rows: [
            for (final st in r.staff)
              [
                st.staffName,
                '${st.reservationCount}',
                '${st.completedReservationCount}',
                '${st.cancelledReservationCount}',
                '${st.noShowReservationCount}',
                '${st.completedWalkInServiceCount}',
                formatMinutes(st.averageCompletedWalkInServiceMinutes),
              ],
          ],
        ),
        const SectionTitle('서비스별 실제 소요 시간'),
        _Table(
          headers: const ['서비스', '건수', '예상', '실제 평균', '차이'],
          rows: [
            for (final sv in r.services)
              [
                sv.serviceName,
                '${sv.sessionCount}',
                formatMinutes(sv.expectedDurationMinutes),
                formatMinutes(sv.averageActualDurationMinutes),
                '${sv.averageDurationDeltaMinutes >= 0 ? '+' : ''}${sv.averageDurationDeltaMinutes}분',
              ],
          ],
        ),
      ],
    );
  }
}

/// 단일 계열 막대 차트: 한 가지 색, 얇은 막대, 끝 4px 라운드, 막대 사이 2px 간격, 막대별 툴팁.
class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.daily});

  final List<DailyReservationStat> daily;

  @override
  Widget build(BuildContext context) {
    if (daily.isEmpty) return const Text('표시할 데이터가 없어요.', style: TextStyle(color: AppColors.lightText));
    final maxValue = max(1, daily.map((d) => d.reservationCount).reduce(max));
    const chartHeight = 160.0;
    final labelEvery = max(1, (daily.length / 7).ceil());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('최대 $maxValue건', style: const TextStyle(color: AppColors.lightText, fontSize: 12)),
        const SizedBox(height: 4),
        SizedBox(
          height: chartHeight,
          child: Container(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in daily)
                  Expanded(
                    child: Tooltip(
                      triggerMode: TooltipTriggerMode.tap,
                      message: '${formatYmdLabel(d.date)}\n예약 ${d.reservationCount}건 · 완료 ${d.completedCount} · 취소 ${d.cancelledCount} · 노쇼 ${d.noShowCount}',
                      child: Container(
                        // 막대보다 넓은 터치 영역
                        color: Colors.transparent,
                        height: chartHeight,
                        alignment: Alignment.bottomCenter,
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Container(
                          height: max(2, chartHeight * d.reservationCount / maxValue),
                          constraints: const BoxConstraints(maxWidth: 24),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 0; i < daily.length; i++)
              Expanded(
                child: Text(
                  i % labelEvery == 0 ? formatShortCalendarDate(parseYmd(daily[i].date) ?? storeToday()).split('(').first : '',
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  style: const TextStyle(fontSize: 10, color: AppColors.lightText),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const Text('표시할 데이터가 없어요.', style: TextStyle(color: AppColors.lightText));
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
          columns: [for (final h in headers) DataColumn(label: Text(h))],
          rows: [for (final r in rows) DataRow(cells: [for (final c in r) DataCell(Text(c))])],
        ),
      ),
    );
  }
}

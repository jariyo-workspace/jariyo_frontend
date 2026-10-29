import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_time_format.dart';
import '../../../../core/widgets/dialogs.dart';

/// 하루의 시간 구간 목록 편집기. 구간 사이의 빈 시간을 휴게시간으로 보여준다.
class DayPeriodEditor extends StatelessWidget {
  const DayPeriodEditor({
    super.key,
    required this.dayLabel,
    required this.periods,
    required this.onChanged,
    this.closedLabel = '휴무',
    this.defaultPeriod = ('09:00', '18:00'),
  });

  final String dayLabel;
  final List<(String, String)> periods;
  final ValueChanged<List<(String, String)>> onChanged;
  final String closedLabel;
  final (String, String) defaultPeriod;

  List<(String, String)> get _breaks {
    final sorted = [...periods]..sort((a, b) => a.$1.compareTo(b.$1));
    return [
      for (var i = 0; i < sorted.length - 1; i++)
        if (sorted[i].$2.compareTo(sorted[i + 1].$1) < 0) (sorted[i].$2, sorted[i + 1].$1),
    ];
  }

  Future<void> _edit(BuildContext context, int index) async {
    final current = periods[index];
    final start = await pickHm(context, initial: current.$1, helpText: '$dayLabel 시작 시간');
    if (start == null || !context.mounted) return;
    final end = await pickHm(context, initial: current.$2, helpText: '$dayLabel 종료 시간');
    if (end == null) return;
    if (start.compareTo(end) >= 0) return;
    final next = [...periods]..[index] = (start, end);
    onChanged(next..sort((a, b) => a.$1.compareTo(b.$1)));
  }

  @override
  Widget build(BuildContext context) {
    final closed = periods.isEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(dayLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                Text(closed ? closedLabel : '운영', style: TextStyle(color: closed ? AppColors.danger : AppColors.positive)),
                Switch(
                  value: !closed,
                  onChanged: (on) => onChanged(on ? [defaultPeriod] : []),
                ),
              ],
            ),
            for (var i = 0; i < periods.length; i++)
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _edit(context, i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '${formatHm(periods[i].$1)} – ${formatHm(periods[i].$2)}',
                          style: const TextStyle(color: AppColors.primary, fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '구간 삭제',
                    onPressed: () => onChanged([...periods]..removeAt(i)),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ],
              ),
            for (final (start, end) in _breaks)
              Text('휴게 ${formatHm(start)} – ${formatHm(end)}', style: const TextStyle(color: AppColors.lightText, fontSize: 13)),
            if (!closed)
              TextButton.icon(
                onPressed: () {
                  final last = periods.last.$2;
                  final hour = (int.tryParse(last.split(':').first) ?? 18) + 1;
                  onChanged([...periods, (hmOf(hour.clamp(0, 22), 0), hmOf((hour + 2).clamp(1, 23), 0))]);
                },
                icon: const Icon(Icons.add),
                label: const Text('시간 구간 추가'),
              ),
          ],
        ),
      ),
    );
  }
}

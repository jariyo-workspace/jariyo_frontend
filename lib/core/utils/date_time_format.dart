/// 날짜·시간 표시 규칙.
///
/// 서버 일시는 시간대가 포함된 ISO 8601이다. 자리요 매장은 모두 `Asia/Seoul`(UTC+9, 서머타임 없음)
/// 기준이므로, 기기 시간대와 관계없이 매장 현지 시각으로 바꿔 표시한다.
/// 매장 현지 시각은 UTC 필드에 벽시계 값을 담은 [DateTime]으로 표현한다.
library;

const _storeOffset = Duration(hours: 9);
const _weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
const _shortWeekdays = ['월', '화', '수', '목', '금', '토', '일'];

DateTime toStoreTime(DateTime instant) => instant.toUtc().add(_storeOffset);

DateTime storeNow() => toStoreTime(DateTime.now());

/// 매장 현지 날짜(자정)를 돌려준다.
DateTime storeToday() {
  final now = storeNow();
  return DateTime.utc(now.year, now.month, now.day);
}

String _two(int value) => value.toString().padLeft(2, '0');

/// `오후 2:00`
String formatClock(int hour, int minute) {
  final period = hour < 12 ? '오전' : '오후';
  final h = hour % 12 == 0 ? 12 : hour % 12;
  return '$period $h:${_two(minute)}';
}

/// `7월 18일 토요일`
String formatDate(DateTime instant) => formatCalendarDate(toStoreTime(instant));

/// 매장 현지 날짜 값을 `7월 18일 토요일`로 표시한다.
String formatCalendarDate(DateTime localDate) =>
    '${localDate.month}월 ${localDate.day}일 ${_weekdays[localDate.weekday - 1]}';

String formatShortCalendarDate(DateTime localDate) =>
    '${localDate.month}/${localDate.day}(${_shortWeekdays[localDate.weekday - 1]})';

String weekdayShort(DateTime localDate) => _shortWeekdays[localDate.weekday - 1];

/// `오후 2:00`
String formatTime(DateTime instant) {
  final t = toStoreTime(instant);
  return formatClock(t.hour, t.minute);
}

/// `7월 18일 토요일 오후 2:00`
String formatDateTime(DateTime instant) => '${formatDate(instant)} ${formatTime(instant)}';

/// `내일 · 오후 2:00` 처럼 상대 날짜를 보조 정보로 표시한다.
String formatRelative(DateTime instant, {DateTime? now}) {
  final target = toStoreTime(instant);
  final base = now == null ? storeNow() : toStoreTime(now);
  final days = DateTime.utc(target.year, target.month, target.day)
      .difference(DateTime.utc(base.year, base.month, base.day))
      .inDays;
  final label = switch (days) {
    0 => '오늘',
    1 => '내일',
    2 => '모레',
    -1 => '어제',
    > 0 => '$days일 후',
    _ => '${-days}일 전',
  };
  return '$label · ${formatClock(target.hour, target.minute)}';
}

/// `YYYY-MM-DD`
String formatYmd(DateTime localDate) => '${localDate.year}-${_two(localDate.month)}-${_two(localDate.day)}';

DateTime? parseYmd(String? value) {
  if (value == null || value.length < 10) return null;
  final parts = value.substring(0, 10).split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime.utc(y, m, d);
}

/// 서버의 `YYYY-MM-DD` 날짜를 `7월 18일 토요일`로 표시한다.
String formatYmdLabel(String? ymd) {
  final date = parseYmd(ymd);
  return date == null ? (ymd ?? '-') : formatCalendarDate(date);
}

/// `13:00` 또는 `13:00:00`을 `HH:mm`으로 정리한다.
String normalizeHm(String? value) {
  if (value == null || value.length < 5) return value ?? '';
  return value.substring(0, 5);
}

/// `13:00` → `오후 1:00`
String formatHm(String? value) {
  final hm = normalizeHm(value);
  final parts = hm.split(':');
  if (parts.length < 2) return hm;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return hm;
  return formatClock(h, m);
}

String hmOf(int hour, int minute) => '${_two(hour)}:${_two(minute)}';

/// `1시간 30분`
String formatMinutes(int minutes) {
  if (minutes < 60) return '$minutes분';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h시간' : '$h시간 $m분';
}

/// `02:41`
String formatCountdown(Duration remaining) {
  if (remaining.isNegative) return '00:00';
  final total = remaining.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '${_two(m)}:${_two(s)}';
}

/// 남은 시간을 문장으로 표시한다. (접근성: 숫자와 문장을 함께 제공)
String describeRemaining(Duration remaining) {
  if (remaining.inSeconds <= 0) return '시간이 끝났어요';
  final m = remaining.inMinutes;
  final s = remaining.inSeconds % 60;
  if (m == 0) return '$s초 남았어요';
  return s == 0 ? '$m분 남았어요' : '$m분 $s초 남았어요';
}

/// 매장 현지 벽시계 날짜와 시각을 ISO 8601(+09:00) 문자열로 만든다.
String storeIso(DateTime localDate, int hour, int minute) =>
    '${formatYmd(localDate)}T${_two(hour)}:${_two(minute)}:00+09:00';

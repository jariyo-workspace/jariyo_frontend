import 'dart:math';

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// 응답 문자열의 오프셋 기준 현지 시각. 기기 시간대로 변환하지 않는다.
class LocalDateTime {
  final int year, month, day, hour, minute;

  const LocalDateTime(this.year, this.month, this.day, this.hour, this.minute);

  static final _pattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})');

  static LocalDateTime? tryParse(String? value) {
    if (value == null) return null;
    final m = _pattern.firstMatch(value);
    if (m == null) return null;
    int g(int i) => int.parse(m.group(i)!);
    return LocalDateTime(g(1), g(2), g(3), g(4), g(5));
  }

  String get weekdayLabel => _weekdays[DateTime.utc(year, month, day).weekday - 1];
}

String formatTime(int hour, int minute) {
  final ampm = hour < 12 ? '오전' : '오후';
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$ampm $h12:${minute.toString().padLeft(2, '0')}';
}

/// M월 d일 E요일 a h:mm
String formatDateTime(String? value) {
  final t = LocalDateTime.tryParse(value);
  if (t == null) return value ?? '';
  return '${t.month}월 ${t.day}일 ${t.weekdayLabel}요일 ${formatTime(t.hour, t.minute)}';
}

/// a h:mm
String formatTimeOnly(String? value) {
  final t = LocalDateTime.tryParse(value);
  if (t == null) return value ?? '';
  return formatTime(t.hour, t.minute);
}

int? minutesBetween(String? start, String? end) {
  final s = start == null ? null : DateTime.tryParse(start);
  final e = end == null ? null : DateTime.tryParse(end);
  if (s == null || e == null) return null;
  return e.difference(s).inMinutes;
}

/// 분 단위 값을 시간·분으로 바꾼다(1440 → 24시간).
String formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m분';
  if (m == 0) return '$h시간';
  return '$h시간 $m분';
}

/// "10:00:00" → "10:00"
String trimSeconds(String time) {
  final parts = time.split(':');
  return parts.length >= 2 ? '${parts[0]}:${parts[1]}' : time;
}

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String firstChar(String? name) {
  if (name == null || name.trim().isEmpty) return '?';
  return String.fromCharCode(name.trim().runes.first);
}

String uuidV4() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

import 'package:flutter_test/flutter_test.dart';
import 'package:jariyo_frontend/core/format.dart';

void main() {
  test('일시는 응답 오프셋 기준 현지 시각으로 표시한다', () {
    expect(formatDateTime('2026-10-22T14:00:00+09:00'), '10월 22일 목요일 오후 2:00');
    expect(formatDateTime('2026-10-22T14:00:00Z'), '10월 22일 목요일 오후 2:00');
  });

  test('정오는 오후 12:00, 자정은 오전 12:00', () {
    expect(formatTimeOnly('2026-10-22T12:00:00+09:00'), '오후 12:00');
    expect(formatTimeOnly('2026-10-22T00:05:00+09:00'), '오전 12:05');
  });

  test('분 단위 정책 값을 시간·분으로 바꾼다', () {
    expect(formatMinutes(1440), '24시간');
    expect(formatMinutes(120), '2시간');
    expect(formatMinutes(90), '1시간 30분');
    expect(formatMinutes(30), '30분');
  });

  test('예상 소요 시간은 serviceEndAt - startAt', () {
    expect(minutesBetween('2026-10-22T14:00:00+09:00', '2026-10-22T14:30:00+09:00'), 30);
  });

  test('UUID v4 형식', () {
    final id = uuidV4();
    expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(id), isTrue);
    expect(uuidV4(), isNot(id));
  });
}

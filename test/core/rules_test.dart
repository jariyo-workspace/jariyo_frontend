import 'package:flutter_test/flutter_test.dart';
import 'package:jariyo_frontend/core/domain/statuses.dart';
import 'package:jariyo_frontend/core/network/idempotency.dart';
import 'package:jariyo_frontend/core/utils/date_time_format.dart';
import 'package:jariyo_frontend/features/auth/domain/auth_usecases.dart';
import 'package:jariyo_frontend/features/walk_in/domain/walk_in_usecases.dart';

void main() {
  group('멱등성 키', () {
    test('UUID v4 형식이다', () {
      expect(
        newIdempotencyKey(),
        matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
      );
    });

    test('같은 요청 재시도는 기존 키, 내용이 바뀌거나 응답을 받은 뒤에는 새 키', () {
      final holder = IdempotencyKeyHolder();
      final first = holder.keyFor({'slot': 'a'});
      expect(holder.keyFor({'slot': 'a'}), first);
      final changed = holder.keyFor({'slot': 'b'});
      expect(changed, isNot(first));
      holder.settle();
      expect(holder.keyFor({'slot': 'b'}), isNot(changed));
    });
  });

  group('시간 표시', () {
    final instant = DateTime.parse('2026-07-18T14:00:00+09:00');

    test('절대 날짜를 매장 현지 시각으로 표시한다', () {
      expect(formatDateTime(instant), '7월 18일 토요일 오후 2:00');
      expect(formatTime(DateTime.parse('2026-07-18T00:05:00Z')), '오전 9:05');
    });

    test('상대 시간은 보조 정보로 붙인다', () {
      expect(formatRelative(instant, now: DateTime.parse('2026-07-17T10:00:00+09:00')), '내일 · 오후 2:00');
      expect(formatRelative(instant, now: DateTime.parse('2026-07-18T23:00:00+09:00')), '오늘 · 오후 2:00');
    });

    test('남은 시간은 숫자와 문장으로 제공한다', () {
      expect(formatCountdown(const Duration(seconds: 161)), '02:41');
      expect(describeRemaining(const Duration(seconds: 161)), '2분 41초 남았어요');
    });

    test('서버 시간 문자열을 정리한다', () {
      expect(normalizeHm('13:00:00'), '13:00');
      expect(formatHm('13:00'), '오후 1:00');
      expect(storeIso(DateTime.utc(2026, 7, 18), 9, 30), '2026-07-18T09:30:00+09:00');
    });
  });

  test('내부 상태 코드는 공통 사용자 문구로 바꾼다', () {
    expect(ReservationStatus.parse('HELD').label, '예약 확인 중');
    expect(ReservationStatus.parse('NO_SHOW').label, '미방문');
    expect(WalkInStatus.parse('CALLED').label, '입장 요청');
    expect(WaitlistStatus.parse('OFFERED').label, '예약 가능');
    expect(ReservationStatus.parse('SOMETHING_NEW'), ReservationStatus.unknown);
    expect(ReservationStatus.checkedIn.isUpcoming, isTrue);
    expect(ReservationStatus.expired.isPast, isTrue);
  });

  group('회원가입 규칙', () {
    test('비밀번호는 서버와 같이 15~64자', () {
      expect(AccountRules.validatePassword('short'), isNotNull);
      expect(AccountRules.validatePassword('a' * 15), isNull);
      expect(AccountRules.validatePassword('a' * 65), isNotNull);
    });

    test('휴대폰 번호는 010 11자리', () {
      expect(AccountRules.validatePhone('01012345678'), isNull);
      expect(AccountRules.validatePhone('0101234567'), isNotNull);
      expect(AccountRules.validatePhone('01112345678'), isNotNull);
    });
  });

  test('매장 QR에서 매장 ID를 꺼낸다', () {
    const id = '3f2b8c1e-1d2a-4b5c-9e8f-0a1b2c3d4e5f';
    expect(parseStoreIdFromQr('jariyo://stores/$id/walk-in'), id);
    expect(parseStoreIdFromQr('https://jariyo.app/w?storeId=$id'), id);
    expect(parseStoreIdFromQr(id), id);
    expect(parseStoreIdFromQr('hello world'), isNull);
  });
}

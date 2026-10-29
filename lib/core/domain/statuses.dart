/// 예약·대기·현장 상태와 사용자 표시 문구의 공통 매핑.
///
/// 내부 상태 코드는 화면에 그대로 노출하지 않고, 모든 화면이 이 매핑을 사용한다.
library;

/// 상태 배지의 시각적 성격. 색상과 아이콘을 함께 사용해 색만으로 구분하지 않는다.
enum StatusTone { positive, active, attention, waiting, neutral, negative }

T _parse<T extends Enum>(List<T> values, Object? raw, String Function(T) codeOf, T fallback) {
  for (final value in values) {
    if (codeOf(value) == raw) return value;
  }
  return fallback;
}

enum ReservationStatus {
  held('HELD', '예약 확인 중', StatusTone.waiting),
  confirmed('CONFIRMED', '예약 확정', StatusTone.positive),
  checkedIn('CHECKED_IN', '체크인 완료', StatusTone.active),
  inService('IN_SERVICE', '이용 중', StatusTone.active),
  completed('COMPLETED', '이용 완료', StatusTone.neutral),
  cancelled('CANCELLED', '취소됨', StatusTone.negative),
  noShow('NO_SHOW', '미방문', StatusTone.negative),
  expired('EXPIRED', '만료됨', StatusTone.neutral),
  unknown('UNKNOWN', '확인 필요', StatusTone.attention);

  const ReservationStatus(this.code, this.label, this.tone);

  final String code;
  final String label;
  final StatusTone tone;

  static ReservationStatus parse(Object? raw) => _parse(values, raw, (s) => s.code, unknown);

  /// 내 예약 탭 분류 (문서 6.8)
  bool get isUpcoming => this == held || this == confirmed || this == checkedIn;
  bool get isInUse => this == inService;
  bool get isPast => this == completed || this == cancelled || this == noShow || this == expired;
}

enum WaitlistStatus {
  waiting('WAITING', '예약 대기 중', StatusTone.waiting),
  offered('OFFERED', '예약 가능', StatusTone.attention),
  reserved('RESERVED', '예약으로 전환됨', StatusTone.positive),
  cancelled('CANCELLED', '대기 취소', StatusTone.negative),
  expired('EXPIRED', '대기 기간 종료', StatusTone.neutral),
  unknown('UNKNOWN', '확인 필요', StatusTone.attention);

  const WaitlistStatus(this.code, this.label, this.tone);

  final String code;
  final String label;
  final StatusTone tone;

  static WaitlistStatus parse(Object? raw) => _parse(values, raw, (s) => s.code, unknown);

  bool get isActive => this == waiting || this == offered;
}

enum SlotOfferStatus {
  pending('PENDING', '응답 대기', StatusTone.attention),
  accepted('ACCEPTED', '수락함', StatusTone.positive),
  declined('DECLINED', '건너뜀', StatusTone.neutral),
  expired('EXPIRED', '만료됨', StatusTone.neutral),
  revoked('REVOKED', '매장에서 취소', StatusTone.negative),
  unknown('UNKNOWN', '확인 필요', StatusTone.attention);

  const SlotOfferStatus(this.code, this.label, this.tone);

  final String code;
  final String label;
  final StatusTone tone;

  static SlotOfferStatus parse(Object? raw) => _parse(values, raw, (s) => s.code, unknown);
}

enum WalkInStatus {
  waiting('WAITING', '대기 중', StatusTone.waiting),
  called('CALLED', '입장 요청', StatusTone.attention),
  checkedIn('CHECKED_IN', '입장 확인됨', StatusTone.active),
  inService('IN_SERVICE', '이용 중', StatusTone.active),
  completed('COMPLETED', '이용 완료', StatusTone.neutral),
  skipped('SKIPPED', '순서 보류', StatusTone.attention),
  cancelled('CANCELLED', '대기 취소', StatusTone.negative),
  noShow('NO_SHOW', '응답 없음 처리', StatusTone.negative),
  unknown('UNKNOWN', '확인 필요', StatusTone.attention);

  const WalkInStatus(this.code, this.label, this.tone);

  final String code;
  final String label;
  final StatusTone tone;

  static WalkInStatus parse(Object? raw) => _parse(values, raw, (s) => s.code, unknown);

  bool get isActive => this == waiting || this == called || this == skipped || this == checkedIn || this == inService;
}

/// 운영자 예약 목록의 체크인 배지.
enum CheckInStatus {
  notCheckedIn('NOT_CHECKED_IN', '체크인 전', StatusTone.waiting),
  checkedIn('CHECKED_IN', '체크인', StatusTone.active),
  inService('IN_SERVICE', '서비스 진행', StatusTone.active),
  completed('COMPLETED', '완료', StatusTone.neutral),
  noShow('NO_SHOW', '노쇼', StatusTone.negative),
  cancelled('CANCELLED', '취소', StatusTone.negative),
  unknown('UNKNOWN', '확인 필요', StatusTone.attention);

  const CheckInStatus(this.code, this.label, this.tone);

  final String code;
  final String label;
  final StatusTone tone;

  static CheckInStatus parse(Object? raw) => _parse(values, raw, (s) => s.code, unknown);
}

enum StoreStatus {
  preparing('PREPARING', '오픈 준비 중'),
  active('ACTIVE', '운영 중'),
  temporarilyClosed('TEMPORARILY_CLOSED', '임시 휴무'),
  closed('CLOSED', '운영 종료'),
  unknown('UNKNOWN', '확인 필요');

  const StoreStatus(this.code, this.label);

  final String code;
  final String label;

  static StoreStatus parse(Object? raw) => _parse(values, raw, (s) => s.code, unknown);
}

enum StoreRole {
  staff('STAFF', '직원', 1),
  manager('MANAGER', '관리자', 2),
  owner('OWNER', '소유자', 3);

  const StoreRole(this.code, this.label, this.level);

  final String code;
  final String label;
  final int level;

  static StoreRole parse(Object? raw) => _parse(values, raw, (s) => s.code, staff);

  bool atLeast(StoreRole other) => level >= other.level;
}

enum MemberStatus {
  active('ACTIVE', '근무 중'),
  inactive('INACTIVE', '비활성'),
  invited('INVITED', '초대됨'),
  unknown('UNKNOWN', '확인 필요');

  const MemberStatus(this.code, this.label);

  final String code;
  final String label;

  static MemberStatus parse(Object? raw) => _parse(values, raw, (s) => s.code, unknown);
}

enum StaffPreferenceType {
  specificOnly('SPECIFIC_ONLY', '선택한 직원만'),
  specificPreferred('SPECIFIC_PREFERRED', '선택한 직원 우선, 다른 직원도 가능'),
  anyStaff('ANY_STAFF', '직원 무관');

  const StaffPreferenceType(this.code, this.label);

  final String code;
  final String label;

  static StaffPreferenceType parse(Object? raw) => _parse(values, raw, (s) => s.code, anyStaff);
}

enum ReservationSource {
  customerBooking('CUSTOMER_BOOKING', '앱 예약'),
  storeManual('STORE_MANUAL', '매장 등록'),
  waitlistOffer('WAITLIST_OFFER', '빈자리 제안'),
  walkInConversion('WALK_IN_CONVERSION', '현장 전환'),
  unknown('UNKNOWN', '-');

  const ReservationSource(this.code, this.label);

  final String code;
  final String label;

  static ReservationSource parse(Object? raw) => _parse(values, raw, (s) => s.code, unknown);
}

/// 서버의 행위자 구분을 사용자 문구로 바꾼다.
String actorLabel(String? type) => switch (type) {
  'CUSTOMER' => '고객',
  'STORE_MEMBER' || 'STAFF' => '직원',
  'SYSTEM' => '시스템',
  _ => '-',
};

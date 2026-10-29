/// media-files/data/strings_ko.json 과 동일한 문구.
class S {
  // app
  static const appName = '자리요';
  static const appTagline = '예약도 대기도 한자리에서';
  static const appSubtitle = '기다림은 짧게, 경험은 풍성하게.\n자리요와 함께 특별한 시간을 보내세요.';
  static const appCopyright = '© 2026 Jariyo. All rights reserved.';

  // nav
  static const navStores = '매장 탐색';
  static const navMyReservations = '내 예약';

  // title
  static const titleSignIn = '로그인';
  static const titleStores = '매장 탐색';
  static const titleStoreDetail = '매장 상세';
  static const titleMyReservations = '내 예약';
  static const titleReservationDetail = '예약 상세';
  static const titleConfirm = '예약 확인';

  // signIn
  static const signInEmail = '이메일';
  static const signInPassword = '비밀번호';
  static const signInSubmit = '로그인';
  static const signInEmailRequired = '이메일을 입력해 주세요.';
  static const signInEmailInvalid = '이메일 형식이 올바르지 않아요.';
  static const signInPasswordRequired = '비밀번호를 입력해 주세요.';

  // common
  static const networkError = '잠시 연결이 원활하지 않아요.';
  static const networkErrorSub = '현재 예약과 대기 정보는 유지되고 있어요.';
  static const retry = '다시 시도';
  static const none = '없음';
  static const close = '닫기';
  static const unknownStatus = '확인 필요';

  // stores
  static const storesEmpty = '등록된 매장이 없어요.';
  static String storesCount(int n) => '$n곳';

  // storeDetail
  static const businessHours = '영업시간';
  static const policy = '예약 및 취소 정책';
  static const selectService = '서비스 선택';
  static const selectStaff = '직원 선택';
  static const selectDateTime = '날짜 및 시간 선택';
  static const note = '요청사항';
  static const closedDay = '휴무';
  static String policyBookingOpen(int days) => '최대 $days일 후까지 예약할 수 있어요.';
  static String policyMinNotice(String v) => '예약 시작 $v 전까지 예약할 수 있어요.';
  static String policyCancel(String v) => '예약 시작 $v 전까지 취소할 수 있어요.';
  static const serviceFirst = '서비스를 먼저 선택해 주세요.';
  static const notBookable = '지금은 예약할 수 없는 매장이에요.';
  static const unavailable = '선택 불가';
  static const anyStaff = '가능한 직원 누구나';
  static String duration(int n) => '소요 $n분';
  static String staffCount(int n) => '담당 $n명';
  static const morning = '오전';
  static const afternoon = '오후';
  static String calendarHeader(int y, int m) => '$y년 $m월';
  static const noSlots = '선택한 날짜에 예약 가능한 시간이 없어요.';
  static const otherDate = '다른 날짜 보기';
  static const slotTaken = '방금 다른 고객이 이 시간을 예약했어요.';
  static const slotTakenSub = '다른 가능한 시간을 선택해 주세요.';
  static const backToStores = '매장 탐색으로';
  static const book = '예약하기';
  static String step(int n) => '예약 단계 $n / 3';
  static const stepDone = '선택 완료';
  static const selection = '선택한 예약';
  static const anyStaffHint = '가장 빠른 시간으로 배정';
  static const notePlaceholder = '요청사항을 입력해 주세요 (선택)';

  // confirm
  static const confirmAgree = '예약 및 취소 정책 동의';
  static const confirmSubmit = '예약 확정하기';
  static const confirmSubmitting = '예약을 확인하고 있어요';
  static const confirmUnknown = '예약 결과를 바로 확인하지 못했어요.';
  static const confirmUnknownSub = '내 예약에서 처리 결과를 확인해 주세요.';
  static const confirmCheckMine = '내 예약 확인';
  static const confirmStore = '매장';
  static const confirmService = '서비스';
  static const confirmStaff = '담당 직원';
  static const confirmDateTime = '예약 일시';
  static const confirmEnd = '예상 종료';
  static const confirmSummary = '예약 요약';

  // myReservations
  static const myAll = '전체';
  static String myShown(int n) => '$n건 표시';
  static const myFilterEmpty = '해당 상태의 예약이 없어요.';
  static const myAllLoaded = '모든 예약을 불러왔어요.';
  static const myEmpty = '아직 예약 내역이 없어요.';
  static const myEmptySub = '원하는 매장을 찾아 예약해 보세요.';
  static const myFindStores = '매장 찾아보기';
  static const myLogoutTitle = '로그아웃할까요?';
  static const myCancel = '취소';
  static const myLogout = '로그아웃';

  // reservationDetail
  static const rdConfirmed = '예약이 확정되었어요';
  static const rdInService = '서비스가 진행 중이에요';
  static const rdCancelled = '취소된 예약이에요';
  static const rdHistory = '상태 변경 이력';
  static String rdUntil(String dateTime) => '$dateTime까지';
  static const rdDeadlinePassed = '취소 가능 시간이 지났어요. 매장에 문의해 주세요.';
  static const rdCancel = '예약 취소';
  static const rdRebook = '다시 예약';
  static const rdCancelDone = '예약을 취소했어요.';
  static const rdBackToMine = '내 예약으로';
  static const rdStore = '매장';
  static const rdAddress = '주소';
  static const rdPhone = '전화번호';
  static const rdService = '서비스';
  static const rdStaff = '담당 직원';
  static const rdDateTime = '예약 일시';
  static const rdDuration = '예상 소요 시간';
  static const rdPartySize = '인원';
  static const rdNote = '요청사항';
  static const rdCancelUntil = '취소 가능 시간';
  static String rdMinutes(int n) => '$n분';
  static String rdPeople(int n) => '$n명';
  static const rdInfoTitle = '예약 정보';
  static const rdPolicyTitle = '취소 정책';
  static String rdPolicyText(String dateTime) => '$dateTime까지 취소할 수 있어요.';
  static const rdBookedSub = '예약 시간에 맞춰 매장을 방문해 주세요.';

  // cancelSheet
  static const csTitle = '예약을 취소할까요?';
  static const csBody1 = '취소한 시간은 다른 고객에게 제공될 수 있으며,';
  static const csBody2 = '취소 후에는 되돌릴 수 없어요.';
  static const csReason = '취소 사유';
  static const csReasonRequired = '취소 사유를 입력해 주세요.';
  static const csKeep = '예약 유지';
  static const csConfirm = '예약 취소';

  static const weekday = {
    'MONDAY': '월요일',
    'TUESDAY': '화요일',
    'WEDNESDAY': '수요일',
    'THURSDAY': '목요일',
    'FRIDAY': '금요일',
    'SATURDAY': '토요일',
    'SUNDAY': '일요일',
  };
}

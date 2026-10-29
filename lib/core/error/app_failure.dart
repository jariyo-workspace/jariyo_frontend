/// 앱 전 계층에서 공통으로 사용하는 실패 표현.
///
/// 서버의 `error.code`는 화면 분기에, `error.message`는 사용자 안내에 사용한다.
enum FailureKind {
  /// 요청이 서버에 닿지 않았다(읽기 요청).
  network,

  /// 쓰기 요청의 처리 결과를 확인할 수 없다. 새 요청을 만들기 전에 결과를 확인해야 한다.
  unknownOutcome,

  /// 5xx 및 일시 장애.
  server,

  unauthorized,
  forbidden,
  notFound,
  conflict,
  validation,

  /// 토큰 재발급까지 실패해 다시 로그인해야 한다.
  sessionExpired,
}

class AppFailure implements Exception {
  const AppFailure({
    required this.kind,
    required this.code,
    required this.message,
    this.statusCode,
  });

  factory AppFailure.fromResponse(int statusCode, Object? body) {
    String code = 'HTTP_$statusCode';
    String? message;
    if (body is Map && body['error'] is Map) {
      final error = body['error'] as Map;
      code = error['code']?.toString() ?? code;
      message = error['message']?.toString();
    }
    final kind = switch (statusCode) {
      400 || 422 => FailureKind.validation,
      401 => FailureKind.unauthorized,
      403 => FailureKind.forbidden,
      404 || 410 => FailureKind.notFound,
      409 => FailureKind.conflict,
      >= 500 => FailureKind.server,
      _ => FailureKind.validation,
    };
    if (kind == FailureKind.server) message = serverMessage;
    if (kind == FailureKind.forbidden && (message == null || code == 'AUTH-403')) {
      message = forbiddenMessage;
    }
    return AppFailure(
      kind: kind,
      code: code,
      message: message ?? '요청을 처리하지 못했어요. 잠시 후 다시 시도해 주세요.',
      statusCode: statusCode,
    );
  }

  const AppFailure.network()
    : kind = FailureKind.network,
      code = 'NETWORK',
      message = serverMessage,
      statusCode = null;

  const AppFailure.unknownOutcome()
    : kind = FailureKind.unknownOutcome,
      code = 'UNKNOWN_OUTCOME',
      message = '요청 결과를 바로 확인하지 못했어요.\n중복 처리를 막기 위해 다시 시도하기 전에 현재 상태를 확인해 주세요.',
      statusCode = null;

  const AppFailure.sessionExpired()
    : kind = FailureKind.sessionExpired,
      code = 'SESSION_EXPIRED',
      message = '로그인이 만료되었어요. 다시 로그인해 주세요.',
      statusCode = 401;

  static const serverMessage = '잠시 연결이 원활하지 않아요.\n현재 예약과 대기 정보는 유지되고 있어요.';
  static const forbiddenMessage = '이 작업을 수행할 권한이 없어요.\n매장 관리자에게 권한을 요청해 주세요.';

  final FailureKind kind;
  final String code;
  final String message;
  final int? statusCode;

  bool get isTransient =>
      kind == FailureKind.network || kind == FailureKind.server || kind == FailureKind.unknownOutcome;

  /// 화면이 오래된 상태라 상세를 다시 조회해야 하는 상태 충돌 오류.
  bool get isStateConflict => const {
    'RESERVATION_INVALID_STATE',
    'WAITLIST_INVALID_STATE',
    'WALK_IN_INVALID_STATE',
    'SERVICE_SESSION_INVALID_STATE',
  }.contains(code);

  /// 입력값 오류로 필드 아래에 표시해야 하는 오류.
  bool get isFieldError => const {
    'INVALID_FIELD_FORMAT',
    'MISSING_REQUIRED_FIELD',
    'INVALID_DATE_RANGE',
    'INVALID_PARTY_SIZE',
  }.contains(code);

  @override
  String toString() => 'AppFailure($code, $statusCode): $message';
}

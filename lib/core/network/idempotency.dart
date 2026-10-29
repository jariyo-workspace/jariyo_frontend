import 'dart:convert';
import 'dart:math';

final _random = Random.secure();

/// UUID v4 형식의 멱등성 키를 만든다.
String newIdempotencyKey() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// 하나의 사용자 명령에 대한 멱등성 키를 관리한다.
///
/// * 버튼을 누르는 시점에 새 키를 만든다.
/// * 결과가 불명확해 같은 요청을 다시 보낼 때는 기존 키를 재사용한다.
/// * 요청 내용이 바뀌면 새 키를 만든다.
/// * 서버가 응답(성공 또는 업무 오류)을 돌려주면 [settle]로 키를 정리한다.
class IdempotencyKeyHolder {
  String? _key;
  String? _fingerprint;

  String keyFor(Object? request) {
    final fingerprint = jsonEncode(request);
    if (_key == null || fingerprint != _fingerprint) {
      _key = newIdempotencyKey();
      _fingerprint = fingerprint;
    }
    return _key!;
  }

  bool get hasPendingKey => _key != null;

  void settle() {
    _key = null;
    _fingerprint = null;
  }
}

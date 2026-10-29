/// 서버 JSON을 엔티티로 옮길 때 사용하는 느슨한 변환 함수.
///
/// 서버 응답 필드가 생략되거나 타입이 조금 달라도 화면이 깨지지 않도록 기본값을 돌려준다.
typedef Json = Map<String, dynamic>;

Json asJson(Object? value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Json> asJsonList(Object? value) =>
    value is List ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Json>[];

String str(Object? value, [String fallback = '']) => value?.toString() ?? fallback;

String? strOrNull(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

int intOf(Object? value, [int fallback = 0]) => intOrNull(value) ?? fallback;

int? intOrNull(Object? value) {
  if (value is num) return value.toInt();
  if (value == null) return null;
  return int.tryParse(value.toString());
}

double doubleOf(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value == null) return fallback;
  return double.tryParse(value.toString()) ?? fallback;
}

bool boolOf(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value == null) return fallback;
  return value.toString() == 'true';
}

bool? boolOrNull(Object? value) => value == null ? null : boolOf(value);

DateTime? timeOrNull(Object? value) => value == null ? null : DateTime.tryParse(value.toString());

DateTime timeOf(Object? value) => timeOrNull(value) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

/// 쿼리 파라미터에서 null 값을 제거하고 문자열로 바꾼다.
Map<String, String>? cleanQuery(Map<String, Object?>? query) {
  if (query == null) return null;
  final result = <String, String>{};
  query.forEach((key, value) {
    if (value != null && value.toString().isNotEmpty) result[key] = value.toString();
  });
  return result.isEmpty ? null : result;
}

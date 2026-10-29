import '../network/json.dart';

/// 다른 리소스를 가리키는 `{id, name}` 요약.
class NamedRef {
  const NamedRef({required this.id, required this.name});

  /// `name` 또는 `displayName` 필드를 모두 허용한다.
  static NamedRef? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = asJson(value);
    return NamedRef(id: str(json['id']), name: str(json['name'] ?? json['displayName']));
  }

  final String id;
  final String name;
}

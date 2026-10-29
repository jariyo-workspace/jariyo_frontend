import '../domain/paged.dart';
import 'api_client.dart';
import 'json.dart';

Paged<T> pagedFrom<T>(ApiResult result, T Function(Json json) map) => Paged(
  items: result.list.map(map).toList(),
  cursor: result.page?.cursor,
  hasNext: result.page?.hasNext ?? false,
);

UpdateResult updateResultFrom(Json json) => UpdateResult(
  // 일부 설정 API는 수정된 리소스를 그대로 돌려주므로 `updated`가 없으면 성공으로 본다.
  updated: boolOf(json['updated'], true),
  conflicts: asJsonList(json['conflicts'])
      .map((c) => ReservationConflict(reservationId: str(c['reservationId']), startAt: timeOf(c['startAt'])))
      .toList(),
);

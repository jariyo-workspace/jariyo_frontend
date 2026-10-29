/// 커서 기반 목록 한 페이지.
///
/// 커서는 해석하거나 수정하지 않고 다음 요청에 그대로 전달한다.
class Paged<T> {
  const Paged({required this.items, this.cursor, this.hasNext = false});

  final List<T> items;
  final String? cursor;
  final bool hasNext;
}

/// `{updated, conflicts}` 계약을 사용하는 설정 쓰기 결과.
///
/// `updated == false`이면 저장되지 않은 것으로 보고 충돌 예약을 보여준다.
class UpdateResult {
  const UpdateResult({required this.updated, this.conflicts = const []});

  final bool updated;
  final List<ReservationConflict> conflicts;
}

class ReservationConflict {
  const ReservationConflict({required this.reservationId, required this.startAt});

  final String reservationId;
  final DateTime startAt;
}

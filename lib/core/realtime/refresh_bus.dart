import 'dart:async';

/// 화면 데이터 무효화 단위.
///
/// 쓰기 요청 성공이나 실시간 이벤트 수신 시 관련 주제를 발행하면,
/// 해당 주제를 구독한 화면이 상세·목록 API를 다시 조회한다.
enum RefreshTopic {
  home,
  myReservations,
  reservationDetail,
  availability,
  waitlists,
  slotOffers,
  walkIns,
  notifications,
  storeDetail,
  adminDashboard,
  adminReservations,
  adminWalkIns,
  adminWaitlists,
  adminSlotOffers,
  adminSettings,
  adminFailedJobs,
}

class RefreshBus {
  final _controller = StreamController<Set<RefreshTopic>>.broadcast();

  Stream<Set<RefreshTopic>> get stream => _controller.stream;

  void emit(Set<RefreshTopic> topics) {
    if (topics.isNotEmpty) _controller.add(topics);
  }

  /// 문서 13장 "캐시 및 데이터 갱신 기준"의 무효화 묶음.
  static const afterReservationCreated = {
    RefreshTopic.availability,
    RefreshTopic.myReservations,
    RefreshTopic.home,
    RefreshTopic.storeDetail,
  };
  static const afterReservationCancelled = {
    RefreshTopic.reservationDetail,
    RefreshTopic.myReservations,
    RefreshTopic.availability,
    RefreshTopic.home,
    RefreshTopic.adminReservations,
  };
  static const afterSlotOfferAccepted = {
    RefreshTopic.slotOffers,
    RefreshTopic.waitlists,
    RefreshTopic.myReservations,
    RefreshTopic.home,
    RefreshTopic.availability,
  };
  static const afterWaitlistChanged = {RefreshTopic.waitlists, RefreshTopic.slotOffers, RefreshTopic.home};
  static const afterWalkInChanged = {
    RefreshTopic.walkIns,
    RefreshTopic.home,
    RefreshTopic.adminWalkIns,
    RefreshTopic.adminDashboard,
  };
  static const afterServiceSessionChanged = {
    RefreshTopic.reservationDetail,
    RefreshTopic.walkIns,
    RefreshTopic.adminDashboard,
    RefreshTopic.adminWalkIns,
    RefreshTopic.adminReservations,
  };
  static const afterAdminReservationChanged = {
    RefreshTopic.adminReservations,
    RefreshTopic.adminDashboard,
    RefreshTopic.availability,
  };
}

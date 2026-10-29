import '../../../core/domain/paged.dart';
import '../../../core/domain/statuses.dart';
import '../../store/domain/store_entities.dart';
import 'admin_entities.dart';

/// 오늘의 운영, 예약·현장 대기·예약 대기·서비스 진행 처리
abstract interface class AdminOperationRepository {
  Future<TodayDashboard> getDashboard(String storeId);

  Future<List<AdminReservation>> listReservations(
    String storeId, {
    DateTime? from,
    DateTime? to,
    String? staffId,
    String? serviceId,
    ReservationStatus? status,
    String? customerQuery,
  });

  Future<AdminReservation> getReservation(String storeId, String reservationId);

  Future<void> createReservation(String storeId, ManualReservationRequest request, {required String idempotencyKey});

  Future<void> rescheduleReservation(
    String storeId,
    String reservationId, {
    required String staffId,
    required String startAt,
    required String reason,
    required bool sendNotification,
    required String idempotencyKey,
  });

  Future<void> assignStaff(
    String storeId,
    String reservationId, {
    required String staffId,
    required String reason,
    required String idempotencyKey,
  });

  Future<void> cancelReservation(
    String storeId,
    String reservationId, {
    required String reasonCode,
    required String reason,
    required bool sendNotification,
    required String idempotencyKey,
  });

  Future<void> markReservationNoShow(String storeId, String reservationId, {required String reason, required String idempotencyKey});

  Future<void> checkInReservation(String storeId, String reservationId, {required String idempotencyKey});

  /// 서비스 세션 ID를 돌려준다.
  Future<String> startReservationService(
    String storeId,
    String reservationId, {
    required String staffId,
    required String idempotencyKey,
  });

  Future<void> completeServiceSession(String storeId, String sessionId, {String? note, required String idempotencyKey});

  Future<List<AdminWalkIn>> listWalkIns(String storeId, {WalkInStatus? status, DateTime? date});

  Future<void> registerGuestWalkIn(String storeId, GuestWalkInRequest request, {required String idempotencyKey});

  /// 호출 응답 만료 시각을 돌려준다.
  Future<DateTime?> callWalkIn(String storeId, String walkInId, {required int timeoutMinutes, required String idempotencyKey, bool recall = false});

  Future<void> checkInWalkIn(String storeId, String walkInId, {required String idempotencyKey});

  Future<void> skipWalkIn(String storeId, String walkInId, {required String reason, required String idempotencyKey});

  Future<void> cancelWalkIn(String storeId, String walkInId, {required String reason, required String idempotencyKey});

  Future<void> restoreWalkIn(String storeId, String walkInId, {required String idempotencyKey});

  Future<void> markWalkInNoShow(String storeId, String walkInId, {required String reason, required String idempotencyKey});

  Future<String> startWalkInService(String storeId, String walkInId, {required String staffId, required String idempotencyKey});

  Future<void> reorderWalkIn(
    String storeId,
    String walkInId, {
    String? beforeWalkInId,
    required String reasonCode,
    required String reason,
    required String idempotencyKey,
  });

  Future<List<AdminWaitlist>> listWaitlists(
    String storeId, {
    DateTime? date,
    String? serviceId,
    String? staffId,
    WaitlistStatus? status,
  });

  Future<AdminWaitlist> getWaitlist(String storeId, String waitlistId);

  Future<void> createOffer(String storeId, String waitlistId, ManualOfferRequest request, {required String idempotencyKey});

  Future<List<AdminSlotOffer>> listSlotOffers(String storeId, {SlotOfferStatus? status, DateTime? date});

  Future<void> revokeOffer(String storeId, String offerId, {required String reason, required String idempotencyKey});

  Future<void> offerNext(String storeId, String offerId, {required String idempotencyKey});

  /// 서비스 시작 응답의 세션 ID는 완료 처리에 필요하므로 기기에 보관한다.
  String? sessionIdFor(String referenceId);

  Future<void> rememberSession(String referenceId, String sessionId);

  Future<void> forgetSession(String referenceId);
}

/// 서비스·직원·근무 일정·영업시간·예외 일정·정책·매장 정보
abstract interface class StoreSettingsRepository {
  Future<StoreDetail> getStore(String storeId);

  Future<void> updateStore(String storeId, StoreInfoInput input);

  Future<List<ServiceItem>> listServices(String storeId);

  Future<void> createService(String storeId, ServiceInput input);

  Future<void> updateService(String storeId, String serviceId, ServiceInput input);

  Future<void> activateService(String storeId, String serviceId);

  Future<UpdateResult> deactivateService(String storeId, String serviceId);

  Future<List<StaffMember>> listStaff(String storeId);

  Future<StaffMember> getStaff(String storeId, String staffId);

  Future<void> addStaff(String storeId, {required String email, required StoreRole role, required String displayName});

  Future<UpdateResult> updateStaff(
    String storeId,
    String staffId, {
    required String displayName,
    required StoreRole role,
    required bool bookingEnabled,
    required MemberStatus status,
  });

  Future<UpdateResult> deactivateStaff(String storeId, String staffId);

  /// 서비스별 담당 직원 조회를 모아 직원의 담당 서비스를 만든다.
  Future<List<StaffServiceAssignment>> staffAssignments(String storeId, String staffId);

  Future<UpdateResult> replaceStaffServices(String storeId, String staffId, List<StaffServiceAssignment> assignments);

  Future<List<StaffScheduleEntry>> staffSchedules(String storeId, String staffId);

  Future<UpdateResult> replaceStaffSchedules(
    String storeId,
    String staffId,
    List<WeeklySchedule> schedules, {
    required String validFrom,
    String? validUntil,
  });

  Future<List<ScheduleException>> staffExceptions(String storeId, String staffId);

  Future<UpdateResult> createStaffException(String storeId, String staffId, ExceptionInput input);

  Future<UpdateResult> deleteStaffException(String storeId, String staffId, String exceptionId);

  Future<List<BusinessDay>> businessHours(String storeId);

  Future<UpdateResult> replaceBusinessHours(String storeId, List<BusinessDay> days);

  Future<List<ScheduleException>> storeExceptions(String storeId);

  Future<UpdateResult> createStoreException(String storeId, ExceptionInput input);

  Future<UpdateResult> deleteStoreException(String storeId, String exceptionId);

  Future<StorePolicy> getPolicy(String storeId);

  Future<StorePolicy> updatePolicy(String storeId, StorePolicy policy);
}

/// 통계·감사 로그·처리 실패
abstract interface class AdminInsightsRepository {
  Future<AnalyticsReport> analytics(String storeId, {required DateTime from, required DateTime to});

  Future<Paged<AuditLogEntry>> auditLogs(
    String storeId, {
    String? action,
    String? targetType,
    String? targetId,
    DateTime? from,
    DateTime? to,
    String? cursor,
  });

  Future<Paged<FailedJob>> failedJobs(String storeId, {FailedJobStatus? status, String? cursor});

  Future<FailedJob> failedJob(String storeId, String jobId);

  Future<void> retryFailedJob(String storeId, String jobId, {required String idempotencyKey});

  Future<void> ignoreFailedJob(String storeId, String jobId, {required String reason});
}

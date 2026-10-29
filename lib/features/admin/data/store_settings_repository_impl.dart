import '../../../core/domain/paged.dart';
import '../../../core/domain/statuses.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/common_mappers.dart';
import '../../../core/network/json.dart';
import '../../store/data/store_mappers.dart';
import '../../store/domain/store_entities.dart';
import '../domain/admin_entities.dart';
import '../domain/admin_repositories.dart';
import 'admin_mappers.dart';

class StoreSettingsRepositoryImpl implements StoreSettingsRepository {
  const StoreSettingsRepositoryImpl(this._api);

  final ApiClient _api;

  String _base(String storeId) => '/admin/stores/$storeId';

  @override
  Future<StoreDetail> getStore(String storeId) async => storeDetailFromJson((await _api.get('/stores/$storeId')).json);

  @override
  Future<void> updateStore(String storeId, StoreInfoInput input) => _api.put(
    _base(storeId),
    body: {
      'name': input.name,
      'description': input.description,
      'phoneNumber': input.phoneNumber,
      'address': input.address,
    },
  );

  @override
  Future<List<ServiceItem>> listServices(String storeId) async =>
      (await _api.get('/stores/$storeId/services', query: {'activeOnly': false})).list.map(serviceItemFromJson).toList();

  @override
  Future<void> createService(String storeId, ServiceInput input) =>
      _api.post('${_base(storeId)}/services', body: input.toJson());

  @override
  Future<void> updateService(String storeId, String serviceId, ServiceInput input) =>
      _api.put('${_base(storeId)}/services/$serviceId', body: input.toJson());

  @override
  Future<void> activateService(String storeId, String serviceId) =>
      _api.post('${_base(storeId)}/services/$serviceId/activate');

  @override
  Future<UpdateResult> deactivateService(String storeId, String serviceId) async =>
      updateResultFrom((await _api.post('${_base(storeId)}/services/$serviceId/deactivate')).json);

  @override
  Future<List<StaffMember>> listStaff(String storeId) async =>
      (await _api.get('${_base(storeId)}/staff')).list.map(staffMemberFromJson).toList();

  @override
  Future<StaffMember> getStaff(String storeId, String staffId) async =>
      staffMemberFromJson((await _api.get('${_base(storeId)}/staff/$staffId')).json);

  @override
  Future<void> addStaff(String storeId, {required String email, required StoreRole role, required String displayName}) =>
      _api.post('${_base(storeId)}/staff', body: {'email': email, 'role': role.code, 'displayName': displayName});

  @override
  Future<UpdateResult> updateStaff(
    String storeId,
    String staffId, {
    required String displayName,
    required StoreRole role,
    required bool bookingEnabled,
    required MemberStatus status,
  }) async => updateResultFrom(
    (await _api.put(
      '${_base(storeId)}/staff/$staffId',
      body: {'displayName': displayName, 'role': role.code, 'bookingEnabled': bookingEnabled, 'status': status.code},
    )).json,
  );

  @override
  Future<UpdateResult> deactivateStaff(String storeId, String staffId) async =>
      updateResultFrom((await _api.post('${_base(storeId)}/staff/$staffId/deactivate')).json);

  @override
  Future<List<StaffServiceAssignment>> staffAssignments(String storeId, String staffId) async {
    final services = await listServices(storeId);
    final assigned = await Future.wait(
      services.map((service) async {
        final staff = (await _api.get('/stores/$storeId/services/${service.id}/staff')).list;
        return staff.where((s) => str(s['id']) == staffId).firstOrNull;
      }),
    );
    return [
      for (var i = 0; i < services.length; i++)
        StaffServiceAssignment(
          serviceId: services[i].id,
          serviceName: services[i].name,
          active: assigned[i] != null,
          customDurationMinutes: assigned[i] == null ? null : intOrNull(assigned[i]!['customDurationMinutes']),
          defaultDurationMinutes: services[i].durationMinutes,
        ),
    ];
  }

  @override
  Future<UpdateResult> replaceStaffServices(
    String storeId,
    String staffId,
    List<StaffServiceAssignment> assignments,
  ) async => updateResultFrom(
    (await _api.put(
      '${_base(storeId)}/staff/$staffId/services',
      body: {
        'services': [
          for (final a in assignments)
            {'serviceId': a.serviceId, 'active': a.active, 'customDurationMinutes': a.customDurationMinutes},
        ],
      },
    )).json,
  );

  @override
  Future<List<StaffScheduleEntry>> staffSchedules(String storeId, String staffId) async =>
      (await _api.get('${_base(storeId)}/staff/$staffId/schedules')).list.map(staffScheduleFromJson).toList();

  @override
  Future<UpdateResult> replaceStaffSchedules(
    String storeId,
    String staffId,
    List<WeeklySchedule> schedules, {
    required String validFrom,
    String? validUntil,
  }) async => updateResultFrom(
    (await _api.put(
      '${_base(storeId)}/staff/$staffId/schedules',
      body: {
        'schedules': [
          for (final day in schedules.where((d) => d.periods.isNotEmpty))
            {
              'dayOfWeek': day.dayOfWeek,
              'periods': [
                for (final (start, end) in day.periods) {'startTime': start, 'endTime': end},
              ],
              'validFrom': validFrom,
              'validUntil': validUntil,
            },
        ],
      },
    )).json,
  );

  @override
  Future<List<ScheduleException>> staffExceptions(String storeId, String staffId) async =>
      (await _api.get('${_base(storeId)}/staff/$staffId/schedule-exceptions')).list.map(staffExceptionFromJson).toList();

  @override
  Future<UpdateResult> createStaffException(String storeId, String staffId, ExceptionInput input) async =>
      updateResultFrom((await _api.post('${_base(storeId)}/staff/$staffId/schedule-exceptions', body: input.toJson())).json);

  @override
  Future<UpdateResult> deleteStaffException(String storeId, String staffId, String exceptionId) async =>
      updateResultFrom((await _api.delete('${_base(storeId)}/staff/$staffId/schedule-exceptions/$exceptionId')).json);

  @override
  Future<List<BusinessDay>> businessHours(String storeId) async =>
      (await _api.get('${_base(storeId)}/business-hours')).list.map(businessDayFromJson).toList();

  @override
  Future<UpdateResult> replaceBusinessHours(String storeId, List<BusinessDay> days) async => updateResultFrom(
    (await _api.put(
      '${_base(storeId)}/business-hours',
      body: {
        'businessHours': [
          for (final day in days)
            {
              'dayOfWeek': day.dayOfWeek,
              'isClosed': day.isClosed,
              'periods': day.isClosed
                  ? <Json>[]
                  : [
                      for (final p in day.periods) {'openTime': p.start, 'closeTime': p.end},
                    ],
            },
        ],
      },
    )).json,
  );

  @override
  Future<List<ScheduleException>> storeExceptions(String storeId) async =>
      (await _api.get('${_base(storeId)}/schedule-exceptions')).list.map(storeExceptionFromJson).toList();

  @override
  Future<UpdateResult> createStoreException(String storeId, ExceptionInput input) async =>
      updateResultFrom((await _api.post('${_base(storeId)}/schedule-exceptions', body: input.toJson())).json);

  @override
  Future<UpdateResult> deleteStoreException(String storeId, String exceptionId) async =>
      updateResultFrom((await _api.delete('${_base(storeId)}/schedule-exceptions/$exceptionId')).json);

  @override
  Future<StorePolicy> getPolicy(String storeId) async =>
      storePolicyFromJson((await _api.get('${_base(storeId)}/policy')).json);

  @override
  Future<StorePolicy> updatePolicy(String storeId, StorePolicy policy) async => storePolicyFromJson(
    (await _api.put(
      '${_base(storeId)}/policy',
      body: {
        'bookingOpenDays': policy.bookingOpenDays,
        'minimumBookingNoticeMinutes': policy.minimumBookingNoticeMinutes,
        'cancellationDeadlineMinutes': policy.cancellationDeadlineMinutes,
        'checkInOpenBeforeMinutes': policy.checkInOpenBeforeMinutes,
        'lateToleranceMinutes': policy.lateToleranceMinutes,
        'noShowAfterMinutes': policy.noShowAfterMinutes,
        'reservationHoldMinutes': policy.reservationHoldMinutes,
        'slotOfferExpirationMinutes': policy.slotOfferExpirationMinutes,
        'walkInCallTimeoutMinutes': policy.walkInCallTimeoutMinutes,
        'waitlistEnabled': policy.waitlistEnabled,
        'walkInEnabled': policy.walkInEnabled,
        'autoNoShowEnabled': policy.autoNoShowEnabled,
      },
    )).json,
  );
}

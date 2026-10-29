import '../../../core/domain/paged.dart';
import '../../../core/domain/statuses.dart';
import '../../store/domain/store_entities.dart';
import 'admin_entities.dart';
import 'admin_repositories.dart';

class GetManagedStore {
  const GetManagedStore(this._repository);

  final StoreSettingsRepository _repository;

  Future<StoreDetail> call(String storeId) => _repository.getStore(storeId);
}

class UpdateStoreInfo {
  const UpdateStoreInfo(this._repository);

  final StoreSettingsRepository _repository;

  Future<void> call(String storeId, StoreInfoInput input) => _repository.updateStore(storeId, input);
}

class GetManagedServices {
  const GetManagedServices(this._repository);

  final StoreSettingsRepository _repository;

  Future<List<ServiceItem>> call(String storeId) => _repository.listServices(storeId);
}

/// 서비스 추가·수정·활성화·비활성화. 기존 예약이 있는 서비스는 삭제하지 않고 비활성화한다.
class ManageService {
  const ManageService(this._repository);

  final StoreSettingsRepository _repository;

  Future<void> create(String storeId, ServiceInput input) => _repository.createService(storeId, input);

  Future<void> update(String storeId, String serviceId, ServiceInput input) =>
      _repository.updateService(storeId, serviceId, input);

  Future<void> activate(String storeId, String serviceId) => _repository.activateService(storeId, serviceId);

  Future<UpdateResult> deactivate(String storeId, String serviceId) => _repository.deactivateService(storeId, serviceId);
}

class GetStaffMembers {
  const GetStaffMembers(this._repository);

  final StoreSettingsRepository _repository;

  Future<List<StaffMember>> call(String storeId) async {
    final staff = await _repository.listStaff(storeId);
    return staff..sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return a.displayName.compareTo(b.displayName);
    });
  }
}

class GetStaffMember {
  const GetStaffMember(this._repository);

  final StoreSettingsRepository _repository;

  Future<StaffMember> call(String storeId, String staffId) => _repository.getStaff(storeId, staffId);
}

/// 직원 추가·정보 수정·비활성화·담당 서비스 설정
class ManageStaff {
  const ManageStaff(this._repository);

  final StoreSettingsRepository _repository;

  Future<void> add(String storeId, {required String email, required StoreRole role, required String displayName}) =>
      _repository.addStaff(storeId, email: email, role: role, displayName: displayName);

  Future<UpdateResult> update(
    String storeId,
    String staffId, {
    required String displayName,
    required StoreRole role,
    required bool bookingEnabled,
    required MemberStatus status,
  }) => _repository.updateStaff(
    storeId,
    staffId,
    displayName: displayName,
    role: role,
    bookingEnabled: bookingEnabled,
    status: status,
  );

  Future<UpdateResult> deactivate(String storeId, String staffId) => _repository.deactivateStaff(storeId, staffId);

  Future<List<StaffServiceAssignment>> assignments(String storeId, String staffId) =>
      _repository.staffAssignments(storeId, staffId);

  Future<UpdateResult> replaceAssignments(String storeId, String staffId, List<StaffServiceAssignment> assignments) =>
      _repository.replaceStaffServices(storeId, staffId, assignments);
}

/// 직원 반복 근무시간
class ManageStaffSchedule {
  const ManageStaffSchedule(this._repository);

  final StoreSettingsRepository _repository;

  Future<List<WeeklySchedule>> load(String storeId, String staffId) async {
    final entries = await _repository.staffSchedules(storeId, staffId);
    return toWeeklySchedules(entries);
  }

  Future<List<StaffScheduleEntry>> entries(String storeId, String staffId) => _repository.staffSchedules(storeId, staffId);

  Future<UpdateResult> save(
    String storeId,
    String staffId,
    List<WeeklySchedule> schedules, {
    required String validFrom,
    String? validUntil,
  }) => _repository.replaceStaffSchedules(storeId, staffId, schedules, validFrom: validFrom, validUntil: validUntil);
}

/// 반복 근무시간 행 목록을 요일별 구간 묶음으로 바꾼다.
List<WeeklySchedule> toWeeklySchedules(List<StaffScheduleEntry> entries) {
  final byDay = <String, List<(String, String)>>{};
  for (final entry in entries) {
    byDay.putIfAbsent(entry.dayOfWeek, () => []).add((entry.start, entry.end));
  }
  return [
    for (final day in dayOfWeekCodes)
      if (byDay[day] != null) WeeklySchedule(dayOfWeek: day, periods: byDay[day]!..sort((a, b) => a.$1.compareTo(b.$1))),
  ];
}

/// 휴무 및 예외 일정 (매장 전체·직원)
class ManageExceptions {
  const ManageExceptions(this._repository);

  final StoreSettingsRepository _repository;

  Future<List<ScheduleException>> store(String storeId) => _repository.storeExceptions(storeId);

  Future<UpdateResult> createForStore(String storeId, ExceptionInput input) =>
      _repository.createStoreException(storeId, input);

  Future<UpdateResult> deleteForStore(String storeId, String exceptionId) =>
      _repository.deleteStoreException(storeId, exceptionId);

  Future<List<ScheduleException>> staff(String storeId, String staffId) => _repository.staffExceptions(storeId, staffId);

  Future<UpdateResult> createForStaff(String storeId, String staffId, ExceptionInput input) =>
      _repository.createStaffException(storeId, staffId, input);

  Future<UpdateResult> deleteForStaff(String storeId, String staffId, String exceptionId) =>
      _repository.deleteStaffException(storeId, staffId, exceptionId);
}

class ManageBusinessHours {
  const ManageBusinessHours(this._repository);

  final StoreSettingsRepository _repository;

  /// 생략된 요일은 휴무로 채워 7일을 모두 돌려준다.
  Future<List<BusinessDay>> load(String storeId) async {
    final days = await _repository.businessHours(storeId);
    return [
      for (final code in dayOfWeekCodes)
        days.where((d) => d.dayOfWeek == code).firstOrNull ?? BusinessDay(dayOfWeek: code, isClosed: true),
    ];
  }

  Future<UpdateResult> save(String storeId, List<BusinessDay> days) => _repository.replaceBusinessHours(storeId, days);
}

class ManagePolicy {
  const ManagePolicy(this._repository);

  final StoreSettingsRepository _repository;

  Future<StorePolicy> load(String storeId) => _repository.getPolicy(storeId);

  Future<StorePolicy> save(String storeId, StorePolicy policy) => _repository.updatePolicy(storeId, policy);
}

import 'package:flutter/foundation.dart';

import '../../../store/domain/store_entities.dart';
import '../../domain/reservation_entities.dart';
import '../../domain/reservation_usecases.dart';

/// 예약 단계(서비스 → 직원 → 시간 → 확인) 사이에 유지되는 선택 정보.
///
/// 단계가 바뀔 때마다 임시 저장해, 로그인이 만료되어도 로그인 후 이어서 진행할 수 있게 한다.
class BookingFlow extends ChangeNotifier {
  BookingFlow({required this.store, required this._drafts});

  final StoreDetail store;
  final BookingDrafts _drafts;

  ServiceItem? service;

  /// null이면 "가능한 직원 누구나"
  StaffOption? staff;
  TimeSlot? slot;
  int partySize = 1;
  String customerNote = '';

  void selectService(ServiceItem value) {
    if (service?.id != value.id) {
      staff = null;
      slot = null;
    }
    service = value;
    _persist();
  }

  void selectStaff(StaffOption? value) {
    if (staff?.id != value?.id) slot = null;
    staff = value;
    _persist();
  }

  void selectSlot(TimeSlot? value) {
    slot = value;
    _persist();
  }

  void clearSlot() => selectSlot(null);

  void updateNote(String value) {
    customerNote = value;
    _persist();
  }

  int get durationMinutes => staff?.customDurationMinutes ?? service?.durationMinutes ?? 0;

  NewReservation toRequest() => NewReservation(
    storeId: store.id,
    serviceId: service!.id,
    staffId: slot!.staffId,
    startAt: slot!.startAtRaw,
    partySize: partySize,
    customerNote: customerNote,
  );

  BookingDraft toDraft() => BookingDraft(
    storeId: store.id,
    storeName: store.name,
    serviceId: service?.id,
    serviceName: service?.name,
    serviceDurationMinutes: service?.durationMinutes,
    staffId: staff?.id,
    staffName: staff?.displayName,
    slotStartAt: slot?.startAtRaw,
    slotStaffId: slot?.staffId,
    partySize: partySize,
    customerNote: customerNote,
  );

  /// 예약이 완료되면 남아 있는 단계 화면이 선택을 바꿔도 임시 정보를 다시 저장하지 않는다.
  bool _finished = false;

  void _persist() {
    if (!_finished) _drafts.save(toDraft());
    notifyListeners();
  }

  Future<void> finish() {
    _finished = true;
    return _drafts.clear();
  }
}

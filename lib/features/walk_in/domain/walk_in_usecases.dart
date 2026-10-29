import '../../../core/domain/statuses.dart';
import 'walk_in_entities.dart';
import 'walk_in_repository.dart';

class RegisterWalkIn {
  const RegisterWalkIn(this._repository);

  final WalkInRepository _repository;

  Future<WalkIn> call(NewWalkIn request, {required String idempotencyKey}) =>
      _repository.register(request, idempotencyKey: idempotencyKey);
}

class GetMyWalkIns {
  const GetMyWalkIns(this._repository);

  final WalkInRepository _repository;

  Future<List<WalkIn>> call({WalkInStatus? status, DateTime? date}) =>
      _repository.listMine(status: status, date: date);
}

class GetWalkInDetail {
  const GetWalkInDetail(this._repository);

  final WalkInRepository _repository;

  Future<WalkIn> call(String walkInId) => _repository.get(walkInId);
}

class CancelWalkIn {
  const CancelWalkIn(this._repository);

  final WalkInRepository _repository;

  Future<void> call(String walkInId, {required String reason, required String idempotencyKey}) =>
      _repository.cancel(walkInId, reason: reason, idempotencyKey: idempotencyKey);
}

class RespondToCall {
  const RespondToCall(this._repository);

  final WalkInRepository _repository;

  Future<WalkIn> call(String walkInId, CallResponse response, {required String idempotencyKey}) =>
      _repository.respondCall(walkInId, response, idempotencyKey: idempotencyKey);
}

/// 매장 QR 또는 직원이 전달한 링크에서 매장 ID를 꺼낸다.
///
/// 지원 형식: `jariyo://stores/{id}/walk-in`, `https://…/stores/{id}…`, `storeId={id}`, 또는 ID 자체.
String? parseStoreIdFromQr(String raw) {
  final value = raw.trim();
  final path = RegExp(r'stores/([0-9a-zA-Z_-]+)').firstMatch(value);
  if (path != null) return path.group(1);
  final query = RegExp(r'storeId=([0-9a-zA-Z_-]+)').firstMatch(value);
  if (query != null) return query.group(1);
  if (RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(value)) {
    return value;
  }
  return null;
}

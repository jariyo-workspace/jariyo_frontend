import '../../../core/domain/statuses.dart';
import 'walk_in_entities.dart';

abstract interface class WalkInRepository {
  Future<WalkIn> register(NewWalkIn request, {required String idempotencyKey});

  Future<List<WalkIn>> listMine({WalkInStatus? status, DateTime? date});

  Future<WalkIn> get(String walkInId);

  Future<void> cancel(String walkInId, {required String reason, required String idempotencyKey});

  Future<WalkIn> respondCall(String walkInId, CallResponse response, {required String idempotencyKey});
}

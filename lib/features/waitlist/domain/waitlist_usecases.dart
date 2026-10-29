import '../../../core/domain/statuses.dart';
import 'waitlist_entities.dart';
import 'waitlist_repository.dart';

class ApplyWaitlist {
  const ApplyWaitlist(this._repository);

  final WaitlistRepository _repository;

  Future<WaitlistEntry> call(NewWaitlist request, {required String idempotencyKey}) =>
      _repository.create(request, idempotencyKey: idempotencyKey);
}

class GetMyWaitlists {
  const GetMyWaitlists(this._repository);

  final WaitlistRepository _repository;

  Future<List<WaitlistEntry>> call({WaitlistStatus? status}) => _repository.listMine(status: status);
}

class GetWaitlistDetail {
  const GetWaitlistDetail(this._repository);

  final WaitlistRepository _repository;

  Future<WaitlistEntry> call(String waitlistId) => _repository.get(waitlistId);
}

class UpdateWaitlist {
  const UpdateWaitlist(this._repository);

  final WaitlistRepository _repository;

  Future<void> call(String waitlistId, WaitlistUpdate update) => _repository.update(waitlistId, update);
}

class CancelWaitlist {
  const CancelWaitlist(this._repository);

  final WaitlistRepository _repository;

  Future<void> call(String waitlistId, {required String reason, required String idempotencyKey}) =>
      _repository.cancel(waitlistId, reason: reason, idempotencyKey: idempotencyKey);
}

class GetMySlotOffers {
  const GetMySlotOffers(this._repository);

  final WaitlistRepository _repository;

  Future<List<SlotOffer>> call({SlotOfferStatus? status}) => _repository.listOffers(status: status);
}

class GetSlotOffer {
  const GetSlotOffer(this._repository);

  final WaitlistRepository _repository;

  Future<SlotOffer> call(String offerId) => _repository.getOffer(offerId);
}

class AcceptSlotOffer {
  const AcceptSlotOffer(this._repository);

  final WaitlistRepository _repository;

  Future<SlotOfferAcceptance> call(String offerId, {required String idempotencyKey}) =>
      _repository.acceptOffer(offerId, idempotencyKey: idempotencyKey);
}

class DeclineSlotOffer {
  const DeclineSlotOffer(this._repository);

  final WaitlistRepository _repository;

  Future<SlotOfferDecline> call(String offerId, {required bool keepWaitlistActive, required String idempotencyKey}) =>
      _repository.declineOffer(offerId, keepWaitlistActive: keepWaitlistActive, idempotencyKey: idempotencyKey);
}

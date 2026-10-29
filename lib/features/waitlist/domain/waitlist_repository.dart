import '../../../core/domain/statuses.dart';
import 'waitlist_entities.dart';

abstract interface class WaitlistRepository {
  Future<WaitlistEntry> create(NewWaitlist request, {required String idempotencyKey});

  Future<List<WaitlistEntry>> listMine({WaitlistStatus? status});

  Future<WaitlistEntry> get(String waitlistId);

  Future<void> update(String waitlistId, WaitlistUpdate update);

  Future<void> cancel(String waitlistId, {required String reason, required String idempotencyKey});

  Future<List<SlotOffer>> listOffers({SlotOfferStatus? status});

  Future<SlotOffer> getOffer(String offerId);

  Future<SlotOfferAcceptance> acceptOffer(String offerId, {required String idempotencyKey});

  Future<SlotOfferDecline> declineOffer(String offerId, {required bool keepWaitlistActive, required String idempotencyKey});
}

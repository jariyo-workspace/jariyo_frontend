import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../../reservation/data/reservation_repository_impl.dart';
import '../../store/domain/store_entities.dart';
import '../../waitlist/data/waitlist_repository_impl.dart';
import '../../walk_in/data/walk_in_repository_impl.dart';
import '../domain/home_entities.dart';
import '../domain/home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  const HomeRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<HomeSummary> fetchHome() async {
    final json = (await _api.get('/me/home')).json;
    final action = asJson(json['priorityAction']);
    final type = PriorityActionType.parse(action['type']);
    return HomeSummary(
      priorityAction: type == null
          ? null
          : PriorityAction(
              type: type,
              referenceId: str(action['referenceId']),
              title: str(action['title']),
              subtitle: strOrNull(action['subtitle'] ?? action['description']),
              expiresAt: timeOrNull(action['expiresAt']),
            ),
      upcomingReservations: asJsonList(json['upcomingReservations']).map(reservationSummaryFromJson).toList(),
      activeWaitlists: asJsonList(json['activeWaitlists']).map(waitlistFromJson).toList(),
      activeWalkIns: asJsonList(json['activeWalkIns']).map(walkInFromJson).toList(),
      recentStores: asJsonList(json['recentStores'])
          .map(
            (s) => RecentStore(
              id: str(s['id'] ?? s['storeId']),
              name: str(s['name'] ?? s['storeName']),
              address: strOrNull(s['address']),
              lastServiceName: strOrNull(s['lastServiceName'] ?? s['serviceName']),
              viewedAt: timeOrNull(s['lastVisitedAt']) ?? DateTime.now(),
            ),
          )
          .toList(),
    );
  }
}

import 'home_entities.dart';

abstract interface class HomeRepository {
  /// `GET /me/home` 통합 홈 상태.
  Future<HomeSummary> fetchHome();
}

import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/env.dart';
import '../core/network/api_client.dart';
import '../core/realtime/realtime_service.dart';
import '../core/realtime/refresh_bus.dart';
import '../core/storage/key_value_store.dart';
import '../core/storage/token_storage.dart';
import '../features/admin/data/admin_insights_repository_impl.dart';
import '../features/admin/data/admin_operation_repository_impl.dart';
import '../features/admin/data/store_settings_repository_impl.dart';
import '../features/admin/domain/admin_repositories.dart';
import '../features/auth/data/auth_remote_data_source.dart';
import '../features/auth/data/auth_repository_impl.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/domain/auth_usecases.dart';
import '../features/home/data/home_repository_impl.dart';
import '../features/home/domain/home_repository.dart';
import '../features/notification/data/notification_repository_impl.dart';
import '../features/notification/domain/notification_repository.dart';
import '../features/reservation/data/reservation_repository_impl.dart';
import '../features/reservation/domain/reservation_repository.dart';
import '../features/store/data/store_reference_cache.dart';
import '../features/store/data/store_repository_impl.dart';
import '../features/store/domain/store_repository.dart';
import '../features/waitlist/data/waitlist_repository_impl.dart';
import '../features/waitlist/domain/waitlist_repository.dart';
import '../features/walk_in/data/walk_in_repository_impl.dart';
import '../features/walk_in/domain/walk_in_repository.dart';
import 'session_controller.dart';

final sl = GetIt.instance;

/// 앱 전역 의존성 구성. 화면은 여기서 등록한 저장소로 유스케이스를 만들어 사용한다.
///
/// 테스트에서는 [httpClient]로 가짜 서버를 주입한다.
Future<void> configureDependencies({http.Client? httpClient}) async {
  final prefs = await SharedPreferences.getInstance();
  final store = KeyValueStore(prefs);
  final tokens = TokenStorage(store);
  final api = ApiClient(httpClient: httpClient ?? http.Client(), baseUrl: Env.apiBaseUrl, tokens: tokens);
  final bus = RefreshBus();
  final realtime = RealtimeService(api: api, bus: bus);
  final references = StoreReferenceCache(api);

  sl
    ..registerSingleton<KeyValueStore>(store)
    ..registerSingleton<TokenStorage>(tokens)
    ..registerSingleton<ApiClient>(api)
    ..registerSingleton<RefreshBus>(bus)
    ..registerSingleton<RealtimeService>(realtime)
    ..registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(AuthRemoteDataSource(api), tokens))
    ..registerLazySingleton<StoreRepository>(() => StoreRepositoryImpl(StoreRemoteDataSource(api), store))
    ..registerLazySingleton<ReservationRepository>(
      () => ReservationRepositoryImpl(ReservationRemoteDataSource(api), store),
    )
    ..registerLazySingleton<WaitlistRepository>(() => WaitlistRepositoryImpl(WaitlistRemoteDataSource(api, references)))
    ..registerLazySingleton<WalkInRepository>(() => WalkInRepositoryImpl(WalkInRemoteDataSource(api, references)))
    ..registerLazySingleton<HomeRepository>(() => HomeRepositoryImpl(api))
    ..registerLazySingleton<NotificationRepository>(() => NotificationRepositoryImpl(api))
    ..registerLazySingleton<AdminOperationRepository>(() => AdminOperationRepositoryImpl(api, store))
    ..registerLazySingleton<StoreSettingsRepository>(() => StoreSettingsRepositoryImpl(api))
    ..registerLazySingleton<AdminInsightsRepository>(() => AdminInsightsRepositoryImpl(api));

  final authRepository = sl<AuthRepository>();
  final session = SessionController(
    getProfile: GetMyProfile(authRepository),
    signOut: SignOut(authRepository),
    hasStoredSession: () => authRepository.hasStoredSession,
    store: store,
    realtime: realtime,
  );
  sl.registerSingleton<SessionController>(session);
  api.onSessionExpired = session.handleSessionExpired;
}

/// 빌드 환경 설정.
///
/// `flutter run --dart-define=API_BASE_URL=https://api.example.com/api/v1` 로 덮어쓸 수 있다.
/// 기본값은 Android 에뮬레이터에서 호스트 PC의 로컬 서버를 가리킨다.
class Env {
  const Env._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );
}

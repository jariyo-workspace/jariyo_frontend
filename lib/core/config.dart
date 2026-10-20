/// 실행 시 `--dart-define=API_BASE_URL=http://<host>:<port>`로 주입한다.
/// 주입하지 않으면 Android 에뮬레이터에서 호스트 PC를 가리키는 주소를 사용한다.
class AppConfig {
  static const String _rawBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  static String get apiBaseUrl {
    final url = _rawBaseUrl.endsWith('/')
        ? _rawBaseUrl.substring(0, _rawBaseUrl.length - 1)
        : _rawBaseUrl;
    return '$url/api/v1';
  }

  static const Duration requestTimeout = Duration(seconds: 10);
  static const Duration snackBarDuration = Duration(seconds: 4);
}

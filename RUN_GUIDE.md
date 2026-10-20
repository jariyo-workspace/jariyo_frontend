# 실행 가이드 (JA1 · 자리요 고객 예약 앱)

## 환경

| 항목 | 버전 |
| --- | --- |
| Flutter | 3.44.1 (stable) |
| Dart | 3.12.1 |
| 외부 패키지 | `http` 만 사용 |
| Android 패키지 이름 | `kr.jariyo.task.a00` (`XX` 배정 후 `android/app/build.gradle.kts` 의 `namespace`·`applicationId` 와 `MainActivity.kt` 경로를 함께 변경) |

## API base URL

- `lib/core/config.dart` 의 `AppConfig` 가 `--dart-define=API_BASE_URL` 값을 읽는다.
- 모든 경로는 `{API_BASE_URL}/api/v1` 로 시작한다.
- 값을 주지 않으면 기본값 `http://10.0.2.2:8080` (Android 에뮬레이터에서 호스트 PC) 을 사용한다.

## 실행

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

## 릴리스 APK 빌드

```bash
flutter build apk --release --dart-define=API_BASE_URL=http://<host>:8080
cp build/app/outputs/flutter-apk/app-release.apk XX_JARIYO.apk
```

## 테스트

```bash
flutter analyze
flutter test
```

## 구조

```
lib/
  core/      설정, 문구(strings_ko.json), 색상·상태 배지(ui_spec.json), 날짜 형식, UUID
  data/      http 클라이언트(세션·토큰 재발급), 모델, 엔드포인트
  ui/        화면 전환(AppNav), 공통 위젯, 화면 5개와 시트 2개
```

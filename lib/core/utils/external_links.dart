import 'package:url_launcher/url_launcher.dart';

import '../navigation/app_navigator.dart';

Future<void> _open(Uri uri, String failureMessage) async {
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) AppMessenger.show(failureMessage);
  } catch (_) {
    AppMessenger.show(failureMessage);
  }
}

/// 매장에 전화
Future<void> callPhone(String? phoneNumber) async {
  final digits = phoneNumber?.replaceAll(RegExp(r'[^0-9+]'), '') ?? '';
  if (digits.isEmpty) {
    AppMessenger.show('매장 전화번호가 등록되어 있지 않아요.');
    return;
  }
  await _open(Uri(scheme: 'tel', path: digits), '전화 앱을 열 수 없어요. $phoneNumber 로 연락해 주세요.');
}

/// 길찾기·매장 위치 보기
Future<void> openMap(String? address, {String? name}) async {
  final query = [name, address].whereType<String>().where((v) => v.isNotEmpty).join(' ');
  if (query.isEmpty) {
    AppMessenger.show('매장 주소가 등록되어 있지 않아요.');
    return;
  }
  await _open(
    Uri.https('map.naver.com', '/p/search/$query'),
    '지도를 열 수 없어요. 주소: ${address ?? '-'}',
  );
}

/// Google 캘린더 일정 추가 화면을 연다.
Future<void> addToCalendar({required String title, required DateTime start, required DateTime end, String? location}) {
  String stamp(DateTime t) {
    final u = t.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${u.year}${two(u.month)}${two(u.day)}T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
  }

  final uri = Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': title,
    'dates': '${stamp(start)}/${stamp(end)}',
    'location': ?location,
  });
  return _open(uri, '캘린더를 열 수 없어요.');
}

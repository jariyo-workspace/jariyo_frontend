import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 로컬 보관이 필요한 작은 값(토큰, 최근 검색어, 예약 임시 정보 등)을 저장한다.
class KeyValueStore {
  KeyValueStore(this._prefs);

  final SharedPreferences _prefs;

  String? getString(String key) => _prefs.getString(key);

  Future<void> setString(String key, String? value) async {
    if (value == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, value);
    }
  }

  List<String> getStringList(String key) => _prefs.getStringList(key) ?? const [];

  Future<void> setStringList(String key, List<String> value) => _prefs.setStringList(key, value);

  Object? getJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  Future<void> setJson(String key, Object? value) =>
      value == null ? _prefs.remove(key) : _prefs.setString(key, jsonEncode(value));

  Future<void> remove(String key) => _prefs.remove(key);
}

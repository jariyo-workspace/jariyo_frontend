import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:jariyo_frontend/model/me.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Core {
  static MethodChannel channel = MethodChannel('channel');
  static toast(message) => channel.invokeMethod('toast', message);

  static late SharedPreferences pref;

  static loadPref() async {
    pref = await SharedPreferences.getInstance();

  }

  static savePref() async {

  }

  static String? accessToken;
  static String? refreshToken;

  static int currentIndex = 0;
  static ValueNotifier<int> updateValue = ValueNotifier(0);
  static update() => updateValue.value += 1;

  static MeModel? me;
}

Client client = Client();

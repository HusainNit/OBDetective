import 'package:shared_preferences/shared_preferences.dart';

class SettingsManager {
  static final SettingsManager _instance = SettingsManager._internal();
  static late SharedPreferences _prefs;

  factory SettingsManager() => _instance;

  SettingsManager._internal();

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Protocol settings
  static String get protocol => _prefs.getString('protocol') ?? 'ATSP0';
  static set protocol(String value) => _prefs.setString('protocol', value);
}

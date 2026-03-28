import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/server_config.dart';

class ConfigService {
  static const String _configKey = 'server_config';
  static const String _localeKey = 'preferred_locale';

  Future<ServerConfig> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_configKey);

      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        return ServerConfig.fromJson(json);
      }
    } catch (_) {}

    return ServerConfig.defaultConfig();
  }

  Future<void> saveConfig(ServerConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(config.toJson());
    await prefs.setString(_configKey, jsonString);
  }

  Future<String> loadPreferredLocaleCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localeCode = prefs.getString(_localeKey);
      if (localeCode == 'ru' || localeCode == 'en') {
        return localeCode!;
      }
    } catch (_) {}

    return 'ru';
  }

  Future<void> savePreferredLocaleCode(String localeCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, localeCode);
  }
}

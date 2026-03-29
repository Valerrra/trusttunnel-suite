import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/server_config.dart';

class ConfigService extends ChangeNotifier {
  static const String _legacyConfigKey = 'server_config';
  static const String _profilesKey = 'server_profiles';
  static const String _activeProfileIdKey = 'active_profile_id';
  static const String _localeKey = 'preferred_locale';

  Future<List<ServerConfig>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_profilesKey);
    if (jsonString != null) {
      try {
        final decoded = jsonDecode(jsonString) as List<dynamic>;
        final profiles = decoded
            .map((item) => ServerConfig.fromJson(item as Map<String, dynamic>))
            .toList();
        if (profiles.isNotEmpty) {
          return profiles;
        }
      } catch (_) {}
    }

    final migrated = await _migrateLegacyConfig(prefs);
    return migrated ?? [ServerConfig.defaultConfig()];
  }

  Future<ServerConfig> loadConfig() async {
    final profiles = await loadProfiles();
    final activeProfileId = await loadActiveProfileId();
    return profiles.firstWhere(
      (profile) => profile.profileId == activeProfileId,
      orElse: () => profiles.first,
    );
  }

  Future<String> loadActiveProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    final activeProfileId = prefs.getString(_activeProfileIdKey);
    if (activeProfileId != null && activeProfileId.isNotEmpty) {
      return activeProfileId;
    }

    final profiles = await loadProfiles();
    return profiles.first.profileId;
  }

  Future<void> saveConfig(ServerConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await loadProfiles();
    final profile = _normalizeProfile(config, fallbackName: config.profileName);
    final index = profiles.indexWhere(
      (item) => item.profileId == profile.profileId,
    );

    if (index >= 0) {
      profiles[index] = profile;
    } else {
      profiles.add(profile);
    }

    await _persistProfiles(
      prefs,
      profiles,
      activeProfileId: profile.profileId,
      removeLegacy: false,
    );
    notifyListeners();
  }

  Future<ServerConfig> saveImportedConfig(ServerConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await loadProfiles();
    final imported = _normalizeProfile(
      config.copyWith(
        profileId: _generateProfileId(),
        profileName: _buildImportedProfileName(config, profiles),
      ),
      fallbackName: config.hostname,
    );

    profiles.add(imported);
    await _persistProfiles(
      prefs,
      profiles,
      activeProfileId: imported.profileId,
      removeLegacy: false,
    );
    notifyListeners();
    return imported;
  }

  Future<void> setActiveProfile(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProfileIdKey, profileId);
    notifyListeners();
  }

  Future<void> deleteProfile(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final profiles = await loadProfiles();
    if (profiles.length <= 1) {
      return;
    }

    final filtered = profiles
        .where((profile) => profile.profileId != profileId)
        .toList();
    final activeProfileId = prefs.getString(_activeProfileIdKey);
    final nextActiveProfileId = activeProfileId == profileId
        ? filtered.first.profileId
        : activeProfileId;

    await _persistProfiles(
      prefs,
      filtered,
      activeProfileId: nextActiveProfileId,
      removeLegacy: false,
    );
    notifyListeners();
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

  Future<List<ServerConfig>?> _migrateLegacyConfig(
    SharedPreferences prefs,
  ) async {
    final jsonString = prefs.getString(_legacyConfigKey);
    if (jsonString == null) {
      return null;
    }

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final migrated = _normalizeProfile(
        ServerConfig.fromJson(json).copyWith(
          profileId: _generateProfileId(),
          profileName: 'Primary',
        ),
        fallbackName: 'Primary',
      );

      final profiles = [migrated];
      await _persistProfiles(
        prefs,
        profiles,
        activeProfileId: migrated.profileId,
        removeLegacy: true,
      );
      return profiles;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistProfiles(
    SharedPreferences prefs,
    List<ServerConfig> profiles, {
    required String? activeProfileId,
    required bool removeLegacy,
  }) async {
    final encoded = jsonEncode(profiles.map((profile) => profile.toJson()).toList());
    await prefs.setString(_profilesKey, encoded);
    if (activeProfileId != null && activeProfileId.isNotEmpty) {
      await prefs.setString(_activeProfileIdKey, activeProfileId);
    }
    if (removeLegacy) {
      await prefs.remove(_legacyConfigKey);
    }
  }

  ServerConfig _normalizeProfile(
    ServerConfig config, {
    required String fallbackName,
  }) {
    final trimmedName = config.profileName.trim();
    final profileName = trimmedName.isEmpty ? fallbackName : trimmedName;
    final profileId = config.profileId.trim().isEmpty
        ? _generateProfileId()
        : config.profileId;
    return config.copyWith(profileId: profileId, profileName: profileName);
  }

  String _buildImportedProfileName(
    ServerConfig config,
    List<ServerConfig> profiles,
  ) {
    final baseName = config.hostname.trim().isEmpty
        ? 'Imported'
        : config.hostname.trim();
    final existingNames = profiles.map((profile) => profile.profileName).toSet();
    if (!existingNames.contains(baseName)) {
      return baseName;
    }

    var suffix = 2;
    while (existingNames.contains('$baseName $suffix')) {
      suffix++;
    }
    return '$baseName $suffix';
  }

  String _generateProfileId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }
}

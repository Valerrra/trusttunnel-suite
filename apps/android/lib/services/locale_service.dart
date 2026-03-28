import 'package:flutter/material.dart';

import 'config_service.dart';

class LocaleService extends ChangeNotifier {
  final ConfigService _configService;
  Locale _locale = const Locale('ru');

  LocaleService(this._configService) {
    _loadPreferredLocale();
  }

  Locale get locale => _locale;
  String get localeCode => _locale.languageCode;

  Future<void> _loadPreferredLocale() async {
    final localeCode = await _configService.loadPreferredLocaleCode();
    final locale = Locale(localeCode);
    if (_locale == locale) {
      return;
    }

    _locale = locale;
    notifyListeners();
  }

  Future<void> setLocaleCode(String localeCode) async {
    if (localeCode != 'ru' && localeCode != 'en') {
      throw ArgumentError('Unsupported locale code: $localeCode');
    }

    if (_locale.languageCode == localeCode) {
      return;
    }

    await _configService.savePreferredLocaleCode(localeCode);
    _locale = Locale(localeCode);
    notifyListeners();
  }
}

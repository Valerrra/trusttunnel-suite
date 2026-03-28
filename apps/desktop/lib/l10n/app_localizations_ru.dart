// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Trusty VPN';

  @override
  String get singleInstanceTitle => 'Trusty VPN уже запущен';

  @override
  String get singleInstanceMessage =>
      'Приложение уже открыто.\nПроверьте системный трей или панель задач.';

  @override
  String get singleInstanceClosing => 'Это окно закроется через 5 секунд...';

  @override
  String get trayShowWindow => 'Показать окно';

  @override
  String get trayConnect => 'Подключить';

  @override
  String get trayDisconnect => 'Отключить';

  @override
  String get trayExit => 'Выход';

  @override
  String get trayTooltip => 'Trusty VPN';

  @override
  String get dialogCloseTitle => 'Закрыть приложение?';

  @override
  String get dialogCloseMessage =>
      'Выйти из приложения или свернуть его в трей?\n\nЕсли VPN подключен, при выходе он будет отключен.';

  @override
  String get dialogCloseMinimize => 'Свернуть в трей';

  @override
  String get dialogCloseExit => 'Выйти';

  @override
  String get navHome => 'Главная';

  @override
  String get navSettings => 'Настройки';

  @override
  String get navSplitTunnel => 'Сплит-туннель';

  @override
  String get navLogs => 'Логи';

  @override
  String get navServer => 'Сервер';

  @override
  String get vpnStatusDisconnected => 'Отключено';

  @override
  String get vpnStatusConnecting => 'Подключение...';

  @override
  String get vpnStatusConnected => 'Подключено';

  @override
  String get vpnStatusDisconnecting => 'Отключение...';

  @override
  String get vpnStatusError => 'Ошибка';

  @override
  String get setupStepIdle => 'Готово к установке';

  @override
  String get setupStepConnecting => 'Подключение по SSH...';

  @override
  String get setupStepCheckingSystem => 'Проверка системы...';

  @override
  String get setupStepInstalling => 'Установка Trusty...';

  @override
  String get setupStepConfiguringServer => 'Настройка сервера...';

  @override
  String get setupStepObtainingCertificate => 'Получение сертификата...';

  @override
  String get setupStepStartingService => 'Запуск сервиса...';

  @override
  String get setupStepVerifying => 'Проверка...';

  @override
  String get setupStepCompleted => 'Установка завершена';

  @override
  String get setupStepFailed => 'Установка не удалась';

  @override
  String get configErrorHostnameEmpty =>
      'Hostname пуст. Проверьте настройки сервера.';

  @override
  String get configErrorAddressEmpty =>
      'Адрес пуст. Проверьте настройки сервера.';

  @override
  String get configErrorUsernameEmpty =>
      'Имя пользователя пусто. Проверьте настройки сервера.';

  @override
  String get homePleaseWait => 'Пожалуйста, подождите...';

  @override
  String get homeDisconnect => 'Отключить';

  @override
  String get homeConnect => 'Подключить';

  @override
  String get homeInfoTitle => 'Информация';

  @override
  String get homeInfoLine1 => 'Настройте сервер на вкладке «Настройки»';

  @override
  String get homeInfoLineClientWindows =>
      'Убедитесь, что `trusttunnel_client.exe` лежит в каталоге client/';

  @override
  String get homeInfoLineClientOther =>
      'Убедитесь, что `trusttunnel_client` лежит в каталоге client/';

  @override
  String get homeInfoLine3 => 'Логи подключения доступны на вкладке «Логи»';

  @override
  String homeError(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get logsTitle => 'Логи подключения';

  @override
  String get logsAutoScrollEnabled => 'Автопрокрутка включена';

  @override
  String get logsAutoScrollDisabled => 'Автопрокрутка отключена';

  @override
  String get logsCopy => 'Копировать логи';

  @override
  String get logsClear => 'Очистить логи';

  @override
  String logsTotalEntries(int count) {
    return 'Всего записей: $count';
  }

  @override
  String get logsEmpty => 'Логи пусты';

  @override
  String get logsConnectToSee => 'Подключитесь к VPN, чтобы увидеть логи';

  @override
  String get logsClearTitle => 'Очистить логи?';

  @override
  String get logsClearMessage =>
      'Все записи логов будут удалены. Это действие нельзя отменить.';

  @override
  String get logsCopied => 'Логи скопированы в буфер обмена';

  @override
  String get logsCleared => 'Логи очищены';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonClear => 'Очистить';

  @override
  String get commonAdd => 'Добавить';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get commonDelete => 'Удалить';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Русский';

  @override
  String get settingsSectionApp => 'Приложение';

  @override
  String get settingsLanguage => 'Язык';

  @override
  String get settingsAutoStartWithWindows => 'Автозагрузка при старте Windows';

  @override
  String get settingsAutoStartWithWindowsHint =>
      'Добавляет Trusty в автозагрузку Windows.';

  @override
  String get settingsAutoConnectOnLaunch => 'Автоподключение при старте';

  @override
  String get settingsAutoConnectOnLaunchHint =>
      'Автоматически подключать VPN при запуске приложения.';

  @override
  String get settingsLaunchMinimized => 'Запускать свернутым';

  @override
  String get settingsLaunchMinimizedHint =>
      'Стартовать скрытым в трее вместо открытия главного окна.';

  @override
  String get settingsWarningConnected =>
      'Отключитесь от VPN перед изменением настроек';

  @override
  String get settingsSectionServer => 'Сервер';

  @override
  String get settingsImportSection => 'Быстрый импорт';

  @override
  String get settingsImportHint =>
      'Импортируйте TrustTunnel-ссылку `tt://` и заполните настройки автоматически.';

  @override
  String get settingsImportFromClipboard => 'Импорт из буфера';

  @override
  String get settingsImportPasteLink => 'Вставить `tt://` ссылку';

  @override
  String get settingsImportDialogTitle => 'Вставьте TrustTunnel-ссылку';

  @override
  String get settingsImportDialogHint => 'tt://?AQ...';

  @override
  String get settingsImportPreviewTitle => 'Предпросмотр импорта';

  @override
  String get settingsImportConfirm => 'Импортировать';

  @override
  String get settingsImported => 'Конфигурация импортирована';

  @override
  String get settingsImportClipboardEmpty =>
      'В буфере обмена нет `tt://` ссылки';

  @override
  String settingsImportError(String error) {
    return 'Ошибка импорта: $error';
  }

  @override
  String get settingsHostname => 'Hostname';

  @override
  String get settingsHostnameError => 'Введите hostname';

  @override
  String get settingsAddress => 'IP-адрес';

  @override
  String get settingsAddressError => 'Введите IP-адрес';

  @override
  String get settingsPort => 'Порт';

  @override
  String get settingsPortErrorEmpty => 'Введите порт';

  @override
  String get settingsPortErrorInvalid => 'Некорректный порт';

  @override
  String get settingsSectionAuth => 'Авторизация';

  @override
  String get settingsUsername => 'Имя пользователя';

  @override
  String get settingsUsernameError => 'Введите имя пользователя';

  @override
  String get settingsPassword => 'Пароль';

  @override
  String get settingsPasswordError => 'Введите пароль';

  @override
  String get settingsSectionNetwork => 'Сеть';

  @override
  String get settingsDns => 'DNS-сервер';

  @override
  String get settingsDnsError => 'Введите DNS-сервер';

  @override
  String get settingsProtocol => 'Протокол';

  @override
  String get settingsLogLevel => 'Уровень логов';

  @override
  String get settingsSectionAdvanced => 'Дополнительно';

  @override
  String get settingsIpv6 => 'Поддержка IPv6';

  @override
  String get settingsSkipVerification => 'Пропуск проверки сертификата';

  @override
  String get settingsAntiDpi => 'Anti-DPI';

  @override
  String get settingsCustomSni => 'Custom SNI (необязательно)';

  @override
  String get settingsSave => 'Сохранить настройки';

  @override
  String get settingsSaved => 'Настройки сохранены';

  @override
  String settingsSaveError(String error) {
    return 'Ошибка сохранения: $error';
  }

  @override
  String get splitTunnelWarningConnected =>
      'Отключитесь от VPN перед изменением настроек';

  @override
  String get splitTunnelVpnMode => 'Режим VPN';

  @override
  String get splitTunnelModeGeneralTitle => 'Весь трафик через VPN';

  @override
  String get splitTunnelModeGeneralSubtitle =>
      'Исключения не будут идти через VPN';

  @override
  String get splitTunnelModeSelectiveTitle =>
      'Только выбранный трафик через VPN';

  @override
  String get splitTunnelModeSelectiveSubtitle =>
      'Через VPN идут только указанные домены и приложения';

  @override
  String splitTunnelDomainsTab(int count) {
    return 'Домены ($count)';
  }

  @override
  String splitTunnelAppsTab(int count) {
    return 'Приложения ($count)';
  }

  @override
  String get splitTunnelAutoSave => 'Настройки сохраняются автоматически';

  @override
  String get splitTunnelDomainsExclude =>
      'Домены, которые НЕ будут идти через VPN:';

  @override
  String get splitTunnelDomainsInclude =>
      'Домены, которые БУДУТ идти через VPN:';

  @override
  String get splitTunnelDomainsHint =>
      'Домены (google.com), IP (8.8.8.8), CIDR (10.0.0.0/8)';

  @override
  String get splitTunnelDomainsInputHint => 'Введите домен, IP или CIDR';

  @override
  String get splitTunnelNoDomains => 'Домены не добавлены';

  @override
  String get splitTunnelOther => 'Другое';

  @override
  String splitTunnelAddToGroup(String groupName) {
    return 'Добавить домен в «$groupName»';
  }

  @override
  String get splitTunnelEnterDomain => 'Введите домен';

  @override
  String get splitTunnelRenameGroup => 'Переименовать группу';

  @override
  String get splitTunnelGroupName => 'Название группы';

  @override
  String get splitTunnelDeleteGroupTitle => 'Удалить группу?';

  @override
  String splitTunnelDeleteGroupMessage(String groupName) {
    return 'Группа «$groupName» и все её домены будут удалены.';
  }

  @override
  String splitTunnelDomainCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# домена',
      many: '# доменов',
      few: '# домена',
      one: '# домен',
      zero: '0 доменов',
    );
    return '$_temp0';
  }

  @override
  String get splitTunnelSuggestionTitle =>
      'Обнаружено в логах: добавить в исключения?';

  @override
  String get splitTunnelSuggestionAddToGroup => 'Добавить в группу';

  @override
  String get splitTunnelSuggestionAddStandalone => 'Добавить отдельно';

  @override
  String get splitTunnelSuggestionHide => 'Скрыть';

  @override
  String get splitTunnelDomainAlreadyAdded => 'Этот домен уже добавлен';

  @override
  String splitTunnelSaveError(String error) {
    return 'Ошибка сохранения: $error';
  }

  @override
  String get splitTunnelAppsExclude =>
      'Приложения, которые НЕ будут использовать VPN:';

  @override
  String get splitTunnelAppsInclude =>
      'Приложения, которые БУДУТ использовать VPN:';

  @override
  String get splitTunnelSearchApps => 'Поиск приложений...';

  @override
  String get splitTunnelNoApps => 'Приложения не найдены';

  @override
  String splitTunnelSelectedApps(int count) {
    return 'Выбрано приложений: $count';
  }

  @override
  String splitTunnelToGroup(String groupName) {
    return 'В «$groupName»';
  }

  @override
  String discoveryTitle(String domain) {
    return 'Добавить $domain';
  }

  @override
  String get discoverySearching => 'Поиск связанных доменов...';

  @override
  String get discoveryRelatedFound => 'Найдены связанные домены:';

  @override
  String get discoveryGroupName => 'Название группы';

  @override
  String get discoveryNoRelated => 'Связанные домены не найдены.';

  @override
  String get discoveryAddStandalone => 'Домен будет добавлен отдельно.';

  @override
  String get discoveryWithoutGroup => 'Без группы';

  @override
  String get discoveryAddGroup => 'Добавить группу';

  @override
  String get serverInfoBanner =>
      'Установка сервера TrustTunnel на удалённый VPS. Нужен VPS с Linux (Ubuntu/Debian), домен и SSH-доступ (root).';

  @override
  String get serverSectionSsh => 'SSH-подключение';

  @override
  String get serverVpsIp => 'IP-адрес VPS';

  @override
  String get serverVpsIpError => 'Введите IP-адрес';

  @override
  String get serverSshPort => 'SSH-порт';

  @override
  String get serverSshUser => 'Пользователь';

  @override
  String get serverSshPassword => 'SSH-пароль';

  @override
  String get serverSshPasswordError => 'Введите пароль';

  @override
  String get serverSshKeyPath => 'Путь к SSH-ключу';

  @override
  String get serverSshKeyPathError => 'Введите путь к ключу';

  @override
  String get serverAuthPassword => 'Пароль';

  @override
  String get serverAuthKey => 'SSH-ключ';

  @override
  String get serverSectionDomain => 'Домен и сертификат';

  @override
  String get serverDomain => 'Домен';

  @override
  String get serverDomainError => 'Введите домен';

  @override
  String get serverDomainHint =>
      'Домен должен указывать на IP сервера (A-запись в DNS)';

  @override
  String get serverEmail => 'Email (Let\'s Encrypt)';

  @override
  String get serverEmailError => 'Введите email';

  @override
  String get serverSectionVpnAccount => 'VPN-аккаунт';

  @override
  String get serverVpnUsername => 'VPN-пользователь';

  @override
  String get serverVpnUsernameError => 'Введите имя пользователя';

  @override
  String get serverVpnPassword => 'VPN-пароль';

  @override
  String get serverVpnPasswordError => 'Введите пароль';

  @override
  String get serverGeneratePassword => 'Сгенерировать пароль';

  @override
  String get serverInstallButton => 'Установить сервер';

  @override
  String get serverInstalling => 'Установка...';

  @override
  String get serverInstallLog => 'Журнал установки';

  @override
  String get serverLogEmpty => 'Журнал пуст';

  @override
  String get serverInstalled => 'Сервер установлен и запущен';

  @override
  String serverSuccessInfo(String domain, String port, String username) {
    return 'Домен: $domain\nПорт: $port\nVPN-пользователь: $username';
  }

  @override
  String get serverApplySettings => 'Применить настройки клиента';

  @override
  String get serverSettingsApplied => 'Настройки клиента обновлены';

  @override
  String serverError(String error) {
    return 'Ошибка: $error';
  }
}

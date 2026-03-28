import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/server_config.dart';
import '../models/vpn_status.dart';
import '../screens/qr_scanner_screen.dart';
import '../services/config_service.dart';
import '../services/locale_service.dart';
import '../services/trusttunnel_deep_link_service.dart';
import '../services/vpn_service.dart';
import '../widgets/trusttunnel_import_flow.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _hostnameController;
  late final TextEditingController _addressController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _dnsController;
  late final TextEditingController _customSniController;

  final TrustTunnelDeepLinkService _deepLinkService =
      TrustTunnelDeepLinkService();

  bool _hasIpv6 = true;
  bool _skipVerification = false;
  bool _antiDpi = false;
  bool _passwordVisible = false;
  bool _isLoading = true;
  String _upstreamProtocol = 'http2';
  String _logLevel = 'info';
  ServerConfig _currentConfig = ServerConfig.defaultConfig();

  @override
  void initState() {
    super.initState();
    _hostnameController = TextEditingController();
    _addressController = TextEditingController();
    _portController = TextEditingController();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _dnsController = TextEditingController();
    _customSniController = TextEditingController();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await context.read<ConfigService>().loadConfig();
    if (!mounted) {
      return;
    }

    setState(() {
      _currentConfig = config;
      _applyConfigToForm(config);
      _isLoading = false;
    });
  }

  void _applyConfigToForm(ServerConfig config) {
    _hostnameController.text = config.hostname;
    _addressController.text = config.address;
    _portController.text = config.port.toString();
    _usernameController.text = config.username;
    _passwordController.text = config.password;
    _dnsController.text = config.dns;
    _customSniController.text = config.customSni;
    _hasIpv6 = config.hasIpv6;
    _skipVerification = config.skipVerification;
    _antiDpi = config.antiDpi;
    _upstreamProtocol = config.upstreamProtocol;
    _logLevel = config.logLevel;
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final config = _currentConfig.copyWith(
      hostname: _hostnameController.text.trim(),
      address: _addressController.text.trim(),
      port: int.parse(_portController.text.trim()),
      hasIpv6: _hasIpv6,
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      skipVerification: _skipVerification,
      upstreamProtocol: _upstreamProtocol,
      antiDpi: _antiDpi,
      dns: _dnsController.text.trim(),
      logLevel: _logLevel,
      customSni: _customSniController.text.trim(),
    );

    await context.read<ConfigService>().saveConfig(config);
    _currentConfig = config;

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.settingsSaved),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _importFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text?.trim() ?? '';

    if (!_deepLinkService.looksLikeDeepLink(text)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.settingsImportClipboardEmpty,
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await _importDeepLink(text);
  }

  Future<void> _showPasteImportDialog() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final clipboardText = clipboardData?.text?.trim() ?? '';
    if (!mounted) {
      return;
    }

    final deepLink = await TrustTunnelImportFlow.promptForDeepLink(
      context,
      initialValue: _deepLinkService.looksLikeDeepLink(clipboardText)
          ? clipboardText
          : '',
    );
    if (deepLink == null || deepLink.isEmpty) {
      return;
    }

    await _importDeepLink(deepLink);
  }

  Future<void> _scanQrImport() async {
    final deepLink = await QrScannerScreen.show(context);
    if (deepLink == null || deepLink.isEmpty || !mounted) {
      return;
    }

    if (!_deepLinkService.looksLikeDeepLink(deepLink)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.settingsImportQrInvalid),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await _importDeepLink(deepLink);
  }

  Future<void> _importDeepLink(String deepLink) async {
    final imported = await TrustTunnelImportFlow.importDeepLink(
      context,
      deepLink: deepLink,
      baseConfig: _currentConfig,
    );
    if (imported == null || !mounted) {
      return;
    }

    setState(() {
      _currentConfig = imported;
      _applyConfigToForm(imported);
    });
  }

  @override
  void dispose() {
    _hostnameController.dispose();
    _addressController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _dnsController.dispose();
    _customSniController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<VpnService, VpnStatus>(
      selector: (_, vpn) => vpn.status,
      builder: (context, status, child) {
        final localeService = context.watch<LocaleService>();
        final isConnected = status.isActive;
        if (_isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isConnected) _buildWarning(context),
                  _buildSectionTitle(
                    context,
                    AppLocalizations.of(context)!.settingsImportSection,
                  ),
                  _buildImportCard(context, isConnected),
                  const SizedBox(height: 20),
                  _buildSectionTitle(
                    context,
                    AppLocalizations.of(context)!.settingsSectionApp,
                  ),
                  _buildDropdown(
                    value: localeService.localeCode,
                    label: AppLocalizations.of(context)!.settingsLanguage,
                    icon: Icons.language,
                    items: const ['ru', 'en'],
                    itemLabels: {
                      'ru': AppLocalizations.of(context)!.languageRussian,
                      'en': AppLocalizations.of(context)!.languageEnglish,
                    },
                    onChanged: (value) async {
                      if (value == null) {
                        return;
                      }
                      await context.read<LocaleService>().setLocaleCode(value);
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle(
                    context,
                    AppLocalizations.of(context)!.settingsSectionServer,
                  ),
                  _buildTextField(
                    controller: _hostnameController,
                    label: AppLocalizations.of(context)!.settingsHostname,
                    icon: Icons.dns,
                    enabled: !isConnected,
                    validator: (value) => value?.isEmpty ?? true
                        ? AppLocalizations.of(context)!.settingsHostnameError
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _addressController,
                    label: AppLocalizations.of(context)!.settingsAddress,
                    icon: Icons.public,
                    enabled: !isConnected,
                    validator: (value) => value?.isEmpty ?? true
                        ? AppLocalizations.of(context)!.settingsAddressError
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _portController,
                    label: AppLocalizations.of(context)!.settingsPort,
                    icon: Icons.pin,
                    enabled: !isConnected,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return AppLocalizations.of(
                          context,
                        )!.settingsPortErrorEmpty;
                      }
                      final port = int.tryParse(value!);
                      if (port == null || port < 1 || port > 65535) {
                        return AppLocalizations.of(
                          context,
                        )!.settingsPortErrorInvalid;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle(
                    context,
                    AppLocalizations.of(context)!.settingsSectionAuth,
                  ),
                  _buildTextField(
                    controller: _usernameController,
                    label: AppLocalizations.of(context)!.settingsUsername,
                    icon: Icons.person,
                    enabled: !isConnected,
                    validator: (value) => value?.isEmpty ?? true
                        ? AppLocalizations.of(context)!.settingsUsernameError
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _passwordController,
                    label: AppLocalizations.of(context)!.settingsPassword,
                    icon: Icons.lock,
                    enabled: !isConnected,
                    obscureText: !_passwordVisible,
                    validator: (value) => value?.isEmpty ?? true
                        ? AppLocalizations.of(context)!.settingsPasswordError
                        : null,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _passwordVisible = !_passwordVisible;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle(
                    context,
                    AppLocalizations.of(context)!.settingsSectionNetwork,
                  ),
                  _buildTextField(
                    controller: _dnsController,
                    label: AppLocalizations.of(context)!.settingsDns,
                    icon: Icons.router,
                    enabled: !isConnected,
                    validator: (value) => value?.isEmpty ?? true
                        ? AppLocalizations.of(context)!.settingsDnsError
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown(
                    value: _upstreamProtocol,
                    label: AppLocalizations.of(context)!.settingsProtocol,
                    icon: Icons.settings_ethernet,
                    enabled: !isConnected,
                    items: const ['http2', 'http3'],
                    onChanged: (value) {
                      setState(() {
                        _upstreamProtocol = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildDropdown(
                    value: _logLevel,
                    label: AppLocalizations.of(context)!.settingsLogLevel,
                    icon: Icons.bug_report,
                    enabled: !isConnected,
                    items: const ['error', 'warn', 'info', 'debug', 'trace'],
                    onChanged: (value) {
                      setState(() {
                        _logLevel = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle(
                    context,
                    AppLocalizations.of(context)!.settingsSectionAdvanced,
                  ),
                  _buildSwitch(
                    title: AppLocalizations.of(context)!.settingsIpv6,
                    value: _hasIpv6,
                    enabled: !isConnected,
                    onChanged: (value) {
                      setState(() {
                        _hasIpv6 = value;
                      });
                    },
                  ),
                  _buildSwitch(
                    title: AppLocalizations.of(
                      context,
                    )!.settingsSkipVerification,
                    value: _skipVerification,
                    enabled: !isConnected,
                    onChanged: (value) {
                      setState(() {
                        _skipVerification = value;
                      });
                    },
                  ),
                  _buildSwitch(
                    title: AppLocalizations.of(context)!.settingsAntiDpi,
                    value: _antiDpi,
                    enabled: !isConnected,
                    onChanged: (value) {
                      setState(() {
                        _antiDpi = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _customSniController,
                    label: AppLocalizations.of(context)!.settingsCustomSni,
                    icon: Icons.security,
                    enabled: !isConnected,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: isConnected ? null : _saveConfig,
                      icon: const Icon(Icons.save),
                      label: Text(AppLocalizations.of(context)!.settingsSave),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWarning(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.settingsWarningConnected,
              style: const TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportCard(BuildContext context, bool isConnected) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.settingsImportHint),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: isConnected ? null : _importFromClipboard,
            icon: const Icon(Icons.content_paste_go),
            label: Text(
              AppLocalizations.of(context)!.settingsImportFromClipboard,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: isConnected ? null : _scanQrImport,
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(AppLocalizations.of(context)!.settingsImportScanQr),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: isConnected ? null : _showPasteImportDialog,
            icon: const Icon(Icons.link),
            label: Text(AppLocalizations.of(context)!.settingsImportPasteLink),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required String label,
    required IconData icon,
    required List<String> items,
    required void Function(String?) onChanged,
    Map<String, String>? itemLabels,
    bool enabled = true,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(itemLabels?[item] ?? item),
        );
      }).toList(),
      onChanged: enabled ? onChanged : null,
    );
  }

  Widget _buildSwitch({
    required String title,
    required bool value,
    required void Function(bool) onChanged,
    bool enabled = true,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }
}

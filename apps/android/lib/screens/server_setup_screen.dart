import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/server_setup_config.dart';
import '../models/setup_step.dart';
import '../services/config_service.dart';
import '../services/server_setup_service.dart';

class ServerSetupScreen extends StatefulWidget {
  const ServerSetupScreen({super.key});

  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  late final TextEditingController _hostController;
  late final TextEditingController _sshPortController;
  late final TextEditingController _sshUserController;
  late final TextEditingController _sshPasswordController;
  late final TextEditingController _domainController;
  late final TextEditingController _emailController;
  late final TextEditingController _listenPortController;
  late final TextEditingController _vpnUsernameController;
  late final TextEditingController _vpnPasswordController;

  bool _sshPasswordVisible = false;
  bool _vpnPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController();
    _sshPortController = TextEditingController(text: '22');
    _sshUserController = TextEditingController(text: 'root');
    _sshPasswordController = TextEditingController();
    _domainController = TextEditingController();
    _emailController = TextEditingController();
    _listenPortController = TextEditingController(text: '443');
    _vpnUsernameController = TextEditingController();
    _vpnPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _hostController.dispose();
    _sshPortController.dispose();
    _sshUserController.dispose();
    _sshPasswordController.dispose();
    _domainController.dispose();
    _emailController.dispose();
    _listenPortController.dispose();
    _vpnUsernameController.dispose();
    _vpnPasswordController.dispose();
    super.dispose();
  }

  String _generatePassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%^&*';
    final rng = Random.secure();
    return List.generate(16, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  ServerSetupConfig _buildConfig() {
    return ServerSetupConfig(
      host: _hostController.text.trim(),
      sshPort: int.tryParse(_sshPortController.text.trim()) ?? 22,
      sshUsername: _sshUserController.text.trim(),
      sshPassword: _sshPasswordController.text,
      domain: _domainController.text.trim(),
      email: _emailController.text.trim(),
      listenPort: int.tryParse(_listenPortController.text.trim()) ?? 443,
      vpnUsername: _vpnUsernameController.text.trim(),
      vpnPassword: _vpnPasswordController.text,
    );
  }

  Future<void> _startInstallation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final service = context.read<ServerSetupService>();
    await service.installAndRemember(_buildConfig());
  }

  Future<void> _applyToClient() async {
    final setupService = context.read<ServerSetupService>();
    final configService = context.read<ConfigService>();

    try {
      await setupService.applyToClientConfig(configService);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.serverSettingsApplied),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.serverError(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServerSetupService>(
      builder: (context, service, child) {
        final tr = AppLocalizations.of(context)!;
        final isRunning = service.currentStep.isInProgress;

        return ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            _buildInfoBanner(context),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(context, tr.serverSectionSsh),
                  _buildTextField(
                    controller: _hostController,
                    label: tr.serverVpsIp,
                    icon: Icons.computer,
                    enabled: !isRunning,
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return tr.serverVpsIpError;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          controller: _sshUserController,
                          label: tr.serverSshUser,
                          icon: Icons.person,
                          enabled: !isRunning,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _sshPortController,
                          label: tr.serverSshPort,
                          icon: Icons.pin,
                          enabled: !isRunning,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _sshPasswordController,
                    label: tr.serverSshPassword,
                    icon: Icons.lock,
                    enabled: !isRunning,
                    obscureText: !_sshPasswordVisible,
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return tr.serverSshPasswordError;
                      }
                      return null;
                    },
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _sshPasswordVisible = !_sshPasswordVisible;
                        });
                      },
                      icon: Icon(
                        _sshPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle(context, tr.serverSectionDomain),
                  _buildTextField(
                    controller: _domainController,
                    label: tr.serverDomain,
                    icon: Icons.language,
                    enabled: !isRunning,
                    hintText: 'vpn.example.com',
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return tr.serverDomainError;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      tr.serverDomainHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          controller: _emailController,
                          label: tr.serverEmail,
                          icon: Icons.email,
                          enabled: !isRunning,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value?.trim().isEmpty ?? true) {
                              return tr.serverEmailError;
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _listenPortController,
                          label: tr.settingsPort,
                          icon: Icons.pin,
                          enabled: !isRunning,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle(context, tr.serverSectionVpnAccount),
                  _buildTextField(
                    controller: _vpnUsernameController,
                    label: tr.serverVpnUsername,
                    icon: Icons.person_outline,
                    enabled: !isRunning,
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return tr.serverVpnUsernameError;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _vpnPasswordController,
                          label: tr.serverVpnPassword,
                          icon: Icons.lock_outline,
                          enabled: !isRunning,
                          obscureText: !_vpnPasswordVisible,
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return tr.serverVpnPasswordError;
                            }
                            return null;
                          },
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _vpnPasswordVisible = !_vpnPasswordVisible;
                              });
                            },
                            icon: Icon(
                              _vpnPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: isRunning
                            ? null
                            : () {
                                setState(() {
                                  _vpnPasswordController.text =
                                      _generatePassword();
                                  _vpnPasswordVisible = true;
                                });
                              },
                        tooltip: tr.serverGeneratePassword,
                        icon: const Icon(Icons.casino),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: isRunning ? null : _startInstallation,
                      icon: Icon(
                        isRunning ? Icons.hourglass_top : Icons.rocket_launch,
                      ),
                      label: Text(
                        isRunning ? tr.serverInstalling : tr.serverInstallButton,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (service.currentStep != SetupStep.idle) ...[
              const SizedBox(height: 24),
              _buildProgressSection(context, service),
              const SizedBox(height: 16),
              _buildLogSection(context, service),
            ],
            if (service.currentStep == SetupStep.completed) ...[
              const SizedBox(height: 16),
              _buildSuccessCard(context),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _applyToClient,
                  icon: const Icon(Icons.download_done),
                  label: Text(tr.serverApplySettings),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildInfoBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.serverInfoBanner,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
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

  Widget _buildProgressSection(
    BuildContext context,
    ServerSetupService service,
  ) {
    final currentIndex = service.currentStep.stepIndex;
    final progress = currentIndex < 0 ? 0.0 : (currentIndex + 1) / 7;
    final steps = [
      SetupStep.connecting,
      SetupStep.checkingSystem,
      SetupStep.installing,
      SetupStep.configuringServer,
      SetupStep.obtainingCertificate,
      SetupStep.startingService,
      SetupStep.verifying,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(service.currentStep.icon, color: service.currentStep.color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  service.currentStep.displayText,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: service.currentStep.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: progress == 0 ? null : progress),
          const SizedBox(height: 14),
          ...steps.map((step) => _buildStepRow(service, step)),
          if (service.errorMessage != null) ...[
            const SizedBox(height: 14),
            SelectableText(
              service.errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepRow(ServerSetupService service, SetupStep step) {
    final currentIndex = service.currentStep.stepIndex;
    final stepIndex = step.stepIndex;

    final bool isDone =
        stepIndex < currentIndex || service.currentStep == SetupStep.completed;
    final bool isCurrent = stepIndex == currentIndex;

    final icon = isDone
        ? Icons.check_circle
        : isCurrent
        ? Icons.radio_button_checked
        : Icons.radio_button_unchecked;
    final color = isDone
        ? Colors.green
        : isCurrent
        ? Colors.orange
        : Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              step.displayText.replaceAll('...', ''),
              style: TextStyle(
                color: color,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogSection(BuildContext context, ServerSetupService service) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.serverInstallLog,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 140, maxHeight: 260),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: service.logs.isEmpty
                ? Text(AppLocalizations.of(context)!.serverLogEmpty)
                : SingleChildScrollView(
                    child: SelectableText(service.logs.join('\n')),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessCard(BuildContext context) {
    final tr = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr.serverInstalled,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            tr.serverSuccessInfo(
              _domainController.text.trim(),
              _listenPortController.text.trim(),
              _vpnUsernameController.text.trim(),
            ),
          ),
        ],
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
    String? hintText,
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
        hintText: hintText,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

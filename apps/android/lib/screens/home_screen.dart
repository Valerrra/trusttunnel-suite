import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/server_config.dart';
import '../models/vpn_status.dart';
import '../services/config_service.dart';
import '../services/vpn_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ConfigService? _configService;
  List<ServerConfig> _profiles = const [];
  String? _activeProfileId;
  bool _isLoadingProfiles = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final configService = context.read<ConfigService>();
    if (_configService == configService) {
      return;
    }
    _configService?.removeListener(_handleConfigChanged);
    _configService = configService;
    _configService!.addListener(_handleConfigChanged);
    _loadProfiles();
  }

  @override
  void dispose() {
    _configService?.removeListener(_handleConfigChanged);
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    final configService = context.read<ConfigService>();
    final profiles = await configService.loadProfiles();
    final activeProfileId = await configService.loadActiveProfileId();
    if (!mounted) {
      return;
    }
    setState(() {
      _profiles = profiles;
      _activeProfileId = activeProfileId;
      _isLoadingProfiles = false;
    });
  }

  void _handleConfigChanged() {
    _loadProfiles();
  }

  ServerConfig get _activeProfile {
    if (_profiles.isEmpty) {
      return ServerConfig.defaultConfig();
    }
    return _profiles.firstWhere(
      (profile) => profile.profileId == _activeProfileId,
      orElse: () => _profiles.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Selector<VpnService, (VpnStatus, String?)>(
      selector: (_, vpn) => (vpn.status, vpn.errorMessage),
      builder: (context, record, child) {
        final vpnService = context.read<VpnService>();
        final status = record.$1;
        final errorMessage = record.$2;

        if (_isLoadingProfiles) {
          return const Center(child: CircularProgressIndicator());
        }

        final activeProfile = _activeProfile;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 148,
                height: 148,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: status.color.withValues(alpha: 0.10),
                  border: Border.all(color: status.color, width: 4),
                ),
                child: Icon(status.icon, size: 76, color: status.color),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              status.displayText,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: status.color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${activeProfile.profileName}  ·  ${activeProfile.hostname}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 20),
            _buildMainButton(context, vpnService, status, activeProfile),
            const SizedBox(height: 20),
            if (errorMessage != null && errorMessage.isNotEmpty)
              _buildErrorCard(context, errorMessage),
            const SizedBox(height: 20),
            _buildProfilePanel(context, activeProfile, status),
          ],
        );
      },
    );
  }

  Widget _buildProfilePanel(
    BuildContext context,
    ServerConfig activeProfile,
    VpnStatus status,
  ) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;
    final canSwitch = !status.isActive;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dns_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr.homeProfilesTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${_profiles.length}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _profiles.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final profile = _profiles[index];
              final isActive = profile.profileId == activeProfile.profileId;
              return _buildProfileListTile(
                context,
                profile: profile,
                isActive: isActive,
                enabled: canSwitch,
                canDelete: _profiles.length > 1,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileListTile(
    BuildContext context, {
    required ServerConfig profile,
    required bool isActive,
    required bool enabled,
    required bool canDelete,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? () => _switchProfile(profile.profileId) : null,
        onLongPress: canDelete ? () => _confirmDeleteProfile(profile) : null,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.25),
              width: isActive ? 2 : 1,
            ),
            color: isActive
                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                : theme.colorScheme.surface,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isActive ? Icons.radio_button_checked : Icons.dns_outlined,
                    size: 18,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      profile.profileName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isActive)
                    Icon(
                      Icons.check_circle,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${profile.hostname}:${profile.port}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                profile.username,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _switchProfile(String profileId) async {
    await context.read<ConfigService>().setActiveProfile(profileId);
  }

  Future<void> _confirmDeleteProfile(ServerConfig profile) async {
    final tr = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(tr.homeDeleteProfileTitle),
          content: Text(tr.homeDeleteProfileMessage(profile.profileName)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(tr.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(tr.homeDeleteProfileConfirm),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await context.read<ConfigService>().deleteProfile(profile.profileId);
    }
  }

  Widget _buildMainButton(
    BuildContext context,
    VpnService vpnService,
    VpnStatus status,
    ServerConfig activeProfile,
  ) {
    final isLoading =
        status == VpnStatus.connecting || status == VpnStatus.disconnecting;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: isLoading
            ? null
            : () => _handleButtonPress(context, vpnService, status, activeProfile),
        icon: Icon(
          status == VpnStatus.connected
              ? Icons.stop_circle_outlined
              : Icons.play_circle_outline,
        ),
        label: Text(
          isLoading
              ? AppLocalizations.of(context)!.homePleaseWait
              : status == VpnStatus.connected
              ? AppLocalizations.of(context)!.homeDisconnect
              : AppLocalizations.of(context)!.homeConnect,
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String errorMessage) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleButtonPress(
    BuildContext context,
    VpnService vpnService,
    VpnStatus status,
    ServerConfig activeProfile,
  ) async {
    try {
      if (status == VpnStatus.connected) {
        await vpnService.disconnect();
        return;
      }

      await vpnService.connect(activeProfile);
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.homeError(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

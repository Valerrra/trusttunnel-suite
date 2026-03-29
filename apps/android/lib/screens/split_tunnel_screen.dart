import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/server_config.dart';
import '../models/vpn_status.dart';
import '../services/config_service.dart';
import '../services/vpn_service.dart';

class SplitTunnelScreen extends StatefulWidget {
  const SplitTunnelScreen({super.key});

  @override
  State<SplitTunnelScreen> createState() => _SplitTunnelScreenState();
}

class _SplitTunnelScreenState extends State<SplitTunnelScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _domainController = TextEditingController();

  VpnMode _vpnMode = VpnMode.general;
  List<String> _domains = [];
  List<String> _apps = [];
  List<AppInfo> _installedApps = [];
  bool _isLoading = true;
  bool _isLoadingApps = true;
  String _appSearchQuery = '';
  ConfigService? _configService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInstalledApps();
  }

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
    _loadConfig();
  }

  @override
  void dispose() {
    _configService?.removeListener(_handleConfigChanged);
    _tabController.dispose();
    _domainController.dispose();
    super.dispose();
  }

  void _handleConfigChanged() {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await context.read<ConfigService>().loadConfig();
    if (!mounted) {
      return;
    }

    setState(() {
      _vpnMode = config.vpnMode;
      _domains = List<String>.from(config.splitTunnelDomains);
      _apps = List<String>.from(config.splitTunnelApps);
      _isLoading = false;
    });
  }

  Future<void> _loadInstalledApps() async {
    try {
      final apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: true,
        excludeNonLaunchableApps: true,
        withIcon: false,
      );

      apps.sort((a, b) {
        final left = a.name.isNotEmpty ? a.name : a.packageName;
        final right = b.name.isNotEmpty ? b.name : b.packageName;
        return left.toLowerCase().compareTo(right.toLowerCase());
      });

      if (!mounted) {
        return;
      }
      setState(() {
        _installedApps = apps;
        _isLoadingApps = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingApps = false;
      });
    }
  }

  Future<void> _saveConfig() async {
    try {
      final configService = context.read<ConfigService>();
      final currentConfig = await configService.loadConfig();
      final updated = currentConfig.copyWith(
        vpnMode: _vpnMode,
        splitTunnelDomains: List<String>.from(_domains),
        splitTunnelApps: List<String>.from(_apps),
      );
      await configService.saveConfig(updated);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.splitTunnelSaveError(e.toString()),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _setVpnMode(VpnMode mode) {
    setState(() {
      _vpnMode = mode;
    });
    _saveConfig();
  }

  void _addDomain() {
    final domain = _domainController.text.trim();
    if (domain.isEmpty) {
      return;
    }
    final exists = _domains.any(
      (item) => item.toLowerCase() == domain.toLowerCase(),
    );
    if (exists) {
      _domainController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.splitTunnelDomainAlreadyAdded),
        ),
      );
      return;
    }

    setState(() {
      _domains = [..._domains, domain];
      _domainController.clear();
    });
    _saveConfig();
  }

  void _removeDomain(String domain) {
    setState(() {
      _domains = _domains.where((item) => item != domain).toList();
    });
    _saveConfig();
  }

  void _toggleApp(String packageName) {
    setState(() {
      if (_apps.contains(packageName)) {
        _apps = _apps.where((item) => item != packageName).toList();
      } else {
        _apps = [..._apps, packageName];
      }
    });
    _saveConfig();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<VpnService, VpnStatus>(
      selector: (_, vpn) => vpn.status,
      builder: (context, status, child) {
        final isConnected = status.isActive;
        final tr = AppLocalizations.of(context)!;

        if (_isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            if (isConnected)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _buildWarningCard(context),
              ),
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  icon: const Icon(Icons.language, size: 20),
                  text: tr.splitTunnelDomainsTab(_domains.length),
                ),
                Tab(
                  icon: const Icon(Icons.apps, size: 20),
                  text: tr.splitTunnelAppsTab(_apps.length),
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDomainsTab(context, isConnected),
                  _buildAppsTab(context, isConnected),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr.splitTunnelVpnMode,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildModeCard(
                    context,
                    title: tr.splitTunnelModeGeneralTitle,
                    subtitle: tr.splitTunnelModeGeneralSubtitle,
                    icon: Icons.shield_outlined,
                    isSelected: _vpnMode == VpnMode.general,
                    enabled: !isConnected,
                    onTap: () => _setVpnMode(VpnMode.general),
                  ),
                  const SizedBox(height: 10),
                  _buildModeCard(
                    context,
                    title: tr.splitTunnelModeSelectiveTitle,
                    subtitle: tr.splitTunnelModeSelectiveSubtitle,
                    icon: Icons.filter_alt_outlined,
                    isSelected: _vpnMode == VpnMode.selective,
                    enabled: !isConnected,
                    onTap: () => _setVpnMode(VpnMode.selective),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tr.splitTunnelAutoSave,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
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

  Widget _buildWarningCard(BuildContext context) {
    return Container(
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
              AppLocalizations.of(context)!.splitTunnelWarningConnected,
              style: const TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withValues(alpha: 0.25),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: enabled
                            ? theme.colorScheme.outline
                            : theme.disabledColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDomainsTab(BuildContext context, bool isConnected) {
    final tr = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _vpnMode == VpnMode.general
                ? tr.splitTunnelDomainsExclude
                : tr.splitTunnelDomainsInclude,
          ),
          const SizedBox(height: 4),
          Text(
            tr.splitTunnelDomainsHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _domainController,
            enabled: !isConnected,
            minLines: 2,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: tr.splitTunnelDomainsInputHint,
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 28),
                child: Icon(Icons.add_link, size: 22),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
            onSubmitted: (_) => _addDomain(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: isConnected ? null : _addDomain,
                  icon: const Icon(Icons.add),
                  label: Text(tr.splitTunnelEnterDomain),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _domains.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.dns_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr.splitTunnelNoDomains,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _domains.length,
                    itemBuilder: (context, index) {
                      final domain = _domains[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          leading: Icon(_domainIcon(domain), size: 24),
                          title: Text(domain),
                          trailing: IconButton(
                            onPressed: isConnected
                                ? null
                                : () => _removeDomain(domain),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppsTab(BuildContext context, bool isConnected) {
    final tr = AppLocalizations.of(context)!;
    final filteredApps = _appSearchQuery.isEmpty
        ? _installedApps
        : _installedApps.where((app) {
            final query = _appSearchQuery.toLowerCase();
            return app.name.toLowerCase().contains(query) ||
                app.packageName.toLowerCase().contains(query);
          }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _vpnMode == VpnMode.general
                ? tr.splitTunnelAppsExclude
                : tr.splitTunnelAppsInclude,
          ),
          const SizedBox(height: 8),
          if (_apps.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr.splitTunnelSelectedApps(_apps.length),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            enabled: !isConnected,
            decoration: InputDecoration(
              hintText: tr.splitTunnelSearchApps,
              prefixIcon: const Icon(Icons.search, size: 22),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _appSearchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoadingApps
                ? const Center(child: CircularProgressIndicator())
                : filteredApps.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.apps_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr.splitTunnelNoApps,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredApps.length,
                    itemBuilder: (context, index) {
                      final app = filteredApps[index];
                      final isSelected = _apps.contains(app.packageName);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: CheckboxListTile(
                          value: isSelected,
                          onChanged: isConnected
                              ? null
                              : (_) => _toggleApp(app.packageName),
                          secondary: const Icon(Icons.apps, size: 24),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          title: Text(
                            app.name.isNotEmpty
                                ? app.name
                                : app.packageName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          subtitle: Text(app.packageName),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  IconData _domainIcon(String value) {
    if (value.contains('/')) {
      return Icons.hub;
    }
    if (RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(value)) {
      return Icons.router;
    }
    return Icons.language;
  }
}

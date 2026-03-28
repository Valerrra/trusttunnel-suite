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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadConfig();
    _loadInstalledApps();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _domainController.dispose();
    super.dispose();
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
            Expanded(
              flex: 0,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isConnected) _buildWarningCard(context),
                      Text(
                        tr.splitTunnelVpnMode,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSummaryCard(context),
                      const SizedBox(height: 12),
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
              ),
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

  Widget _buildSummaryCard(BuildContext context) {
    final theme = Theme.of(context);
    final tr = AppLocalizations.of(context)!;
    final modeTitle = _vpnMode == VpnMode.general
        ? tr.splitTunnelModeGeneralTitle
        : tr.splitTunnelModeSelectiveTitle;
    final modeSubtitle = _vpnMode == VpnMode.general
        ? tr.splitTunnelModeGeneralSubtitle
        : tr.splitTunnelModeSelectiveSubtitle;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.route,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  modeTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            modeSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSummaryChip(
                context,
                icon: Icons.language,
                label: tr.splitTunnelDomainsTab(_domains.length),
              ),
              _buildSummaryChip(
                context,
                icon: Icons.apps,
                label: tr.splitTunnelAppsTab(_apps.length),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurface),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningCard(BuildContext context) {
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _domainController,
                  enabled: !isConnected,
                  decoration: InputDecoration(
                    hintText: tr.splitTunnelDomainsInputHint,
                    prefixIcon: const Icon(Icons.add_link, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSubmitted: (_) => _addDomain(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: isConnected ? null : _addDomain,
                icon: const Icon(Icons.add),
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
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          leading: Icon(_domainIcon(domain), size: 20),
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
          const SizedBox(height: 12),
          TextField(
            enabled: !isConnected,
            decoration: InputDecoration(
              hintText: tr.splitTunnelSearchApps,
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
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
                        margin: const EdgeInsets.only(bottom: 6),
                        child: CheckboxListTile(
                          value: isSelected,
                          onChanged: isConnected
                              ? null
                              : (_) => _toggleApp(app.packageName),
                          secondary: const Icon(Icons.apps, size: 20),
                          title: Text(
                            app.name.isNotEmpty
                                ? app.name
                                : app.packageName,
                          ),
                          subtitle: Text(app.packageName),
                        ),
                      );
                    },
                  ),
          ),
          if (_apps.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr.splitTunnelSelectedApps(_apps.length),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
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

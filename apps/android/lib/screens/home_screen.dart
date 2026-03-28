import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/vpn_status.dart';
import '../services/config_service.dart';
import '../services/vpn_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<VpnService, (VpnStatus, String?)>(
      selector: (_, vpn) => (vpn.status, vpn.errorMessage),
      builder: (context, record, child) {
        final vpnService = context.read<VpnService>();
        final status = record.$1;
        final errorMessage = record.$2;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),
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
            const SizedBox(height: 20),
            _buildMainButton(context, vpnService, status),
            const SizedBox(height: 20),
            if (errorMessage != null && errorMessage.isNotEmpty)
              _buildErrorCard(context, errorMessage),
          ],
        );
      },
    );
  }

  Widget _buildMainButton(
    BuildContext context,
    VpnService vpnService,
    VpnStatus status,
  ) {
    final isLoading =
        status == VpnStatus.connecting || status == VpnStatus.disconnecting;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: isLoading
            ? null
            : () => _handleButtonPress(context, vpnService, status),
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
  ) async {
    try {
      if (status == VpnStatus.connected) {
        await vpnService.disconnect();
        return;
      }

      final configService = context.read<ConfigService>();
      final config = await configService.loadConfig();
      await vpnService.connect(config);
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/vpn_service.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VpnService>(
      builder: (context, vpnService, child) {
        final logs = vpnService.logs;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.logsTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: logs.isEmpty
                        ? null
                        : () => context.read<VpnService>().clearLogs(),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(AppLocalizations.of(context)!.logsClear),
                  ),
                ],
              ),
            ),
            Expanded(
              child: logs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          AppLocalizations.of(context)!.mobileLogsHint,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        return SelectableText(
                          logs[index],
                          style: Theme.of(context).textTheme.bodySmall,
                        );
                      },
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 10),
                      itemCount: logs.length,
                    ),
            ),
          ],
        );
      },
    );
  }
}

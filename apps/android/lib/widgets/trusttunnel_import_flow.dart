import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/server_config.dart';
import '../services/config_service.dart';
import '../services/trusttunnel_deep_link_service.dart';

class TrustTunnelImportFlow {
  static final TrustTunnelDeepLinkService _deepLinkService =
      TrustTunnelDeepLinkService();

  static Future<String?> promptForDeepLink(
    BuildContext context, {
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);

    final deepLink = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(dialogContext)!.settingsImportDialogTitle,
          ),
          content: SizedBox(
            width: 520,
            child: TextField(
              controller: controller,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(
                  dialogContext,
                )!.settingsImportDialogHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(AppLocalizations.of(dialogContext)!.commonCancel),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text(
                AppLocalizations.of(dialogContext)!.settingsImportConfirm,
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return deepLink;
  }

  static Future<ServerConfig?> importDeepLink(
    BuildContext context, {
    required String deepLink,
    required ServerConfig baseConfig,
  }) async {
    try {
      final imported = _deepLinkService.parse(deepLink, baseConfig: baseConfig);

      final confirmed = await _showImportPreview(context, imported);
      if (confirmed != true || !context.mounted) {
        return null;
      }

      final configService = context.read<ConfigService>();
      final saved = await configService.saveImportedConfig(imported);
      if (!context.mounted) {
        return null;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.settingsImported),
          backgroundColor: Colors.green,
        ),
      );

      return saved;
    } catch (e) {
      if (!context.mounted) {
        return null;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.settingsImportError(e.toString()),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      return null;
    }
  }

  static Future<bool?> _showImportPreview(
    BuildContext context,
    ServerConfig config,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(dialogContext)!.settingsImportPreviewTitle,
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPreviewRow(dialogContext, 'Hostname', config.hostname),
                  _buildPreviewRow(
                    dialogContext,
                    'Address',
                    '${config.address}:${config.port}',
                  ),
                  _buildPreviewRow(dialogContext, 'Username', config.username),
                  _buildPreviewRow(
                    dialogContext,
                    'Protocol',
                    config.upstreamProtocol,
                  ),
                  _buildPreviewRow(
                    dialogContext,
                    'IPv6',
                    config.hasIpv6 ? 'Enabled' : 'Disabled',
                  ),
                  _buildPreviewRow(
                    dialogContext,
                    'Skip verification',
                    config.skipVerification ? 'Yes' : 'No',
                  ),
                  _buildPreviewRow(
                    dialogContext,
                    'Anti-DPI',
                    config.antiDpi ? 'Enabled' : 'Disabled',
                  ),
                  if (config.customSni.isNotEmpty)
                    _buildPreviewRow(
                      dialogContext,
                      'Custom SNI',
                      config.customSni,
                    ),
                  if (config.clientRandomPrefix.isNotEmpty)
                    _buildPreviewRow(
                      dialogContext,
                      'Client random prefix',
                      config.clientRandomPrefix,
                    ),
                  if (config.certificate.isNotEmpty)
                    _buildPreviewRow(
                      dialogContext,
                      'Certificate',
                      'Included in deep link',
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(AppLocalizations.of(dialogContext)!.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                AppLocalizations.of(dialogContext)!.settingsImportConfirm,
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildPreviewRow(
    BuildContext context,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 2),
          SelectableText(value),
        ],
      ),
    );
  }
}

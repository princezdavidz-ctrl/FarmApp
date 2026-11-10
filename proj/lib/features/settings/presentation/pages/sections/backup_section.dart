import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:proj/app/theme/app_dimensions.dart';
import 'package:proj/features/auth/presentation/providers/auth_provider.dart';
import 'package:proj/features/reports/data/report_export_service.dart';
import 'package:proj/features/reports/presentation/providers/reports_providers.dart';
import 'package:proj/features/settings/domain/entities/backup_settings.dart';
import 'package:proj/features/settings/domain/entities/device_settings.dart';
import 'package:proj/features/settings/domain/entities/payment_settings.dart';
import 'package:proj/features/settings/domain/entities/security_settings.dart';
import 'package:proj/features/settings/domain/entities/user_preferences.dart';
import 'package:proj/features/settings/presentation/providers/settings_providers.dart';

class BackupSection extends ConsumerStatefulWidget {
  const BackupSection({super.key});

  @override
  ConsumerState<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<BackupSection> {
  bool _busy = false;

  Future<Map<String, dynamic>> _settingsSnapshot() async {
    final local = ref.read(settingsLocalDataSourceProvider);
    final farm = ref.read(authProvider).valueOrNull?.selectedFarm;
    return {
      // Keep the v1 marker so existing FarmApp settings backups remain restorable.
      'format': 'pigworld-settings-backup',
      'version': 1,
      'created_at': DateTime.now().toIso8601String(),
      'farm': farm == null ? null : {'id': farm.id, 'name': farm.name},
      'settings': {
        'preferences': (await local.readPreferences()).toJson(),
        'security': (await local.readSecuritySettings()).toJson(),
        'backup': (await local.readBackupSettings()).toJson(),
        'payment': (await local.readPaymentSettings()).toJson(),
        'devices': {
          'devices': (await local.readDeviceSettings()).devices
              .map((device) => device.toJson())
              .toList(),
        },
      },
    };
  }

  Future<void> _createBackup() async {
    setState(() => _busy = true);
    try {
      final snapshot = await _settingsSnapshot();
      final filePath = await ReportExportService().exportReport(
        reportName: 'farmapp_settings_backup',
        format: 'json',
        data: snapshot,
      );
      await ref
          .read(backupSettingsProvider.notifier)
          .recordBackup(DateTime.now());
      await _shareFile(filePath, 'Farm App settings backup');
      if (mounted) {
        _message(
          'Settings backup created at $filePath. Server farm records are not included.',
        );
      }
    } catch (error) {
      if (mounted) _message('Could not create settings backup: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    final controller = TextEditingController();
    final json = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore settings backup'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    final clipboard = await Clipboard.getData('text/plain');
                    if (clipboard?.text != null) {
                      controller.text = clipboard!.text!;
                    }
                  },
                  icon: const Icon(Icons.content_paste),
                  label: const Text('Paste JSON'),
                ),
              ),
              TextField(
                controller: controller,
                minLines: 5,
                maxLines: 9,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Paste the contents of a settings backup JSON file',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Restore settings'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (json == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic> ||
          decoded['format'] != 'pigworld-settings-backup' ||
          decoded['version'] != 1 ||
          decoded['settings'] is! Map) {
        throw const FormatException('This is not a supported settings backup.');
      }
      final values = Map<String, dynamic>.from(decoded['settings'] as Map);
      final preferences = UserPreferences.fromJson(
        Map<String, dynamic>.from(values['preferences'] as Map),
      );
      final security = SecuritySettings.fromJson(
        Map<String, dynamic>.from(values['security'] as Map),
      );
      final backup = BackupSettings.fromJson(
        Map<String, dynamic>.from(values['backup'] as Map),
      );
      final payment = PaymentSettings.fromJson(
        Map<String, dynamic>.from(values['payment'] as Map),
      );
      final devices = DeviceSettings(
        devices: ((values['devices'] as Map)['devices'] as List<dynamic>)
            .map(
              (item) => ConnectedDevice.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
      );

      final local = ref.read(settingsLocalDataSourceProvider);
      await local.savePreferences(preferences);
      await local.saveSecuritySettings(security);
      await local.saveBackupSettings(backup);
      await local.savePaymentSettings(payment);
      await local.saveDeviceSettings(devices);
      ref
        ..invalidate(userPreferencesProvider)
        ..invalidate(securitySettingsProvider)
        ..invalidate(backupSettingsProvider)
        ..invalidate(paymentSettingsProvider);
      if (mounted) {
        _message(
          'Local settings restored. Server farm records were not changed.',
        );
      }
    } catch (error) {
      if (mounted) _message('Could not restore settings backup: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportReport(String format) async {
    final farm = ref.read(authProvider).valueOrNull?.selectedFarm;
    if (farm == null) {
      _message('Select a farm before exporting its report.');
      return;
    }
    setState(() => _busy = true);
    try {
      final metrics = await ref
          .read(reportsApiProvider)
          .getMetrics(farm.id, dateRange: 'month');
      final filePath = await ReportExportService().exportReport(
        reportName: '${farm.name}_monthly_report',
        format: format,
        data: {'farm': farm.name, ...metrics.toJson()},
      );
      await _shareFile(filePath, '${farm.name} monthly report');
      if (mounted) _message('Report exported to $filePath.');
    } catch (error) {
      if (mounted) _message('Could not export report: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareFile(String filePath, String subject) async {
    final renderObject = context.findRenderObject();
    final box = renderObject is RenderBox ? renderObject : null;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath)],
        subject: subject,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 6)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backupSettings = ref.watch(backupSettingsProvider);
    return backupSettings.when(
      data: (settings) => ListView(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Local Settings Backup',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create a JSON backup of app settings. Payment settings may be included; store the file securely. Farm records remain on the server and are not part of this backup.',
                  ),
                  if (settings.lastBackupDate != null) ...[
                    const SizedBox(height: AppDimensions.spacingMedium),
                    Text(
                      'Last backup: ${settings.lastBackupDate}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: AppDimensions.spacingMedium),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _createBackup,
                      icon: const Icon(Icons.backup),
                      label: const Text('Create Settings Backup'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _restoreBackup,
                      icon: const Icon(Icons.restore),
                      label: const Text('Restore Settings Backup'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLarge),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Farm Reports',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Export monthly farm metrics from the server.'),
                  const SizedBox(height: AppDimensions.spacingMedium),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _exportReport('pdf'),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Export PDF'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _exportReport('xlsx'),
                      icon: const Icon(Icons.table_chart),
                      label: const Text('Export Excel'),
                    ),
                  ),
                  if (_busy) ...[
                    const SizedBox(height: AppDimensions.spacingMedium),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('Could not load backup settings: $error')),
    );
  }
}

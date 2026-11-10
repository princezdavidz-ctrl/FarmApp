import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:proj/app/routes/app_routes.dart';
import 'package:proj/app/theme/app_colors.dart';
import 'package:proj/app/theme/app_dimensions.dart';
import 'package:proj/features/auth/domain/entities/farm.dart';
import 'package:proj/features/auth/domain/entities/session.dart';
import 'package:proj/features/auth/domain/entities/user.dart';
import 'package:proj/features/auth/presentation/providers/auth_provider.dart';
import 'package:proj/features/auth/presentation/providers/auth_providers.dart';
import 'package:proj/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:proj/features/settings/data/settings_api.dart';
import 'package:proj/features/settings/presentation/providers/settings_providers.dart';
import 'package:proj/l10n/generated/app_localizations.dart';
import 'package:proj/features/settings/presentation/widgets/farm_location_picker_dialog.dart';
import 'package:proj/security/authorization/roles.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  Future<void> _changeLanguage(String language) async {
    try {
      await ref.read(userPreferencesProvider.notifier).updateLanguage(language);
      ref
          .read(onboardingProvider.notifier)
          .setLanguage(
            name: language == 'sw' ? 'Kiswahili' : 'English',
            code: language,
          );
      if (mounted) _showMessage(AppLocalizations.of(context)!.languageChanged);
    } catch (_) {
      if (mounted) {
        _showMessage(
          AppLocalizations.of(context)!.languageChangeFailed,
          isError: true,
        );
      }
    }
  }

  Future<void> _changeProfileName(Session? session) async {
    if (session == null) return;
    final l10n = AppLocalizations.of(context)!;
    final name = await _editTextDialog(
      l10n.changeProfileNameTitle,
      l10n.profileName,
      session.user.name,
    );
    if (name == null || !mounted) return;
    try {
      await SettingsApi(ref.read(dioProvider)).updateDisplayName(name);
      if (!mounted) return;
      final user = session.user;
      ref
          .read(authProvider.notifier)
          .setSession(
            Session(
              accessToken: session.accessToken,
              refreshToken: session.refreshToken,
              user: User(
                id: user.id,
                name: name,
                email: user.email,
                phone: user.phone,
                role: user.role,
              ),
              farms: session.farms,
              selectedFarm: session.selectedFarm,
            ),
          );
      _showMessage(l10n.profileNameUpdated);
    } catch (_) {
      _showMessage(l10n.profileNameUpdateFailed, isError: true);
    }
  }

  Future<void> _changeFarmName(Session? session, Farm? farm) async {
    if (session == null || farm == null) return;
    final l10n = AppLocalizations.of(context)!;
    final name = await _editTextDialog(
      l10n.farmNameTitle,
      l10n.farmName,
      farm.name,
    );
    if (name == null || !mounted) return;
    try {
      await SettingsApi(
        ref.read(dioProvider),
      ).requestFarmNameChange(farmId: farm.id, requestedName: name.trim());
      ref.invalidate(farmNameChangeRequestsProvider(farm.id));
      if (!mounted) return;
      _showMessage(
        'Farm name change sent to Farm App support for approval.',
      );
    } catch (_) {
      _showMessage(l10n.farmNameUpdateFailed, isError: true);
    }
  }

  Future<void> _changeFarmLocation(Session? session, Farm? farm) async {
    if (session == null || farm == null) return;
    final selection = await showDialog<FarmLocationSelection>(
      context: context,
      builder: (_) => FarmLocationPickerDialog(
        initialAddress: farm.location,
        initialLatitude: farm.latitude,
        initialLongitude: farm.longitude,
      ),
    );
    if (selection == null || !mounted) return;
    try {
      await SettingsApi(ref.read(dioProvider)).updateFarmLocation(
        farmId: farm.id,
        location: selection.address,
        latitude: selection.latitude,
        longitude: selection.longitude,
      );
      if (!mounted) return;
      final updatedFarm = Farm(
        id: farm.id,
        name: farm.name,
        location: selection.address,
        latitude: selection.latitude,
        longitude: selection.longitude,
        inviteCode: farm.inviteCode,
        motherPigCount: farm.motherPigCount,
        registeredPigletCount: farm.registeredPigletCount,
        pregnantPigCount: farm.pregnantPigCount,
        subscriptionPlan: farm.subscriptionPlan,
      );
      ref
          .read(authProvider.notifier)
          .setSession(
            Session(
              accessToken: session.accessToken,
              refreshToken: session.refreshToken,
              user: session.user,
              farms: [
                for (final item in session.farms)
                  item.id == farm.id ? updatedFarm : item,
              ],
              selectedFarm: updatedFarm,
            ),
          );
      _showMessage('Farm location saved.');
    } catch (_) {
      _showMessage('Could not save the farm location.', isError: true);
    }
  }

  Future<void> _setNewPassword() async {
    final l10n = AppLocalizations.of(context)!;
    final passwords = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _PasswordDialog(),
    );
    if (passwords == null || !mounted) return;
    try {
      await SettingsApi(ref.read(dioProvider)).changePassword(
        currentPassword: passwords.$1,
        newPassword: passwords.$2,
      );
      if (mounted) {
        _showMessage(l10n.passwordUpdated);
      }
    } catch (_) {
      if (mounted) {
        _showMessage(l10n.passwordUpdateFailed, isError: true);
      }
    }
  }

  Future<String?> _editTextDialog(
    String title,
    String label,
    String initialValue,
  ) => showDialog<String>(
    context: context,
    builder: (_) =>
        _TextEditDialog(title: title, label: label, initialValue: initialValue),
  );

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final preferences = ref.watch(userPreferencesProvider).valueOrNull;
    final session = ref.watch(authProvider).valueOrNull;
    final farm = session?.selectedFarm ?? session?.farms.firstOrNull;
    final nameRequests = farm == null
        ? null
        : ref.watch(farmNameChangeRequestsProvider(farm.id));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.pagePadding),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.language_outlined),
              title: Text(l10n.changeLanguage),
              subtitle: Text(
                SettingsHelper.getLanguageName(preferences?.language ?? 'en'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showLanguagePicker,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLarge),
          if (nameRequests?.valueOrNull?.isNotEmpty == true) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.hourglass_top_outlined),
                title: const Text('Farm name change request'),
                subtitle: Text(
                  '${nameRequests!.valueOrNull!.first['requested_name']} · '
                  '${nameRequests.valueOrNull!.first['status']}',
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingLarge),
          ],
          Text(
            l10n.accountSettings,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          Card(
            child: Column(
              children: [
                _SettingsAction(
                  icon: Icons.person_outline,
                  title: l10n.changeProfileName,
                  onTap: () => _changeProfileName(session),
                ),
                const Divider(height: 1),
                _SettingsAction(
                  icon: Icons.agriculture_outlined,
                  title: l10n.changeFarmName,
                  onTap: farm == null
                      ? null
                      : () => _changeFarmName(session, farm),
                ),
                const Divider(height: 1),
                _SettingsAction(
                  icon: Icons.lock_outline,
                  title: l10n.setNewPassword,
                  onTap: _setNewPassword,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLarge),
          Text(
            l10n.farmConfiguration,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          Card(
            child: Column(
              children: [
                _SettingsAction(
                  icon: Icons.location_on_outlined,
                  title: l10n.farmLocation,
                  subtitle: farm?.location ?? l10n.addFarmLocation,
                  onTap: farm == null
                      ? null
                      : () => _changeFarmLocation(session, farm),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLarge),
          Text(
            l10n.billingAndSubscription,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppDimensions.spacingMedium),
          Card(
            child: Column(
              children: [
                _SettingsAction(
                  icon: Icons.credit_card_outlined,
                  title: l10n.currentPlan,
                  subtitle: farm?.subscriptionPlan ?? l10n.starterPlan,
                  onTap: session?.user.role.value == 'farmOwner'
                      ? () => context.go(AppRoutes.billing)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLarge),
          Text('More settings', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppDimensions.spacingMedium),
          Card(
            child: Column(
              children: [
                _SettingsAction(
                  icon: Icons.person_outline,
                  title: 'Profile & preferences',
                  onTap: () =>
                      context.push('${AppRoutes.settingsDetails}?tab=profile'),
                ),
                const Divider(height: 1),
                _SettingsAction(
                  icon: Icons.security_outlined,
                  title: l10n.securityAndSessions,
                  onTap: () =>
                      context.push('${AppRoutes.settingsDetails}?tab=security'),
                ),
                const Divider(height: 1),
                _SettingsAction(
                  icon: Icons.payment_outlined,
                  title: 'Payment settings',
                  onTap: () =>
                      context.push('${AppRoutes.settingsDetails}?tab=payment'),
                ),
                const Divider(height: 1),
                _SettingsAction(
                  icon: Icons.backup_outlined,
                  title: 'Backup & exports',
                  onTap: () =>
                      context.push('${AppRoutes.settingsDetails}?tab=backup'),
                ),
                const Divider(height: 1),
                _SettingsAction(
                  icon: Icons.devices_outlined,
                  title: 'Device permissions',
                  onTap: () =>
                      context.push('${AppRoutes.settingsDetails}?tab=devices'),
                ),
                const Divider(height: 1),
                _SettingsAction(
                  icon: Icons.notifications_outlined,
                  title: 'Notification settings',
                  onTap: () => context.push(
                    '${AppRoutes.settingsDetails}?tab=notifications',
                  ),
                ),
                const Divider(height: 1),
                _SettingsAction(
                  icon: Icons.support_agent_outlined,
                  title: 'Support & legal',
                  onTap: () =>
                      context.push('${AppRoutes.settingsDetails}?tab=support'),
                ),
                const Divider(height: 1),
                _SettingsAction(
                  icon: Icons.group_outlined,
                  title: 'Farm member management',
                  onTap: () =>
                      context.push('${AppRoutes.settingsDetails}?tab=team'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLanguagePicker() => showDialog<void>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(AppLocalizations.of(context)!.changeLanguage),
      children: [
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(dialogContext);
            _changeLanguage('en');
          },
          child: Text(AppLocalizations.of(context)!.english),
        ),
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(dialogContext);
            _changeLanguage('sw');
          },
          child: Text(AppLocalizations.of(context)!.kiswahili),
        ),
      ],
    ),
  );
}

class _SettingsAction extends StatelessWidget {
  const _SettingsAction({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: AppColors.primaryGreen),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: onTap == null ? null : const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

class _TextEditDialog extends StatefulWidget {
  const _TextEditDialog({
    required this.title,
    required this.label,
    required this.initialValue,
  });
  final String title;
  final String label;
  final String initialValue;
  @override
  State<_TextEditDialog> createState() => _TextEditDialogState();
}

class _TextEditDialogState extends State<_TextEditDialog> {
  late final TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: InputDecoration(labelText: widget.label),
      onSubmitted: (_) => _save(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(AppLocalizations.of(context)!.cancel),
      ),
      FilledButton(
        onPressed: _save,
        child: Text(AppLocalizations.of(context)!.save),
      ),
    ],
  );
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();
  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _currentController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  @override
  void dispose() {
    _currentController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  void _updatePassword() {
    final password = _passwordController.text;
    if (password.length >= 8 && password == _confirmationController.text) {
      Navigator.pop(context, (_currentController.text, password));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(AppLocalizations.of(context)!.setNewPassword),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _currentController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.currentPassword,
          ),
        ),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.newPassword,
          ),
        ),
        TextField(
          controller: _confirmationController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.confirmNewPassword,
          ),
          onSubmitted: (_) => _updatePassword(),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(AppLocalizations.of(context)!.cancel),
      ),
      FilledButton(
        onPressed: _updatePassword,
        child: Text(AppLocalizations.of(context)!.update),
      ),
    ],
  );
}

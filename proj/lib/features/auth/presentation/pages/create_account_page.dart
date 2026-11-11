import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../shared/widgets/farm_app_mark.dart';
import '../../../../security/authorization/roles.dart';
import '../providers/auth_provider.dart';
import '../providers/auth_providers.dart';
import '../widgets/server_settings_dialog.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';

class CreateAccountPage extends ConsumerStatefulWidget {
  const CreateAccountPage({super.key});

  @override
  ConsumerState<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends ConsumerState<CreateAccountPage> {
  static const _roles = [
    (
      UserRole.farmOwner,
      'Farm owner',
      'Create a new farm and control its policies.',
    ),
    (
      UserRole.farmManager,
      'Farm manager',
      'Join an existing farm with an owner-shared code.',
    ),
    (
      UserRole.farmWorker,
      'Farm worker',
      'Join an existing farm with an owner-shared code.',
    ),
  ];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _farmName = TextEditingController();
  final _productionTypes = TextEditingController();
  final _inviteCode = TextEditingController();
  UserRole _role = UserRole.farmOwner;
  String _farmingType = 'mixed';
  bool _submitting = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final selectedRoles = ref.read(onboardingProvider).roles;
    if (selectedRoles.isNotEmpty) {
      _role = selectedRoles.first;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _farmName.dispose();
    _productionTypes.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  bool get _needsInviteCode => _role != UserRole.farmOwner;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final session = await ref.read(registerUseCaseProvider)(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text,
        role: _role,
        farmName: _role == UserRole.farmOwner ? _farmName.text.trim() : null,
        inviteCode: _needsInviteCode ? _inviteCode.text.trim() : null,
        motherPigCount: ref.read(onboardingProvider).motherPigCount,
        pigletGroups: ref
            .read(onboardingProvider)
            .pigletGroups
            .map((group) => group.toJson())
            .toList(),
        pregnantPigCount: ref.read(onboardingProvider).pregnantPigCount,
        farmingType: _farmingType,
        productionTypes: _productionTypes.text
            .split(',')
            .map((type) => type.trim())
            .where((type) => type.isNotEmpty)
            .toList(),
      );
      await ref.read(authServiceProvider).setRememberMe(true);
      await ref.read(sessionManagerProvider).markActive();
      await ref.read(onboardingStorageProvider).markCompleted();
      ref.read(authProvider.notifier).setSession(session);
      if (mounted) {
        context.go(
          _role == UserRole.farmOwner ? AppRoutes.subscription : AppRoutes.home,
        );
      }
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Create account'),
      actions: [
        IconButton(
          tooltip: 'Server address',
          icon: const Icon(Icons.settings_ethernet),
          onPressed: () => showServerSettingsDialog(context, ref),
        ),
      ],
    ),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Center(child: FarmAppMark(size: 88)),
            const SizedBox(height: 16),
            Text(
              'Join FarmApp',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Set up your account to start managing your farm.'),
            const SizedBox(height: 24),
            DropdownButtonFormField<UserRole>(
              initialValue: _role,
              decoration: const InputDecoration(
                labelText: 'Account type',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              items: [
                for (final entry in _roles)
                  DropdownMenuItem(value: entry.$1, child: Text(entry.$2)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _role = value);
              },
              validator: (value) =>
                  value == null ? 'Choose an account type.' : null,
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: MediaQuery.of(context).disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              child: Text(
                _roles.firstWhere((entry) => entry.$1 == _role).$3,
                key: ValueKey(_role),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (value) => (value == null || value.trim().length < 8)
                  ? 'Enter a valid phone number.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter your full name.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.contact_mail_outlined),
              ),
              validator: (value) => (value == null || !value.contains('@'))
                  ? 'Enter a valid email.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (value) => (value == null || value.length < 8)
                  ? 'Use at least 8 characters.'
                  : null,
            ),
            const SizedBox(height: 16),
            if (_role == UserRole.farmOwner) ...[
              TextFormField(
                controller: _farmName,
                decoration: const InputDecoration(
                  labelText: 'Farm name',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Name your farm.'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _farmingType,
                decoration: const InputDecoration(
                  labelText: 'Farm production type',
                  prefixIcon: Icon(Icons.grass_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'crops', child: Text('Crops')),
                  DropdownMenuItem(
                    value: 'livestock',
                    child: Text('Livestock'),
                  ),
                  DropdownMenuItem(
                    value: 'mixed',
                    child: Text('Mixed farming'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _farmingType = value);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _productionTypes,
                decoration: const InputDecoration(
                  labelText: 'Crops, livestock, or animals',
                  hintText: 'Maize, dairy cattle, poultry, goats',
                  helperText:
                      'Separate items with commas; add any crop or animal.',
                  prefixIcon: Icon(Icons.eco_outlined),
                ),
              ),
            ] else
              TextFormField(
                controller: _inviteCode,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Owner invite code',
                  prefixIcon: Icon(Icons.link),
                  helperText:
                      'Optional. You can request a farm after creating your account.',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter the invite code from your farm owner.'
                    : null,
              ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create account'),
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.login),
              child: const Text('Back to sign in'),
            ),
          ],
        ),
      ),
    ),
  );
}

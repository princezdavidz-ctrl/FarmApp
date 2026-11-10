import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:proj/features/settings/data/settings_api.dart';
import 'package:proj/features/settings/presentation/providers/profile_image_provider.dart';
import 'package:proj/features/auth/domain/entities/session.dart';
import 'package:proj/features/auth/domain/entities/user.dart';
import 'package:proj/features/auth/presentation/providers/auth_providers.dart';
import 'package:proj/app/theme/app_colors.dart';
import 'package:proj/app/theme/app_dimensions.dart';
import 'package:proj/features/auth/presentation/providers/auth_provider.dart';
import 'package:proj/shared/widgets/profile_avatar.dart';

class ProfileSection extends ConsumerStatefulWidget {
  const ProfileSection({super.key});

  @override
  ConsumerState<ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends ConsumerState<ProfileSection> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _farmNameController;
  late TextEditingController _farmLocationController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _farmNameController = TextEditingController();
    _farmLocationController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = ref.watch(authProvider).valueOrNull;
    if (session != null) {
      _nameController.text = session.user.name;
      _emailController.text = session.user.email;
      _phoneController.text = session.user.phone ?? '';
      _farmNameController.text = session.selectedFarm?.name ?? '';
      _farmLocationController.text = session.selectedFarm?.location ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _farmNameController.dispose();
    _farmLocationController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final session = ref.read(authProvider).valueOrNull;
    final name = _nameController.text.trim();
    if (session == null || name.isEmpty) {
      _showMessage('Enter your name before saving.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      if (name != session.user.name) {
        await SettingsApi(ref.read(dioProvider)).updateDisplayName(name);
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
      }
      if (mounted) _showMessage('Profile updated.');
    } catch (error) {
      if (mounted) {
        _showMessage('Could not update profile: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _choosePhoto() async {
    try {
      final changed = await ref
          .read(profileImageProvider.notifier)
          .chooseFromGallery();
      if (mounted && changed) _showMessage('Profile photo updated.');
    } catch (error) {
      if (mounted) {
        _showMessage('Could not update photo: $error', isError: true);
      }
    }
  }

  Future<void> _copyInviteCode(String inviteCode) async {
    await Clipboard.setData(ClipboardData(text: inviteCode));
    if (mounted) _showMessage('Invite code copied.');
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authProvider).valueOrNull;
    final user = session?.user;
    final farm = session?.selectedFarm;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.pagePadding),
      children: [
        // Profile Photo Section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile Photo',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppDimensions.spacingLarge),
                Center(
                  child: Stack(
                    children: [
                      ProfileAvatar(
                        initials:
                            (user.name.isNotEmpty ? user.name.trim()[0] : '?')
                                .toUpperCase(),
                        radius: 50,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: FloatingActionButton.small(
                          backgroundColor: AppColors.primaryGreen,
                          onPressed: () {
                            _choosePhoto();
                          },
                          child: const Icon(Icons.camera_alt),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingLarge),
        // Owner Information
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Owner Information',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppDimensions.spacingMedium),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Owner Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingMedium),
                TextField(
                  controller: _emailController,
                  readOnly: true,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingMedium),
                TextField(
                  controller: _phoneController,
                  readOnly: true,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingLarge),
        // Farm Information
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Farm Information',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppDimensions.spacingMedium),
                TextField(
                  controller: _farmNameController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Farm Name',
                    prefixIcon: Icon(Icons.agriculture),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingMedium),
                TextField(
                  controller: _farmLocationController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Farm Location',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
                if (farm?.inviteCode != null) ...[
                  const SizedBox(height: AppDimensions.spacingMedium),
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.spacingMedium),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(AppDimensions.radius),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invite Code',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.mutedText),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                farm!.inviteCode!,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                _copyInviteCode(farm!.inviteCode!);
                              },
                              icon: const Icon(Icons.copy_outlined),
                            ),
                          ],
                        ),
                        Text(
                          'Share this code with farm managers and workers',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingLarge),
        FilledButton(
          onPressed: _saving ? null : _saveProfile,
          child: Text(_saving ? 'Saving...' : 'Save Changes'),
        ),
        const SizedBox(height: AppDimensions.spacingLarge),
      ],
    );
  }
}

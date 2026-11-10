import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:proj/app/theme/app_colors.dart';
import 'package:proj/app/theme/app_dimensions.dart';

class ConnectedDevicesSection extends ConsumerStatefulWidget {
  const ConnectedDevicesSection({super.key});

  @override
  ConsumerState<ConnectedDevicesSection> createState() =>
      _ConnectedDevicesSectionState();
}

class _ConnectedDevicesSectionState
    extends ConsumerState<ConnectedDevicesSection> {
  bool _cameraAllowed = false;
  bool _bluetoothAllowed = false;
  bool _locationAllowed = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final statuses = await Future.wait([
      Permission.camera.status,
      Permission.bluetooth.status,
      Permission.locationWhenInUse.status,
    ]);
    if (!mounted) return;
    setState(() {
      _cameraAllowed = statuses[0].isGranted;
      _bluetoothAllowed = statuses[1].isGranted;
      _locationAllowed = statuses[2].isGranted;
    });
  }

  Future<void> _requestPermission(Permission permission, String label) async {
    final status = await permission.request();
    if (!mounted) return;
    setState(() {
      if (permission == Permission.camera) _cameraAllowed = status.isGranted;
      if (permission == Permission.bluetooth) {
        _bluetoothAllowed = status.isGranted;
      }
      if (permission == Permission.locationWhenInUse) {
        _locationAllowed = status.isGranted;
      }
    });
    if (status.isPermanentlyDenied) {
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('$label permission is blocked'),
          content: const Text(
            'Enable this permission in system settings to use the feature.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
      if (openSettings == true) await openAppSettings();
    } else if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label permission was not granted.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppDimensions.pagePadding),
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Device permissions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              _DeviceTile(
                icon: Icons.scale,
                title: 'Weighing scale access',
                subtitle: 'Allow Bluetooth access for supported scales',
                hasPermission: _bluetoothAllowed,
                onTap: () =>
                    _requestPermission(Permission.bluetooth, 'Bluetooth'),
              ),
              const Divider(),
              _DeviceTile(
                icon: Icons.location_on,
                title: 'Location access',
                subtitle: 'Allow location access for farm location features',
                hasPermission: _locationAllowed,
                onTap: () => _requestPermission(
                  Permission.locationWhenInUse,
                  'Location',
                ),
              ),
              const Divider(),
              _DeviceTile(
                icon: Icons.camera_alt,
                title: 'Camera access',
                subtitle: 'Allow the camera for photos and records',
                hasPermission: _cameraAllowed,
                onTap: () => _requestPermission(Permission.camera, 'Camera'),
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
                'App Permissions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              SwitchListTile(
                title: const Text('Camera'),
                subtitle: const Text('Allow access to device camera'),
                value: _cameraAllowed,
                onChanged: (_) =>
                    _requestPermission(Permission.camera, 'Camera'),
              ),
              SwitchListTile(
                title: const Text('Bluetooth'),
                subtitle: const Text('Allow compatible Bluetooth access'),
                value: _bluetoothAllowed,
                onChanged: (_) =>
                    _requestPermission(Permission.bluetooth, 'Bluetooth'),
              ),
              SwitchListTile(
                title: const Text('Location'),
                subtitle: const Text('Allow access to device location'),
                value: _locationAllowed,
                onChanged: (_) => _requestPermission(
                  Permission.locationWhenInUse,
                  'Location',
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.hasPermission,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool hasPermission;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: AppColors.primaryGreen),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: Icon(
      hasPermission ? Icons.check_circle : Icons.chevron_right,
      color: hasPermission ? AppColors.success : null,
    ),
    onTap: onTap,
  );
}

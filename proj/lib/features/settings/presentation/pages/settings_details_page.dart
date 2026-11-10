import 'package:flutter/material.dart';
import 'package:proj/features/settings/presentation/pages/sections/backup_section.dart';
import 'package:proj/features/settings/presentation/pages/sections/connected_devices_section.dart';
import 'package:proj/features/settings/presentation/pages/sections/payment_section.dart';
import 'package:proj/features/settings/presentation/pages/sections/profile_section.dart';
import 'package:proj/features/settings/presentation/pages/sections/security_section.dart';
import 'package:proj/features/settings/presentation/pages/sections/support_section.dart';
import 'package:proj/features/settings/presentation/pages/sections/user_management_section.dart';
import 'package:proj/features/settings/presentation/pages/sections/notification_section.dart';
import 'package:proj/app/routes/permission_route.dart';
import 'package:proj/security/authorization/permissions.dart';

class SettingsDetailsPage extends StatelessWidget {
  const SettingsDetailsPage({required this.initialTab, super.key});

  final String initialTab;

  static const _tabs = <String, int>{
    'profile': 0,
    'security': 1,
    'payment': 2,
    'backup': 3,
    'devices': 4,
    'support': 5,
    'team': 6,
    'notifications': 7,
  };

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: _tabs.length,
    initialIndex: _tabs[initialTab] ?? 0,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Profile'),
            Tab(text: 'Security'),
            Tab(text: 'Payments'),
            Tab(text: 'Backup'),
            Tab(text: 'Devices'),
            Tab(text: 'Support'),
            Tab(text: 'Members'),
            Tab(text: 'Notifications'),
          ],
        ),
      ),
      body: const TabBarView(
        children: [
          ProfileSection(),
          SecuritySection(),
          PaymentSection(),
          BackupSection(),
          ConnectedDevicesSection(),
          SupportSection(),
          PermissionRoute(
            permission: AppPermission.manageMembers,
            child: UserManagementSection(),
          ),
          NotificationSection(),
        ],
      ),
    ),
  );
}

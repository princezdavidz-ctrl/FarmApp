import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../shared/components/bottom_navigation.dart';

class FarmHubPage extends StatelessWidget {
  const FarmHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final modules = <({IconData icon, String title, String subtitle, String route})>[
      (icon: Icons.pets_outlined, title: 'Animals & livestock', subtitle: 'Herd records, breeding and animal health', route: AppRoutes.herd),
      (icon: Icons.agriculture_outlined, title: 'Crops & fields', subtitle: 'Crop cycles, plots and field activities', route: AppRoutes.crops),
      (icon: Icons.grass_outlined, title: 'Feed & supplies', subtitle: 'Feed schedules, formulations and stock', route: AppRoutes.feed),
      (icon: Icons.favorite_outline, title: 'Breeding', subtitle: 'Breeding records and schedules', route: AppRoutes.breeding),
      (icon: Icons.task_alt_outlined, title: 'Farm tasks', subtitle: 'Daily work and assigned activities', route: AppRoutes.tasks),
      (icon: Icons.point_of_sale_outlined, title: 'Sales', subtitle: 'Sales, customers and buyers', route: AppRoutes.salesAndExpenses),
    ];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Open menu',
          icon: const Icon(Icons.menu),
          onPressed: () => navigationScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Farm'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Manage your farm', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Open the tools and records for your farming activities.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 18),
          ...modules.map((module) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              minVerticalPadding: 12,
              leading: CircleAvatar(child: Icon(module.icon)),
              title: Text(module.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(module.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(module.route),
            ),
          )),
        ],
      ),
    );
  }
}

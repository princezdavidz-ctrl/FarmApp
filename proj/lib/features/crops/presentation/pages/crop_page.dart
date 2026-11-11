import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/components/bottom_navigation.dart';

class CropPage extends StatelessWidget {
  const CropPage({super.key});

  static const _modules = <({IconData icon, String title, String detail})>[
    (
      icon: Icons.map_outlined,
      title: 'Fields & plots',
      detail: 'Organise farm land, plot sizes and soil details.',
    ),
    (
      icon: Icons.grass_outlined,
      title: 'Crop cycles',
      detail: 'Track crop varieties, planting dates and growth stages.',
    ),
    (
      icon: Icons.water_drop_outlined,
      title: 'Irrigation',
      detail: 'Plan watering schedules and record irrigation.',
    ),
    (
      icon: Icons.compost_outlined,
      title: 'Inputs & soil',
      detail: 'Manage seeds, fertiliser, soil amendments and usage.',
    ),
    (
      icon: Icons.pest_control_outlined,
      title: 'Pests & diseases',
      detail: 'Record field observations and crop protection actions.',
    ),
    (
      icon: Icons.agriculture_outlined,
      title: 'Harvests',
      detail: 'Record harvest quantities, quality and crop sales.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop farming'),
        leading: IconButton(
          tooltip: 'Open menu',
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => navigationScaffoldKey.currentState?.openDrawer(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryGreen, AppColors.deepGreen],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepGreen.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.agriculture_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Grow smarter, season by season.',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage fields, crop cycles, farm inputs and harvests alongside your livestock operations.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.86),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('Crop management', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'The crop workspace is being connected to the farm records service. No sample figures or placeholder crop records are shown.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          for (final module in _modules) ...[
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(module.icon, color: AppColors.primaryGreen),
                ),
                title: Text(
                  module.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(module.detail),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.55,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Next: connect secure, farm-scoped crop records so field, planting, input and harvest changes are saved to the selected farm.',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

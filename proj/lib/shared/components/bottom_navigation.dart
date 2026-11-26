import 'package:flutter/material.dart';

final GlobalKey<ScaffoldState> navigationScaffoldKey = GlobalKey<ScaffoldState>();

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: selectedIndex,
    onDestinationSelected: onSelected,
    destinations: const [
      NavigationDestination(
        icon: _Icons8TabIcon(slug: 'home--v1', fallback: Icons.home_outlined),
        selectedIcon: _Icons8TabIcon(slug: 'home--v1', fallback: Icons.home_rounded),
        label: 'Home',
      ),
      NavigationDestination(
        icon: _Icons8TabIcon(slug: 'tractor', fallback: Icons.agriculture_outlined),
        selectedIcon: _Icons8TabIcon(slug: 'tractor', fallback: Icons.agriculture_rounded),
        label: 'Farm',
      ),
      NavigationDestination(
        icon: _Icons8TabIcon(slug: 'robot-2', fallback: Icons.smart_toy_outlined),
        selectedIcon: _Icons8TabIcon(slug: 'robot-2', fallback: Icons.smart_toy_rounded),
        label: 'AI',
      ),
    ],
  );
}

class _Icons8TabIcon extends StatelessWidget {
  const _Icons8TabIcon({required this.slug, required this.fallback});

  final String slug;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color;
    return Image.network(
      'https://img.icons8.com/ios/50/$slug.png',
      width: 24,
      height: 24,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      errorBuilder: (context, error, stackTrace) =>
          Icon(fallback, size: 24, color: color),
    );
  }
}

import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';

final navigationScaffoldKey = GlobalKey<ScaffoldState>();

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
    this.showHerd = true,
    this.showFeed = true,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool showHerd;
  final bool showFeed;

  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: selectedIndex,
    onDestinationSelected: onSelected,
    destinations: [
      NavigationDestination(
        icon: const Icon(Icons.dashboard_outlined),
        selectedIcon: const Icon(Icons.dashboard),
        label: AppLocalizations.of(context)!.home,
      ),
      if (showHerd)
        NavigationDestination(
          icon: const Icon(Icons.pets_outlined),
          label: AppLocalizations.of(context)!.herd,
        ),
      if (showFeed)
        NavigationDestination(
          icon: const Icon(Icons.grass_outlined),
          label: AppLocalizations.of(context)!.feed,
        ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: AppLocalizations.of(context)!.profile,
      ),
    ],
  );
}

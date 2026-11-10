import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/routes/app_routes.dart';
import '../../domain/entities/farm.dart';
import '../../domain/entities/session.dart';
import '../widgets/farm_card.dart';
import '../providers/auth_provider.dart';

class FarmSelectionPage extends ConsumerWidget {
  const FarmSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider).valueOrNull;
    final farms = session?.farms ?? const <Farm>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your farm')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(
            'Where are we working today?',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text('Select a farm to open its home page.'),
          const SizedBox(height: 24),
          if (farms.isEmpty) ...[
            const Text('You are not connected to a farm yet.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.farmManagement),
              icon: const Icon(Icons.search_outlined),
              label: const Text('Find a farm to work with'),
            ),
          ],
          ...farms.map(
            (farm) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FarmCard(
                farm: farm,
                onTap: () {
                  ref
                      .read(authProvider.notifier)
                      .setSession(
                        Session(
                          accessToken: session!.accessToken,
                          refreshToken: session.refreshToken,
                          user: session.user,
                          farms: session.farms,
                          selectedFarm: farm,
                        ),
                      );
                  context.go(AppRoutes.home);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

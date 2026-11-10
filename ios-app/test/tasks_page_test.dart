import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/features/auth/domain/entities/farm.dart';
import 'package:proj/features/auth/domain/entities/session.dart';
import 'package:proj/features/auth/domain/entities/user.dart';
import 'package:proj/features/auth/presentation/providers/auth_provider.dart';
import 'package:proj/features/settings/presentation/providers/farm_access_provider.dart';
import 'package:proj/features/tasks/data/farm_task.dart';
import 'package:proj/features/tasks/presentation/pages/tasks_page.dart';
import 'package:proj/features/tasks/presentation/providers/farm_tasks_provider.dart';
import 'package:proj/l10n/generated/app_localizations.dart';
import 'package:proj/security/authorization/roles.dart';

void main() {
  testWidgets('tasks page renders persisted farm tasks for the selected farm', (
    WidgetTester tester,
  ) async {
    final session = Session(
      accessToken: 'token',
      refreshToken: 'refresh',
      user: const User(
        id: 'owner-1',
        name: 'Farm Owner',
        email: 'owner@example.com',
        role: UserRole.farmOwner,
      ),
      farms: const [Farm(id: 'farm-1', name: 'Test Farm')],
      selectedFarm: const Farm(id: 'farm-1', name: 'Test Farm'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _TestAuthNotifier(session)),
          farmTasksProvider.overrideWith(_TestFarmTasksNotifier.new),
          farmAccessProvider.overrideWith(_TestFarmAccessNotifier.new),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TasksPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Farm tasks'), findsOneWidget);
    expect(find.text('Due today'), findsWidgets);
    expect(find.text('Check the nursery feed'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this.session);
  final Session session;

  @override
  AsyncValue<Session?> build() => AsyncData(session);
}

class _TestFarmTasksNotifier extends FarmTasksNotifier {
  @override
  Future<List<FarmTask>> build() async => [
    const FarmTask(
      id: '1',
      title: 'Check the nursery feed',
      priority: 'high',
      category: 'feeding',
      status: 'open',
      assignedTo: 'worker-1',
      assigneeName: 'Farm Worker',
    ),
  ];
}

class _TestFarmAccessNotifier extends FarmAccessNotifier {
  @override
  Future<FarmAccessState> build() async => const FarmAccessState(members: []);
}

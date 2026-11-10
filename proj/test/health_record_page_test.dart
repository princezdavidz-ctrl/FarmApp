import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/features/health/presentation/widgets/add_health_record_page.dart';
import 'package:proj/features/herd/domain/entities/animal.dart';
import 'package:proj/features/herd/presentation/providers/herd_provider.dart';

void main() {
  testWidgets(
    'health record page submits a herd animal id and date-only visit',
    (tester) async {
      Map<String, dynamic>? submitted;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [herdProvider.overrideWith(_TestHerdNotifier.new)],
          child: MaterialApp(
            home: AddHealthRecordPage(
              onSubmit: (data) async => submitted = data,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('PIG-001 · sow').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save Record'));
      await tester.tap(find.text('Save Record'));
      await tester.pumpAndSettle();

      expect(submitted?['animal_id'], '17');
      final visitDate = DateTime.parse(submitted!['visit_date'] as String);
      expect(visitDate.hour, 0);
      expect(visitDate.minute, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('health record page shows API validation errors', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [herdProvider.overrideWith(_TestHerdNotifier.new)],
        child: MaterialApp(
          home: AddHealthRecordPage(
            onSubmit: (_) async => throw Exception(
              'The selected pig does not belong to this farm.',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('PIG-001 · sow').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Record'));
    await tester.tap(find.text('Save Record'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Could not save the health record: Exception: The selected pig does not belong to this farm.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _TestHerdNotifier extends HerdNotifier {
  @override
  Future<List<Animal>> build() async => const [
    Animal(
      id: '17',
      tag: 'PIG-001',
      type: 'sow',
      sex: 'female',
      status: 'active',
    ),
  ];
}

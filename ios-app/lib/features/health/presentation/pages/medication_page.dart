import 'package:flutter/material.dart';
import 'health_page.dart';

class MedicationPage extends StatelessWidget {
  const MedicationPage({super.key});

  @override
  Widget build(BuildContext context) => const HealthPage(
    key: ValueKey('medication-records'),
    initialTypeFilter: 'medication',
  );
}

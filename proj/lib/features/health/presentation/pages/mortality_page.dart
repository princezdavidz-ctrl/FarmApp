import 'package:flutter/material.dart';
import 'health_page.dart';

class MortalityPage extends StatelessWidget {
  const MortalityPage({super.key});

  @override
  Widget build(BuildContext context) => const HealthPage(
    key: ValueKey('mortality-records'),
    initialTypeFilter: 'mortality',
  );
}

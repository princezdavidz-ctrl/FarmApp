import 'package:flutter/material.dart';
import 'health_page.dart';

class DewormingPage extends StatelessWidget {
  const DewormingPage({super.key});

  @override
  Widget build(BuildContext context) => const HealthPage(
    key: ValueKey('deworming-records'),
    initialTypeFilter: 'deworming',
  );
}

import 'package:flutter/material.dart';
import '../../../../shared/widgets/module_page.dart';

class UsagePage extends StatelessWidget {
  const UsagePage({super.key});
  @override
  Widget build(BuildContext context) => const ModulePage(
    title: 'Feed usage',
    description: 'Track feed consumption by group and period.',
    icon: Icons.receipt_long_outlined,
  );
}

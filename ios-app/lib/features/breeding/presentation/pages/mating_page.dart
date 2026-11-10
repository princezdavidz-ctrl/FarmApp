import 'package:flutter/material.dart';
import '../../../../shared/widgets/module_page.dart';

class MatingPage extends StatelessWidget {
  const MatingPage({super.key});
  @override
  Widget build(BuildContext context) => const ModulePage(
    title: 'Insemination',
    description: 'Record and review insemination activity.',
    icon: Icons.favorite_outline,
  );
}

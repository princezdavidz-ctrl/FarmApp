import 'package:flutter/material.dart';
import '../../../../shared/widgets/module_page.dart';

class FormulationPage extends StatelessWidget {
  const FormulationPage({super.key});
  @override
  Widget build(BuildContext context) => const ModulePage(
    title: 'Formulations',
    description: 'Build and review feed formulations.',
    icon: Icons.science_outlined,
  );
}

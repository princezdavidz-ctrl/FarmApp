import 'package:flutter/material.dart';
import 'finance_page.dart';

class IncomePage extends StatelessWidget {
  const IncomePage({super.key});

  @override
  Widget build(BuildContext context) => const FinancePage(typeFilter: 'income');
}

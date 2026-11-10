import 'package:flutter/material.dart';
import 'finance_page.dart';

class ExpensesPage extends StatelessWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const FinancePage(typeFilter: 'expense');
}

import 'package:flutter/material.dart';
import '../../domain/entities/farm.dart';

class FarmCard extends StatelessWidget {
  const FarmCard({required this.farm, required this.onTap, super.key});
  final Farm farm;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(leading: const Icon(Icons.agriculture), title: Text(farm.name), subtitle: farm.location == null ? null : Text(farm.location!), trailing: const Icon(Icons.chevron_right), onTap: onTap));
}

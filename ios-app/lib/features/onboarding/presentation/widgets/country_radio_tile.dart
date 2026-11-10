import 'package:flutter/material.dart';

class CountryRadioTile extends StatelessWidget {
  const CountryRadioTile({
    required this.country,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final String country;
  final bool selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final value = country.substring(country.indexOf('  ') + 2);

    return Card(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surface,
      child: ListTile(
        leading: Checkbox(
          value: selected,
          onChanged: (_) => onChanged(value),
          activeColor: Theme.of(context).colorScheme.primary,
        ),
        title: Text(country),
        trailing: Icon(
          Icons.public_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: () => onChanged(value),
      ),
    );
  }
}

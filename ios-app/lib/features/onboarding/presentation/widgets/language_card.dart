import 'package:flutter/material.dart';

class LanguageCard extends StatelessWidget {
  const LanguageCard({
    required this.flag,
    required this.nativeName,
    required this.translation,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String flag;
  final String nativeName;
  final String translation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: selected
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surface,
    child: AnimatedContainer(
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  flag,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nativeName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      translation,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: MediaQuery.of(context).disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                child: selected
                    ? Icon(
                        Icons.check_circle,
                        key: const ValueKey('selected'),
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : const SizedBox(key: ValueKey('unselected'), width: 24),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

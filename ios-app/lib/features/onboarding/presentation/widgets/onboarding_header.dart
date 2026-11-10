import 'package:flutter/material.dart';
import 'package:proj/app/theme/app_colors.dart';

class OnboardingHeader extends StatelessWidget {
  const OnboardingHeader({
    required this.title,
    required this.subtitle,
    this.eyebrow,
    super.key,
  });

  final String title;
  final String subtitle;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (eyebrow != null) ...[
        Text(
          eyebrow!.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            letterSpacing: 1.2,
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
      ],
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      Text(
        subtitle,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: AppColors.mutedText),
      ),
    ],
  );
}

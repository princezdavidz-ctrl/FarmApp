import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../features/settings/presentation/providers/profile_image_provider.dart';

class ProfileAvatar extends ConsumerWidget {
  const ProfileAvatar({required this.initials, this.radius = 30, super.key});

  final String initials;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imagePath = ref.watch(profileImageProvider).valueOrNull;
    final size = radius * 2;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: imagePath == null
            ? _InitialsAvatar(initials: initials, radius: radius)
            : Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _InitialsAvatar(initials: initials, radius: radius),
              ),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials, required this.radius});

  final String initials;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.inverseText.withValues(alpha: 0.18),
    alignment: Alignment.center,
    child: Text(
      initials,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: AppColors.inverseText,
        fontSize: radius * 0.75,
      ),
    ),
  );
}

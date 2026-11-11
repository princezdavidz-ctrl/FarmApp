import 'package:flutter/material.dart';

/// Consistent FarmApp identity mark used across launch and authentication.
class FarmAppMark extends StatelessWidget {
  const FarmAppMark({super.key, this.size = 112});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'FarmApp',
      image: true,
      child: Image.asset(
        'assets/images/app_icon.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.agriculture_outlined,
          size: size * 0.78,
          color: Theme.of(context).colorScheme.primary,
          semanticLabel: 'FarmApp',
        ),
      ),
    );
  }
}

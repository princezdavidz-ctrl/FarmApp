import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
	const AppButton({required this.label, required this.onPressed, this.icon, super.key});

	final String label;
	final VoidCallback? onPressed;
	final IconData? icon;

	@override
	Widget build(BuildContext context) => ElevatedButton.icon(
			onPressed: onPressed,
			icon: icon == null ? const SizedBox.shrink() : Icon(icon),
			label: Text(label),
		);
}

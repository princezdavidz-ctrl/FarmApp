import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
	const AppCard({required this.child, this.padding, super.key});

	final Widget child;
	final EdgeInsetsGeometry? padding;

	@override
	Widget build(BuildContext context) => Card(
			child: Padding(padding: padding ?? const EdgeInsets.all(16), child: child),
		);
}

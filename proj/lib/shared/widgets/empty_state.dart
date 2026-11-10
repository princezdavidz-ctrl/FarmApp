import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
	const EmptyState({required this.title, this.message, super.key});

	final String title;
	final String? message;

	@override
	Widget build(BuildContext context) => Center(
			child: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					const Icon(Icons.inbox_outlined, size: 48),
					Text(title, style: Theme.of(context).textTheme.titleLarge),
					if (message != null) Text(message!),
				],
			),
		);
}

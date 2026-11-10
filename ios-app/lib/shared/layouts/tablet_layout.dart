import 'package:flutter/widgets.dart';

class TabletLayout extends StatelessWidget {
	const TabletLayout({required this.child, super.key});

	final Widget child;

	@override
	Widget build(BuildContext context) => Center(child: ConstrainedBox(
			constraints: const BoxConstraints(maxWidth: 960),
			child: child,
		));
}

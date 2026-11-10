import 'package:flutter/widgets.dart';

class ResponsiveBuilder extends StatelessWidget {
	const ResponsiveBuilder({required this.mobile, this.tablet, this.desktop, super.key});

	final WidgetBuilder mobile;
	final WidgetBuilder? tablet;
	final WidgetBuilder? desktop;

	@override
	Widget build(BuildContext context) {
		final width = MediaQuery.sizeOf(context).width;
		if (width >= 1200 && desktop != null) return desktop!(context);
		if (width >= 600 && tablet != null) return tablet!(context);
		return mobile(context);
	}
}

import 'package:flutter/material.dart';

class LoadingWidget extends StatelessWidget {
	const LoadingWidget({this.message = 'Loading...', super.key});

	final String message;

	@override
	Widget build(BuildContext context) => Column(
			mainAxisSize: MainAxisSize.min,
			children: [const CircularProgressIndicator(), const SizedBox(height: 12), Text(message)],
		);
}

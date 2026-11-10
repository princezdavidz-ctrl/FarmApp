import 'package:flutter/material.dart';

Future<bool> showConfirmationDialog(BuildContext context, {required String title, required String message}) async {
		return await showDialog<bool>(
			context: context,
			builder: (context) => AlertDialog(
				title: Text(title),
				content: Text(message),
				actions: [
					TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
					FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
				],
			),
		) ?? false;
}

import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
	const AppTextField({this.controller, this.label, this.hint, this.obscureText = false, super.key});

	final TextEditingController? controller;
	final String? label;
	final String? hint;
	final bool obscureText;

	@override
	Widget build(BuildContext context) => TextField(
			controller: controller,
			obscureText: obscureText,
			decoration: InputDecoration(labelText: label, hintText: hint),
		);
}

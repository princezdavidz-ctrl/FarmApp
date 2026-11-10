import 'package:flutter/material.dart';

class PasswordField extends StatefulWidget {
  const PasswordField({this.controller, super.key});
  final TextEditingController? controller;
  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool obscure = true;
  @override
  Widget build(BuildContext context) => TextField(
        controller: widget.controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: 'Password',
          suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => obscure = !obscure)),
        ),
      );
}

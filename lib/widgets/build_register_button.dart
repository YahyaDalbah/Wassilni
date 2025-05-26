import 'package:flutter/material.dart';
import 'package:wassilni/pages/auth/register_page.dart';

Widget buildRegisterButton(BuildContext context) {
  return TextButton(
    style: TextButton.styleFrom(
      textStyle: const TextStyle(decoration: TextDecoration.underline),
    ),
    onPressed: () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const RegisterPage()),
      );
    },
    child: const Text(
      "Don't have account ?",
      style: TextStyle(decoration: TextDecoration.underline),
    ),
  );
}
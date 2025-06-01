import 'package:flutter/material.dart';
import 'package:wassilni/pages/auth/register_page.dart';

class BuildRegisterButton extends StatelessWidget {
  const BuildRegisterButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        textStyle: TextStyle(decoration: TextDecoration.underline),
      ),
      onPressed: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => RegisterPage()),
        );
      },
      child: Text(
        "Don't have account ?",
        style: TextStyle(decoration: TextDecoration.underline),
      ),
    );
  }
}


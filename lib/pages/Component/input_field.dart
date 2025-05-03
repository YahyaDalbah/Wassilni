import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class InputField extends StatelessWidget {
  final TextEditingController controller;
  final FormFieldValidator<String> validate;
  final String text;
  final String? prefixText;
  final bool obscureText;
  final TextInputType keyboardType;
  const InputField({
    super.key,
    required this.controller,
    required this.validate,
    required this.text,
    this.prefixText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        prefixText: prefixText,
        prefixStyle: TextStyle(color: Colors.white, fontSize: 20),
        errorStyle: TextStyle(
          fontSize: 16,
          color: Colors.red[400],
          fontWeight: FontWeight.w500,
        ),
        label: RichText(
          text: TextSpan(
            text: text,
            style: TextStyle(color: Colors.grey, fontSize: 20),
            children: <TextSpan>[
              TextSpan(text: '*', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white54),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
        ),
      ),
      style: TextStyle(color: Colors.white, fontSize: 20),
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validate,
    );
  }
}

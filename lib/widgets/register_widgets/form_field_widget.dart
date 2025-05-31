import 'package:flutter/material.dart';
import 'package:wassilni/pages/Component/input_field.dart';
import './phone_field_widget.dart';

class BuildFormFields extends StatelessWidget {
  final TextEditingController phoneController;
  final TextEditingController passwordController;

  const BuildFormFields({
    super.key,
    required this.phoneController,
    required this.passwordController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BuildPhoneNumberField(controller: phoneController),
        SizedBox(height: 20),
        InputField(
          controller: passwordController,
          validate: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter password';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
          text: "Password ",
          obscureText: true,
        ),
      ],
    );
  }
}

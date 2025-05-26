import 'package:flutter/material.dart';
import 'package:wassilni/pages/Component/input_field.dart';
import 'package:wassilni/widgets/phone_number_fields_widget.dart';

class FormFields extends StatelessWidget {
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final ValueChanged<String> onCountryChanged;

  const FormFields({
    super.key,
    required this.phoneController,
    required this.passwordController,
    required this.onCountryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PhoneNumberField(
          controller: phoneController,
          onCountryChanged: onCountryChanged,
        ),
        const SizedBox(height: 20),
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
          text: "Password",
          obscureText: true,
        ),
      ],
    );
  }
}
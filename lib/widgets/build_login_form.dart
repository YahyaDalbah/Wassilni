import 'package:flutter/material.dart';

Widget buildLoginForm({
  required GlobalKey<FormState> formState,
  required TextEditingController phoneController,
  required TextEditingController passwordController,
}) {
  return Form(
    autovalidateMode: AutovalidateMode.onUserInteraction,
    key: formState,
    child: Column(
      children: [
        TextFormField(
          controller: phoneController,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (val) {
            if (val == null || val.isEmpty) {
              return "Phone number is required";
            }
            if (val.length < 10 || val.length > 15) {
              return "Your number must be between 10 - 15 digits";
            }
            return null;
          },
          decoration: const InputDecoration(
            prefixText: '+',
            contentPadding: EdgeInsets.symmetric(vertical: 10),
            prefixStyle: TextStyle(color: Colors.white, fontSize: 20),
            labelText: "Phone",
            labelStyle: TextStyle(color: Colors.grey, fontSize: 20),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white54),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 20),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: passwordController,
          obscureText: true,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(
            labelText: "Password",
            labelStyle: TextStyle(color: Colors.grey, fontSize: 20),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white54),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white),
            ),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 20),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Password is required';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
      ],
    ),
  );
}
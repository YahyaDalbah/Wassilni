import 'package:flutter/material.dart';

Widget buildLoginButton({
  required bool isLoading,
  required GlobalKey<FormState> formState,
  required TextEditingController phoneController,
  required TextEditingController passwordController,
  required Future<void> Function(String, String) onLogin,
  required BuildContext context,
}) {
  return ElevatedButton(
    onPressed: isLoading
        ? null
        : () async {
            if (formState.currentState!.validate()) {
              try {
                await onLogin(
                  "+${phoneController.text}",
                  passwordController.text,
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString()),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      minimumSize: const Size(300, 50),
      textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          )
        : const Text("Login"),
  );
}
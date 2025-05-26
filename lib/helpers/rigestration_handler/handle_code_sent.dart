import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wassilni/pages/auth/verify_phone_page.dart';

class RegistrationHandler {
  final BuildContext context;
  final TextEditingController passwordController;
  DateTime? lastSmsTime;

  RegistrationHandler(this.context, this.passwordController);

  Future<void> handleVerificationCompleted(PhoneAuthCredential credential, String phoneNumber) async {
    if (context.mounted) {
      try {
        await FirebaseAuth.instance.signInWithCredential(credential);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone number verified automatically'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void handleCodeSent(String verificationId, String phoneNumber) {
    lastSmsTime = DateTime.now();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification code sent successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VerifyPhonePage(
            verificationId: verificationId,
            phoneNumber: phoneNumber,
            password: passwordController.text,
          ),
        ),
      );
    }
  }
}
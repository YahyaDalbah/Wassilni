import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VerificationFailureHandler {
  final BuildContext context;

  const VerificationFailureHandler(this.context);

  void handleFailure(FirebaseAuthException e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification failed: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
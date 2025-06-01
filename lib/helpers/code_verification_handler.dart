import 'package:flutter/material.dart';
import 'package:wassilni/services/verification_service.dart';
import '../pages/rider_screen.dart';

class CodeVerificationHandler {
  final BuildContext context;
  final VerificationService verificationService;
  final String verificationId;
  final String phoneNumber;
  final String password;
  final Function(bool) setLoading;

  CodeVerificationHandler({
    required this.context,
    required this.verificationService,
    required this.verificationId,
    required this.phoneNumber,
    required this.password,
    required this.setLoading,
  });

  Future<void> validateCode(String enteredCode) async {
    if (enteredCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the complete verification code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setLoading(true);

    try {
      await verificationService.verifyPhoneAndCreateUser(
        verificationId: verificationId,
        smsCode: enteredCode,
        phoneNumber: phoneNumber,
        password: password,
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone number verified successfully'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RiderScreen()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (context.mounted) {
        setLoading(false);
      }
    }
  }
}
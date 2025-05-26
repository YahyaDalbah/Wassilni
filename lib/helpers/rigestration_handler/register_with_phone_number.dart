import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:wassilni/helpers/rigestration_handler/handle_code_sent.dart';
import 'package:wassilni/helpers/rigestration_handler/handle_sms_timeout.dart';
import 'package:wassilni/helpers/rigestration_handler/handle_verification_failed.dart';

class PhoneRegistration {
  final BuildContext context;
  final GlobalKey<FormState> formKey;
  final String selectedCountryCode;
  final TextEditingController phoneController;
  final Function(bool) setLoading;
  final RegistrationHandler registrationHandler;
  final SmsTimeoutHandler timeoutHandler;
  final VerificationFailureHandler failureHandler;

  PhoneRegistration({
    required this.context,
    required this.formKey,
    required this.selectedCountryCode,
    required this.phoneController,
    required this.setLoading,
    required this.registrationHandler,
    required this.timeoutHandler,
    required this.failureHandler,
  });

  Future<void> register() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    final phoneNumber = selectedCountryCode + phoneController.text.trim();
    final canProceed = await timeoutHandler.handleSmsTimeout();
    if (!canProceed) return;

    setLoading(true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (credential) => registrationHandler.handleVerificationCompleted(credential, phoneNumber),
        verificationFailed: failureHandler.handleFailure,
        codeSent: (verificationId, resendToken) => registrationHandler.handleCodeSent(verificationId, phoneNumber),
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
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
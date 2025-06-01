import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wassilni/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:wassilni/pages/auth/verify_phone_page.dart';
import 'package:wassilni/pages/rider_screen.dart';

class RegisterFunctionsHandler {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  DateTime? _lastSmsTime;

  Future<void> handleSmsTimeout(String phoneNumber) async {
    if (_lastSmsTime != null) {
      final difference = DateTime.now().difference(_lastSmsTime!);
      if (difference.inSeconds < 60) {
        throw Exception('please ${60 - difference.inSeconds} seconds');
      }
    }
  }

  Future<void> registerWithPhoneNumber({
    required String phoneNumber,
    required String password,
    required BuildContext context,
  }) async {
    try {
      await handleSmsTimeout(phoneNumber);
      _lastSmsTime = DateTime.now();
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (credential) async {
          await _auth.signInWithCredential(credential);
          await _addUserToFirestore(phoneNumber, password);
          Navigator.pushReplacement(context, 
            MaterialPageRoute(builder: (_) => const RiderScreen()));
        },
        verificationFailed: (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message ?? 'error verification')));
        },
        codeSent: (verificationId, _) {
          Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => VerifyPhonePage(
              verificationId: verificationId,
              phoneNumber: phoneNumber,
              password: password,
            )));
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())));
    }
  }
}

Future<void> _addUserToFirestore(String phone, String pass) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await UserModel.addToFireStore(
      type: UserType.rider,
      password: pass,
      phone: phone,
      isOnline: true,
      vehicle: {"make": "", "model": "", "licensePlate": ""},
      location: const GeoPoint(0, 0),
    );
  }
}

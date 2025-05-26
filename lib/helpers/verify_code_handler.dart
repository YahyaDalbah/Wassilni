import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user_model.dart';
import '../pages/rider_screen.dart';

class VerifyCodeHandler {
  final BuildContext context;
  final List<TextEditingController> controllers;
  final String verificationId;
  final String phoneNumber;
  final String password;
  final Function(bool) setLoading;

  VerifyCodeHandler({
    required this.context,
    required this.controllers,
    required this.verificationId,
    required this.phoneNumber,
    required this.password,
    required this.setLoading,
  });

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  void showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> verifyCode() async {
    if (controllers.any((controller) => controller.text.isEmpty)) {
      showSnackBar('Please enter the complete verification code', isError: true);
      return;
    }
    setLoading(true);
    final enteredCode = controllers.map((c) => c.text).join();
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: enteredCode,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      await UserModel.addToFireStore(
        type: UserType.rider,
        phone: phoneNumber,
        password: _hashPassword(password),
        isOnline: true,
        vehicle: {"make": "", "model": "", "licensePlate": ""},
        location: const GeoPoint(0, 0),
      );
      showSnackBar('Phone number verified successfully', isError: false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const RiderScreen()),
      );
    } catch (e) {
      showSnackBar('Verification failed: \${e.toString()}', isError: true);
    } finally {
      setLoading(false);
    }
  }
}
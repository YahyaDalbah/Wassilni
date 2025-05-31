import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wassilni/models/user_model.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  Future<UserCredential> verifyPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {
    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    return await _auth.signInWithCredential(credential);
  }

  Future<void> createUserInFirestore({
    required String phoneNumber,
    required String password,
  }) async {
    await UserModel.addToFireStore(
      type: UserType.rider,
      phone: phoneNumber,
      password: _hashPassword(password),
      isOnline: true,
      vehicle: {
        "make": "",
        "model": "",
        "licensePlate": ""
      },
      location: const GeoPoint(0, 0),
    );
  }
}
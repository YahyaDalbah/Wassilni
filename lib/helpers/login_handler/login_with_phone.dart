import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wassilni/models/user_model.dart';
import 'package:wassilni/providers/user_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../pages/rider_screen.dart';
import '../../pages/driver_page.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class LoginHandler {
  final BuildContext context;
  final Function setLoading;
  final Function handleFailedLogin;
  final int loginAttempts;
  final DateTime? lastFailedLogin;

  LoginHandler({
    required this.context,
    required this.setLoading,
    required this.handleFailedLogin,
    required this.loginAttempts,
    required this.lastFailedLogin,
  });

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  Future<void> loginWithPhone(String phoneNumber, String password) async {
    if (lastFailedLogin != null) {
      final difference = DateTime.now().difference(lastFailedLogin!);
      if (difference.inMinutes < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Too many attempts. Please try again in \${60 - difference.inSeconds} seconds',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setLoading(true);
    try {
      String cleanPhoneNumber = phoneNumber.trim();
      if (!cleanPhoneNumber.startsWith('+')) {
        cleanPhoneNumber = '+\$cleanPhoneNumber';
      }

      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('phone', isEqualTo: cleanPhoneNumber)
              .get();

      if (querySnapshot.docs.isEmpty) {
        handleFailedLogin();
        throw Exception("Phone number not found");
      }

      final userData = querySnapshot.docs.first.data();
      final storedPassword = userData['password'];
      final hashedInputPassword = _hashPassword(password);

      if (storedPassword != hashedInputPassword) {
        handleFailedLogin();
        throw Exception("Phone number or password is incorrect");
      }

      final userProvider = Provider.of<UserProvider>(context, listen: false);

      if (loginAttempts != 0) {
        // Reset attempts if login successful
        handleFailedLogin(reset: true);
      }

      await userProvider.login(phoneNumber, password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('logged_in_phone', phoneNumber);

      if (userProvider.currentUser!.type == UserType.rider) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RiderScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DriverMap()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      setLoading(false);
    }
  }
}
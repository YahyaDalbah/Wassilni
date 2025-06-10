import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wassilni/models/user_model.dart';
import 'package:wassilni/pages/driver_page.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:wassilni/providers/user_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wassilni/widgets/login_widget/build_login_button.dart';
import 'package:wassilni/widgets/login_widget/build_login_form.dart';
import 'package:wassilni/widgets/login_widget/build_register_button.dart';
import 'package:wassilni/widgets/login_widget/header.dart';
import '../rider_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  GlobalKey<FormState> formState = GlobalKey();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  int _loginAttempts = 0;
  DateTime? _lastFailedLogin;

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  Future<void> _loginWithPhone(String phoneNumber, String password) async {
    if (_lastFailedLogin != null) {
      final difference = DateTime.now().difference(_lastFailedLogin!);
      if (difference.inMinutes < 1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Too many attempts. Please try again in ${60 - difference.inSeconds} seconds',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      } else {
        _loginAttempts = 0;
        _lastFailedLogin = null;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String cleanPhoneNumber = '+${phoneNumber.trim()}';
      if (!cleanPhoneNumber.startsWith('+')) {
        cleanPhoneNumber = '+$cleanPhoneNumber';
      }

      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('phone', isEqualTo: cleanPhoneNumber)
              .get();

      if (querySnapshot.docs.isEmpty) {
        _handleFailedLogin();
        throw Exception("Phone number not found");
      }

      final userData = querySnapshot.docs.first.data();
      final storedPassword = userData['password'];
      final hashedInputPassword = _hashPassword(password);

      if (storedPassword != hashedInputPassword) {
        _handleFailedLogin();
        throw Exception("Phone number or password is incorrect");
      }

      final userProvider = Provider.of<UserProvider>(context, listen: false);

      _loginAttempts = 0;
      _lastFailedLogin = null;

      if (mounted) {
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleFailedLogin() {
    _loginAttempts++;
    if (_loginAttempts >= 5) {
      _lastFailedLogin = DateTime.now();
      throw Exception("Too many failed attempts. Please try again in 1 minute");
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Widget _buildLoginForm() {
    return BuildLoginForm(
      formKey: formState,
      phoneController: _phoneController,
      passwordController: _passwordController,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white10,
      appBar: AppBar(
        title: Text(
          "Login Page",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        centerTitle: true,
        elevation: 2.6,
        shadowColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      BuildHeader(),
                      _buildLoginForm(),
                      BuildLoginButton(
                        isLoading: _isLoading,
                        onPressed: () {
                          if (formState.currentState!.validate()) {
                            _loginWithPhone(
                              _phoneController.text,
                              _passwordController.text,
                            );
                          }
                        },
                      ),
                      BuildRegisterButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

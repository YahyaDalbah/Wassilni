import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wassilni/pages/auth/register_page.dart';
import 'package:wassilni/pages/home_page.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:wassilni/providers/user_provider.dart';

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
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('phone', isEqualTo: phoneNumber)
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
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

  Widget _buildHeader() {
    return Column(
      children: [
        SizedBox(height: 100),
        Text(
          "Enter Your Phone Number",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 30),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Form(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      key: formState,
      child: Column(
        children: [
          TextFormField(
            controller: _phoneController,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (val) {
              if (val!.isEmpty) {
                return "Phone number is required";
              }
              if (!RegExp(r'^\+').hasMatch(val)) {
                return "Your number must start with (+) and your national prefix";
              }
              if (val.length < 10 || val.length > 15) {
                return "Your number must be between 10 - 15 digits";
              }
              return null;
            },
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(vertical: 10),
              prefixStyle: TextStyle(color: Colors.white, fontSize: 20),
              labelText: "Phone",
              labelStyle: TextStyle(color: Colors.grey, fontSize: 20),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white54),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
            style: TextStyle(color: Colors.white, fontSize: 20),
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: 20),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(
              labelText: "Password",
              labelStyle: TextStyle(color: Colors.grey, fontSize: 20),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white54),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
            style: TextStyle(color: Colors.white, fontSize: 20),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterButton() {
    return TextButton(
      style: TextButton.styleFrom(
        textStyle: TextStyle(decoration: TextDecoration.underline),
      ),
      onPressed: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => RegisterPage()),
        );
      },
      child: Text(
        "Don't have account ?",
        style: TextStyle(decoration: TextDecoration.underline),
      ),
    );
  }

  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed:
          _isLoading
              ? null
              : () async {
                if (formState.currentState!.validate()) {
                  try {
                    await _loginWithPhone(
                      _phoneController.text,
                      _passwordController.text,
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
        minimumSize: Size(300, 50),
        textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child:
          _isLoading
              ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
              : Text("Login"),
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
                      _buildHeader(),
                      _buildLoginForm(),
                      SizedBox(height: 20),
                      _buildRegisterButton(),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: _buildLoginButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

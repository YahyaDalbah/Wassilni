import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:wassilni/pages/Component/input_field.dart';
import 'package:wassilni/pages/auth/login_page.dart';
import 'package:wassilni/pages/auth/verify_email_page.dart';

class Registerpage extends StatefulWidget {
  const Registerpage({super.key});

  @override
  State<Registerpage> createState() => _RegisterpageState();
}

class _RegisterpageState extends State<Registerpage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

 Future<void> _sendCodeToEmail(String email) async {
    setState(() {
      _isLoading = true; 
    });
    
    try {
      final existingUser = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (existingUser.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This email is used try enter other email'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }
      final random = Random();
      final code = (random.nextInt(9000) + 1000).toString();

      await FirebaseFirestore.instance.collection('users').doc(email).set({
        'code': code,
      });

      _sendCode(email, code);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error occurs : ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
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

  void _sendCode(String email, String code) async {
    String username = "s12220672@stu.najah.edu";
    String password = "tvcg rwln jspb xxyd";
    final smtpServer = gmail(username, password);
    final message =
        Message()
          ..from = Address('Wasilni@gmail.com', 'Wasilni')
          ..recipients.add(email)
          ..subject = "Email Verification Code"
          ..text =
              "To verify your email in Wasilni app you should enter this code in Verification page"
              "The code is : $code";
    try {
      await send(message, smtpServer);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => VerifyEmailPage(
                email: email,
                password: _passwordController.text.trim(),
              ),
        ),
      );
    } catch (e) {
  
      debugPrint("Email send failed: $e");
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send verification email"),backgroundColor: Colors.red,),
      );
    }
  }

  void _register() {
    if (_formKey.currentState?.validate() ?? false) {
      final email = _emailController.text.trim();
      _sendCodeToEmail(email);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white10,
      appBar: AppBar(
        title: Text(
          "Register Page",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        centerTitle: true,
        elevation: 2,
        shadowColor: Colors.white30,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Form(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: 100),
                        Center(
                          child: Text(
                            "Enter Your Email and Password",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(height: 30),
                        InputField(
                          controller: _emailController,
                          validate: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                          text: "Email ",
                        ),
                        InputField(
                          controller: _passwordController,
                          text: "Password ",
                          validate: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                          obscureText: true,
                        ),
                        SizedBox(height: 20),
                        TextButton(
                          style: TextButton.styleFrom(
                            textStyle: TextStyle(decoration: TextDecoration.underline),
                          ),
                          onPressed: () {
                            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context)=>LoginPage()));
                          },
                          child: Text(
                            "Don you have account?",
                            style: TextStyle(decoration: TextDecoration.underline),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: Size(300, 50),
                      textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading 
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text("Confirm"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

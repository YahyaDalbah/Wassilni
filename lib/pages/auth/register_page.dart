import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:wassilni/models/user_model.dart';
import 'package:wassilni/pages/Component/input_field.dart';
import 'package:wassilni/pages/auth/login_page.dart';
import 'package:wassilni/pages/auth/verify_phone_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _selectedCountryCode = '+970';
  String _selectedCountryFlag = '🇵🇸';
  DateTime? _lastSmsTime;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSmsTimeout(String phoneNumber) async {
    if (_lastSmsTime != null) {
      final difference = DateTime.now().difference(_lastSmsTime!);
      if (difference.inSeconds < 60) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please wait ${60 - difference.inSeconds} seconds before trying again'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }
  }

  void _handleVerificationFailed(FirebaseAuthException e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification failed: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleCodeSent(String verificationId, String phoneNumber) {
    _lastSmsTime = DateTime.now();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification code sent successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VerifyPhonePage(
            verificationId: verificationId,
            phoneNumber: phoneNumber,
            password: _passwordController.text,
          ),
        ),
      );
    }
  }

  Future<void> _handleVerificationCompleted(PhoneAuthCredential credential, String phoneNumber) async {
    await _addUserToFirestore(phoneNumber, _passwordController.text);
    await FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<void> _registerWithPhoneNumber() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final phoneNumber = _selectedCountryCode + _phoneController.text.trim();
    await _handleSmsTimeout(phoneNumber);
    
    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (credential) => _handleVerificationCompleted(credential, phoneNumber),
        verificationFailed: _handleVerificationFailed,
        codeSent: (verificationId, resendToken) => _handleCodeSent(verificationId, phoneNumber),
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
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

   _buildAppBar() {
    return AppBar(
      title: Text(
        "Register Page",
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      backgroundColor: Colors.black,
      centerTitle: true,
      elevation: 2,
      shadowColor: Colors.white30,
    );
  }

  Widget _buildPhoneNumberField() {
    return Row(
      children: [
        Text(
          _selectedCountryFlag,
          style: TextStyle(fontSize: 24),
        ),
        IconButton(
          onPressed: () {
            showCountryPicker(
              context: context,
              showPhoneCode: true,
              onSelect: (Country country) {
                setState(() {
                  _selectedCountryCode = '+${country.phoneCode}';
                  _selectedCountryFlag = country.flagEmoji;
                });
              },
            );
          },
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        Expanded(
          child: InputField(
            controller: _phoneController,
            validate: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your phone number';
              }
              if(value.length < 8 || value.length > 10){
                return "The number must be between 8 - 10 digits";
              }
              return null;
            },
            text: "Phone Number ",
            prefixText: _selectedCountryCode,
            keyboardType: TextInputType.phone,
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        _buildPhoneNumberField(),
        SizedBox(height: 20),
        InputField(
          controller: _passwordController,
          validate: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter password';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
          text: "Password ",
          obscureText: true,
        ),
      ],
    );
  }

  Widget _buildConfirmButton() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _registerWithPhoneNumber,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white10,
      appBar: _buildAppBar(),
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
                        SizedBox(height: 50),
                        Center(
                          child: Text(
                            "Register with your phone number",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(height: 30),
                        _buildFormFields(),
                        SizedBox(height: 20),
                        TextButton(
                          style: TextButton.styleFrom(
                            textStyle: TextStyle(decoration: TextDecoration.underline),
                          ),
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (context) => LoginPage())
                            );
                          },
                          child: Text(
                            "Do you have account?",
                            style: TextStyle(decoration: TextDecoration.underline),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildConfirmButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _addUserToFirestore(String phoneNumber,String password) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await UserModel.addToFireStore(
      type: UserType.rider,
      password: password ,
      phone: phoneNumber,
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

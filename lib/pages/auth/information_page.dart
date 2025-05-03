import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:wassilni/pages/auth/login_page.dart';

class InformationPage extends StatefulWidget {
  const InformationPage({super.key});

  @override
  State<InformationPage> createState() => _InformationPageState();
}

class _InformationPageState extends State<InformationPage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _selectedCountryCode = '+970';
  String _selectedCountryFlag = '🇵🇸';
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveUserInfo() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true; 
      });
      
      try {
        final user = FirebaseAuth.instance.currentUser;
        final phoneNumber = '$_selectedCountryCode${_phoneController.text.trim()}';

        if (user != null) {
          final existingUser = await FirebaseFirestore.instance
              .collection('users')
              .where('phoneNumber', isEqualTo: phoneNumber)
              .limit(1)
              .get();

          if (existingUser.docs.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Phone number already in use'),backgroundColor: Colors.red,),
            );
            return;
          }
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'firstName': _firstNameController.text.trim(),
            'lastName': _lastNameController.text.trim(),
            'phoneNumber': phoneNumber,
            'email': user.email,
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Information saved successfully'),backgroundColor: Colors.green,),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => LoginPage()),
            );
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'),backgroundColor: Colors.red,),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false; 
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white10,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          "Personal Information",
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
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: 100),
                        Text(
                          "Enter Your Personal Information",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 30),
                        Row(
                          children: [
                            Expanded(
                              child: InputField(
                                controller: _firstNameController,
                                validate: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your first name';
                                  }
                                  return null;
                                },
                                text: "F Name ",
                              ),
                            ),
                            SizedBox(width: 20),
                            Expanded(
                              child: InputField(
                                controller: _lastNameController,
                                validate: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your last name';
                                  }
                                  return null;
                                },
                                text: "L Name ",
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Row(
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
                                  return null;
                                },
                                text: "Phone Number ",
                                prefixText: _selectedCountryCode,
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(bottom: 20),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveUserInfo, 
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: Size(300, 50),
                      textStyle: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
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
                        : Text("Next"),
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

class InputField extends StatelessWidget {
  final TextEditingController controller;
  final FormFieldValidator<String> validate;
  final String text;
  final String? prefixText;
  final bool obscureText;
  final TextInputType keyboardType;
  const InputField({
    super.key,
    required this.controller,
    required this.validate,
    required this.text,
    this.prefixText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        prefixText: prefixText,
        prefixStyle: TextStyle(color: Colors.white, fontSize: 20), 
        errorStyle: TextStyle( 
          fontSize: 16,
          color: Colors.red[400],
          fontWeight: FontWeight.w500,
        ),
        label: RichText(
          text: TextSpan(
            text: text,
            style: TextStyle(color: Colors.grey, fontSize: 20),
            children: <TextSpan>[
              TextSpan(text: '*', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white54),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
        ),
      ),
      style: TextStyle(color: Colors.white, fontSize: 20),
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validate,
    );
  }
}

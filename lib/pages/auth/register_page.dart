import 'package:flutter/material.dart';
import 'package:wassilni/helpers/register_functions_handler.dart';
import 'package:wassilni/pages/auth/login_page.dart';

import 'package:wassilni/widgets/register_widgets/confirm_button_widget.dart';
import 'package:wassilni/widgets/register_widgets/form_field_widget.dart';

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
  /*String _selectedCountryFlag = '🇵🇸';
  DateTime? _lastSmsTime;*/

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
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

  Future<void> _registerWithPhoneNumber() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await RegisterFunctionsHandler().registerWithPhoneNumber(
        phoneNumber: _selectedCountryCode + _phoneController.text,
        password: _passwordController.text,
        context: context,
      );
    } finally {
      setState(() => _isLoading = false);
    }
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
                        BuildFormFields(
                          phoneController: _phoneController,
                          passwordController: _passwordController,
                        ),
                        SizedBox(height: 20),
                        TextButton(
                          style: TextButton.styleFrom(
                            textStyle: TextStyle(
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => LoginPage(),
                              ),
                            );
                          },
                          child: Text(
                            "Do you have account?",
                            style: TextStyle(
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ConfirmButtonWidget(
                  isLoading: _isLoading,
                  onPressed: _registerWithPhoneNumber,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

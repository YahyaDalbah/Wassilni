import 'package:flutter/material.dart';
import 'package:wassilni/helpers/rigestration_handler/handle_code_sent.dart';
import 'package:wassilni/helpers/rigestration_handler/handle_sms_timeout.dart';
import 'package:wassilni/helpers/rigestration_handler/handle_verification_failed.dart';
import 'package:wassilni/helpers/rigestration_handler/register_with_phone_number.dart';
import 'package:wassilni/pages/auth/login_page.dart';
import 'package:wassilni/widgets/confirmation_button_widget.dart';
import 'package:wassilni/widgets/form_field_widget.dart';


class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _selectedCountryCode = '+970';
  DateTime? _lastSmsTime;

  late final _registrationHandler = RegistrationHandler(context, _passwordController);
  late final _timeoutHandler = SmsTimeoutHandler(context, _lastSmsTime);
  late final _failureHandler = VerificationFailureHandler(context);
  late final _phoneRegistration = PhoneRegistration(
    context: context,
    formKey: _formKey,
    selectedCountryCode: _selectedCountryCode,
    phoneController: _phoneController,
    setLoading: (bool value) => setState(() => _isLoading = value),
    registrationHandler: _registrationHandler,
    timeoutHandler: _timeoutHandler,
    failureHandler: _failureHandler,
  );

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white10,
      appBar: AppBar(
        title: const Text(
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 50),
                        const Text(
                          "Register with your phone number",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 30),
                        FormFields(
                          phoneController: _phoneController,
                          passwordController: _passwordController,
                          onCountryChanged: (code) => setState(() => _selectedCountryCode = code),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginPage()),
                          ),
                          child: const Text(
                            "Already have an account?",
                            style: TextStyle(decoration: TextDecoration.underline),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ConfirmationButton(
                  isLoading: _isLoading,
                  onPressed: _phoneRegistration.register,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
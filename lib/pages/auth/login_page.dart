import 'package:flutter/material.dart';
import 'package:wassilni/widgets/build_header.dart';
import 'package:wassilni/widgets/build_login_form.dart';
import 'package:wassilni/widgets/build_login_button.dart';
import 'package:wassilni/widgets/build_register_button.dart';
import 'package:wassilni/helpers/login_handler/login_with_phone.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> formState = GlobalKey();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  int _loginAttempts = 0;
  DateTime? _lastFailedLogin;

  void _setLoading(bool value) {
    setState(() {
      _isLoading = value;
    });
  }

  void _handleFailedLogin({bool reset = false}) {
    setState(() {
      if (reset) {
        _loginAttempts = 0;
        _lastFailedLogin = null;
      } else {
        _loginAttempts++;
        if (_loginAttempts >= 5) {
          _lastFailedLogin = DateTime.now();
          throw Exception("Too many failed attempts. Please try again in 1 minute");
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loginHandler = LoginHandler(
      context: context,
      setLoading: _setLoading,
      handleFailedLogin: _handleFailedLogin,
      loginAttempts: _loginAttempts,
      lastFailedLogin: _lastFailedLogin,
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildHeader(),
              buildLoginForm(
                formState: formState,
                phoneController: _phoneController,
                passwordController: _passwordController,
              ),
              const SizedBox(height: 40),
              buildLoginButton(
                isLoading: _isLoading,
                formState: formState,
                phoneController: _phoneController,
                passwordController: _passwordController,
                onLogin: loginHandler.loginWithPhone,
                context: context,
              ),
              const SizedBox(height: 20),
              buildRegisterButton(context),
            ],
          ),
        ),
      ),
    );
  }
}
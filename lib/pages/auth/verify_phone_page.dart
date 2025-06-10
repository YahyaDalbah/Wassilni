import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:wassilni/helpers/code_verification_handler.dart';
import 'dart:convert';
import 'package:wassilni/services/verification_service.dart';
import 'package:wassilni/widgets/verification/verification_app_bar.dart';
import 'package:wassilni/widgets/verification/verification_header.dart';
import 'package:wassilni/widgets/verification/verify_button.dart';

class VerifyPhonePage extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final String password;

  const VerifyPhonePage({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    required this.password,
  });

  @override
  State<VerifyPhonePage> createState() => _VerifyPhonePageState();
}

class _VerifyPhonePageState extends State<VerifyPhonePage> {
  late List<FocusNode> _focusNodes;
  late List<TextEditingController> _controllers;
  bool _isLoading = false;
  late final CodeVerificationHandler _codeVerificationHandler;
  final _verificationService = VerificationService();

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(6, (_) => FocusNode());
    _controllers = List.generate(6, (_) => TextEditingController());
    _codeVerificationHandler = CodeVerificationHandler(
      context: context,
      verificationService: _verificationService,
      verificationId: widget.verificationId,
      phoneNumber: widget.phoneNumber,
      password: widget.password,
      setLoading: (value) => setState(() => _isLoading = value),
    );
  }

  void _checkValidateOfCode() async {
    final enteredCode = _controllers.map((item) => item.text).join();
    await _codeVerificationHandler.validateCode(enteredCode);
  }

  @override
  void dispose() {
    for (var item in _controllers) {
      item.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _handleBackspaceBtn(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password); 
    final hash = sha256.convert(bytes); 
    return hash.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white10,
      appBar: const VerificationAppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const VerificationHeader(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  return Container(
                    width: 30,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: KeyboardListener(
                      focusNode: FocusNode(),
                      onKeyEvent: (KeyEvent event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.backspace) {
                          _handleBackspaceBtn(index);
                        }
                      },
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(1),
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(color: Colors.white),
                        onChanged: (value) {
                          if (value.isNotEmpty && index < 5) {
                            _focusNodes[index + 1].requestFocus();
                          }
                        },
                      ),
                    ),
                  );
                }),
              ),
              const Spacer(),
              VerifyButton(
                isLoading: _isLoading,
                onPressed: _checkValidateOfCode,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

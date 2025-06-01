import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:wassilni/services/auth_service.dart';
import '../rider_screen.dart';

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

  @override
  void initState() {
    _focusNodes = List.generate(6, (_) => FocusNode());
    _controllers = List.generate(6, (_) => TextEditingController());
    super.initState();
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

  void _checkValidateOfCode() async {
    if (_controllers.any((controller) => controller.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the complete verification code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });

    String enteredCode = _controllers.map((item) => item.text).join();
    try {
      final authService = AuthService();
      await authService.verifyPhoneCode(
        verificationId: widget.verificationId,
        smsCode: enteredCode,
      );
      
      await authService.createUserInFirestore(
        phoneNumber: widget.phoneNumber,
        password: widget.password,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone number verified successfully'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RiderScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: ${e.toString()}'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white10,
      appBar: AppBar(
        title: const Text(
          "Phone Verification",
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
              const SizedBox(height: 100),
              const Text(
                "Enter the 6-digit code sent to your phone",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  return Container(
                    width: 30,
                    margin: EdgeInsets.symmetric(horizontal: 8),
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
                            borderSide: BorderSide(color: Colors.white54),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(1),
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) {
                          if (value.isNotEmpty &&
                              index < _focusNodes.length - 1) {
                            _focusNodes[index + 1].requestFocus();
                          }
                        },
                      ),
                    ),
                  );
                }),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _checkValidateOfCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(300, 50),
                    textStyle: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("Verify"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

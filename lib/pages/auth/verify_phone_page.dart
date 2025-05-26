import 'package:flutter/material.dart';
import 'package:wassilni/widgets/build_code_field.dart';
import 'package:wassilni/helpers/verify_code_handler.dart';

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
  late final List<FocusNode> _focusNodes;
  late final List<TextEditingController> _controllers;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(6, (_) => FocusNode());
    _controllers = List.generate(6, (_) => TextEditingController());
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
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

  void _setLoading(bool value) {
    setState(() => _isLoading = value);
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 100),
              const Text(
                "Enter the 6-digit code sent to your phone",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              BuildCodeField(
                controllers: _controllers,
                focusNodes: _focusNodes,
                handleBackspaceBtn: _handleBackspaceBtn,
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          final handler = VerifyCodeHandler(
                            context: context,
                            controllers: _controllers,
                            verificationId: widget.verificationId,
                            phoneNumber: widget.phoneNumber,
                            password: widget.password,
                            setLoading: _setLoading,
                          );
                          handler.verifyCode();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(300, 50),
                    textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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
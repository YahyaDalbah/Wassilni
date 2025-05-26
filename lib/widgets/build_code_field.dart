import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BuildCodeField extends StatelessWidget {
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final Function(int) handleBackspaceBtn;

  const BuildCodeField({
    super.key,
    required this.controllers,
    required this.focusNodes,
    required this.handleBackspaceBtn,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        return Container(
          width: 30,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: KeyboardListener(
            focusNode: FocusNode(),
            onKeyEvent: (event) {
              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
                handleBackspaceBtn(index);
              }
            },
            child: TextField(
              controller: controllers[index],
              focusNode: focusNodes[index],
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
              style: const TextStyle(color: Colors.white, fontSize: 20),
              keyboardType: TextInputType.number,
              inputFormatters: [
                LengthLimitingTextInputFormatter(1),
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: (value) {
                if (value.isNotEmpty && index < focusNodes.length - 1) {
                  focusNodes[index + 1].requestFocus();
                }
              },
            ),
          ),
        );
      }),
    );
  }
}
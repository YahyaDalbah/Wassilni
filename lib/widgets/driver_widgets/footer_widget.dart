import 'package:flutter/material.dart';

class FooterWidget extends StatelessWidget {
  final String text;

  const FooterWidget({required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
}

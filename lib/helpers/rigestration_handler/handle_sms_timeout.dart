import 'package:flutter/material.dart';

class SmsTimeoutHandler {
  final BuildContext context;
  final DateTime? lastSmsTime;

  const SmsTimeoutHandler(this.context, this.lastSmsTime);

  Future<bool> handleSmsTimeout() async {
    if (lastSmsTime != null) {
      final difference = DateTime.now().difference(lastSmsTime!);
      if (difference.inSeconds < 60) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please wait ${60 - difference.inSeconds} seconds before trying again'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return false;
      }
    }
    return true;
  }
}
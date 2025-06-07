import 'package:flutter/material.dart';

Widget onlineOfflineButton({
  required VoidCallback onPressed,
  required bool isOnline,
}) {
  return Positioned(
    bottom: 100,
    left: 0,
    right: 0,
    child: Center(
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isOnline ? Colors.red : Colors.blue,
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(20),
        ),
        child: Text(
          isOnline ? "Stop!" : "Go!",
          style: const TextStyle(fontSize: 18, color: Colors.white),
        ),
      ),
    ),
  );
}

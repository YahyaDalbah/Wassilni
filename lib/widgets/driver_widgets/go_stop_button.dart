import 'package:flutter/material.dart';

Widget goStopButton({required VoidCallback onPressed, required bool isOnline}) {
  return Positioned(
    bottom: 100,
    left: 0,
    right: 0,
    child: Center(
      child: Material(
        color: isOnline ? Colors.red : Colors.blue,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          splashColor: Colors.white.withOpacity(0.5),
          highlightColor: Colors.white.withOpacity(0.3),
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              isOnline ? "Stop!" : "Go!",
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        ),
      ),
    ),
  );
}

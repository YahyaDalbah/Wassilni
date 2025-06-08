import 'package:flutter/material.dart';

Widget waitingSlidingPanel({
  required String userName,
  required String waitTime,
  required VoidCallback onStartRide,
  VoidCallback? onCancelRide,
  required bool isCancelEnabled,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const SizedBox(height: 30),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(Icons.call, color: Colors.white),
            Text(
              "Waiting For $userName",
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
            Text(
              waitTime,
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
          ],
        ),
      ),
      const Divider(color: Colors.white),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Material(
            color: Colors.green,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onStartRide,
              borderRadius: BorderRadius.circular(8),
              splashColor: Colors.white.withOpacity(0.5),
              highlightColor: Colors.white.withOpacity(0.3),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 24,
                ),
                child: const Text(
                  "Start Ride",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
          Material(
            color: isCancelEnabled ? Colors.red : const Color(0xFFCF8383),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: isCancelEnabled ? onCancelRide : null,
              borderRadius: BorderRadius.circular(8),
              splashColor: Colors.white.withOpacity(0.5),
              highlightColor: Colors.white.withOpacity(0.3),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 24,
                ),
                child: const Text(
                  "Cancel Ride",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

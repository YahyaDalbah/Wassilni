import 'package:flutter/material.dart';

Widget buildPickingUpFooter({
  required String userName,
  required String distanceText,
  required VoidCallback onTap,
}) {
  return Positioned(
    bottom: 0,
    left: 0,
    right: 0,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        color: Colors.black,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Picking Up $userName",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "$distanceText to pickup",
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    ),
  );
}

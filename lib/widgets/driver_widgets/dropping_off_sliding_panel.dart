import 'package:flutter/material.dart';

Widget droppingOffSlidingPanel({
  required VoidCallback onCompleteRide,
  required String distanceText,
  required String timeText,
}) {
  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      children: [
        const SizedBox(height: 10),
        const Text(
          "Dropping Off Rider",
          style: TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Divider(color: Colors.white54, height: 24),
        Text(
          "📍 Distance: $distanceText",
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
        const SizedBox(height: 12),
        Text(
          "⏱ Time Remaining: $timeText",
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
        const SizedBox(height: 24),
        Material(
          color: Colors.green,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onCompleteRide,
            borderRadius: BorderRadius.circular(20),
            splashColor: Colors.white.withOpacity(0.5),
            highlightColor: Colors.white.withOpacity(0.3),
            child: Container(
              width: 300,
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 15),
              alignment: Alignment.center,
              child: const Text(
                "Complete Ride",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

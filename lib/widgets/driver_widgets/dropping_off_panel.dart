import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wassilni/models/ride_model.dart';
import 'package:wassilni/providers/fare_provider.dart';

Widget droppingOffPanel({
  required BuildContext context,
  required Ride currentRide,
  required VoidCallback onCompleteRide,
}) {
  return Consumer<FareProvider>(
    builder: (context, fareProvider, _) {
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
              "📍 Distance: ${((fareProvider.estimatedDistance ?? 0) / 1000).toStringAsFixed(1)} KM",
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              "⏱ Time Remaining: ${(fareProvider.estimatedDuration ?? 0) ~/ 60} min",
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onCompleteRide,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 15),
                fixedSize: const Size(300, 60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                "Complete Ride",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    },
  );
}

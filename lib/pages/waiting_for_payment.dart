import 'package:flutter/material.dart';
import 'package:wassilni/models/ride.dart';
import 'package:wassilni/pages/rides.dart';

class WaitingForPayment extends StatelessWidget {
  final Ride ride;

  const WaitingForPayment({super.key, required this.ride});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Waiting for Payment'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Colors.white,
          ),
          const SizedBox(height: 20),
          Text(
            'Waiting for payment from ${ride.passengerName}...',
            style: const TextStyle(color: Colors.white, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
            ),
            onPressed: () {
              // Navigate back to RidesPage and clear the navigation stack
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const RidesPage()),
                (route) => false, // Remove all previous routes
              );
            },
            child: const Text(
              'I Got Paid',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
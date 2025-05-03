import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wassilni/main.dart'; // Import the notification plugin instance
import 'package:wassilni/models/ride.dart';
import 'package:wassilni/pages/map_with_path.dart';

class RidesPage extends StatefulWidget {
  const RidesPage({super.key});

  @override
  State<RidesPage> createState() => _RidesPageState();
}

class _RidesPageState extends State<RidesPage> {
  final List<Ride> _rides = [
    Ride(
      id: '1',
      passengerName: 'John Doe',
      pickupLatitude: 32.2275,
      pickupLongitude: 35.2226,
      dropoffLatitude: 32.2211,
      dropoffLongitude: 35.2544,
      phoneNumber: "000",
      timestamp: DateTime.now(),
    ),
    Ride(
      id: '2',
      passengerName: 'Jane Smith',
      pickupLatitude: 32.2333,
      pickupLongitude: 35.2000,
      dropoffLatitude: 32.2400,
      dropoffLongitude: 35.2600,
      timestamp: DateTime.now(),
      phoneNumber: "000",
    ),
  ];

  late Timer _rideTimer;
  int _rideCount = 0;

  @override
  void initState() {
    super.initState();
    _startAddingRides();
  }

  @override
  void dispose() {
    _rideTimer.cancel();
    super.dispose();
  }

  void _startAddingRides() {
    _rideTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_rideCount >= 5) {
        _rideTimer.cancel(); // Stop after 5 rides
        return;
      }

      final newRide = Ride(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        passengerName: 'Passenger ${_rideCount + 3}',
        pickupLatitude: 32.2200 + (_rideCount * 0.01), // Example latitude
        pickupLongitude: 35.2100 + (_rideCount * 0.01), // Example longitude
        dropoffLatitude: 32.2300 + (_rideCount * 0.01), // Example latitude
        dropoffLongitude: 35.2200 + (_rideCount * 0.01), // Example longitude
        timestamp: DateTime.now(),
        phoneNumber: '555-010${_rideCount + 1}', // Dummy phone number
      );

      setState(() {
        _rides.add(newRide);
      });

      _rideCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Rides'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: ListView.builder(
        itemCount: _rides.length,
        itemBuilder: (context, index) {
          final ride = _rides[index];
          return Card(
            color: Colors.grey[900],
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: ListTile(
              title: Text(
                '${ride.passengerName}',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Pickup: (${ride.pickupLatitude}, ${ride.pickupLongitude})\n'
                'Dropoff: (${ride.dropoffLatitude}, ${ride.dropoffLongitude})\n'
                'Time: ${ride.timestamp.hour}:${ride.timestamp.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white70),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                onPressed: () {
                  // Navigate to MapWithPath with the selected ride
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MapWithPath(ride: ride),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
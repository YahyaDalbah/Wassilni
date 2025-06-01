import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:provider/provider.dart';
import 'package:wassilni/models/ride_model.dart';
import 'package:wassilni/models/user_model.dart';
import 'package:wassilni/providers/ride_provider.dart';
import 'package:wassilni/pages/map.dart';
import 'package:wassilni/pages/rides_history.dart';
import 'package:wassilni/pages/rider_screen.dart';


class ToDestination extends StatefulWidget {
  const ToDestination({super.key});

  @override
  State<ToDestination> createState() => _ToDestinationState();
}

class _ToDestinationState extends State<ToDestination> {
  Ride? _currentRide;
  UserModel? _driver;
  int _etaMinutes = 0;
  Timer? _etaTimer;
  StreamSubscription<DocumentSnapshot>? _rideSubscription;
  StreamSubscription<DocumentSnapshot>? _driverSubscription;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    _currentRide = rideProvider.currentRide;
    if (_currentRide == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No current ride found')));
      Navigator.pop(context);
      return;
    }
    _driver = await _fetchDriverData();
    _setupRideStatusListener();
    _setupDriverLocationListener();
    _etaTimer = Timer.periodic(const Duration(seconds: 15), (_) => _updateETA());
  }

  Future<UserModel?> _fetchDriverData() async {
    try {
      final driverDoc = await FirebaseFirestore.instance.collection('users').doc(_currentRide!.driverId).get();
      return driverDoc.exists ? UserModel.fromFireStore(driverDoc) : null;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading driver data: $e')));
      return null;
    }
  }

  void _setupRideStatusListener() {
    _rideSubscription = FirebaseFirestore.instance
        .collection('rides')
        .doc(_currentRide!.rideId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data()?['status'] == 'completed') _showRideCompletedDialog();
    });
  }

  void _setupDriverLocationListener() {
    _driverSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentRide!.driverId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        _driver?.location = snapshot.data()!['location'] as GeoPoint;
        _updateETA();
      }
    });
  }

  Future<void> _updateETA() async {
    if (_driver?.location == null || _currentRide == null) return;
    final destination = _currentRide!.destination['coordinates'] as GeoPoint;
    final distance = gl.Geolocator.distanceBetween(
      _driver!.location.latitude,
      _driver!.location.longitude,
      destination.latitude,
      destination.longitude,
    );
    setState(() => _etaMinutes = ((distance / 8.33) / 60).ceil().clamp(1, double.infinity).toInt());
  }

  void _showRideCompletedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Ride Completed'),
        content: const Text('Your ride has been completed.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const RiderScreen()));

            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _etaTimer?.cancel();
    _rideSubscription?.cancel();
    _driverSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_driver == null || _currentRide == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      body: Stack(
        children: [
          const Map(),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.85), borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Car Info', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(_driver!.vehicle['model'] ?? 'Unknown', style: TextStyle(color: Colors.grey[300], fontSize: 14)),
                        Text(_driver!.vehicle['licensePlate'] ?? 'Unknown', style: TextStyle(color: Colors.grey[300], fontSize: 14)),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$_etaMinutes min', style: const TextStyle(color: Colors.white, fontSize: 14)),
                      Text('\$${_currentRide!.fare.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
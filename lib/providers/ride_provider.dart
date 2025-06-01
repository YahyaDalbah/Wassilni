import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:wassilni/models/ride_model.dart';

class RideProvider with ChangeNotifier {
  Ride? _currentRide;

  Ride? get currentRide => _currentRide;

  void setCurrentRide(Ride ride) {
    _currentRide = ride;
    notifyListeners();
  }

  void clearCurrentRide() {
    _currentRide = null;
    notifyListeners();
  }

  Future<void> updateRideStatus(String newStatus, Ride? ride) async {
  if (ride == null || ride!.rideId.isEmpty) return;

  try {
    // 1. Update Firestore
    await FirebaseFirestore.instance
      .collection('rides')
      .doc(ride!.rideId)
      .update({
        'status': newStatus,
        'timestamps.$newStatus': FieldValue.serverTimestamp(),
      });

    // 2. Update local state directly (no copyWith needed)
    ride!.status = newStatus;
    notifyListeners();

  } catch (e) {
    print('Error updating ride status: $e');
    rethrow;
  }
}
}
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

  void updateStatus(String newStatus) {
    if (_currentRide != null) {
      _currentRide = Ride(
        rideId: _currentRide!.rideId,
        riderId: _currentRide!.riderId,
        driverId: _currentRide!.driverId,
        status: newStatus,
        pickup: _currentRide!.pickup,
        destination: _currentRide!.destination,
        fare: _currentRide!.fare,
        distance: _currentRide!.distance,
        duration: _currentRide!.duration,
        timestamps: {
          ..._currentRide!.timestamps,
          newStatus == 'accepted' ? 'accepted' : newStatus == 'in_progress' ? 'started' : 'completed': Timestamp.now(),
        },
      );
      FirebaseFirestore.instance.collection('rides').doc(_currentRide!.rideId).update({
        'status': newStatus,
        'timestamps.$newStatus': Timestamp.now(),
      });
      notifyListeners();
    }
  }
}
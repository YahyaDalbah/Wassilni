import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:wassilni/helpers/directions_handler.dart';

class FareProvider with ChangeNotifier {
  double? _estimatedFare;

  double? get estimatedFare => _estimatedFare;

  set estimatedFare(double? newFare) {
    _estimatedFare = newFare;
    notifyListeners();
  }

  double? _estimatedDuration;

  double? get estimatedDuration => _estimatedDuration;

  set estimatedDuration(double? newFare) {
    _estimatedDuration = newFare;
    notifyListeners();
  }

  double? _estimatedDistance;

  double? get estimatedDistance => _estimatedDistance;

  set estimatedDistance(double? newFare) {
    _estimatedDistance = newFare;
    notifyListeners();
  }

  double? _currentToPickupDuration; // New property
  double? _pickupToDropoffDuration; // New property

  double? get currentToPickupDuration => _currentToPickupDuration;
  double? get pickupToDropoffDuration => _pickupToDropoffDuration;

  void updateDurations(double pickupDuration, double dropoffDuration) {
    _currentToPickupDuration = pickupDuration;
    _pickupToDropoffDuration = dropoffDuration;
    notifyListeners();
  }

  Future<void> updateCurrentToPickupDuration(Point current, Point pickup) async {
    try {
      _currentToPickupDuration = await getRouteDuration(current, pickup);
            notifyListeners();
    } catch (e) {
      _currentToPickupDuration = null;
    }
  }
void clear() {
    _estimatedFare = null;
    _estimatedDuration = null;
    _estimatedDistance = null;
    _currentToPickupDuration = null;
    notifyListeners();
  }
}

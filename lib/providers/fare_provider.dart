import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class FareProvider with ChangeNotifier {
  double? _estimatedFare;
  double? _duration;
  double? _distance;

  double? get estimatedFare => _estimatedFare;
  double? get duration => _duration;
  double? get distance => _distance;

  set estimatedFare(double? newFare) {
    _estimatedFare = newFare;
    notifyListeners();
  }

  void updateFareDetails(double fare, double durationMinutes, double distanceKm) {
     print("💸 Updating Fare: $fare, Duration: $duration min, Distance: $distance km");

    _estimatedFare = fare;
    _duration = durationMinutes;
    _distance = distanceKm;
    notifyListeners();
  }

  void clearFareDetails() {
    _estimatedFare = null;
    _duration = null;
    _distance = null;
    notifyListeners();
  }
}
import 'package:flutter/material.dart';

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
}
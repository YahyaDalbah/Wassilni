import 'package:flutter/material.dart';

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
}
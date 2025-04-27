import 'package:flutter/material.dart';

class FareProvider with ChangeNotifier {
  double? _estimatedFare;

  double? get estimatedFare => _estimatedFare;

  set estimatedFare(double? newFare) {
    _estimatedFare = newFare;
    notifyListeners();
  }
}

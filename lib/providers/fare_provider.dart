import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class FareProvider with ChangeNotifier {
  double? _estimatedFare;

  double? get estimatedFare => _estimatedFare;

  set estimatedFare(double? newFare) {
    _estimatedFare = newFare;
    notifyListeners();
  }
}
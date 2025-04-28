import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapProvider with ChangeNotifier {
  //fare
  double? _estimatedFare;

  double? get estimatedFare => _estimatedFare;

  set estimatedFare(double? newFare) {
    _estimatedFare = newFare;
    notifyListeners();
  }

  //destination
  Point? _destination = Point(coordinates: Position(35.029994, 32.314459));

  Point? get destination => _destination;

  set destination(Point? newDestination) {
    _destination = newDestination;
    notifyListeners();
  }

  void clearDestination() {
    _destination = null;
    notifyListeners();
  }
}

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class DestinationProvider with ChangeNotifier {
  Point? _destination;

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

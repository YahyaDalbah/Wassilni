import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class DestinationProvider with ChangeNotifier {
  Point? _destination; 
  Point? _pickup; 
  Point? _dropoff; 
  Point? get destination => _destination;
  Point? get pickup => _pickup;
  Point? get dropoff => _dropoff;
  set destination(Point? newDestination) {
    _destination = newDestination;
    notifyListeners();
  }
  set pickup(Point? newPickup) {
    _pickup = newPickup;
    notifyListeners();
  }

  set dropoff(Point? newDropoff) {
    _dropoff = newDropoff;
    notifyListeners();
  }

  void clearDestination() {
    _destination = null;
    notifyListeners();
  }
  void clearAll() {
    _destination = null;
    _pickup = null;
    _dropoff = null;
    notifyListeners();
  }

  double? _pickupDistance;
  double? get pickupDistance => _pickupDistance;
  void updatePickupDistance(double distance) {
    _pickupDistance = distance;
    notifyListeners();
  }

  double? _currentToPickupDistance;

  double? get currentToPickupDistance => _currentToPickupDistance;

  bool _isUpdating = false;


  void updateDistances(double currentToPickup) {
    if (_isUpdating) return;
    _isUpdating = true;
    _currentToPickupDistance = currentToPickup;
    notifyListeners();
    _isUpdating = false;
  }
  void clearDistances() {
    _currentToPickupDistance = null;
    notifyListeners();
  }
  double? _currentToDropoffDistance;
  double? get currentToDropoffDistance => _currentToDropoffDistance;
  void updateCurrentToDropoffDistance(double distance) {
    _currentToDropoffDistance = distance;
    notifyListeners();
  }
  
  int _drawRoute = 0;
  int get drawRoute => _drawRoute;
  void redrawRoute() {
    _drawRoute++;
    notifyListeners();
  }
}

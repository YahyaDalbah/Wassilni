import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class DestinationProvider with ChangeNotifier {
  Point? _destination; // Existing destination point
  Point? _pickup; // New pickup point
  Point? _dropoff; // New dropoff point

  // Getter for the existing destination
  Point? get destination => _destination;

  // Getter for the new pickup point
  Point? get pickup => _pickup;

  // Getter for the new dropoff point
  Point? get dropoff => _dropoff;

  // Setter for the existing destination
  set destination(Point? newDestination) {
    _destination = newDestination;
    notifyListeners();
  }

  // Setter for the new pickup point
  set pickup(Point? newPickup) {
    _pickup = newPickup;
    notifyListeners();
  }

  // Setter for the new dropoff point
  set dropoff(Point? newDropoff) {
    _dropoff = newDropoff;
    notifyListeners();
  }

  void clearDestination() {
    _destination = null;
    notifyListeners();
  }

  // Clear all points (destination, pickup, and dropoff)
  void clearAll() {
    _destination = null;
    _pickup = null;
    _dropoff = null;
    notifyListeners();
  }

  void notifyRouteUpdate() {
    notifyListeners();
  }

  // New functionality for pickup distance
  double? _pickupDistance;

  double? get pickupDistance => _pickupDistance;

  void updatePickupDistance(double distance) {
    _pickupDistance = distance;
    notifyListeners();
  }

  // New properties for distances
  double? _currentToPickupDistance;
  double? _pickupToDropoffDistance;

  // Getters for distances
  double? get currentToPickupDistance => _currentToPickupDistance;
  double? get pickupToDropoffDistance => _pickupToDropoffDistance;

  // Flag to prevent simultaneous updates
  bool _isUpdating = false;

  // Method to update distances
  void updateDistances(double currentToPickup, double pickupToDropoff) {
    if (_isUpdating) return;
    _isUpdating = true;

    _currentToPickupDistance = currentToPickup;
    _pickupToDropoffDistance = pickupToDropoff;

    // Log the updated distances
    print("💥 DISTANCES: Current→Pickup: $currentToPickup KM, Pickup→Dropoff: $pickupToDropoff KM");

    notifyListeners();
    _isUpdating = false;
  }

  // Method to clear distances
  void clearDistances() {
    _currentToPickupDistance = null;
    _pickupToDropoffDistance = null;
    notifyListeners();
  }
}

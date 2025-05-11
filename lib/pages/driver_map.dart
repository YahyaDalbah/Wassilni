import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wassilni/models/ride.dart';
import 'package:wassilni/providers/destination_provider.dart';
import 'package:wassilni/providers/fare_provider.dart';
import 'package:wassilni/pages/map.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:wassilni/pages/driver_widgets.dart'; // Import the new file
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:geolocator/geolocator.dart' as gl;
import 'dart:async'; // Add this import for Timer

// Static Ride object
final Ride staticRide = Ride(
  rideId: "ride123",
  riderId: "rider456",
  driverId: "driver789",
  status: "requested",
  pickup: Location(
    address: "Al-Najah University, Nablus",
    coordinates: GeoPoint(32.2276, 35.2603),
  ),
  destination: Location(
    address: "Rafidia Hospital, Nablus",
    coordinates: GeoPoint(32.2211, 35.2544),
  ),
  fare: 10.00,
  distance: 3.5,
  duration: 8.0,
  timestamps: RideTimestamps(
    requested: Timestamp.now(),
    accepted: null,
    started: null,
    completed: null,
  ),
);

// Define the DriverState enum
enum DriverState { offline, online, pickingUp, waiting, droppingOff }

class DriverMap extends StatefulWidget {
  const DriverMap({super.key});

  @override
  State<DriverMap> createState() => _DriverMapState();
}

class _DriverMapState extends State<DriverMap> {
  // Use DriverState for managing the driver's state
  DriverState driverState = DriverState.offline;

  // Variables for panel content
  String panelTitle = "${staticRide.fare}\$";
  String panelSubtitle1(BuildContext context) {
    final provider = Provider.of<DestinationProvider>(context);
    final distance = provider.currentToPickupDistance?.toStringAsFixed(1) ?? '--';
    return "${staticRide.duration} min ($distance KM) away";
  }

  String panelSubtitle2(BuildContext context) {
    final provider = Provider.of<DestinationProvider>(context);
    final distance = provider.pickupToDropoffDistance?.toStringAsFixed(1) ?? '--';
    return "${staticRide.duration} min ($distance KM) away";
  }

  String get panelLocation1 => staticRide.pickup.address; // Pickup location
  String get panelLocation2 => staticRide.destination.address; // Dropoff location

  // Variables for footer content
  String get userName => "Rider ${staticRide.riderId}";
  String get distance => "${staticRide.distance} KM";
  String get estTimeLeft => "${staticRide.duration} min";

  Timer? _distanceUpdateTimer;
  Timer? _onlineDistanceTimer; // Timer for online state updates
  int _remainingWaitTime = 7; // Countdown timer for waiting state
  Timer? _waitTimer;

  String _formatWaitTime() {
    return "0:${_remainingWaitTime.toString().padLeft(2, '0')}"; // Format as "0:07"
  }

  bool get _isCancelEnabled => _remainingWaitTime == 0;

  Future<void> _updateDroppingOffDistance() async {
    try {
      final currentPosition = await gl.Geolocator.getCurrentPosition();
      final destinationProvider = Provider.of<DestinationProvider>(context, listen: false);

      final currentToDropoff = gl.Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        staticRide.destination.coordinates.latitude,
        staticRide.destination.coordinates.longitude,
      );

      destinationProvider.updateCurrentToDropoffDistance(currentToDropoff / 1000); // Convert to kilometers
      print("📍 Updated dropoff distance: ${currentToDropoff / 1000} KM");
    } catch (e) {
      print("🚨 Failed to update dropoff distance: $e");
    }
  }

  void _startOnlineUpdates() {
    _onlineDistanceTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (driverState == DriverState.online || driverState == DriverState.pickingUp) {
        _calculateDistances(); // Recalculate distances every 5 seconds
      }
    });
  }

  void toggleOnlineStatus() {
    setState(() {
      if (driverState == DriverState.offline) {
        driverState = DriverState.online;
        _calculateDistances(); // Initial calculation
        _startOnlineUpdates(); // Start periodic updates
      } else if (driverState == DriverState.online) {
        driverState = DriverState.offline;
        _onlineDistanceTimer?.cancel(); // Stop updates when going offline
      }
      print("Driver state: $driverState");
    });
  }

  Future<void> _calculateDistances() async {
    try {
      if (driverState != DriverState.online && driverState != DriverState.pickingUp) return;

      // Get the current location
      final currentPosition = await gl.Geolocator.getCurrentPosition();
      final destinationProvider = Provider.of<DestinationProvider>(context, listen: false);

      // Calculate distances
      final currentToPickup = gl.Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        staticRide.pickup.coordinates.latitude,
        staticRide.pickup.coordinates.longitude,
      ) / 1000; // Convert to kilometers

      final pickupToDropoff = gl.Geolocator.distanceBetween(
        staticRide.pickup.coordinates.latitude,
        staticRide.pickup.coordinates.longitude,
        staticRide.destination.coordinates.latitude,
        staticRide.destination.coordinates.longitude,
      ) / 1000;

      destinationProvider.updateDistances(currentToPickup, pickupToDropoff);

      // Automatic transition to "waiting" state if within 15 meters of pickup
      if (driverState == DriverState.pickingUp && currentToPickup <= 0.015 && mounted) {
        transitionToWaiting();
      }

      print("✅ Distances calculated: Current→Pickup: ${currentToPickup.toStringAsFixed(3)} KM");
    } catch (e) {
      print("🚨 Distance calculation failed: $e");
      if (mounted) setState(() => driverState = DriverState.offline);
    }
  }

  void acceptRide() {
    setState(() {
      // Update the driver's state to "picking up"
      driverState = DriverState.pickingUp;

      // Convert pickup and dropoff locations to Mapbox points
      final pickupPoint = mp.Point(
        coordinates: mp.Position(
          staticRide.pickup.coordinates.longitude,
          staticRide.pickup.coordinates.latitude,
        ),
      );

      final dropoffPoint = mp.Point(
        coordinates: mp.Position(
          staticRide.destination.coordinates.longitude,
          staticRide.destination.coordinates.latitude,
        ),
      );

      // Update the DestinationProvider with pickup and dropoff points
      final destinationProvider = Provider.of<DestinationProvider>(context, listen: false);
      destinationProvider.pickup = pickupPoint;
      destinationProvider.dropoff = dropoffPoint;
      destinationProvider.notifyRouteUpdate();

      // Add markers for pickup and dropoff points
      Map.mapKey.currentState?.createPickupAndDropoffMarkers(pickupPoint, dropoffPoint);

      // Log the ride acceptance
      print("Ride accepted - Pickup: ${staticRide.pickup.address}, Dropoff: ${staticRide.destination.address}");
    });
  }

  void clearPickup() {
    final dp = Provider.of<DestinationProvider>(context, listen: false);
    dp.pickup = null;
    Map.mapKey.currentState?.clearPickupMarker();
    dp.notifyListeners();
  }

  void clearDropoff() {
    final dp = Provider.of<DestinationProvider>(context, listen: false);
    dp.dropoff = null;
    Map.mapKey.currentState?.clearDropoffMarker();
    dp.notifyListeners();
  }

  void clearSpecificRoute(String routeId) {
    Map.mapKey.currentState?.clearRoute(routeId);
  }

  void startRide() async {
    print("startRide method triggered");
    setState(() {
      driverState = DriverState.droppingOff;

      // Clear the existing path and pickup marker
      clearPath();
      clearPickup();
    });

    // Start periodic updates for the dropoff distance
    _distanceUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _updateDroppingOffDistance();
    });

    // Get the current location and draw the new route
    final currentPosition = await gl.Geolocator.getCurrentPosition();
    final currentLocationPoint = mp.Point(
      coordinates: mp.Position(
        currentPosition.longitude,
        currentPosition.latitude,
      ),
    );

    final destinationProvider = Provider.of<DestinationProvider>(context, listen: false);
    final dropoffPoint = destinationProvider.dropoff;

    if (dropoffPoint == null) {
      print("Dropoff point is not set. Cannot create a new path.");
      return;
    }

    // Update the destination provider and draw the route
    destinationProvider.pickup = currentLocationPoint;
    Map.mapKey.currentState?.createPickupAndDropoffMarkers(currentLocationPoint, dropoffPoint);

    print("New path created from current location to dropoff.");
    print("Driver state updated to: $driverState");
  }

  void resetToDefault() {
    setState(() {
      // Reset the driver's state to "offline"
      driverState = DriverState.offline;

      // Clear distances in the DestinationProvider
      Provider.of<DestinationProvider>(context, listen: false).clearDistances();

      // Clear the map
      clearPoints();
      clearPath();

      print("Driver state: $driverState");
    });
  }

  void transitionToWaiting() {
    print("transitionToWaiting method triggered");
    setState(() {
      driverState = DriverState.waiting;
      _remainingWaitTime = 7; // Reset timer
      _waitTimer?.cancel(); // Cancel any existing timer

      // Start countdown
      _waitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;

        setState(() {
          if (_remainingWaitTime > 0) {
            _remainingWaitTime--;
          } else {
            timer.cancel(); // Stop timer at 0
            if (mounted) setState(() {}); // Force rebuild to enable button
          }
        });
      });

      print("Driver state updated to: $driverState");
    });
  }

  void clearPoints() {
    final dp = Provider.of<DestinationProvider>(context, listen: false);
    dp.pickup = null;
    dp.dropoff = null;
    dp.notifyListeners();

    // Clear pickup→dropoff route and markers
    Map.mapKey.currentState?.clearPickupDropoffRouteAndMarkers();
  }

  void clearPath() {
    final dp = Provider.of<DestinationProvider>(context, listen: false);
    dp.notifyListeners();

    // Clear the route only
    clearSpecificRoute("pickup_to_dropoff_route");
  }

  @override
  void dispose() {
    _waitTimer?.cancel(); // Cancel waiting timer
    _distanceUpdateTimer?.cancel();
    _onlineDistanceTimer?.cancel(); // Cancel online timer
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destinationProvider = Provider.of<DestinationProvider>(context);

    return SafeArea(
      child: Scaffold(
      body: Stack(
        children: [
          // Map widget
          Positioned.fill(
            child: Map(
              key: Map.mapKey, // Use the global key
            ),
          ),
          // Online/Offline toggle button
          if (driverState == DriverState.offline || driverState == DriverState.online)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton(
                  onPressed: toggleOnlineStatus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: driverState == DriverState.online ? Colors.red : Colors.blue,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(20),
                  ),
                  child: Text(
                    driverState == DriverState.online ? "Stop!" : "Go!",
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            ),
          // Sliding panel for "You're Online"
          if (driverState == DriverState.online)
          
            Consumer<DestinationProvider>(
              builder: (context, provider, _) {
                
              print("💣 FORCE REBUILD - DISTANCES: "
      "${provider.currentToPickupDistance}/${provider.pickupToDropoffDistance}");
               
                return SlidingUpPanel(
                  minHeight: 50,
                  maxHeight: 350,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  color: Colors.black,
                  panel: buildPanelContent(

                    panelTitle: panelTitle,
                    panelSubtitle1: panelSubtitle1(context),
                    panelSubtitle2: panelSubtitle2(context),
                    panelLocation1: panelLocation1,
                    panelLocation2: panelLocation2,
                    onAcceptRide: acceptRide,
                  ),
                  collapsed: buildCollapsedPanel("You're Online"),
                );
              },
            ),
          // Footer for "Picking Up User"
          if (driverState == DriverState.pickingUp)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {
                  print("Footer tapped to transition to waiting");
                  transitionToWaiting();
                },
                child: Container(
                  height: 100, // Increased height
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  color: Colors.black,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Picking Up $userName",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Consumer<DestinationProvider>(
                        builder: (context, provider, _) {
                          final distanceKm = provider.currentToPickupDistance;
                          final String distanceText;

                          if (distanceKm == null) {
                            distanceText = '--';
                          } else if (distanceKm <= 0.1) {
                            // Convert to meters and round to nearest integer
                            final distanceMeters = (distanceKm * 1000).round();
                            distanceText = '$distanceMeters m';
                          } else {
                            distanceText = '${distanceKm.toStringAsFixed(1)} km';
                          }

                          return Text(
                            "$distanceText to pickup",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Sliding panel for "Waiting for User"
          if (driverState == DriverState.waiting)
            SlidingUpPanel(
              minHeight: 100,
              maxHeight: 300,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              color: Colors.black,
              panel: buildWaitingPanel(
                userName: userName,
                waitTime: _formatWaitTime(),
                onStartRide: startRide,
                onCancelRide: _isCancelEnabled ? resetToDefault : null, // Disable when timer running
                isCancelEnabled: _isCancelEnabled, // Pass enabled state
              ),
              collapsed: buildCollapsedPanel(
                "Waiting For $userName - ${_formatWaitTime()}" // Add timer to collapsed panel
              ),
            ),
          // Sliding panel for "Dropping Off User"
          if (driverState == DriverState.droppingOff)
            SlidingUpPanel(
              minHeight: 100,
              maxHeight: 300,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              color: Colors.black,
              panel: buildDroppingOffPanel(
                userName: userName,
                distance: "${Provider.of<DestinationProvider>(context).currentToDropoffDistance?.toStringAsFixed(1) ?? staticRide.distance.toStringAsFixed(1)} KM", // Use dynamic distance
                estTimeLeft: estTimeLeft,
                onCompleteRide: resetToDefault,
              ),
              collapsed: buildCollapsedPanel("Dropping Off $userName"),
            ),
          // Footer for "You're Offline"
          if (driverState == DriverState.offline)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: FooterWidget(
                text: "You're Offline", // Pass the required text parameter
              ),
            ),
        ],
      ),
    ));
  }
}


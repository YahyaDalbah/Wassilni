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

  void toggleOnlineStatus() {
    setState(() {
      if (driverState == DriverState.offline) {
        driverState = DriverState.online;
        _calculateDistances();
      } else if (driverState == DriverState.online) {
        driverState = DriverState.offline;
      }
      print("Driver state: $driverState");
    });
  }

  Future<void> _calculateDistances() async {
    try {
      // Get the current location
      final currentPosition = await gl.Geolocator.getCurrentPosition();
      final destinationProvider = Provider.of<DestinationProvider>(context, listen: false);

      // Calculate distances
      final currentToPickup = gl.Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        staticRide.pickup.coordinates.latitude,
        staticRide.pickup.coordinates.longitude,
      );

      final pickupToDropoff = gl.Geolocator.distanceBetween(
        staticRide.pickup.coordinates.latitude,
        staticRide.pickup.coordinates.longitude,
        staticRide.destination.coordinates.latitude,
        staticRide.destination.coordinates.longitude,
      );

      // Update distances in the provider
      destinationProvider.updateDistances(
        currentToPickup / 1000, // Convert to kilometers
        pickupToDropoff / 1000, // Convert to kilometers
      );

      print("✅ Distances calculated: Current→Pickup: ${currentToPickup / 1000} KM, Pickup→Dropoff: ${pickupToDropoff / 1000} KM");
    } catch (e) {
      print("🚨 Distance calculation failed: $e");

      // Optional: revert to offline state on failure
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
                child: FooterWidget(
                  text: "Picking Up $userName",
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
                estTimeLeft: estTimeLeft,
                onStartRide: startRide,
                onCancelRide: resetToDefault,
              ),
              collapsed: buildCollapsedPanel("Waiting For $userName"),
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
                distance: distance,
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


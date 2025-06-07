import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:wassilni/models/ride_model.dart';
import 'package:wassilni/providers/destination_provider.dart';
import 'package:wassilni/providers/fare_provider.dart';
import 'package:wassilni/providers/ride_provider.dart';
import 'package:wassilni/providers/user_provider.dart';

enum DriverState {
  offline,
  lookingForRide,
  foundRide,
  pickingUp,
  waiting,
  droppingOff,
}

class DriverLogic {
  final BuildContext context;
  final VoidCallback onStateChanged;
  final bool Function() isMounted;
  final UserProvider userProvider;
  final DestinationProvider destinationProvider;
  final FareProvider fareProvider;
  final RideProvider rideProvider;

  DriverState _driverState = DriverState.offline;
  DriverState get driverState => _driverState;
  set driverState(DriverState value) {
    _driverState = value;
    onStateChanged(); // Missing notification
  }

  Ride? _currentRide;
  StreamSubscription<QuerySnapshot>? _ridesSubscription;
  Timer? _distanceUpdateTimer;
  Timer? _onlineDistanceTimer;
  Timer? _waitTimer;
  int _remainingWaitTime = 7;

  DriverLogic(this.context, this.onStateChanged, this.isMounted)
    : userProvider = Provider.of<UserProvider>(context, listen: false),
      destinationProvider = Provider.of<DestinationProvider>(
        context,
        listen: false,
      ),
      fareProvider = Provider.of<FareProvider>(context, listen: false),
      rideProvider = Provider.of<RideProvider>(context, listen: false) {
    userProvider.updateOnlineStatus(false);
  }

  Ride? get currentRide => _currentRide;
  set currentRide(Ride? ride) {
    _currentRide = ride;
    onStateChanged();
  }

  bool get isCancelEnabled => _remainingWaitTime == 0;

  void transitionToOffline() {
    driverState = DriverState.offline;
    _ridesSubscription = null;
    currentRide = null;
    resetproviders();
    cancelAllActiveOperations();
  }

  void transitionToLookingForRide() {
    userProvider.updateOnlineStatus(true);
    driverState = DriverState.lookingForRide;
    _startRideListener();
    _startOnlineUpdates();
  }

  void transitionToFoundRide() {
    driverState = DriverState.foundRide;
    _calculateDistances();
    _startOnlineUpdates();
  }

  void transitionToPickingUp() {
    driverState = DriverState.pickingUp;
    userProvider.updateOnlineStatus(false);
    rideProvider.updateRideStatus("accepted", currentRide!);
    final pickupPoint = mp.Point(
      coordinates: mp.Position(
        currentRide!.pickup["coordinates"].longitude,
        currentRide!.pickup["coordinates"].latitude,
      ),
    );
    destinationProvider
      ..destination = pickupPoint
      ..pickup = pickupPoint
      ..redrawRoute();
  }

  void transitionToWaiting() {
    driverState = DriverState.waiting;
    _remainingWaitTime = 7;
    _waitTimer?.cancel();
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isMounted()) return;
      if (_remainingWaitTime > 0) {
        _remainingWaitTime--;
        onStateChanged();
      } else {
        timer.cancel();
        onStateChanged();
      }
    });
  }

  void transitionToDroppingOff() {
    driverState = DriverState.droppingOff;
    rideProvider.updateRideStatus("in_progress", currentRide!);
    final dropoffPoint = mp.Point(
      coordinates: mp.Position(
        currentRide!.destination["coordinates"].longitude,
        currentRide!.destination["coordinates"].latitude,
      ),
    );
    destinationProvider
      ..destination = dropoffPoint
      ..redrawRoute();
    _distanceUpdateTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) => _updateDroppingOffDistance(),
    );
  }

  void handleRideCancel() async {
    if (!isMounted()) return;

    final context = this.context;
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cancel Ride?'),
            content: const Text('Are you sure you want to cancel this ride?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('NO'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('YES'),
              ),
            ],
          ),
    );

    if (confirmed ?? false) {
      _performCancellation();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ride canceled')));
      }
    }
  }

  void _startRideListener() {
    _ridesSubscription?.cancel();
    final driverId = userProvider.currentUser?.id;
    _ridesSubscription = FirebaseFirestore.instance
        .collection('rides')
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: "requested")
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) async {
          if (snapshot.metadata.isFromCache) {
            debugPrint("Ride stream is from cache, skipping processing.");
            return;
          }
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added &&
                !change.doc.metadata.hasPendingWrites) {
              currentRide = Ride.fromFirestore(change.doc);
              transitionToFoundRide();
              _updateProvidersWithRideData(currentRide!);
            }
          }
        }, onError: (error) => debugPrint("Ride stream error: $error"));
  }

  void _updateProvidersWithRideData(Ride ride) {
    final pickupPoint = _createMapboxPoint(ride.pickup);
    final dropoffPoint = _createMapboxPoint(ride.destination);
    _updateDestinationProvider(pickupPoint, dropoffPoint);
    _updateFareProvider(ride);
  }

  mp.Point _createMapboxPoint(Map<String, dynamic> location) {
    final coords = location["coordinates"];
    return mp.Point(
      coordinates: mp.Position(coords.longitude, coords.latitude),
    );
  }

  void _updateDestinationProvider(mp.Point pickup, mp.Point dropoff) {
    destinationProvider
      ..pickup = pickup
      ..destination = dropoff;
  }

  void _updateFareProvider(Ride ride) {
    fareProvider
      ..estimatedDistance = ride.distance
      ..estimatedDuration = ride.duration
      ..estimatedFare = ride.fare;
  }

  void _startOnlineUpdates() {
    _onlineDistanceTimer?.cancel();
    _onlineDistanceTimer = Timer.periodic(const Duration(seconds: 2), (
      timer,
    ) async {
      if (driverState == DriverState.foundRide ||
          driverState == DriverState.pickingUp ||
          driverState == DriverState.droppingOff) {
        await _calculateDistances();
      }
    });
  }

  Future<void> _calculateDistances() async {
    try {
      final currentPosition = await gl.Geolocator.getCurrentPosition();
      final currentToPickupDistanceKm = _calculateDistanceToPickup(
        currentPosition,
      );
      _updateDistanceProviders(currentPosition, currentToPickupDistanceKm);

      if (_ifIAmCloseTransitionToWaiting(currentToPickupDistanceKm)) {
        transitionToWaiting();
      }
    } catch (e) {
      debugPrint("Distance calculation error: $e");
      if (isMounted()) driverState = DriverState.offline;
    }
  }

  double _calculateDistanceToPickup(gl.Position currentPosition) {
    return gl.Geolocator.distanceBetween(
          currentPosition.latitude,
          currentPosition.longitude,
          currentRide!.pickup["coordinates"].latitude,
          currentRide!.pickup["coordinates"].longitude,
        ) /
        1000;
  }

  void _updateDistanceProviders(
    gl.Position currentPosition,
    double distanceKm,
  ) {
    destinationProvider.updateDistances(distanceKm);

    final currentPoint = mp.Point(
      coordinates: mp.Position(
        currentPosition.longitude,
        currentPosition.latitude,
      ),
    );

    final pickupPoint = mp.Point(
      coordinates: mp.Position(
        currentRide!.pickup["coordinates"].longitude,
        currentRide!.pickup["coordinates"].latitude,
      ),
    );

    fareProvider.updateCurrentToPickupDuration(currentPoint, pickupPoint);
  }

  bool _ifIAmCloseTransitionToWaiting(double distanceKm) {
    // Transition state if close to pickup point
    return driverState == DriverState.pickingUp && distanceKm <= 0.040;
  }

  //
  void toggleOnlineStatus() {
    if (driverState == DriverState.offline) {
      transitionToLookingForRide();
    } else if (driverState == DriverState.foundRide ||
        driverState == DriverState.lookingForRide) {
      transitionToOffline();
    }
  }

  Future<void> _updateDroppingOffDistance() async {
    try {
      final currentPosition = await gl.Geolocator.getCurrentPosition();
      final currentToDropoff = gl.Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        currentRide!.destination["coordinates"].latitude,
        currentRide!.destination["coordinates"].longitude,
      );
      destinationProvider.updateCurrentToDropoffDistance(
        currentToDropoff / 1000,
      );
    } catch (e, stackTrace) {
      debugPrint("Failed to update dropoff distance: $e\n$stackTrace");
    }
  }

  resetproviders() {
    userProvider.updateOnlineStatus(false);
    fareProvider.clear();
    destinationProvider
      ..clearAll()
      ..clearDistances()
      ..redrawRoute();
  }

  cancelAllActiveOperations() {
    _ridesSubscription?.cancel();
    _onlineDistanceTimer?.cancel();
    _distanceUpdateTimer?.cancel();
    _waitTimer?.cancel();
  }

  String formatWaitTime() {
    return "0:${_remainingWaitTime.toString().padLeft(2, '0')}";
  }

  void _performCancellation() {
    rideProvider.updateRideStatus("canceled", currentRide!);
    currentRide = null;
    resetproviders();
    transitionToLookingForRide();
  }

  void dispose() {
    transitionToOffline();
  }
}

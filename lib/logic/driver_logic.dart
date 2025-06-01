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

enum DriverState { offline, lookingForRide, foundRide, pickingUp, waiting, droppingOff }

class DriverLogic {
  final BuildContext context;
  final VoidCallback onStateChanged;
  final bool Function() isMounted;

  DriverState _driverState = DriverState.offline;
  Ride? _currentRide;
  StreamSubscription<QuerySnapshot>? _ridesSubscription;
  Timer? _distanceUpdateTimer;
  Timer? _onlineDistanceTimer;
  Timer? _waitTimer;
  int _remainingWaitTime = 7;

  DriverLogic(this.context, this.onStateChanged, this.isMounted);

  DriverState get driverState => _driverState;
  set driverState(DriverState value) {
    _driverState = value;
    onStateChanged();
  }

  Ride? get currentRide => _currentRide;
  set currentRide(Ride? ride) {
    _currentRide = ride;
    onStateChanged();
  }

  void _startRideListener() {
    _ridesSubscription?.cancel();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
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
              driverState = DriverState.foundRide;
              await userProvider.updateOnlineStatus(false);
              _updateProvidersWithRideData(currentRide!);
            }
          }
        }, onError: (error) => debugPrint("Ride stream error: $error"));
  }

  void _updateProvidersWithRideData(Ride ride) {
      final pickupPoint = mp.Point(
      coordinates: mp.Position(
        ride.pickup["coordinates"].longitude,
        ride.pickup["coordinates"].latitude,
      ),
    );
    final dropoffPoint = mp.Point(
      coordinates: mp.Position(
        ride.destination["coordinates"].longitude,
        ride.destination["coordinates"].latitude,
      ),
    );
    Provider.of<DestinationProvider>(context, listen: false)
      ..pickup = pickupPoint
      ..destination = dropoffPoint;
      Provider.of<FareProvider>(context, listen: false)
      ..estimatedDistance = ride.distance
      ..estimatedDuration = ride.duration
      ..estimatedFare = ride.fare;
  }

  void _startOnlineUpdates() {
    _onlineDistanceTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (driverState == DriverState.foundRide ||
          driverState == DriverState.pickingUp ||
          driverState == DriverState.droppingOff) {
        await _calculateDistances();
      }
    });
  }

  Future<void> _calculateDistances() async {
    try {
      if (driverState != DriverState.foundRide && driverState != DriverState.pickingUp && driverState!= DriverState.droppingOff) return;
      final currentPosition = await gl.Geolocator.getCurrentPosition();
      final currentToPickup = gl.Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        currentRide!.pickup["coordinates"].latitude,
        currentRide!.pickup["coordinates"].longitude,
      ) / 1000;
      Provider.of<DestinationProvider>(context, listen: false).updateDistances(currentToPickup);
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
      await Provider.of<FareProvider>(context, listen: false).updateCurrentToPickupDuration(currentPoint, pickupPoint);
      if (driverState == DriverState.pickingUp && currentToPickup <= 0.040 && isMounted()) {
        transitionToWaiting();
      }
    } catch (e) {
      debugPrint("Distance error: $e");
      if (isMounted()) driverState = DriverState.offline;
    }
  }

  void toggleOnlineStatus() async {
    if (driverState == DriverState.offline) {
      await Provider.of<UserProvider>(context, listen: false).updateOnlineStatus(true);
      driverState = DriverState.lookingForRide;
      _startRideListener();
      _calculateDistances();
      _startOnlineUpdates();
    } else if (driverState == DriverState.foundRide || driverState == DriverState.lookingForRide) {
      resetToDefault();
    }
  }

  void acceptRide() {
    driverState = DriverState.pickingUp;
    final destinationProvider = Provider.of<DestinationProvider>(context, listen: false);
    Provider.of<RideProvider>(context, listen: false).updateRideStatus("accepted", currentRide!);
    final pickupPoint = mp.Point(
      coordinates: mp.Position(
        currentRide!.pickup["coordinates"].longitude,
        currentRide!.pickup["coordinates"].latitude,
      ),
    );
    destinationProvider.destination = pickupPoint;
    destinationProvider.pickup = pickupPoint;
    destinationProvider.redrawRoute();
  }

  void startRide() async {
    driverState = DriverState.droppingOff;
    final destinationProvider = Provider.of<DestinationProvider>(context, listen: false);
    Provider.of<RideProvider>(context, listen: false).updateRideStatus("in_progress", currentRide!);
    final dropoffPoint = mp.Point(
      coordinates: mp.Position(
        currentRide!.destination["coordinates"].longitude,
        currentRide!.destination["coordinates"].latitude,
      ),
    );
    destinationProvider.destination = dropoffPoint;
    destinationProvider.redrawRoute();
    _distanceUpdateTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) => _updateDroppingOffDistance(),
    );
  }

  Future<void> _updateDroppingOffDistance() async {
    try {
      final currentPosition = await gl.Geolocator.getCurrentPosition();
      final destinationProvider = Provider.of<DestinationProvider>(context, listen: true);
      final currentToDropoff = gl.Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        currentRide!.destination["coordinates"].latitude,
        currentRide!.destination["coordinates"].longitude,
      );
      destinationProvider.updateCurrentToDropoffDistance(currentToDropoff / 1000);
    } catch (e, stackTrace) {
      debugPrint("Failed to update dropoff distance: $e\n$stackTrace");
    }
  }

  void resetToDefault() {
    Provider.of<UserProvider>(context, listen: false).updateOnlineStatus(false);
    Provider.of<DestinationProvider>(context, listen: false).clearAll();
    Provider.of<FareProvider>(context, listen: false).clear();
    driverState = DriverState.offline;
    _ridesSubscription = null;
    currentRide = null;
    _ridesSubscription?.cancel();
    _onlineDistanceTimer?.cancel();
    _distanceUpdateTimer?.cancel();
    _waitTimer?.cancel();
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

  String formatWaitTime() {
    return "0:${_remainingWaitTime.toString().padLeft(2, '0')}";
  }

  bool get isCancelEnabled => _remainingWaitTime == 0;

  void handleRideCancel() async { 
    if (!isMounted()) return;

    final context = this.context;
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride canceled')),
        );
      }
    }
  }

  void _performCancellation() {
    Provider.of<RideProvider>(context, listen: false).updateRideStatus("canceled", currentRide!);
    Provider.of<UserProvider>(context, listen: false).updateOnlineStatus(true);
    driverState = DriverState.lookingForRide;
    _startRideListener();
    _calculateDistances();
    _startOnlineUpdates();
    currentRide = null;
  }

  void dispose() {
    _ridesSubscription?.cancel();
    _onlineDistanceTimer?.cancel();
    _distanceUpdateTimer?.cancel();
    _waitTimer?.cancel();
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wassilni/models/ride_model.dart';
import 'package:wassilni/pages/auth/login_page.dart';
import 'package:wassilni/providers/destination_provider.dart';
import 'package:wassilni/providers/fare_provider.dart';
import 'package:wassilni/pages/map.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:wassilni/widgets/driver_widget.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:geolocator/geolocator.dart' as gl;
import 'dart:async'; 
import 'package:wassilni/providers/user_provider.dart';
import 'package:wassilni/providers/ride_provider.dart';


enum DriverState { offline, lookingForRide, foundRide, pickingUp, waiting, droppingOff }
class DriverMap extends StatefulWidget {
  const DriverMap({super.key});
  @override
  State<DriverMap> createState() => _DriverMapState();
}

class _DriverMapState extends State<DriverMap> {
  DriverState driverState = DriverState.offline;
  StreamSubscription<QuerySnapshot>? _ridesSubscription;
 
  @override
  void initState() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    userProvider.updateOnlineStatus(false);
    super.initState();
  }

  @override
  void dispose() {
     resetToDefault();
    _ridesSubscription?.cancel();
    _onlineDistanceTimer?.cancel();
    _distanceUpdateTimer?.cancel();
    _waitTimer?.cancel();
    super.dispose();
   
  }

  void _startRideListener([bool forceNew = false]) {
    if (_ridesSubscription != null && !forceNew) return;
  _ridesSubscription?.cancel(); 
  final userProvider = Provider.of<UserProvider>(context, listen: false);
  final driverId = userProvider.currentUser?.id;
  if (driverId == null) return;
  bool initialDataProcessed = false;
  _ridesSubscription = FirebaseFirestore.instance
      .collection('rides')
      .where('driverId', isEqualTo: driverId)
      .where('status', isEqualTo: "requested")
      .snapshots(includeMetadataChanges: true)
      .listen((snapshot) async {
        if (!initialDataProcessed) {
          if (snapshot.metadata.isFromCache) return;
          initialDataProcessed = true;
        }
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added &&
              !change.doc.metadata.hasPendingWrites) {
            setState(() {
              _currentRide = Ride.fromFirestore(change.doc);
              driverState = DriverState.foundRide;
            });
            await userProvider.updateOnlineStatus(false);
            _updateProvidersWithRideData(_currentRide!);
          }
        }
      }, onError: (error) => debugPrint("Ride stream error: $error"));
}
Ride? _currentRide;
Ride get currentRide => _currentRide!;
set currentRide(Ride? ride) {
  setState(() {
    _currentRide = ride;
  });
}


void _updateProvidersWithRideData(Ride ride) {
  final destProvider = Provider.of<DestinationProvider>(context, listen: false);
  final fareProvider = Provider.of<FareProvider>(context, listen: false);
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
  destProvider..pickup = pickupPoint..destination = dropoffPoint;
  fareProvider..estimatedDistance = ride.distance..estimatedDuration = ride.duration..estimatedFare = ride.fare;
}
  String panelTitle() {
    return "${currentRide.fare.toStringAsFixed(2)}\$";
  }
  String panelSubtitle1(BuildContext context) {
    final destinationProvider = Provider.of<DestinationProvider>(context);
    final distance = destinationProvider.currentToPickupDistance?.toStringAsFixed(1) ?? '--';
    final fareProvider = Provider.of<FareProvider>(context);
    final duration = (fareProvider.currentToPickupDuration ?? 0).toInt();
    return "${(duration/60).toStringAsFixed(1)} min ($distance KM) away";
  }
  String panelSubtitle2(BuildContext context) {
    return "${(currentRide.duration/60).toStringAsFixed(1)} min (${(currentRide.distance/1000).toStringAsFixed(1)} KM) away";
  }
  String get panelLocation1 => currentRide.pickup["address"]; // Pickup location
  String get panelLocation2 => currentRide.destination["address"]; // Dropoff location
  String get userName => "Rider"; //this was planned to use the rider's name, but due to it not being the model i used a placeholder
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
      final destinationProvider = Provider.of<DestinationProvider>(context, listen: true);
      final currentToDropoff = gl.Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        currentRide.destination["coordinates"].latitude,
        currentRide.destination["coordinates"].longitude,
      );
      destinationProvider.updateCurrentToDropoffDistance(currentToDropoff / 1000); 
    } catch (e, stackTrace) {
      debugPrint("Failed to update dropoff distance: $e\n$stackTrace");
    }
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
 void toggleOnlineStatus() async {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (driverState == DriverState.offline) {
        await userProvider.updateOnlineStatus(true);
        setState(() {
          driverState = DriverState.lookingForRide;
        });
        _startRideListener(true);
        _calculateDistances();
        _startOnlineUpdates();
      } 
    else if (driverState == DriverState.foundRide || driverState == DriverState.lookingForRide) {
          await userProvider.updateOnlineStatus(false);
          setState(() {
            driverState = DriverState.offline;
          });
          _onlineDistanceTimer?.cancel(); 
          resetToDefault();
        }
}
  Future<void> _calculateDistances() async {
    try {
      if (driverState != DriverState.foundRide && driverState != DriverState.pickingUp) return;
      final currentPosition = await gl.Geolocator.getCurrentPosition();
      final destinationProvider = Provider.of<DestinationProvider>(context, listen: false);
      final currentToPickup = gl.Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        currentRide.pickup["coordinates"].latitude,
        currentRide.pickup["coordinates"].longitude,
      ) / 1000; 
      destinationProvider.updateDistances(currentToPickup);
      final fareProvider = Provider.of<FareProvider>(context, listen: false);
      final currentPoint = mp.Point(
      coordinates: mp.Position(
        currentPosition.longitude,
        currentPosition.latitude,
      ),
    );
    final pickupPoint = mp.Point(
      coordinates: mp.Position(
        currentRide.pickup["coordinates"].longitude,
        currentRide.pickup["coordinates"].latitude,
      ),
    );
      await fareProvider.updateCurrentToPickupDuration(currentPoint, pickupPoint); // Update duration,
      if (driverState == DriverState.pickingUp && currentToPickup <= 0.040 && mounted) {
        transitionToWaiting();
      }
    } catch (e) {
      debugPrint("Distance error: $e");
      if (mounted) setState(() => driverState = DriverState.offline);
    }
  }
  void acceptRide() {
  setState(() => driverState = DriverState.pickingUp);
  final destinationProvider = Provider.of<DestinationProvider>(context, listen: false);
  Provider.of<RideProvider>(context, listen: false).updateRideStatus("accepted", currentRide);
  final pickupPoint = mp.Point(
    coordinates: mp.Position(
      currentRide.pickup["coordinates"].longitude,
      currentRide.pickup["coordinates"].latitude,
    ),
  );
  destinationProvider.destination = pickupPoint;
  destinationProvider.pickup = pickupPoint;
  destinationProvider.redrawRoute(); // Call redrawRoute after accepting ride 
}
  void startRide() async {
  setState(() => driverState = DriverState.droppingOff);
  final destinationProvider = Provider.of<DestinationProvider>(context, listen: false);
  Provider.of<RideProvider>(context, listen: false).updateRideStatus("in_progress", currentRide);
  final dropoffPoint = mp.Point(
    coordinates: mp.Position(
      currentRide.destination["coordinates"].longitude,
      currentRide.destination["coordinates"].latitude,
    ),
  );
  destinationProvider.destination = dropoffPoint;
  destinationProvider.redrawRoute(); 
  _distanceUpdateTimer = Timer.periodic(
    const Duration(seconds: 5),
    (timer) => _updateDroppingOffDistance()
  );
}
  void resetToDefault() {
    final destinationProvider = Provider.of<DestinationProvider>(context, listen: false);
    final fareProvider = Provider.of<FareProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    userProvider.updateOnlineStatus(false); 
    setState(() {
    driverState = DriverState.offline;
    destinationProvider.clearAll();
    destinationProvider.clearDistances();
    fareProvider.clear();
    _ridesSubscription?.cancel();
    _ridesSubscription = null;
    _currentRide = null;
    destinationProvider.redrawRoute();
  });
    _onlineDistanceTimer?.cancel();
    _distanceUpdateTimer?.cancel();
    _waitTimer?.cancel();
  }

  void transitionToWaiting() {
    setState(() {
      driverState = DriverState.waiting;
      _remainingWaitTime = 7; // Reset timer
      _waitTimer?.cancel(); 
      _waitTimer = Timer.periodic(const Duration(seconds: 1), (timer) { // Start countdown
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
    });
  }
void _handleRideCancel() async {
  context.read<RideProvider>().updateRideStatus("canceled", currentRide);
  await context.read<UserProvider>().updateOnlineStatus(true);
  setState(() => driverState = DriverState.lookingForRide);
  _startRideListener(true);
  _calculateDistances();
  _startOnlineUpdates();
}
@override
  Widget build(BuildContext context) {
    final destinationProvider = Provider.of<DestinationProvider>(context);
    return SafeArea(
      child: Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Map(
              key: ValueKey(
                  destinationProvider.drawRoute.hashCode), // Reload map when redraw changes
            ),
          ),
          if (driverState == DriverState.offline)
            Positioned(
              top: 40, 
              left: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  iconSize: 30,
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: () async {
                    final userProvider = Provider.of<UserProvider>(context, listen: false);
                    await userProvider.logout();
                    if (mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    }
                  },
                ),
              ),
            ),
          // Online/Offline toggle button
          if (driverState == DriverState.offline ||driverState == DriverState.lookingForRide || driverState == DriverState.foundRide)
            buildOnlineOfflineButton(
              onPressed: toggleOnlineStatus,
              isOnline: driverState != DriverState.offline,
            ),
          // Sliding panel for "You're Online"
           if (driverState == DriverState.foundRide)
            Consumer<DestinationProvider>(
              builder: (context, provider, _) {
                // Add force rebuild trigger
                return SlidingUpPanel(
                  minHeight: 50,
                  maxHeight: 450,
                  defaultPanelState: PanelState.OPEN,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  color: Colors.black,
                  panel: buildPanelContent(
                    panelTitle: panelTitle(),
                    panelSubtitle1: panelSubtitle1(context),
                    panelSubtitle2: panelSubtitle2(context),
                    panelLocation1: panelLocation1,
                    panelLocation2: panelLocation2,
                    onAcceptRide: acceptRide,
                    onCancelRide: _handleRideCancel,
                  ),
                  collapsed: buildCollapsedPanel("You're Online"),
                );
              },
            ),
          // Footer for "Picking Up User"
          if (driverState == DriverState.pickingUp)
            Consumer<DestinationProvider>(
              builder: (context, provider, _) {
                final distanceKm = provider.currentToPickupDistance;
                String distanceText;
                if (distanceKm == null) {
                  distanceText = '--';
                } else if (distanceKm <= 0.1) {
                  final distanceMeters = (distanceKm * 1000).round();
                  distanceText = '$distanceMeters m';
                } else {
                  distanceText = '${distanceKm.toStringAsFixed(1)} km';
                }
                return buildPickingUpFooter(
                  userName: userName,
                  distanceText: distanceText,
                  onTap: transitionToWaiting,
                );
              },
            ),
          // Sliding panel for "Waiting for User"
          if (driverState == DriverState.waiting)
            SlidingUpPanel(
              minHeight: 100,
              maxHeight: 180,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              color: Colors.black,
              panel: buildWaitingPanel(
                userName: userName,
                waitTime: _formatWaitTime(),
                onStartRide: startRide,
                onCancelRide: _isCancelEnabled
                  ? _handleRideCancel
                  : null,
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
              maxHeight: 280,
              defaultPanelState: PanelState.OPEN,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              color: Colors.black,
              panel: buildDroppingOffPanels(
                currentRide: currentRide,
                context: context,
                onCompleteRide: () {
                  Provider.of<RideProvider>(context, listen: false)
                    .updateRideStatus("completed", currentRide);
                  resetToDefault();
                },
              ),
              collapsed: buildCollapsedPanel("Dropping Off rider"),
                ),

              if (driverState == DriverState.offline || driverState == DriverState.lookingForRide)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: FooterWidget(
                        text: driverState == DriverState.lookingForRide
                            ? "You're Online"
                            : "You're Offline",
                      ),
                    ),
        ],
      ),
    ));
  }
}
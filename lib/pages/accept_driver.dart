import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:provider/provider.dart';
import 'package:wassilni/models/user_model.dart';
import 'package:wassilni/pages/to_destination.dart';
import 'package:wassilni/providers/destination_provider.dart';
import 'package:wassilni/providers/user_provider.dart';
import 'package:wassilni/providers/ride_provider.dart';
import 'package:wassilni/pages/map.dart';
import '../models/ride_model.dart';

class AcceptDriverPage extends StatefulWidget {
  final routeInfo;

  const AcceptDriverPage({Key? key, required this.routeInfo}) : super(key: key);

  @override
  State<AcceptDriverPage> createState() => _AcceptDriverPageState();
}

class _AcceptDriverPageState extends State<AcceptDriverPage> with WidgetsBindingObserver {
  UserModel? _currentUser;
  UserModel? _driver;
  Timer? _etaTimer;
  int _etaMinutes = 0;
  StreamSubscription? _driverLocationSubscription;
  gl.Position? _currentPosition;
  DestinationProvider? _destinationProvider;
  RideProvider? _rideProvider;
  bool _isInitialized = false;
  bool _isMounted = false;
  StreamSubscription<DocumentSnapshot>? _rideSubscription;
  List<String> _excludedDrivers = []; // List to track declined drivers
  String? _currentRideId;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    WidgetsBinding.instance.addObserver(this);
    Future.delayed(Duration.zero, () {
      if (_isMounted) {
        _initializeData();
      }
    });
  }

  void _initializeData() async {
    await _getCurrentPosition();
    _findNearestDriver(_excludedDrivers); // Start with no excluded drivers
    _etaTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_isMounted) {
        _updateETA();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized && _isMounted) {
      _isInitialized = true;
      try {
        _destinationProvider = Provider.of<DestinationProvider>(context, listen: false);
        _rideProvider = Provider.of<RideProvider>(context, listen: false);
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        if (userProvider.currentUser != null) {
          _currentUser = userProvider.currentUser;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not found. Please login again.')),
          );
          Future.delayed(const Duration(seconds: 1), () {
            if (_isMounted) Navigator.pop(context);
          });
        }
      } catch (e) {
        print("Error in didChangeDependencies: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Initialization error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _isMounted = false;
    WidgetsBinding.instance.removeObserver(this);
    _etaTimer?.cancel();
    _driverLocationSubscription?.cancel();
    _rideSubscription?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentPosition() async {
    if (!_isMounted) return;
    try {
      _currentPosition = await gl.Geolocator.getCurrentPosition();
      if (_isMounted && _driver != null) {
        _updateETA();
      }
    } catch (e) {
      print("Error getting current position: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get your location: $e')),
      );
    }
  }

  Future<void> _findNearestDriver(List<String> excludedDrivers) async {
    if (!_isMounted) return;
    try {
      // Fetch all online drivers
      final driversSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('type', isEqualTo: 'driver')
          .where('isOnline', isEqualTo: true)
          .get();

      // Filter out excluded drivers and convert to list
      final availableDrivers = driversSnapshot.docs
          .map((doc) => UserModel.fromFireStore(doc))
          .where((driver) => !excludedDrivers.contains(driver.id))
          .toList();

      if (availableDrivers.isEmpty || _currentPosition == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No drivers available or location unavailable')),
        );
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (_isMounted) Navigator.pop(context);
        });
        return;
      }

      // Sort by distance
      availableDrivers.sort((a, b) {
        final distanceA = gl.Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          a.location.latitude,
          a.location.longitude,
        );
        final distanceB = gl.Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          b.location.latitude,
          b.location.longitude,
        );
        return distanceA.compareTo(distanceB);
      });

      // Select the closest driver
      final closestDriver = availableDrivers.first;

      // Create the ride
      final ride = Ride(
        rideId: _currentRideId ?? '',
        riderId: _currentUser!.id,
        driverId: closestDriver.id,
        status: 'requested',
        pickup: {
          'coordinates': GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
          'address': widget.routeInfo['pickup']['address'] ?? ''
        },
        destination: widget.routeInfo['destination'],
        fare: widget.routeInfo['fare'],
        distance: widget.routeInfo['distance'],
        duration: widget.routeInfo['duration'],
        timestamps: {'requested': Timestamp.now()},
      );

      if (_currentRideId == null) {
        // Create new ride
        final rideRef = await FirebaseFirestore.instance.collection('rides').add(ride.toMap());
        _currentRideId = rideRef.id;
        final rideDoc = await rideRef.get();
        _rideProvider!.setCurrentRide(Ride.fromFirestore(rideDoc));
      } else {
        // Update existing ride with new driver
        await FirebaseFirestore.instance.collection('rides').doc(_currentRideId).update({
          'driverId': closestDriver.id,
          'status': 'requested',
        });
        _rideProvider!.setCurrentRide(ride.copyWith(rideId: _currentRideId, driverId: closestDriver.id));
      }

      // Set up listener if not already
      if (_rideSubscription == null) {
        _rideSubscription = FirebaseFirestore.instance
            .collection('rides')
            .doc(_currentRideId)
            .snapshots()
            .listen(_handleRideUpdate);
      }
    } catch (e) {
      print("Error in _findNearestDriver: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error finding driver: $e')),
      );
      Future.delayed(const Duration(seconds: 1), () {
        if (_isMounted) Navigator.pop(context);
      });
    }
  }

  void _handleRideUpdate(DocumentSnapshot snapshot) {
    if (!snapshot.exists || !_isMounted) return;
    final updatedRide = Ride.fromFirestore(snapshot);
    _rideProvider!.setCurrentRide(updatedRide);

    if (updatedRide.status == 'accepted') {
      // Driver accepted, fetch driver details and update UI
      FirebaseFirestore.instance
          .collection('users')
          .doc(updatedRide.driverId)
          .get()
          .then((driverDoc) {
        if (_isMounted) {
          setState(() {
            _driver = UserModel.fromFireStore(driverDoc);
          });
          _listenToDriverLocation();
          _updateETA();
        }
      });
    } else if (updatedRide.status == 'canceled') {
      // Driver declined, mark driver and find next
      setState(() {
        _excludedDrivers.add(updatedRide.driverId);
        _driver = null; // Clear current driver
      });
      _findNearestDriver(_excludedDrivers);
    } else if (updatedRide.status == 'in_progress') {
      print("################################");
      print("triggered");
      // Navigate to ToDestination
      final geoPoint = updatedRide.destination['coordinates'] as GeoPoint;
      final newDestination = mp.Point(
        coordinates: mp.Position(
          geoPoint.longitude,
          geoPoint.latitude,
        ),
      );

      _destinationProvider!.destination = newDestination;
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => ToDestination(),
      ));
    }
  }

  void _listenToDriverLocation() {
    if (_driver == null || !_isMounted) return;
    _driverLocationSubscription?.cancel();
    _driverLocationSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_driver!.id)
        .snapshots()
        .listen((snapshot) {
      if (!_isMounted || !snapshot.exists) return;
      final updatedDriver = UserModel.fromFireStore(snapshot);
      setState(() => _driver = updatedDriver);
      _updateETA();
    }, onError: (e) => print("Error in driver location subscription: $e"));
  }

  Future<void> _updateETA() async {
    if (_driver == null || _currentPosition == null || !_isMounted) return;
    final distance = gl.Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _driver!.location.latitude,
      _driver!.location.longitude,
    );
    const double averageSpeedMps = 8.33; // 30 km/h
    final etaSeconds = (distance / averageSpeedMps).round();
    setState(() => _etaMinutes = (etaSeconds / 60).ceil().clamp(1, double.infinity).toInt());
  }

  void _handleCancelRide() {
    if (!_isMounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Ride?'),
        content: const Text('Are you sure you want to cancel this ride?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('NO'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelRide();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ride canceled')),
              );
              Navigator.pop(context);
            },
            child: const Text('YES'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelRide() async {
    if (_rideProvider?.currentRide != null) {
      try {
        await FirebaseFirestore.instance
            .collection('rides')
            .doc(_rideProvider!.currentRide!.rideId)
            .update({
          'status': 'canceled',
          'timestamps.canceled': Timestamp.now(),
        });
        _rideProvider!.clearCurrentRide();
      } catch (e) {
        print("Error canceling ride: $e");
      }
    }
  }

  void _selectPaymentMethod() {
    if (!_isMounted) return;
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        color: Colors.black,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Payment Method',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.money, color: Colors.green),
              title: const Text('Cash', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.credit_card, color: Colors.blue),
              title: const Text('Credit Card', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Consumer<RideProvider>(
        builder: (context, rideProvider, child) {
          final currentRide = rideProvider.currentRide;
          if (currentRide == null || currentRide.status == 'requested' || _driver == null) {
            return _buildLoadingScreen();
          } else if (currentRide.status == 'accepted' && _driver != null) {
            return _buildDriverDetails();
          } else {
            return _buildLoadingScreen(); // Default to loading for other statuses
          }
        },
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Stack(
      children: [
        Container(
          color: Colors.black.withOpacity(0.7),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  "Finding your driver...",
                  style: TextStyle(color: Colors.white, fontSize: 18),

                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 50,
          left: 16,
          child: CircleAvatar(
            backgroundColor: Colors.black54,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDriverDetails() {
    return Stack(
      children: [
       const Map(),

        Positioned(
          top: 200,
          left: 100,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              "$_etaMinutes MIN\nETA",
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "YOUR DRIVER IS EN ROUTE...",
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.grey,
                      backgroundImage: _driver!.vehicle['photoUrl']?.isNotEmpty == true
                          ? NetworkImage(_driver!.vehicle['photoUrl']!)
                          : null,
                      child: _driver!.vehicle['photoUrl']?.isEmpty != false
                          ? const Icon(Icons.person, size: 30, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _driver!.vehicle['driver_name'] ?? 'Driver',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            _driver!.phone,
                            style: const TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white),
                      ),
                      child: Text(
                        _driver!.vehicle['licensePlate'] ?? 'Unknown',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "COST ",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    Consumer<RideProvider>(
                      builder: (context, rideProvider, child) {
                        final fare = rideProvider.currentRide?.fare ?? 0.0;
                        return Text(
                          "\$${fare.toStringAsFixed(1)}",
                          style: const TextStyle(color: Colors.grey, fontSize: 20),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _selectPaymentMethod,
                  child: const Text("Choose Payment Method"),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _handleCancelRide,
                  child: const Text(
                    "Cancel Ride",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
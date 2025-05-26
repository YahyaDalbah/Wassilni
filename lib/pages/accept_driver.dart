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
  final routeInfo; //from position_destination

  const AcceptDriverPage({Key? key, required this.routeInfo}) : super(key: key);

  @override
  State<AcceptDriverPage> createState() => _AcceptDriverPageState();
}

class _AcceptDriverPageState extends State<AcceptDriverPage> with WidgetsBindingObserver {
  UserModel? _currentUser;
  UserModel? _driver;
  Timer? _etaTimer;
  int _etaMinutes = 0;
  bool _isLoading = true;
  StreamSubscription? _driverLocationSubscription;
  gl.Position? _currentPosition;
  DestinationProvider? _destinationProvider;
  RideProvider? _rideProvider;
  bool _isInitialized = false;
  bool _isMounted = false;
  StreamSubscription<DocumentSnapshot>? _rideSubscription;

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
    _findNearestDriver();
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

  Future<void> _findNearestDriver() async {
    if (!_isMounted) return;
    try {
      setState(() => _isLoading = true);

      final QuerySnapshot driversSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('type', isEqualTo: 'driver')
          .where('isOnline', isEqualTo: true)
          .get();

      if (!_isMounted) return;

      if (driversSnapshot.docs.isEmpty || _currentPosition == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No drivers available or location unavailable')),
        );
        setState(() => _isLoading = false);
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (_isMounted) Navigator.pop(context);
        });
        return;
      }

      UserModel? closestDriver;
      num minDistance = double.infinity;

      for (var doc in driversSnapshot.docs) {
        final driver = UserModel.fromFireStore(doc);
        final distance = gl.Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          driver.location.latitude,
          driver.location.longitude,
        );
        if (distance < minDistance) {
          minDistance = distance;
          closestDriver = driver;
        }
      }

      if (closestDriver != null) {
        _driver = closestDriver;
        _listenToDriverLocation();
        _updateETA();
        await _createRide();
        setState(() => _isLoading = false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No drivers available at the moment')),
        );
        setState(() => _isLoading = false);
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (_isMounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      print("Error fetching nearest driver: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching driver: $e')),
      );
      setState(() => _isLoading = false);
      Future.delayed(const Duration(seconds: 1), () {
        if (_isMounted) Navigator.pop(context);
      });
    }
  }

  Future<void> _createRide() async {
    if (!_isMounted || _currentUser == null || _driver == null || _rideProvider == null) return;

    try {
      final ride = Ride(
        rideId: '', // Will be set by Firestore
        riderId: _currentUser!.id,
        driverId: _driver!.id,
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

      final rideRef = await FirebaseFirestore.instance.collection('rides').add(ride.toMap());
      final rideDoc = await rideRef.get();
      _rideProvider!.setCurrentRide(Ride.fromFirestore(rideDoc));

      _rideSubscription = FirebaseFirestore.instance
        .collection('rides')
        .doc(rideDoc.id)
        .snapshots()
        .listen((snapshot) async {
      if (!_isMounted) return;
      final updatedRide = Ride.fromFirestore(snapshot);
      _rideProvider!.setCurrentRide(updatedRide);
      if (updatedRide.status == 'in_progress') {
        print("################################");
        print("triggered");
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
    });
    } catch (e) {
      print("Error creating ride: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating ride: $e')),
      );
    }
  }

  void _listenToDriverLocation() {
    if (_driver == null || !_isMounted) return;
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('NO')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelRide();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ride canceled')));
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
            const Text('Select Payment Method', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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

    if (_isLoading || _driver == null) {
      return Scaffold(
        body: Stack(
          children: [
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text("Finding your driver...", style: TextStyle(color: Colors.white, fontSize: 18)),
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
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Consumer<DestinationProvider>(builder: (context, destProvider, child) => const Map()),
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
          Positioned(
            top: 200,
            left: 100,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
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
                  const Text("YOUR DRIVER IS EN ROUTE...", style: TextStyle(color: Colors.white70)),
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
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            Text(_driver!.phone, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(border: Border.all(color: Colors.white)),
                        child: Text(_driver!.vehicle['licensePlate'] ?? 'Unknown', style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("COST ", style: TextStyle(color: Colors.white, fontSize: 18)),
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
                    child: const Text("Cancel Ride", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
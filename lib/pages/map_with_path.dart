import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:provider/provider.dart';
import 'package:wassilni/helpers/directions_handler.dart';
import 'package:wassilni/models/ride.dart';
import 'package:wassilni/pages/waiting_for_payment.dart';
import 'package:wassilni/providers/destination_provider.dart';
import 'package:wassilni/providers/fare_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart'; // Add this import
import 'package:turf/turf.dart' as turf; // Add this import

class MapWithPath extends StatefulWidget {
  final Ride ride;

  const MapWithPath({super.key, required this.ride});

  @override
  State<MapWithPath> createState() => _MapWithPathState();
}

void _onStyleLoadedCallback(mp.StyleLoadedEventData event) {
  // Add any logic you want to execute when the map style is loaded.
  print("Map style loaded successfully.");
}

class _MapWithPathState extends State<MapWithPath> {
  mp.MapboxMap? mapboxMap;
  StreamSubscription? userPositionStream;

  late DestinationProvider _destinationProvider;
  mp.CameraOptions? _initialCameraOptions;

  bool isRideStarted = false; // Track if the ride has started
  bool isWaitingForYahya = false; // Track if the "Waiting for Yahya" sheet is shown

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _destinationProvider = Provider.of<DestinationProvider>(context);
  }

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _setupPositionTracking();
  }

  @override
  void dispose() {
    print("Disposing resources...");
    userPositionStream?.cancel();
    super.dispose();
  }

  void _onMapCreated(mp.MapboxMap? controller) async {
    setState(() {
      mapboxMap = controller;
    });

    // Enable location settings
    mapboxMap?.location.updateSettings(
      mp.LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        showAccuracyRing: true,
      ),
    );

    // Apply the initial camera options to focus on the user's position
    if (_initialCameraOptions != null) {
      mapboxMap?.flyTo(
        _initialCameraOptions!,
        mp.MapAnimationOptions(duration: 1000),
      );
    }

    // Render the points
    _renderPoints();

    // Render the route
    _renderRoute();
  }

  Future<void> _initializeCamera() async {
    try {
      final position = await gl.Geolocator.getCurrentPosition();
      print("User position: ${position.latitude}, ${position.longitude}");
      setState(() {
        _initialCameraOptions = mp.CameraOptions(
          center: mp.Point(
            coordinates: mp.Position(position.longitude, position.latitude),
          ),
          zoom: 13.0,
        );
      });
    } catch (e) {
      print("Error fetching position: $e");
      setState(() {
        _initialCameraOptions = mp.CameraOptions(
          center: mp.Point(coordinates: mp.Position(35.031363, 32.317301)),
          zoom: 13.0,
        );
      });
    }
  }

  Future<void> _setupPositionTracking() async {
    bool serviceEnabled;
    gl.LocationPermission permission;

    serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return Future.error("Location services are disabled");
    }
    permission = await gl.Geolocator.checkPermission();
    if (permission == gl.LocationPermission.denied) {
      permission = await gl.Geolocator.requestPermission();
      if (permission == gl.LocationPermission.denied) {
        return Future.error("Location permissions are denied");
      }
    }
    if (permission == gl.LocationPermission.deniedForever) {
      return Future.error("Location permissions are permanently denied");
    }
    gl.LocationSettings locationSettings = gl.LocationSettings(
      accuracy: gl.LocationAccuracy.high,
      distanceFilter: 100,
    );

    userPositionStream?.cancel();
    userPositionStream = gl.Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((gl.Position position) async {
      if (mapboxMap != null && _destinationProvider.destination != null) {
        var origin = mp.Point(
          coordinates: mp.Position(position.longitude, position.latitude),
        );
        var destination = _destinationProvider.destination!;

        var routeData = await getDirectionsRoute(origin, destination);
        var featureCollection = routeData["featureCollection"];
        var features = featureCollection['features'] as List;
        var rawCods = features[0]["geometry"]["coordinates"] as List;
        var cods = rawCods
            .map<mp.Position>((coord) => mp.Position(coord[0], coord[1]))
            .toList();
        await mapboxMap?.style.updateGeoJSONSourceFeatures(
          "route",
          "updated_route",
          [
            mp.Feature(
              id: "route_line",
              geometry: mp.LineString(coordinates: cods),
            ),
          ],
        );
      }
    });
  }

  Future<Map<String, dynamic>> _fetchRoute() async {
    final String baseUrl = 'https://api.mapbox.com/directions/v5/mapbox/driving';
    final String accessToken = dotenv.env["MAPBOX_ACCESS_TOKEN"] ?? '';
    if (accessToken.isEmpty) {
      throw Exception('Mapbox access token is missing. Please check your .env file.');
    }

    // Use the Ride model's pickup and dropoff coordinates
    final String url =
        '$baseUrl/${widget.ride.pickupLongitude},${widget.ride.pickupLatitude};${widget.ride.dropoffLongitude},${widget.ride.dropoffLatitude}?geometries=geojson&access_token=$accessToken';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch route from Mapbox Directions API: ${response.body}');
    }
  }

  Future<void> _renderRoute() async {
    if (mapboxMap == null) return;

    try {
      // Fetch the route using the Ride model's coordinates
      final routeData = await _fetchRoute();
      final geometry = routeData['routes'][0]['geometry'];

      // Add the route as a GeoJSON source
      await mapboxMap?.style.addSource(
        mp.GeoJsonSource(
          id: 'route',
          data: json.encode({
            'type': 'Feature',
            'geometry': geometry,
          }),
        ),
      );

      // Add a line layer to render the route
      await mapboxMap?.style.addLayer(
        mp.LineLayer(
          id: 'route_layer',
          sourceId: 'route',
          lineJoin: mp.LineJoin.ROUND,
          lineCap: mp.LineCap.ROUND,
          lineColor: Colors.blue.value,
          lineWidth: 5.0,
        ),
      );
    } catch (e) {
      print('Error rendering route: $e');
    }
  }

  Future<void> _initializeRoute() async {
    var destination = _destinationProvider.destination!;
    var currentPosition = await gl.Geolocator.getCurrentPosition();
    var origin = mp.Point(
      coordinates: mp.Position(
        currentPosition.longitude,
        currentPosition.latitude,
      ),
    );

    var routeData = await getDirectionsRoute(origin, destination);
    var featureCollection = routeData["featureCollection"];
    var estimatedFare = routeData["estimatedFare"];
    if (context.mounted) {
      Provider.of<FareProvider>(context, listen: false).estimatedFare =
          estimatedFare;
    }
    await mapboxMap?.style.addSource(
      mp.GeoJsonSource(id: "route", data: json.encode(featureCollection)),
    );

    await mapboxMap?.style.addLayer(
      mp.LineLayer(
        id: "route_layer",
        sourceId: "route",
        lineJoin: mp.LineJoin.ROUND,
        lineCap: mp.LineCap.ROUND,
        lineColor: Colors.purple.value,
        lineWidth: 6.0,
      ),
    );

    createMarker(destination);
  }

  Future<Uint8List> loadMarkerImage() async {
    var byteData = await rootBundle.load("assets/location.png");
    return byteData.buffer.asUint8List();
  }

  void createMarker(mp.Point point) async {
    final pointAnnotationManager =
        await mapboxMap?.annotations.createPointAnnotationManager();
    final Uint8List imageData = await loadMarkerImage();
    mp.PointAnnotationOptions pointAnnotationOptions =
        mp.PointAnnotationOptions(image: imageData, geometry: point);

    pointAnnotationManager?.create(pointAnnotationOptions);
  }

  void _renderPoints() async {
    if (mapboxMap == null) return;

    // Render pickup location
    createMarker(mp.Point(
      coordinates: mp.Position(widget.ride.pickupLongitude, widget.ride.pickupLatitude),
    ));

    // Render dropoff location
    createMarker(mp.Point(
      coordinates: mp.Position(widget.ride.dropoffLongitude, widget.ride.dropoffLatitude),
    ));

    // Render user's current location
    final position = await gl.Geolocator.getCurrentPosition();
    createMarker(mp.Point(
      coordinates: mp.Position(position.longitude, position.latitude),
    ));
  }

  @override
  Widget build(BuildContext context) {
    bool isOnline = false; // Track online/offline state
    bool isAccepted = false; // Track if the ride is accepted
    bool isWaitingForYahya = false; // Track if the "Waiting for Yahya" sheet is shown
    bool isRideStarted = false; // Track if the ride has started
    bool isRideCompleted = false; // Track if the ride is completed
    String buttonText = "Go!"; // Track button text

    return StatefulBuilder(
      builder: (context, setState) {
        return Scaffold(
          body: Stack(
            children: [
              // Fullscreen Map
              _initialCameraOptions == null
                  ? const Center(child: CircularProgressIndicator())
                  : mp.MapWidget(
                      onMapCreated: _onMapCreated,
                      styleUri: mp.MapboxStyles.MAPBOX_STREETS,
                      onStyleLoadedListener: (event) => _onStyleLoadedCallback(event),
                      cameraOptions: _initialCameraOptions,
                    ),
              // Floating Action Button (Go! / Stop! Button)
              if (!isAccepted)
                Positioned(
                  bottom: 80,
                  left: MediaQuery.of(context).size.width * 0.125, // Center horizontally (12.5% padding on each side)
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.75, // 75% of screen width
                    child: FloatingActionButton.extended(
                      onPressed: () {
                        setState(() {
                          // Toggle button text and online/offline state
                          if (buttonText == "Go!") {
                            buttonText = "Stop!";
                            isOnline = true;
                          } else {
                            buttonText = "Go!";
                            isOnline = false;
                          }
                        });
                      },
                      backgroundColor: buttonText == "Go!" ? Colors.blue : Colors.red,
                      label: Text(
                        buttonText,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              // Draggable Bottom Sheet (Online Details)
              if (isOnline && !isAccepted)
                DraggableScrollableSheet(
                  initialChildSize: 0.07, // Initial height of the bottom sheet
                  minChildSize: 0.07, // Minimum height when collapsed
                  maxChildSize: 0.4, // Maximum height when expanded
                  builder: (context, scrollController) {
                    // Static values for demonstration
                    const double staticFare = 10.00; // Static fare value
                    const String pickupDistance = "6 min (3.1 KM)"; // Static pickup distance
                    const String dropoffDistance = "3 min (1.0 KM)"; // Static dropoff distance
                    const String pickupLocation = "Tulkarm"; // Static pickup location
                    const String dropoffLocation = "Nablus"; // Static dropoff location

                    return Container(
                      color: Colors.black,
                      padding: const EdgeInsets.all(0), // Reduced padding
                      child: ListView(
                        controller: scrollController,
                        children: [
                          // Online Status
                          Center(
                            child: Text(
                              "You are online now",
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Centered Fare
                          Center(
                            child: Text(
                              "$staticFare\$",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Pickup Distance
                          Row(
                            children: [
                              const Icon(Icons.circle, color: Colors.white, size: 12),
                              const SizedBox(width: 8),
                              Text(
                                pickupDistance,
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pickupLocation,
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          // Dropoff Distance
                          Row(
                            children: [
                              const Icon(Icons.square, color: Colors.white, size: 12),
                              const SizedBox(width: 8),
                              Text(
                                dropoffDistance,
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dropoffLocation,
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          // Accept Button
                          Center(
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width * 0.75, // 75% of screen width
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    isAccepted = true; // Hide the bottom sheet and button
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green, // Changed to green
                                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                                ),
                                child: const Text(
                                  "Accept!",
                                  style: TextStyle(color: Colors.white, fontSize: 16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              // Bottom Bar (You're Offline)
              if (!isOnline && !isAccepted)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.black,
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        "You're Offline",
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              // Bottom Bar (Picking up Yahya)
              if (isAccepted && !isWaitingForYahya)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        isWaitingForYahya = true; // Show the "Waiting for Yahya" sheet
                      });
                    },
                    child: Container(
                      color: Colors.black,
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.phone, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                "Picking up Yahya",
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Waiting for Yahya Section
              if (isWaitingForYahya)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.black,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min, // Ensure it takes only the required height
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.phone, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  "Waiting for Yahya",
                                  style: TextStyle(color: Colors.white, fontSize: 16),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Start Ride Button
                        Center(
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.75, // 75% of screen width
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  isWaitingForYahya = false; // Hide the "Waiting for Yahya" section
                                  isRideStarted = true; // Start the ride
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                              ),
                              child: const Text(
                                "Start Ride",
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Cancel Ride Button
                        Center(
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.75, // 75% of screen width
                            child: ElevatedButton(
                              onPressed: () {
                                print("Cancel Ride button pressed");
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                              ),
                              child: const Text(
                                "Cancel Ride",
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (isRideStarted)
                DraggableScrollableSheet(
                  initialChildSize: 0.1, // Initial height of the bottom sheet
                  minChildSize: 0.1, // Minimum height when collapsed
                  maxChildSize: 0.2, // Maximum height when expanded
                  builder: (context, scrollController) {
                    return Container(
                      color: Colors.black,
                      padding: const EdgeInsets.all(0),
                      child: ListView(
                        controller: scrollController,
                        children: [
                          // Dropping Off Yahya Info
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.person, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    "Dropping Off Yahya",
                                    style: TextStyle(color: Colors.white, fontSize: 16),
                                  ),
                                ],
                              ),
                              const Text(
                                "1 min | 0.2 KM",
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Complete Ride Button
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                // Reset all state variables
                                isRideStarted = false;
                                isRideCompleted = false;
                                isAccepted = false;
                                isWaitingForYahya = false;
                                isOnline = false;
                                buttonText = "Go!";
                              });

                              // Reinitialize the map and other components
                              _initializeCamera();
                              _renderPoints();
                              _renderRoute();

                              print("Ride completed and page reinitialized!");
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                            ),
                            child: const Text(
                              "Complete Ride!",
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class PickupDropoffHeader extends StatelessWidget {
  final String pickupLocation;
  final String dropoffLocation;

  const PickupDropoffHeader({
    super.key,
    required this.pickupLocation,
    required this.dropoffLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(8.0),
            bottomRight: Radius.circular(8.0),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.circle, color: Colors.white, size:12),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B2B2B),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Text(
                      pickupLocation,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.square, color: Colors.white, size: 12),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B2B2B),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Text(
                      dropoffLocation,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DoneButton extends StatelessWidget {
  final VoidCallback onPressed;

  const DoneButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.5, // 50% of screen width
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16.0),
        ),
        onPressed: onPressed,
        child: const Text(
          'Done',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
}

class CallButton extends StatelessWidget {
  final String phoneNumber;

  const CallButton({super.key, required this.phoneNumber});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);

    // Log the phone number and URI
    print('Attempting to call: $phoneNumber');
    print('Phone URI: $phoneUri');

    try {
      if (await canLaunchUrl(phoneUri)) {
        print('Launching phone app...');
        await launchUrl(phoneUri); // Opens the phone app with the number
      } else {
        print('Could not launch phone app for number: $phoneNumber');
        throw 'Could not launch $phoneNumber';
      }
    } catch (e) {
      print('Error launching phone app: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.5, // 50% of screen width
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16.0),
        ),
        onPressed: () {
          print('Call button pressed');
          _makePhoneCall(phoneNumber);
        },
        child: Text(
          'Call $phoneNumber',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
}

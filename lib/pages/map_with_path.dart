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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Details'),
        backgroundColor: Colors.black,
      ),
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
          // Header with pickup and dropoff
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: PickupDropoffHeader(
              pickupLocation: '(${widget.ride.pickupLatitude}, ${widget.ride.pickupLongitude})',
              dropoffLocation: '(${widget.ride.dropoffLatitude}, ${widget.ride.dropoffLongitude})',
            ),
          ),
          // Buttons at the bottom
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                DoneButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WaitingForPayment(ride: widget.ride),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8), // Add spacing between buttons
                CallButton(
                  phoneNumber: widget.ride.phoneNumber,
                ),
              ],
            ),
          ),
        ],
      ),
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

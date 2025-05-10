import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:provider/provider.dart';
import 'package:wassilni/helpers/directions_handler.dart';
import 'package:wassilni/models/user_model.dart';
import 'package:wassilni/providers/destination_provider.dart';
import 'package:wassilni/providers/fare_provider.dart';
import 'package:wassilni/providers/user_provider.dart';

class Map extends StatefulWidget {
  const Map({super.key});

  // Add a global key to access the state of _Map
  static final GlobalKey<_Map> mapKey = GlobalKey<_Map>();

  @override
  State<Map> createState() => _Map();
}

class _Map extends State<Map> {
  mp.MapboxMap? mapboxMap;
  StreamSubscription? userPositionStream;
  late DestinationProvider _destinationProvider;
  mp.CameraOptions? _initialCameraOptions;

  late mp.PointAnnotationManager? pickupDropoffAnnotationManager;

  late UserModel user;
        


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _destinationProvider = Provider.of<DestinationProvider>(context);

    // Listen for changes in the provider
    _destinationProvider.addListener(() {
      if (_destinationProvider.pickup != null && _destinationProvider.dropoff != null) {
        _initializeRoute();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    user = Provider.of<UserProvider>(context, listen: false).currentUser!;
    if (Provider.of<UserProvider>(context, listen: false).currentUser == null) {
      throw Exception("user is not set");
    }
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
    mapboxMap?.location.updateSettings(
      mp.LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );
    await _fitCameraToBounds();
  }

  Future<void> _fitCameraToBounds() async {
    var currentPosition = await gl.Geolocator.getCurrentPosition();
    if (mapboxMap == null || _destinationProvider.destination == null) return;

    final destination = _destinationProvider.destination!;

    //calculated the southwest and northeast points for the bounds
    final double minLon = [
      currentPosition.longitude,
      destination.coordinates.lng.toDouble(),
    ].reduce((a, b) => a < b ? a : b);
    final double minLat = [
      currentPosition.latitude,
      destination.coordinates.lat.toDouble(),
    ].reduce((a, b) => a < b ? a : b);
    final double maxLon = [
      currentPosition.longitude,
      destination.coordinates.lng.toDouble(),
    ].reduce((a, b) => a > b ? a : b);
    final double maxLat = [
      currentPosition.latitude,
      destination.coordinates.lat.toDouble(),
    ].reduce((a, b) => a > b ? a : b);

    //create the bounds
    final bounds = mp.CoordinateBounds(
      southwest: mp.Point(coordinates: mp.Position(minLon, minLat)),
      northeast: mp.Point(coordinates: mp.Position(maxLon, maxLat)),
      infiniteBounds: false,
    );

    //use cameraForCoordinateBounds with all required parameters
    final cameraOptions = await mapboxMap?.cameraForCoordinateBounds(
      bounds, // bounds
      mp.MbxEdgeInsets(
        // padding
        top: 100,
        left: 50,
        bottom: 200,
        right: 50,
      ),
      0.0, // bearing
      0.0, // pitch
      null, // maxZoom (null means no limit)
      null, // minZoom (null means no limit)
    );

    if (cameraOptions != null) {
      await mapboxMap?.flyTo(
        cameraOptions,
        mp.MapAnimationOptions(duration: 1000),
      );
    }
  }

  Future<void> _initializeRoute() async {
    if (mapboxMap == null) {
      print("❌ MapboxMap is null. Skipping route initialization.");
      return;
    }

    await clearRoute("pickup_to_dropoff_route");
    await clearRoute("current_to_destination_route");

    final fareProvider = Provider.of<FareProvider>(context, listen: false);

    if (_destinationProvider.pickup != null && _destinationProvider.dropoff != null) {
      final pickup = _destinationProvider.pickup!;
      final dropoff = _destinationProvider.dropoff!;

      print("Drawing route from ${pickup.coordinates} to ${dropoff.coordinates}");

      try {
        var routeData = await getDirectionsRoute(pickup, dropoff);

        // Safely extract values
        final double fare = routeData["estimatedFare"] as double;
        final double duration = routeData["duration"] as double;
        final double distance = routeData["distance"] as double;

        fareProvider.updateFareDetails(fare, duration, distance);

        var featureCollection = routeData["featureCollection"];
        await mapboxMap!.style.addSource(
          mp.GeoJsonSource(id: "pickup_to_dropoff_route", data: json.encode(featureCollection)),
        );

        await mapboxMap!.style.addLayer(
          mp.LineLayer(
            id: "pickup_to_dropoff_route_layer",
            sourceId: "pickup_to_dropoff_route",
            lineJoin: mp.LineJoin.ROUND,
            lineCap: mp.LineCap.ROUND,
            lineColor: Colors.blue.value,
            lineWidth: 6.0,
          ),
        );


    // Fallback to current position→destination route
    if (_destinationProvider.destination != null) {
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
    var distance = routeData["estimatedDistance"];
    var duration = routeData["estimatedDuration"];

    if (context.mounted) {
      Provider.of<FareProvider>(context, listen: false).estimatedFare =
          estimatedFare;
      Provider.of<FareProvider>(context, listen: false).estimatedDistance =
          distance;
      Provider.of<FareProvider>(context, listen: false).estimatedDuration =
          duration;
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
    //driver update
    await FirebaseFirestore.instance.collection('users').doc(user.id).update({
      'location': GeoPoint(currentPosition.latitude, currentPosition.longitude),
    });


      print("Drawing route from current position to ${destination.coordinates}");

      try {
        var routeData = await getDirectionsRoute(origin, destination);

        // Safely extract values
        final double fare = routeData["estimatedFare"] as double;
        final double duration = routeData["duration"] as double;
        final double distance = routeData["distance"] as double;

        fareProvider.updateFareDetails(fare, duration, distance);

        var featureCollection = routeData["featureCollection"];
        await mapboxMap!.style.addSource(
          mp.GeoJsonSource(id: "current_to_destination_route", data: json.encode(featureCollection)),
        );

        await mapboxMap!.style.addLayer(
          mp.LineLayer(
            id: "current_to_destination_route_layer",
            sourceId: "current_to_destination_route",
            lineJoin: mp.LineJoin.ROUND,
            lineCap: mp.LineCap.ROUND,
            lineColor: Colors.purple.value,
            lineWidth: 6.0,
          ),
        );

        print("✅ Updated current→destination route");
        createMarker(destination);
      } catch (e) {
        fareProvider.clearFareDetails();
        print("🚨 Error drawing current→destination route: $e");
      }
    }
  }

  Future<void> _showDefaultView() async {
    bool? layerExists = await mapboxMap?.style.styleLayerExists("route_layer");
    if (mapboxMap != null && layerExists != null && layerExists) {
      await mapboxMap?.style.removeStyleLayer("route_layer");
      await mapboxMap?.style.removeStyleSource("route");
    }
  }

  void _onStyleLoadedCallback(mp.StyleLoadedEventData data) async {
    if (_destinationProvider.destination != null) {
      _initializeRoute();
    } else {
      _showDefaultView();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final position = await gl.Geolocator.getCurrentPosition();

      setState(() {
        _initialCameraOptions = mp.CameraOptions(
          center: mp.Point(
            coordinates: mp.Position(position.longitude, position.latitude),
          ),
          zoom: 13.0,
        );
      });
    } catch (e) {
      // Fallback to default position
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
        var distance = routeData["estimatedDistance"];
        var duration = routeData["estimatedDuration"];
        Provider.of<FareProvider>(context, listen: false).estimatedDistance =
            distance;
        Provider.of<FareProvider>(context, listen: false).estimatedDuration =
            duration;
        var featureCollection = routeData["featureCollection"];
        var features = featureCollection['features'] as List;
        var rawCods = features[0]["geometry"]["coordinates"] as List;
        var cods =
            rawCods
                .map<mp.Position>((coord) => mp.Position(coord[0], coord[1]))
                .toList();
        await mapboxMap?.style.updateGeoJSONSourceFeatures(
          "route",
          "updated_route",
          [
            mp.Feature(
              id: "route_line", //same feature id that we used to create the source
              geometry: mp.LineString(coordinates: cods),
            ),
          ],
        );
        //driver update
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .update({
              'location': GeoPoint(position.latitude, position.longitude),
            });
      }
    });
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

    // Create the marker and store the manager
    pointAnnotationManager?.create(pointAnnotationOptions);
    
  }

mp.PointAnnotation? _pickupAnnotation;
mp.PointAnnotation? _dropoffAnnotation;

void createPickupDropoffMarker(mp.Point point, bool isPickup) async {
  pickupDropoffAnnotationManager ??= await mapboxMap?.annotations.createPointAnnotationManager();
  final Uint8List imageData = await loadMarkerImage();
  
  final annotation = await pickupDropoffAnnotationManager?.create(
    mp.PointAnnotationOptions(
      image: imageData,
      geometry: point,
      textField: "",
      textOffset: [0, 0],
    ),
  );

  if (annotation != null) {
    if (isPickup) {
      _pickupAnnotation = annotation;
    } else {
      _dropoffAnnotation = annotation;
    }
  }
}

void clearPickupMarker() {
  if (_pickupAnnotation != null) {
    pickupDropoffAnnotationManager?.delete(_pickupAnnotation!); // Single annotation, not a list
    _pickupAnnotation = null;
  }
}

void clearDropoffMarker() {
  if (_dropoffAnnotation != null) {
    pickupDropoffAnnotationManager?.delete(_dropoffAnnotation!); // Single annotation, not a list
    _dropoffAnnotation = null;
  }
}

void createPickupAndDropoffMarkers(mp.Point pickup, mp.Point dropoff) async {
  // Clear existing markers and route
  await clearPickupDropoffRouteAndMarkers();

  // Create a new annotation manager instance
  pickupDropoffAnnotationManager = await mapboxMap?.annotations.createPointAnnotationManager();

  // Load marker image
  final imageData = await loadMarkerImage();

  // Create pickup marker
  _pickupAnnotation = await pickupDropoffAnnotationManager?.create(
    mp.PointAnnotationOptions(
      image: imageData,
      geometry: pickup,
      textField: "Pickup", // Optional label for the marker
      textOffset: [0, -2], // Adjust text position
    ),
  );

  // Create dropoff marker
  _dropoffAnnotation = await pickupDropoffAnnotationManager?.create(
    mp.PointAnnotationOptions(
      image: imageData,
      geometry: dropoff,
      textField: "Dropoff", // Optional label for the marker
      textOffset: [0, -2], // Adjust text position
    ),
  );

  print("Pickup and dropoff markers created successfully.");
}

  Future<void> clearRoute(String routeId) async {
    if (mapboxMap == null) return;

    final style = mapboxMap!.style;

    // Remove the layer if it exists
    if (await style.styleLayerExists("${routeId}_layer")) {
      await style.removeStyleLayer("${routeId}_layer");
      print("🗑️ Removed layer: ${routeId}_layer");
    }

    // Remove the source if it exists
    if (await style.styleSourceExists(routeId)) {
      await style.removeStyleSource(routeId);
      print("🗑️ Removed source: $routeId");
    }
  }

  Future<void> clearPickupDropoffRouteAndMarkers() async {
    clearRoute("pickup_to_dropoff_route");
    clearPickupMarker();
    clearDropoffMarker();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _initialCameraOptions == null
              ? Center(child: CircularProgressIndicator())
              : mp.MapWidget(
                onMapCreated: _onMapCreated,
                styleUri: mp.MapboxStyles.MAPBOX_STREETS,
                onStyleLoadedListener: _onStyleLoadedCallback,
                cameraOptions: _initialCameraOptions,
              ),
    );
  }
}

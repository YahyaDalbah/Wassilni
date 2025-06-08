import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:provider/provider.dart';
import 'package:wassilni/helpers/directions_handler.dart';
import 'package:wassilni/models/ride_model.dart';
import 'package:wassilni/models/user_model.dart';
import 'package:wassilni/providers/destination_provider.dart';
import 'package:wassilni/providers/fare_provider.dart';
import 'package:wassilni/providers/ride_provider.dart';
import 'package:wassilni/providers/user_provider.dart';
import 'package:wassilni/services/firebase_location_service.dart';

class Map extends StatefulWidget {
  const Map({super.key});
  @override
  State<Map> createState() => _Map();
}

class _Map extends State<Map> {
  mp.MapboxMap? mapboxMap;
  StreamSubscription? userPositionStream;
  late DestinationProvider _destinationProvider;
  mp.CameraOptions? _initialCameraOptions;
  late UserModel user;
  mp.PointAnnotation? _marker;
  mp.PointAnnotationManager? pointAnnotationManager;
  StreamSubscription<DocumentSnapshot>? _driverLocationSub;
  Ride? ride;
  late FirebaseLocationService _locationService;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _destinationProvider = Provider.of<DestinationProvider>(context);
  }

  @override
  void initState() {
    super.initState();
    _locationService = FirebaseLocationService();
    if (Provider.of<UserProvider>(context, listen: false).currentUser == null) {
      throw Exception("user is not set");
    }
    user = Provider.of<UserProvider>(context, listen: false).currentUser!;
    _initializeCamera();
    _setupPositionTracking();
    ride = Provider.of<RideProvider>(context, listen: false).currentRide;
    if (ride != null &&
        user.type.name == "rider" &&
        ride!.status != "in_progress")
      _startTrackingDriver();
  }

  @override
  void dispose() {
    // Proper cleanup sequence
    _locationService.dispose();
    userPositionStream?.cancel();
    _driverLocationSub?.cancel();
    pointAnnotationManager?.deleteAll();
    mapboxMap = null;
    _marker = null;
    mapboxMap?.annotations.removeAnnotationManager(pointAnnotationManager!);
    pointAnnotationManager = null;
    super.dispose();
  }

  void _startTrackingDriver() {
    final driverId =
        Provider.of<RideProvider>(context, listen: false).currentRide!.driverId;
    _locationService.startTrackingDriver(
      driverId,
      _listenerFunction,
      onError: (error) => _showError('Driver tracking failed: $error'),
    );
  }

  void _listenerFunction(mp.Point driverPoint) async {
    try {
      _destinationProvider.destination = driverPoint;
      var currentPosition = await gl.Geolocator.getCurrentPosition();
      _updatePositionAndRoute(currentPosition);
      createMarker(driverPoint);
    } catch (e) {
      _showError('Failed to update driver position: $e');
    }
  }

  void _onMapCreated(mp.MapboxMap? controller) async {
    setState(() {
      mapboxMap = controller;
    });
    mapboxMap?.location.updateSettings(
      mp.LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );
    await _fitCameraToBounds();
    pointAnnotationManager =
        await mapboxMap?.annotations.createPointAnnotationManager();
  }

  Future<void> _fitCameraToBounds() async {
    bool serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      _showError('Location services are disabled. Please enable them.');
      return;
    }
    gl.LocationPermission permission = await gl.Geolocator.checkPermission();
    if (permission == gl.LocationPermission.denied) {
      permission = await gl.Geolocator.requestPermission();
      if (permission == gl.LocationPermission.denied) {
        _showError('Location services are denied. Please enable them.');
        return;
      }
    }
    if (permission == gl.LocationPermission.deniedForever) {
      _showError(
        'Location services are permenantly denied. Please enable them in settings.',
      );
      return;
    }
    var currentPosition = await gl.Geolocator.getCurrentPosition();
    if (mapboxMap == null || _destinationProvider.destination == null) return;

    final destination = _destinationProvider.destination!;

    //calculated the southwest and northeast points for the bounds
    final num minLon = [
      currentPosition.longitude,
      destination.coordinates.lng,
    ].reduce((a, b) => a < b ? a : b);
    final num minLat = [
      currentPosition.latitude,
      destination.coordinates.lat,
    ].reduce((a, b) => a < b ? a : b);
    final num maxLon = [
      currentPosition.longitude,
      destination.coordinates.lng,
    ].reduce((a, b) => a > b ? a : b);
    final num maxLat = [
      currentPosition.latitude,
      destination.coordinates.lat,
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
    try {
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
      var distance = routeData["estimatedDistance"];
      var duration = routeData["estimatedDuration"];

      if (mounted) {
        if (ride == null) {
          var estimatedFare = routeData["estimatedFare"];
          Provider.of<FareProvider>(context, listen: false).estimatedFare =
              estimatedFare;
        }
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
      await _locationService.updateUserPosition(user.id, currentPosition);

      createMarker(destination);
    } on SocketException catch (e) {
      _showError('No internet connection. Failed to draw route.');
    } catch (e) {
      _showError('Failed to initialize route: $e');
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
    gl.LocationSettings locationSettings = gl.LocationSettings(
      accuracy: gl.LocationAccuracy.high,
      distanceFilter: 100,
    );

    userPositionStream?.cancel();
    userPositionStream = gl.Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((gl.Position position) async {
      if (mapboxMap != null && _destinationProvider.destination != null) {
        _updatePositionAndRoute(position);
        //driver update
        try {
          await _locationService.updateUserPosition(user.id, position);
        } on SocketException {
          _showError("Bad internet Connection");
        } catch (e) {
          _showError('$e');
        }
      }
    });
  }

  void _updatePositionAndRoute(gl.Position position) async {
    try {
      var origin = mp.Point(
        coordinates: mp.Position(position.longitude, position.latitude),
      );
      var destination = _destinationProvider.destination!;

      var routeData = await getDirectionsRoute(origin, destination);
      var distance = routeData["estimatedDistance"];
      var duration = routeData["estimatedDuration"];
      if (mounted) {
        if (distance == 0) {
          distance = 0.0;
        }
        if (duration == 0) {
          duration = 0.0;
        }
        Provider.of<FareProvider>(context, listen: false).estimatedDistance =
            distance;
        Provider.of<FareProvider>(context, listen: false).estimatedDuration =
            duration;
      }
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
    } on SocketException {
      _showError('Failed to update route: Bad internet connection');
    } catch (e) {
      _showError('Failed to update route: $e');
    }
  }

  Future<Uint8List> loadMarkerImage(String image) async {
    var byteData = await rootBundle.load(image);
    return byteData.buffer.asUint8List();
  }

  void createMarker(mp.Point point) async {
    try {
      final Uint8List imageData = await loadMarkerImage("assets/location.png");
      mp.PointAnnotationOptions pointAnnotationOptions =
          mp.PointAnnotationOptions(image: imageData, geometry: point);

      if (_marker != null) {
        _marker!.geometry = point;
        pointAnnotationManager?.update(_marker!);
      } else {
        _marker = await pointAnnotationManager?.create(pointAnnotationOptions);
      }
    } catch (e) {
      _showError('Failed to update marker: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _initialCameraOptions == null
              ? Center(child: CircularProgressIndicator())
              : Stack(
                children: [
                  mp.MapWidget(
                    onMapCreated: _onMapCreated,
                    styleUri: mp.MapboxStyles.MAPBOX_STREETS,
                    onStyleLoadedListener: _onStyleLoadedCallback,
                    cameraOptions: _initialCameraOptions,
                  ),
                ],
              ),
    );
  }
}

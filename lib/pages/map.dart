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
import 'package:wassilni/providers/ride_provider.dart';
import 'package:wassilni/providers/user_provider.dart';

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


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _destinationProvider = Provider.of<DestinationProvider>(context);
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
    var ride = Provider.of<RideProvider>(context,listen: false).currentRide;
    if(ride != null && user.type.name == "rider") _startTrackingDriver();
  }

  @override
   @override
  void dispose() {
    // Proper cleanup sequence
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
    // Replace with actual driver ID from your system
    final driverId = Provider.of<RideProvider>(context,listen: false).currentRide!.driverId; 
    final driverDoc = FirebaseFirestore.instance.collection('users').doc(driverId);

    _driverLocationSub = driverDoc.snapshots().listen((snapshot) async {
      if (!snapshot.exists) return;

      final location = snapshot['location'] as GeoPoint;
      final point = mp.Point(
        coordinates: mp.Position(location.longitude, location.latitude)
      );
      _destinationProvider.destination = point;
      var position = await gl.Geolocator.getCurrentPosition();
      _updatePositionAndRoute(position);
      createMarker(point);
    });
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

    createMarker(destination);
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
        
        _updatePositionAndRoute(position);
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

  void _updatePositionAndRoute(gl.Position position) async {
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
  }

  Future<Uint8List> loadMarkerImage(String image) async {
    var byteData = await rootBundle.load(image);
    return byteData.buffer.asUint8List();
  }

  void createMarker(mp.Point point) async {
    final Uint8List imageData = await loadMarkerImage("assets/location.png");
    mp.PointAnnotationOptions pointAnnotationOptions =
        mp.PointAnnotationOptions(image: imageData, geometry: point);

    if (_marker != null) {
      _marker!.geometry = point;
      pointAnnotationManager?.update(_marker!);
    } else {
      _marker = await pointAnnotationManager?.create(pointAnnotationOptions);
    }
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

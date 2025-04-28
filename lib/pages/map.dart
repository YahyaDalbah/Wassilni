import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:provider/provider.dart';
import 'package:wassilni/helpers/directions_handler.dart';
import 'package:wassilni/providers/map_provider.dart';

class Map extends StatefulWidget {
  const Map({super.key});
  @override
  State<Map> createState() => _Map();
}

class _Map extends State<Map> {
  mp.MapboxMap? mapboxMap;
  StreamSubscription? userPositionStream;

  late MapProvider _destinationProvider;
  mp.CameraOptions? _initialCameraOptions;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _destinationProvider = Provider.of<MapProvider>(context);
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
    mapboxMap?.location.updateSettings(
      mp.LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );
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
      Provider.of<MapProvider>(context, listen: false).estimatedFare =
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

  Future<void> _showDefaultView() async {
    await mapboxMap?.style.removeStyleLayer("route_layer");
    await mapboxMap?.style.removeStyleSource("route");
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

    pointAnnotationManager?.create(pointAnnotationOptions);
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

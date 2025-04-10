import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:wassilni/helpers/directions_handler.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  mp.MapboxMap? mapboxMap;
  StreamSubscription? userPositionStream;

  @override
  void initState() {
    super.initState();

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

  var destination = mp.Point(coordinates: mp.Position(35.029994, 32.314459));
  void _onStyleLoadedCallback(mp.StyleLoadedEventData data) async {
    var currentPosition = await gl.Geolocator.getCurrentPosition();
    var origin = mp.Point(
      coordinates: mp.Position(
        currentPosition.longitude,
        currentPosition.latitude,
      ),
    );

    var featureCollection = await getDirectionsRoute(origin, destination);

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

    // consider FreeDriveMode maybe
    userPositionStream?.cancel();
    userPositionStream = gl.Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((gl.Position position) async {
      if (mapboxMap != null) {
        var origin = mp.Point(
          coordinates: mp.Position(position.longitude, position.latitude),
        );
        await mapboxMap?.style.removeStyleLayer("route_layer");
        await mapboxMap?.style.removeStyleSource("route");

        var featureCollection = await getDirectionsRoute(origin, destination);

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
      body: mp.MapWidget(
        onMapCreated: _onMapCreated,
        styleUri: mp.MapboxStyles.MAPBOX_STREETS,
        onStyleLoadedListener: _onStyleLoadedCallback,
        cameraOptions: mp.CameraOptions(
          zoom: 13,
          center: mp.Point(coordinates: mp.Position(35.031363, 32.317301)),
        ),
      ),
    );
  }
}

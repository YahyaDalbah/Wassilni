import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:provider/provider.dart';
import 'package:wassilni/helpers/directions_handler.dart';
import 'package:wassilni/providers/destination_provider.dart';
import 'package:wassilni/providers/fare_provider.dart';

class PositionDestinationPage extends StatefulWidget {
  const PositionDestinationPage({super.key});

  @override
  State<PositionDestinationPage> createState() => _PositionDestinationPageState();
}

class _PositionDestinationPageState extends State<PositionDestinationPage> {
  mp.MapboxMap? mapboxMap;
  StreamSubscription? userPositionStream;
  mp.CameraOptions? _initialCameraOptions;
  late DestinationProvider _destinationProvider;
  bool _isLoading = true;
  bool _routeInitialized = false;
  gl.Position? _currentPosition;
  String _originAddress = 'Finding your location...';
  String _destinationAddress = 'Loading destination...';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _destinationProvider = Provider.of<DestinationProvider>(context);
    if (_destinationProvider.destination == null) {
      //if no destination set then go back
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _setupPositionTracking();
    _fetchAddresses();
  }

  @override
  void dispose() {
    userPositionStream?.cancel();
    super.dispose();
  }

  void _onMapCreated(mp.MapboxMap controller) {
    mapboxMap = controller;
    mapboxMap?.location.updateSettings(
      mp.LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );
  }

  Future<void> _fetchAddresses() async {
    try {
      //get current position
      _currentPosition = await gl.Geolocator.getCurrentPosition();

      //fetch origin address
      _originAddress = await _getAddressFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      //fetch destination address
      if (_destinationProvider.destination != null) {
        final dest = _destinationProvider.destination!;
        _destinationAddress = await _getAddressFromCoordinates(
          dest.coordinates.lat.toDouble(),
          dest.coordinates.lng.toDouble(),
        );
      }

      setState(() {});
    } catch (e) {
      print('Error fetching addresses: $e');
    }
  }

  Future<String> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      final url = Uri.parse(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json?access_token=${await _getAccessToken()}'
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        if (features.isNotEmpty) {
          return features[0]['place_name'] ?? 'Unknown location';
        }
      }
      return 'Unknown location';
    } catch (e) {
      return 'Unknown location';
    }
  }

  Future<String> _getAccessToken() async {
    return dotenv.env["MAPBOX_ACCESS_TOKEN"]!;
  }

  Future<void> _initializeCamera() async {
    try {
      final position = await gl.Geolocator.getCurrentPosition();
      _currentPosition = position;

      //if we have a destination, set camera to fit both points
      //not working yet!!
      if (_destinationProvider.destination != null) {
        final destination = _destinationProvider.destination!;

        //create southwest and northeast points for the camera bounds
        final southwest = mp.Point(coordinates: mp.Position(
          position.longitude - 0.05,
          position.latitude - 0.05,
        ));

        final northeast = mp.Point(coordinates: mp.Position(
          destination.coordinates.lng.toDouble() + 0.05,  //connvert num to double
          destination.coordinates.lat.toDouble() + 0.05,
        ));

        //create a coordinate bounds object
        final bounds = mp.CoordinateBounds(
          southwest: southwest,
          northeast: northeast, infiniteBounds: true,
        );

        setState(() {
          _initialCameraOptions = mp.CameraOptions(
            center: mp.Point( //set center to midpoint of route
              coordinates: mp.Position(
                (position.longitude + destination.coordinates.lng.toDouble()) / 2,
                (position.latitude + destination.coordinates.lat.toDouble()) / 2,
              ),
            ),
            padding: mp.MbxEdgeInsets(top: 100, left: 50, bottom: 150, right: 50),
            zoom: 12.0,
          );
          _isLoading = false;
        });
      } else {
        setState(() {
          _initialCameraOptions = mp.CameraOptions(
            center: mp.Point(
              coordinates: mp.Position(position.longitude, position.latitude),
            ),
            zoom: 13.0,
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error initializing camera: $e');
      //fallback to default position
      setState(() {
        _initialCameraOptions = mp.CameraOptions(
          center: mp.Point(coordinates: mp.Position(35.031363, 32.317301)),
          zoom: 13.0,
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _setupPositionTracking() async {
    bool serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location services are disabled'))
      );
      return;
    }

    gl.LocationPermission permission = await gl.Geolocator.checkPermission();
    if (permission == gl.LocationPermission.denied) {
      permission = await gl.Geolocator.requestPermission();
      if (permission == gl.LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Location permissions are denied'))
        );
        return;
      }
    }

    if (permission == gl.LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permissions are permanently denied'))
      );
      return;
    }

    gl.LocationSettings locationSettings = gl.LocationSettings(
      accuracy: gl.LocationAccuracy.high,
      distanceFilter: 100,
    );

    userPositionStream?.cancel();
    userPositionStream = gl.Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((gl.Position position) async {
      _currentPosition = position;

      if (mapboxMap != null && _destinationProvider.destination != null && _routeInitialized) {
        var origin = mp.Point(
          coordinates: mp.Position(position.longitude, position.latitude),
        );
        var destination = _destinationProvider.destination!;

        var routeData = await getDirectionsRoute(origin, destination);
        var featureCollection = routeData["featureCollection"];
        var features = featureCollection['features'] as List;
        var rawCoords = features[0]["geometry"]["coordinates"] as List;
        var coords = rawCoords
            .map<mp.Position>((coord) => mp.Position(coord[0], coord[1]))
            .toList();

        try {
          await mapboxMap?.style.updateGeoJSONSourceFeatures(
            "route",
            "updated_route",
            [
              mp.Feature(
                id: "route_line",
                geometry: mp.LineString(coordinates: coords),
              ),
            ],
          );
        } catch (e) {
          print('Error updating route: $e');
        }
      }
    });
  }

  Future<void> _initializeRoute() async {
    if (_destinationProvider.destination == null || _currentPosition == null) return;

    var destination = _destinationProvider.destination!;
    var origin = mp.Point(
      coordinates: mp.Position(
        _currentPosition!.longitude,
        _currentPosition!.latitude,
      ),
    );

    try {
      var routeData = await getDirectionsRoute(origin, destination);
      var featureCollection = routeData["featureCollection"];
      var estimatedFare = routeData["estimatedFare"];
      if (context.mounted) {
        Provider.of<FareProvider>(context, listen: false).estimatedFare = estimatedFare;
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

      _createMarker(destination);
      setState(() {
        _routeInitialized = true;
      });
    } catch (e) {
      print('Error initializing route: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading route. Please try again.'))
      );
    }
  }

  Future<Uint8List> _loadMarkerImage() async {
    try {
      var byteData = await rootBundle.load("assets/location.png");
      return byteData.buffer.asUint8List();
    } catch (e) {
      //create a fallback marker image if asset can't be loaded
      final size = 64;
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      final paint = Paint()..color = Colors.red;

      canvas.drawCircle(Offset(size / 2, size / 2), size / 2, paint);

      final img = await pictureRecorder.endRecording().toImage(size, size);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    }
  }

  void _createMarker(mp.Point point) async {
    try {
      final pointAnnotationManager =
      await mapboxMap?.annotations.createPointAnnotationManager();
      final Uint8List imageData = await _loadMarkerImage();
      mp.PointAnnotationOptions pointAnnotationOptions =
      mp.PointAnnotationOptions(image: imageData, geometry: point);

      pointAnnotationManager?.create(pointAnnotationOptions);
    } catch (e) {
      print('Error creating marker: $e');
    }
  }

  void _onStyleLoadedCallback(mp.StyleLoadedEventData data) async {
    if (_destinationProvider.destination != null) {
      await _initializeRoute();
    }
  }

  void _navigateToMyLocation() async {
    if (_currentPosition == null || mapboxMap == null) return;

    await mapboxMap?.flyTo(
      mp.CameraOptions(
        center: mp.Point(
          coordinates: mp.Position(_currentPosition!.longitude, _currentPosition!.latitude),
        ),
        zoom: 15.0,
        bearing: 0,
      ),
      mp.MapAnimationOptions(duration: 1500),
    );
  }

  void _onDoneButtonPressed() {
    //this section after pressing done will take user to find a closest driver


    final fareProvider = Provider.of<FareProvider>(context, listen: false);
    final estimatedFare = fareProvider.estimatedFare;

    ScaffoldMessenger.of(context).showSnackBar(
      //just for test (it goes back to the home page)
        SnackBar(content: Text('your driver is near, estimated fare: \$${estimatedFare?.toStringAsFixed(2)}'))
    );

    //for now just go back to the home page
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          //map
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : mp.MapWidget(
            onMapCreated: _onMapCreated,
            styleUri: mp.MapboxStyles.MAPBOX_STREETS,
            onStyleLoadedListener: _onStyleLoadedCallback,
            cameraOptions: _initialCameraOptions,
          ),

          //top address bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black.withOpacity(0.7),
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, left: 16, right: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  //back button and title
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        'Your Route',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  //origin & destination addresses
                  Container(
                    margin: EdgeInsets.only(top: 8),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.my_location, color: Colors.blue, size: 20),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _originAddress,
                                style: TextStyle(color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Container(
                          margin: EdgeInsets.only(left: 10),
                          height: 16,
                          width: 1,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.red, size: 20),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _destinationAddress,
                                style: TextStyle(color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          //my location button
          Positioned(
            right: 16,
            bottom: 100,
            child: FloatingActionButton(
              heroTag: 'mylocation',
              backgroundColor: Colors.white,
              child: Icon(Icons.my_location, color: Colors.black),
              onPressed: _navigateToMyLocation,
            ),
          ),

          //done button
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _onDoneButtonPressed,
              child: Text(
                'DONE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
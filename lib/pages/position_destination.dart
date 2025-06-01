import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;
import 'package:provider/provider.dart';
import 'package:wassilni/pages/map.dart';
import 'package:wassilni/providers/destination_provider.dart';
import 'package:wassilni/providers/fare_provider.dart';
import 'package:wassilni/pages/accept_driver.dart';

class PositionDestinationPage extends StatefulWidget {
  const PositionDestinationPage({super.key});

  @override
  State<PositionDestinationPage> createState() => _PositionDestinationPageState();
}

class _PositionDestinationPageState extends State<PositionDestinationPage> {
  mp.MapboxMap? mapboxMap;
  StreamSubscription? userPositionStream;
  late DestinationProvider _destinationProvider;
  gl.Position? _currentPosition;
  String _originAddress = 'Finding your location...';
  String _destinationAddress = 'Loading destination...';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _destinationProvider = Provider.of<DestinationProvider>(context);
    if (_destinationProvider.destination == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.pop(context));
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
  }

  @override
  void dispose() {
    userPositionStream?.cancel();
    super.dispose();
  }

  Future<void> _fetchAddresses() async {
    try {
      _currentPosition = await gl.Geolocator.getCurrentPosition();
      _originAddress = await _getAddressFromCoordinates(_currentPosition!.latitude, _currentPosition!.longitude);
      if (_destinationProvider.destination != null) {
        final dest = _destinationProvider.destination!;
        _destinationAddress = await _getAddressFromCoordinates(dest.coordinates.lat.toDouble(), dest.coordinates.lng.toDouble());
      }
      setState(() {});
    } catch (e) {
      print('Error fetching addresses: $e');
    }
  }

  Future<String> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      final url = Uri.parse(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json?access_token=${dotenv.env["MAPBOX_ACCESS_TOKEN"]!}');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final features = json.decode(response.body)['features'] as List;
        return features.isNotEmpty ? features[0]['place_name'] ?? 'Unknown location' : 'Unknown location';
      }
      return 'Unknown location';
    } catch (e) {
      return 'Unknown location';
    }
  }

  void _navigateToMyLocation() async {
    if (_currentPosition == null || mapboxMap == null) return;
    await mapboxMap!.flyTo(
      mp.CameraOptions(
        center: mp.Point(coordinates: mp.Position(_currentPosition!.longitude, _currentPosition!.latitude)),
        zoom: 15.0,
        bearing: 0,
      ),
      mp.MapAnimationOptions(duration: 1500),
    );
  }

  Future<void> _onDoneButtonPressed() async {
    final fareProvider = Provider.of<FareProvider>(context, listen: false);
    final destProvider = Provider.of<DestinationProvider>(context, listen: false);
    final routeInfo = {
      'pickup': {
        'address': _originAddress,
        'coordinates': GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
      },
      'destination': {
        'address': _destinationAddress,
        'coordinates': GeoPoint(destProvider.destination!.coordinates.lat.toDouble(), destProvider.destination!.coordinates.lng.toDouble()),
      },
      'fare': fareProvider.estimatedFare ?? 0.0,
      'distance': fareProvider.estimatedDistance ?? 0.0,
      'duration': fareProvider.estimatedDuration ?? 0.0,
    };
    Navigator.push(context, MaterialPageRoute(builder: (context) => AcceptDriverPage(routeInfo: routeInfo)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Map(),
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
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                      const Text('Your Route', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.my_location, color: Colors.blue, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(_originAddress,
                                  style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ]),
                        const SizedBox(height: 4),
                        Container(margin: const EdgeInsets.only(left: 10), height: 16, width: 1, color: Colors.grey),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.location_on, color: Colors.red, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(_destinationAddress,
                                  style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 100,
            child: FloatingActionButton(
              heroTag: 'mylocation',
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.black),
              onPressed: _navigateToMyLocation,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _onDoneButtonPressed,
              child: const Text('DONE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
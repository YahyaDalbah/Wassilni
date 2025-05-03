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
import 'package:wassilni/pages/map.dart';

class PositionDestinationPage extends StatefulWidget {
  const PositionDestinationPage({super.key});

  @override
  State<PositionDestinationPage> createState() =>
      _PositionDestinationPageState();
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
      //if no destination set then go back
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
      });
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
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json?access_token=${await _getAccessToken()}',
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

  void _navigateToMyLocation() async {
    if (_currentPosition == null || mapboxMap == null) return;

    await mapboxMap?.flyTo(
      mp.CameraOptions(
        center: mp.Point(
          coordinates: mp.Position(
            _currentPosition!.longitude,
            _currentPosition!.latitude,
          ),
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
      SnackBar(
        content: Text(
          'your driver is near, estimated fare: \$${estimatedFare?.toStringAsFixed(2)}',
        ),
      ),
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
          const Map(),

          //top address bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black.withOpacity(0.7),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: 16,
                right: 16,
                bottom: 16,
              ),
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
                            Icon(
                              Icons.my_location,
                              color: Colors.blue,
                              size: 20,
                            ),
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
                            Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 20,
                            ),
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
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:wassilni/pages/position_destination.dart';
import 'package:wassilni/providers/destination_provider.dart';
import 'package:wassilni/providers/user_provider.dart';
import 'package:wassilni/pages/auth/login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState(){
    super.initState();
    _requestLocationPermission();
  }
  void _requestLocationPermission() async{
    bool serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      _showError('Location services are disabled. Please enable them.');
      return;
    }
    gl.LocationPermission permission = await gl.Geolocator.checkPermission();
    if (permission == gl.LocationPermission.denied) {
      permission = await gl.Geolocator.requestPermission();
      if (permission == gl.LocationPermission.denied) {
        _showError("Location services are denied. Please enable them. You won't be able to use the app without them");
        return;
      }
    }
    if (permission == gl.LocationPermission.deniedForever) {
      _showError('Location services are permenantly denied. Please enable them in settings.');
      return;
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

  Future<void> _searchPlaces(String query) async {
    if (query.length < 3) {
      setState(() => _suggestions.clear());
      return;
    }
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json?access_token=${dotenv.env["MAPBOX_ACCESS_TOKEN"]!}&limit=5');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final features = json.decode(response.body)['features'] as List;
        setState(() {
          _suggestions.clear();
          _suggestions.addAll(features.map((f) => {
            'placeName': f['place_name'],
            'coordinates': f['geometry']['coordinates'],
          }));
        });
      }
    } catch (e) {
      print('Error searching places: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onSuggestionTap(Map<String, dynamic> place) {
    final coords = place['coordinates'] as List;
    Provider.of<DestinationProvider>(context, listen: false).destination =
        Point(coordinates: Position(coords[0], coords[1]));
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PositionDestinationPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 20,
              right: 20,
              child: Row(
                children: [
                  const Text('Wassilni', style: TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: () async {
                      await Provider.of<UserProvider>(context, listen: false).logout();
                      if (mounted) {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
                      }
                    },
                  ),
                ],
              ),
            ),
            Positioned(
              top: 80,
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                children: [
                  TextField(
                    controller: _controller,
                    onChanged: _searchPlaces,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[850],
                      hintText: 'Where to?',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      suffixIcon: _isLoading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.search, color: Colors.white),
                    ),
                  ),
                  if (_suggestions.isNotEmpty)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(12)),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _suggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _suggestions[index];
                            return ListTile(
                              title: Text(suggestion['placeName'] ?? '',
                                  style: const TextStyle(color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
                              onTap: () => _onSuggestionTap(suggestion),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
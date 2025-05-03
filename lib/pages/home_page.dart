import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:wassilni/pages/position_destination.dart';
import 'package:wassilni/providers/destination_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  int _currentIndex = 1;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _searchPlaces(String query) async {
    if (query.length < 3) {
      setState(() {
        _suggestions.clear();
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final accessToken = dotenv.env["MAPBOX_ACCESS_TOKEN"]!;
      final endpoint = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json';
      final url = Uri.parse('$endpoint?access_token=$accessToken&limit=5');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;

        setState(() {
          _suggestions.clear();
          for (var feature in features) {
            _suggestions.add({
              'placeName': feature['place_name'],
              'coordinates': feature['geometry']['coordinates'],
            });
          }
        });
      }
    } catch (e) {
      print('Error searching places: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSuggestionTap(Map<String, dynamic> place) {
    final coords = place['coordinates'] as List;

    //creating a destination point
    final destination = Point(
      coordinates: Position(
        coords[0], //longitude
        coords[1], //latitude
      ),
    );

    //update the provider
    Provider.of<DestinationProvider>(context, listen: false).destination = destination;

    //navigate to position_destination page
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PositionDestinationPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // title
            Positioned(
              top: 20,
              right: 20,
              child: Text(
                'Wassilni',
                style: TextStyle(
                  fontSize: 36,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            //search
            Positioned(
              top: 80,
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                children: [
                  TextField(
                    controller: _controller,
                    onChanged: (value) {
                      _searchPlaces(value);
                    },
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[850],
                      hintText: 'Where to?',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: _isLoading
                          ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Icon(Icons.search, color: Colors.white),
                    ),
                  ),

                  //search suggestions
                  if (_suggestions.isNotEmpty)
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[850],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _suggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _suggestions[index];
                            return ListTile(
                              title: Text(
                                suggestion['placeName'] ?? '',
                                style: TextStyle(color: Colors.white),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
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
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        currentIndex: _currentIndex,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          //navigation logic
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
        ],
      ),
    );
  }
}
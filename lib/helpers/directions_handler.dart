import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:http/http.dart' as http;

double estimateFare(dynamic route) {
  final double baseFare = 2.00;
  final double ratePerKm = 1.50;
  final double ratePerMin = 0.20;

  // Added null safety with default values
  final distance = (route['distance'] as num?)?.toDouble() ?? 0.0; // in meters
  final duration = (route['duration'] as num?)?.toDouble() ?? 0.0; // in seconds

  // Convert units
  final distanceKm = distance / 1000;
  final durationMin = duration / 60;

  // Calculate components
  final distanceCost = distanceKm * ratePerKm;
  final timeCost = durationMin * ratePerMin;

  final rawFare = baseFare + distanceCost + timeCost;
  return (rawFare * 2).roundToDouble() / 2;
}

Future<Map<String, dynamic>> getDirectionsRoute(
  Point origin,
  Point destination,
) async {
  print("🌍🌍🌍 API CALL TRIGGERED 🌍🌍🌍"); // Add this first
  final String accessToken = dotenv.env["MAPBOX_ACCESS_TOKEN"]!;

  // Add debug prints for token validation
  print("🔑 Mapbox Token: ${accessToken.isNotEmpty ? 'VALID' : 'MISSING'}");

  final String url =
      'https://api.mapbox.com/directions/v5/mapbox/driving/'
      '${origin.coordinates.lng},${origin.coordinates.lat};'
      '${destination.coordinates.lng},${destination.coordinates.lat}'
      '?geometries=geojson'
      '&annotations=duration,distance'
      '&access_token=$accessToken';

  print("🔗 API URL: $url"); // Log the exact URL being called

  final response = await http.get(Uri.parse(url));
  print("🎯 API Status Code: ${response.statusCode}");

  if (response.statusCode == 200) {
    print("✅ RAW API RESPONSE: ${response.body}"); // Critical for debugging
    final data = json.decode(response.body);

    // Validation for required fields
    if (data['routes']?.isEmpty ?? true) throw Exception("No routes found");
    final route = data['routes'][0];

    var estimatedFare = estimateFare(route);
    var distance = route['distance']; // in meters
    var duration = route['duration']; // in seconds

    final geometry = route['geometry'];


    final featureCollection = {
      "type": "FeatureCollection",
      "features": [routeFeature],
    };
    Map<String,dynamic> map = {
      "estimatedFare": estimatedFare,
      "featureCollection": featureCollection,
      "estimatedDistance": distance,
      "estimatedDuration": duration

    };

    return map;
  } else {
    print("🚨 API ERROR: ${response.reasonPhrase}");
    throw Exception("API request failed: ${response.statusCode}");
  }
}
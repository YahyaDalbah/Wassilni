import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:http/http.dart' as http;

double estimateFare(dynamic route) {
  final double baseFare = 2.00;
  final double ratePerKm = 1.50;
  final double ratePerMin = 0.20;

  final distance = route['distance']; // in meters
  final duration = route['duration']; // in seconds

  // Convert units
  final distanceKm = distance / 1000;
  final durationMin = duration / 60;

  // Calculate components
  final distanceCost = distanceKm * ratePerKm;
  final timeCost = durationMin * ratePerMin;

  var rawFare = baseFare + distanceCost + timeCost;
  var roundedFare = (rawFare * 2).roundToDouble() / 2;
  // Total fare calculation
  return roundedFare;
}

Future<Map<String,dynamic>> getDirectionsRoute(
  Point origin,
  Point destination,
) async {
  final String accessToken = dotenv.env["MAPBOX_ACCESS_TOKEN"]!;
  final String url =
      'https://api.mapbox.com/directions/v5/mapbox/driving/'
      '${origin.coordinates.lng},${origin.coordinates.lat};'
      '${destination.coordinates.lng},${destination.coordinates.lat}'
      '?geometries=geojson&access_token=$accessToken';

  final response = await http.get(Uri.parse(url));
  print("###################################################");
  print("'${origin.coordinates.lng},${origin.coordinates.lat};'${destination.coordinates.lng},${destination.coordinates.lat}'");
  print("###################################################");
  if (response.statusCode == 200) {
    final data = json.decode(response.body);

    // Extract the route geometry from the response
    final route = data['routes'][0];
    var estimatedFare = estimateFare(route);
    final geometry = route['geometry'];
    // Create a GeoJSON feature from the route geometry
    final routeFeature = {
      "type": "Feature",
      "id": "route_line",
      "properties": {},
      "geometry": geometry,
    };

    final featureCollection = {
      "type": "FeatureCollection",
      "features": [routeFeature],
    };
    Map<String,dynamic> map = {
      "estimatedFare": estimatedFare,
      "featureCollection": featureCollection,
    };
    return map;
  } else {
    throw Exception("API not responding");
  }
}

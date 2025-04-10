import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:http/http.dart' as http;

Future<Map<String, Object>> getDirectionsRoute(
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
  if (response.statusCode == 200) {
    final data = json.decode(response.body);

    // Extract the route geometry from the response
    final route = data['routes'][0];
    final geometry = route['geometry'];
    // Create a GeoJSON feature from the route geometry
    final routeFeature = {
      "type": "Feature",
      "properties": {},
      "geometry": geometry,
    };

    final featureCollection = {
      "type": "FeatureCollection",
      "features": [routeFeature],
    };

    return featureCollection;
  } else {
    throw Exception("API not responding");
  }
}

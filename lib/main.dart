import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:wassilni/firebase_options.dart';
import 'package:wassilni/pages/map.dart';

void main() async {
  await setup();
  runApp(const MyApp());
}

Future<void> setup() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await dotenv.load(fileName: ".env");
  MapboxOptions.setAccessToken(dotenv.env["MAPBOX_ACCESS_TOKEN"]!);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Flutter Demo', home: const Map());
  }
}

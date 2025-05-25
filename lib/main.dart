import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:wassilni/firebase_options.dart';
import 'package:wassilni/pages/auth/login_page.dart';
import 'package:wassilni/providers/destination_provider.dart';
import 'package:wassilni/providers/fare_provider.dart';
import 'package:wassilni/providers/user_provider.dart';
import 'package:wassilni/providers/ride_provider.dart';

void main() async {
  await setup();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_)=> UserProvider(),),
        ChangeNotifierProvider(create: (_) => FareProvider()),
        ChangeNotifierProvider(create: (_) => DestinationProvider()),
        ChangeNotifierProvider(create: (_) => RideProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> setup() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await dotenv.load(fileName: ".env");
  MapboxOptions.setAccessToken(dotenv.env["MAPBOX_ACCESS_TOKEN"]!);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Flutter Demo', home: const LoginPage());
  }
}

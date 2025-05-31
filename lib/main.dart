import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:wassilni/firebase_options.dart';
import 'package:wassilni/pages/auth/login_page.dart';
import 'package:wassilni/pages/auth/register_page.dart';
import 'package:wassilni/pages/driver_page.dart';
import 'package:wassilni/providers/destination_provider.dart';
import 'package:wassilni/providers/fare_provider.dart';
import 'package:wassilni/pages/home_page.dart';
import 'package:wassilni/providers/ride_provider.dart';
import 'package:wassilni/providers/user_provider.dart';
import 'pages/rider_screen.dart';

void main() async {
  await setup();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<bool> _initializationFuture;

  @override
  void initState() {
    super.initState();
    // Initialize the UserProvider from the widget tree
    final userProvider = Provider.of<UserProvider>(
      // Use a context that has access to the provider
      context,
      listen: false,
    );
    _initializationFuture = userProvider.initializeFromStorage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: FutureBuilder<bool>(
        future: _initializationFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          // Check the provider's state directly
          final userProvider = Provider.of<UserProvider>(
            context,
            listen: false,
          );
          return userProvider.currentUser != null
              ? userProvider.currentUser!.type.name == "rider" ? const RiderScreen() : DriverMap()
              : const LoginPage();
        },
      ),
    );
  }
}

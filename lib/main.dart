import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:wassilni/firebase_options.dart';
import 'package:wassilni/pages/auth/register_page.dart';
import 'package:wassilni/providers/destination_provider.dart';
import 'package:wassilni/providers/fare_provider.dart';
import 'package:wassilni/pages/home_page.dart';
import 'package:wassilni/providers/user_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setup();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_)=> UserProvider(),),
        ChangeNotifierProvider(create: (_) => FareProvider()),
        ChangeNotifierProvider(create: (_) => DestinationProvider()),
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
  
  final userProvider = UserProvider();
  final hasUserData = await userProvider.initializeFromStorage();
  print("User data initialized: $hasUserData");
  if (hasUserData) {
    print("Current user: ${userProvider.currentUser?.phone}");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: FutureBuilder<bool>(
        future: _checkLoginStatus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData && snapshot.data == true) {
            return const HomePage();
          }
          return const RegisterPage();
        },
      ),
    );
  }

  Future<bool> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('logged_in_phone');
    print("the instance of shared preferences is $phone");
    if (phone == null) return false;
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('phone', isEqualTo: phone)
        .get();

    return querySnapshot.docs.isNotEmpty;
  }
}

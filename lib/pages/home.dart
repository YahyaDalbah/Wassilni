import 'package:flutter/material.dart';
import 'package:wassilni/pages/map.dart';
import 'package:wassilni/pages/rides.dart';
import 'package:wassilni/models/driver.dart';
import 'package:wassilni/pages/profile.dart';

// Constants for colors
const Color kBackgroundColor = Colors.black;
const Color kSearchBarColor = Color(0xFF2B2B2B);
const Color kBottomBarColor = Colors.black;

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text('Wassilni'),
        centerTitle: true,
        backgroundColor: kBackgroundColor,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Map()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              height: 50,
              decoration: BoxDecoration(
                color: kSearchBarColor,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: const [
                  Icon(Icons.search, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'Where?',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const HomeBottomBar(),
    );
  }
}

class HomeBottomBar extends StatelessWidget {
  const HomeBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    // Example driver data
    final driver = Driver(
      id: '1',
      firstName: 'John',
      lastName: 'Doe',
      phoneNumber: '+1234567890',
    );

    return BottomNavigationBar(
      backgroundColor: kBottomBarColor,
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.white70,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.directions_car),
          label: 'Rides',
        ),
      ],
      onTap: (index) {
        if (index == 0) {
          // Home icon tapped, do nothing (already on home)
        } else if (index == 1) {
          // Profile icon tapped, navigate to ProfilePage
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProfilePage(driver: driver)),
          );
        } else if (index == 2) {
          // Rides icon tapped, navigate to RidesPage
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RidesPage()),
          );
        }
      },
    );
  }
}
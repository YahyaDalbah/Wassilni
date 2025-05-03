import 'package:flutter/material.dart';
import 'package:wassilni/models/driver.dart';
import 'package:wassilni/pages/edit_profile.dart';

class ProfilePage extends StatelessWidget {
  final Driver driver;

  const ProfilePage({super.key, required this.driver});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Profile'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Enlarged Profile Photo
              CircleAvatar(
                radius: 60,
                backgroundImage: AssetImage('assets/profile_photo.png'), // Replace with your image path
                backgroundColor: Colors.grey[800],
              ),
              const SizedBox(height: 16),
              // Driver Name
              Text(
                '${driver.firstName} ${driver.lastName}',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // Driver Phone Number with Edit Button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Phone: ${driver.phoneNumber}',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => EditProfilePage(driver: driver)),
                      );
                    },
                    child: const Text(
                      'Edit',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Driver Dashboard
              const Text(
                'Driver Dashboard',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Earnings and Completed Rides
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Earnings
                  Column(
                    children: [
                      const Text(
                        'Earnings',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$1,250', // Replace with dynamic data
                        style: const TextStyle(color: Colors.green, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  // Completed Rides
                  Column(
                    children: [
                      const Text(
                        'Completed Rides',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '45', // Replace with dynamic data
                        style: const TextStyle(color: Colors.blue, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Rides Table
              const Text(
                'Recent Rides',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true, // Allow scrolling within the parent scroll view
                physics: const NeverScrollableScrollPhysics(), // Disable inner scrolling
                itemCount: 5, // Show 5 rides
                itemBuilder: (context, index) {
                  return Card(
                    color: Colors.grey[900],
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      title: Text(
                        'Ride #${index + 1}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'Pickup: Location ${index + 1}\nDropoff: Location ${index + 1}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: Text(
                        '\$${(index + 1) * 10}', // Example fare
                        style: const TextStyle(color: Colors.green, fontSize: 16),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
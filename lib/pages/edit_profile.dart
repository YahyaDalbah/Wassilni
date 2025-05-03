import 'package:flutter/material.dart';
import 'package:wassilni/models/driver.dart';

class EditProfilePage extends StatelessWidget {
  final Driver driver;

  const EditProfilePage({super.key, required this.driver});

  @override
  Widget build(BuildContext context) {
    final TextEditingController firstNameController = TextEditingController(text: driver.firstName);
    final TextEditingController lastNameController = TextEditingController(text: driver.lastName);
    final TextEditingController phoneController = TextEditingController(text: driver.phoneNumber);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile Picture Section
              GestureDetector(
                onTap: () {
                  // Add functionality to change the profile picture (currently static)
                  print('Change profile picture tapped');
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 60, // Same size as in ProfilePage
                      backgroundImage: AssetImage('assets/profile_photo.png'), // Replace with your image path
                      backgroundColor: Colors.grey[800],
                    ),
                    const Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 30, // Edit icon overlay
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Edit First Name
              const Text(
                'Edit First Name',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: firstNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  hintText: 'Enter your first name',
                  hintStyle: const TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 16),
              // Edit Last Name
              const Text(
                'Edit Last Name',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: lastNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  hintText: 'Enter your last name',
                  hintStyle: const TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 16),
              // Edit Phone Number
              const Text(
                'Edit Phone Number',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  hintText: 'Enter your phone number',
                  hintStyle: const TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 32),
              // Save Changes Button
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
                  ),
                  onPressed: () {
                    // Save the updated information
                    print('Updated First Name: ${firstNameController.text}');
                    print('Updated Last Name: ${lastNameController.text}');
                    print('Updated Phone: ${phoneController.text}');
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
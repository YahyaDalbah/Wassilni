import 'package:flutter/material.dart';

class MenuDrawerContent extends StatelessWidget {
  final VoidCallback onProfile;
  final VoidCallback onRides;
  final VoidCallback onLogout;
  final VoidCallback onClose;

  const MenuDrawerContent({
    super.key,
    required this.onProfile,
    required this.onRides,
    required this.onLogout,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta! < -5) onClose();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDrawerItem(Icons.logout, 'Logout', onLogout),
            _buildDrawerItem(Icons.person, 'Profile', onProfile),
            _buildDrawerItem(Icons.directions_car, 'Rides', onRides),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 30),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

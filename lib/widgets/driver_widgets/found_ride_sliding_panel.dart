import 'package:flutter/material.dart';

Widget foundRideSlidingPanel({
  required String panelTitle,
  required String panelSubtitle1,
  required String panelSubtitle2,
  required String panelLocation1,
  required String panelLocation2,
  required VoidCallback onAcceptRide,
  required VoidCallback onCancelRide,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const SizedBox(height: 10),
      Center(
        child: Text(
          panelTitle,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      const Divider(color: Colors.white),
      ListTile(
        leading: const Icon(Icons.location_on, color: Colors.white),
        title: Text(
          panelSubtitle1,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          panelLocation1,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      ListTile(
        leading: const Icon(Icons.location_on, color: Colors.white),
        title: Text(
          panelSubtitle2,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          panelLocation2,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      const Spacer(),
      Column(
        children: [
          ElevatedButton(
            onPressed: onAcceptRide,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 15),
              minimumSize: const Size(300, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              "Accept Ride",
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: onCancelRide,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 15),
              minimumSize: const Size(300, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              "Cancel",
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
    ],
  );
}

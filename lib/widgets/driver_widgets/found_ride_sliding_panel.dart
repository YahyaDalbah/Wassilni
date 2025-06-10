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
          Material(
            color: Colors.green,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: onAcceptRide,
              borderRadius: BorderRadius.circular(20),
              splashColor: Colors.white.withOpacity(0.5),
              highlightColor: Colors.white.withOpacity(0.3),
              child: Container(
                width: 300,
                height: 55,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                child: const Text(
                  "Accept Ride",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: Colors.red,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: onCancelRide,
              borderRadius: BorderRadius.circular(20),
              splashColor: Colors.white.withOpacity(0.5),
              highlightColor: Colors.white.withOpacity(0.3),
              child: Container(
                width: 300,
                height: 55,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                child: const Text(
                  "Cancel",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
    ],
  );
}

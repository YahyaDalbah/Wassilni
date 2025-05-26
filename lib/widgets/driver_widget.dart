import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wassilni/models/ride_model.dart';
import 'package:wassilni/providers/fare_provider.dart';

Widget buildPanelContent({
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
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
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
          // Accept Ride Button (same as before)
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
          // Cancel Button
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
Widget buildWaitingPanel({
  required String userName,
  required String waitTime,
  required VoidCallback onStartRide,
  VoidCallback? onCancelRide, // Keep cancellation logic unchanged
  required bool isCancelEnabled, // Pass enabled state
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const SizedBox(height: 30),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.call, color: Colors.white),
          Text(
            "Waiting For $userName",
            style: const TextStyle(fontSize: 18, color: Colors.white),
          ),
          Text(
            waitTime,
            style: const TextStyle(fontSize: 18, color: Colors.white),
          ),
        ],
      ),
      const Divider(color: Colors.white),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed: onStartRide,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            ),
            child: const Text(
              "Start Ride",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: isCancelEnabled ? onCancelRide : null, // Disable button if not enabled
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, // Enabled color
              disabledBackgroundColor: const Color(0xFFCF8383), // Disabled color
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            ),
            child: const Text(
              "Cancel Ride",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    ],
  );
}

// In driver_widgets.dart
Widget buildDroppingOffPanel({
  required String userName,
  required String distance,
  required String estTimeLeft,
  required VoidCallback onCompleteRide,
}) {
  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      children: [
        const SizedBox(height: 10),
        Text(
          "Dropping Off Rider",
          style: const TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold
          ),
        ),
        const Divider(color: Colors.white54, height: 24),
        Text(
          "📍 Distance: $distance",
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
        const SizedBox(height: 12),
        Text(
          "⏱ Time Remaining: $estTimeLeft",
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: onCompleteRide,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green, // Changed to green
            padding: const EdgeInsets.symmetric(vertical: 15),
            fixedSize: const Size(300, 60), // Approximate 80% width for most screens
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Text(
            "Complete Ride",
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

Widget buildCollapsedPanel(String text) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.black,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 10,
        ),
      ],
    ),
    child: Center(
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    ),
  );
}

class FooterWidget extends StatelessWidget {
  final String text;

  const FooterWidget({required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
}

// Widgets for Online/Offline Toggle and Footers
Widget buildOnlineOfflineButton({
  required VoidCallback onPressed,
  required bool isOnline,
}) {
  return Positioned(
    bottom: 100,
    left: 0,
    right: 0,
    child: Center(
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isOnline ? Colors.red : Colors.blue,
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(20),
        ),
        child: Text(
          isOnline ? "Stop!" : "Go!",
          style: const TextStyle(fontSize: 18, color: Colors.white),
        ),
      ),
    ),
  );
}

Widget buildPickingUpFooter({
  required String userName,
  required String distanceText,
  required VoidCallback onTap, // Add this parameter
}) {
  return Positioned(
    bottom: 0,
    left: 0,
    right: 0,
    child: GestureDetector(
      onTap: onTap, // Use the callback
      child: Container(
        height: 100,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        color: Colors.black,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Picking Up $userName",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "$distanceText to pickup",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}



Widget buildDroppingOffPanels({
  required Ride currentRide,
  required BuildContext context,
  required VoidCallback onCompleteRide,
}) {
  return Consumer<FareProvider>(
    builder: (context, fareProvider, _) {
      return buildDroppingOffPanel(
        userName: "Rider ${currentRide.riderId}",
        distance: "${((fareProvider.estimatedDistance ?? 0) / 1000).toStringAsFixed(1)} KM",
        estTimeLeft: "${(fareProvider.estimatedDuration ?? 0) ~/ 60} min",
        onCompleteRide: onCompleteRide,
      );
    },
  );
}
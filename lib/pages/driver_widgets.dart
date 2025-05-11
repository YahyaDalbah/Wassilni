import 'package:flutter/material.dart';

Widget buildPanelContent({
  required String panelTitle,
  required String panelSubtitle1,
  required String panelSubtitle2,
  required String panelLocation1,
  required String panelLocation2,
  required VoidCallback onAcceptRide,
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
      Center(
        child: ElevatedButton(
          onPressed: onAcceptRide,
          child: const Text("Accept!"),
        ),
      ),
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

Widget buildDroppingOffPanel({
  required String userName,
  required String distance,
  required String estTimeLeft,
  required VoidCallback onCompleteRide,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const SizedBox(height: 10),
      Text(
        "Dropping Off $userName",
        style: const TextStyle(fontSize: 18, color: Colors.white),
      ),
      const Divider(color: Colors.white),
      Text(
        "Distance: $distance",
        style: const TextStyle(fontSize: 16, color: Colors.white),
      ),
      Text(
        "Estimated Time: $estTimeLeft",
        style: const TextStyle(fontSize: 16, color: Colors.white),
      ),
      const SizedBox(height: 10),
      ElevatedButton(
        onPressed: onCompleteRide,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        ),
        child: const Text(
          "Complete Ride",
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    ],
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

  const FooterWidget({required this.text, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print("FooterWidget built with text: $text");
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

class Ride {
  final String id;
  final String passengerName;
  final double pickupLatitude;
  final double pickupLongitude;
  final double dropoffLatitude;
  final double dropoffLongitude;
  final DateTime timestamp;
  final String phoneNumber; // New field

  Ride({
    required this.id,
    required this.passengerName,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.dropoffLatitude,
    required this.dropoffLongitude,
    required this.timestamp,
    required this.phoneNumber, // New field
  });
}
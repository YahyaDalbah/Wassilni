import 'package:cloud_firestore/cloud_firestore.dart';

class Ride {
  final String rideId;
  final String riderId;
  final String driverId;
  String status;
  final Map<String, dynamic> pickup;
  final Map<String, dynamic> destination;
  final double fare;
  final double distance;
  final double duration;
  final Map<String, dynamic> timestamps;

  Ride({
    required this.rideId,
    required this.riderId,
    required this.driverId,
    required this.status,
    required this.pickup,
    required this.destination,
    required this.fare,
    required this.distance,
    required this.duration,
    required this.timestamps,
  });

  // Create Ride from Firestore document
  factory Ride.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Ride(
      rideId: doc.id,
      riderId: data['riderId'] as String,
      driverId: data['driverId'] as String,
      status: data['status'] as String,
      pickup: data['pickup'] as Map<String, dynamic>,
      destination: data['destination'] as Map<String, dynamic>,
      fare: (data['fare'] as num).toDouble(),
      distance: (data['distance'] as num).toDouble(),
      duration: (data['duration'] as num).toDouble(),
      timestamps: data['timestamps'] as Map<String, dynamic>,
    );
  }

  // Convert Ride to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'riderId': riderId,
      'driverId': driverId,
      'status': status,
      'pickup': pickup,
      'destination': destination,
      'fare': fare,
      'distance': distance,
      'duration': duration,
      'timestamps': timestamps,
    };
  }

  Ride copyWith({
    String? rideId,
    String? riderId,
    String? driverId,
    String? status,
    Map<String, dynamic>? pickup,
    Map<String, dynamic>? destination,
    double? fare,
    double? distance,
    double? duration,
    Map<String, dynamic>? timestamps,
  }) {
    return Ride(
      rideId: rideId ?? this.rideId,
      riderId: riderId ?? this.riderId,
      driverId: driverId ?? this.driverId,
      status: status ?? this.status,
      pickup: pickup ?? this.pickup,
      destination: destination ?? this.destination,
      fare: fare ?? this.fare,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      timestamps: timestamps ?? this.timestamps,
    );
  }}
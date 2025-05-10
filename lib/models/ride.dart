import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String userId;
  final String type; // "rider" or "driver"
  final String phone;
  final bool isOnline;
  final Vehicle? vehicle;
  final GeoPoint currentLocation;

  User({
    required this.userId,
    required this.type,
    required this.phone,
    required this.isOnline,
    this.vehicle,
    required this.currentLocation,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      userId: map['userId'],
      type: map['type'],
      phone: map['phone'],
      isOnline: map['isOnline'],
      vehicle: map['vehicle'] != null ? Vehicle.fromMap(map['vehicle']) : null,
      currentLocation: map['currentLocation'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'phone': phone,
      'isOnline': isOnline,
      'vehicle': vehicle?.toMap(),
      'currentLocation': currentLocation,
    };
  }
}

class Vehicle {
  final String make;
  final String model;
  final String licensePlate;

  Vehicle({
    required this.make,
    required this.model,
    required this.licensePlate,
  });

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      make: map['make'],
      model: map['model'],
      licensePlate: map['licensePlate'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'make': make,
      'model': model,
      'licensePlate': licensePlate,
    };
  }
}

class Ride {
  final String rideId;
  final String riderId;
  final String driverId;
  final String status; // "requested", "accepted", "in_progress", "completed", "canceled"
  final Location pickup;
  final Location destination;
  final double fare;
  final double distance;
  final double duration;
  final RideTimestamps timestamps;

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

  factory Ride.fromMap(Map<String, dynamic> map) {
    return Ride(
      rideId: map['rideId'],
      riderId: map['riderId'],
      driverId: map['driverId'],
      status: map['status'],
      pickup: Location.fromMap(map['pickup']),
      destination: Location.fromMap(map['destination']),
      fare: map['fare'],
      distance: map['distance'],
      duration: map['duration'],
      timestamps: RideTimestamps.fromMap(map['timestamps']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rideId': rideId,
      'riderId': riderId,
      'driverId': driverId,
      'status': status,
      'pickup': pickup.toMap(),
      'destination': destination.toMap(),
      'fare': fare,
      'distance': distance,
      'duration': duration,
      'timestamps': timestamps.toMap(),
    };
  }
}

class Location {
  final String address;
  final GeoPoint coordinates;

  Location({
    required this.address,
    required this.coordinates,
  });

  factory Location.fromMap(Map<String, dynamic> map) {
    return Location(
      address: map['address'],
      coordinates: map['coordinates'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'coordinates': coordinates,
    };
  }
}

class RideTimestamps {
  final Timestamp? requested;
  final Timestamp? accepted;
  final Timestamp? started;
  final Timestamp? completed;

  RideTimestamps({
    this.requested,
    this.accepted,
    this.started,
    this.completed,
  });

  factory RideTimestamps.fromMap(Map<String, dynamic> map) {
    return RideTimestamps(
      requested: map['requested'],
      accepted: map['accepted'],
      started: map['started'],
      completed: map['completed'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requested': requested,
      'accepted': accepted,
      'started': started,
      'completed': completed,
    };
  }
}
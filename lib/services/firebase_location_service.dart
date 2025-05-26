import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;


class FirebaseLocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<DocumentSnapshot>? _driverLocationSub;

  void startTrackingDriver(String driverId, void Function(mp.Point driverPoint) onUpdate) {
    _driverLocationSub = _firestore
        .collection('users')
        .doc(driverId)
        .snapshots()
        .listen((snapshot) {
          if (!snapshot.exists) return;

          final location = snapshot['location'] as GeoPoint;
          final driverPoint = mp.Point(
            coordinates: mp.Position(location.longitude, location.latitude),
          );
          onUpdate(driverPoint);
        });
  }

  Future<void> updateUserPosition(String userId, gl.Position position) async {
    await _firestore.collection('users').doc(userId).update({
      'location': GeoPoint(position.latitude, position.longitude),
    });
  }

  void dispose() {
    _driverLocationSub?.cancel();
  }
}

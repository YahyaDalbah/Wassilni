import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mp;

class FirebaseLocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot>? _driverLocationSub;

  void startTrackingDriver(
    String driverId,
    void Function(mp.Point driverPoint) onUpdate, {
    required Function(Object error) onError,
  }) {
    try {
      _driverLocationSub = _firestore
          .collection('users')
          .doc(driverId)
          .snapshots()
          .listen(
            (snapshot) {
              if (!snapshot.exists) {
                throw Exception('Driver document not found');
              }

              final location = snapshot['location'] as GeoPoint?;
              if (location == null) {
                throw Exception('Location data missing in driver document');
              }

              final driverPoint = mp.Point(
                coordinates: mp.Position(location.longitude, location.latitude),
              );
              onUpdate(driverPoint);
            },
            onError: (error) {
              onError(error);
            },
          );
    } on SocketException {
      onError("bad network connection");
    }
     catch (e) {
      onError(e);
    }
  }

  Future<void> updateUserPosition(String userId, gl.Position position) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'location': GeoPoint(position.latitude, position.longitude),
      });
      
    }on SocketException {
      rethrow;
    } 
    
    catch (e) {
      throw Exception('failed to update user in cloud');
    }
  }

  void dispose() {
    _driverLocationSub?.cancel();
  }
}

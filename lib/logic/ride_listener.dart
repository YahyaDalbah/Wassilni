import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:wassilni/models/ride_model.dart';
import 'package:wassilni/providers/user_provider.dart';

class RideListener {
  static StreamSubscription<QuerySnapshot>? create({
    required bool forceNew,
    required UserProvider userProvider,
    required String? driverId,
    required Function(Ride) onRideFound,
    required StreamSubscription<QuerySnapshot>? existingSubscription,
  }) {
    if (existingSubscription != null && !forceNew) return existingSubscription;
    existingSubscription?.cancel();

    if (driverId == null) return null;

    bool initialDataProcessed = false;

    return FirebaseFirestore.instance
        .collection('rides')
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: "requested")
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) async {
          if (!initialDataProcessed) {
            if (snapshot.metadata.isFromCache) return;
            initialDataProcessed = true;
          }
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added &&
                !change.doc.metadata.hasPendingWrites) {
              final ride = Ride.fromFirestore(change.doc);
              onRideFound(ride);
              await userProvider.updateOnlineStatus(false);
            }
          }
        }, onError: (error) => debugPrint("Ride stream error: $error"));
  }
}
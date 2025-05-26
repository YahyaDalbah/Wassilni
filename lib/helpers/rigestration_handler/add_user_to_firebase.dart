import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wassilni/models/user_model.dart';

class FirebaseUserManager {
  static Future<void> addToFirestore(String phone, String pass) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await UserModel.addToFireStore(
        type: UserType.rider,
        password: pass,
        phone: phone,
        isOnline: true,
        vehicle: {"make": "", "model": "", "licensePlate": ""},
        location: const GeoPoint(0, 0),
      );
    }
  }
}
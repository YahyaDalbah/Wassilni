import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  String id; 
  UserType type;
  String password;
  String phone;
  bool isOnline;
  Map<String,String> vehicle = {
  "make": "",
  "model": "",
  "licensePlate": ""
  };
  GeoPoint location;

  UserModel({
    required this.id,
    required this.type,
    required this.phone,
    required this.isOnline,
    required this.vehicle,
    required this.location,
    required this.password
  });

  factory UserModel.fromFireStore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id, 
      type: data['type'] == 'driver' ? UserType.driver : UserType.rider,
      password: data['password'],
      phone: data['phone'] ?? '',
      isOnline: data['isOnline'] ?? false,
      vehicle: Map<String, String>.from(data['vehicle'] ?? {}),
      location: data['location'] ?? const GeoPoint(0, 0),
    );
  }

  Map<String, dynamic> toFireStore() {
    return {
      'type': type == UserType.driver ? 'driver' : 'rider',
      'phone': phone,
      'password': password,
      'isOnline': isOnline,
      'vehicle': vehicle,
      'location': location,
    };
  }

  static Future<UserModel> addToFireStore({
    required UserType type,
    required String password,
    required String phone,
    required bool isOnline,
    required Map<String, String> vehicle,
    required GeoPoint location,
  }) async {
    final docRef = await FirebaseFirestore.instance.collection('users').add({
      'type': type == UserType.driver ? 'driver' : 'rider',
      'password':password,
      'phone': phone,
      'isOnline': isOnline,
      'vehicle': vehicle,
      'location': location,
    });
    return UserModel(
      id: docRef.id,
      type: type,
      password: password,
      phone: phone,
      isOnline: isOnline,
      vehicle: vehicle,
      location: location,
    );
  }
}

enum UserType {
  rider,
  driver
}
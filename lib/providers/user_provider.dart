
import 'package:flutter/cupertino.dart';
import 'package:wassilni/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

class UserProvider extends ChangeNotifier {
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  Future<void> login(String phone, String password) async {

    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('phone', isEqualTo: phone)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final userDoc = querySnapshot.docs.first;
      _currentUser = UserModel.fromFireStore(userDoc);
      notifyListeners();
    } else {
      print('No user found with this phone number');
    }
}

  Future<void> logout() async {
    await auth.FirebaseAuth.instance.signOut();
    _currentUser = null;
    notifyListeners();
  }
}

import 'package:flutter/cupertino.dart';
import 'package:wassilni/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  Future<void> initializeUser() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('logged_in_phone');
    if (phone != null) {
      await login(phone, '');
    }
  }

  Future<void> login(String phone, String password) async {
    String cleanPhoneNumber = phone.trim();
    if (!cleanPhoneNumber.startsWith('+')) {
      cleanPhoneNumber = '+$cleanPhoneNumber';
    }

    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('phone', isEqualTo: cleanPhoneNumber)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final userDoc = querySnapshot.docs.first;
      _currentUser = UserModel.fromFireStore(userDoc);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('logged_in_phone', cleanPhoneNumber);
      await prefs.setString('user_id', userDoc.id);
      
      notifyListeners();
    } else {
      throw Exception('No user found with this phone number');
    }
}

  Future<bool> initializeFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('logged_in_phone');
    final userId = prefs.getString('user_id');

    if (phone != null && userId != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        _currentUser = UserModel.fromFireStore(userDoc);
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('logged_in_phone');
    await prefs.remove('user_id');
    _currentUser = null;
    notifyListeners();
  }

  Future<void> updateOnlineStatus(bool isOnline) async {
    if (_currentUser != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.id)
          .update({'isOnline': isOnline});
      notifyListeners();
    }
  }
}
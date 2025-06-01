import 'package:wassilni/services/auth_service.dart';

class VerificationService {
  final AuthService _authService = AuthService();

  Future<void> verifyPhoneAndCreateUser({
    required String verificationId,
    required String smsCode,
    required String phoneNumber,
    required String password,
  }) async {
    await _authService.verifyPhoneCode(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    
    await _authService.createUserInFirestore(
      phoneNumber: phoneNumber,
      password: password,
    );
  }
}
import 'app_user.dart';

abstract interface class AuthRepository {
  Future<AppUser?> login({
    required String username,
    required String password,
  });

  Future<void> logout();

  Future<AppUser?> currentUser();

  Future<List<AppUser>> listAccounts();

  Future<AppUser> saveAccount(AppUser user, {String? password});

  Future<void> setPassword(String userId, String password);

  Future<void> setPin(String userId, String? pin);

  Future<bool> verifyPin(String userId, String pin);

  Future<void> deleteAccount(String userId);
}

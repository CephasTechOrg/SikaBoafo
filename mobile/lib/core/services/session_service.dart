import '../../data/local/app_database.dart';
import 'secure_token_storage.dart';

class SessionService {
  SessionService({
    required AppDatabase appDb,
    required SecureTokenStorage tokenStorage,
  })  : _appDb = appDb,
        _tokenStorage = tokenStorage;

  final AppDatabase _appDb;
  final SecureTokenStorage _tokenStorage;

  Future<void> applyAuthenticatedSession({
    required String userId,
    String? merchantId,
    required String accessToken,
    required String refreshToken,
  }) async {
    await _appDb.prepareForSession(userId: userId, merchantId: merchantId);
    await _tokenStorage.writeAccessToken(accessToken);
    await _tokenStorage.writeRefreshToken(refreshToken);
  }

  Future<void> bindMerchantToCurrentSession(String merchantId) {
    return _appDb.bindMerchantToCurrentSession(merchantId);
  }

  Future<void> signOut() async {
    await _tokenStorage.clearSession();
    await _appDb.clearBusinessData();
  }
}

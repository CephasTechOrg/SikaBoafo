import '../../data/local/app_database.dart';
import 'secure_token_storage.dart';

class SessionService {
  SessionService({
    required AppDatabase appDb,
    required SecureTokenStorage tokenStorage,
    Future<void> Function()? serverLogout,
  })  : _appDb = appDb,
        _tokenStorage = tokenStorage,
        _serverLogout = serverLogout;

  final AppDatabase _appDb;
  final SecureTokenStorage _tokenStorage;
  final Future<void> Function()? _serverLogout;

  Future<void> applyAuthenticatedSession({
    required String userId,
    String? merchantId,
    required String accessToken,
    required String refreshToken,
    String? role,
  }) async {
    await _appDb.prepareForSession(
      userId: userId,
      merchantId: merchantId,
      role: role,
    );
    await _tokenStorage.writeAccessToken(accessToken);
    await _tokenStorage.writeRefreshToken(refreshToken);
    await _tokenStorage.markSessionGateComplete(DateTime.now());
  }

  Future<void> bindMerchantToCurrentSession(String merchantId) {
    return _appDb.bindMerchantToCurrentSession(merchantId);
  }

  Future<void> signOut() async {
    final serverLogout = _serverLogout;
    if (serverLogout != null) {
      try {
        await serverLogout();
      } catch (_) {
        // Offline or already-invalid token — still clear local session.
      }
    }
    await _tokenStorage.clearSession();
    await _appDb.clearBusinessData();
  }
}

import 'package:supabase/supabase.dart';

const androidEmailConfirmationUrl = 'komuna://auth/confirmacion-correo';
const emailConfirmationPath = '/confirmacion-correo';

AuthClientOptions registrationAuthOptions() =>
    AuthClientOptions(pkceAsyncStorage: _SignupVerifierStorage());

/// Keeps the verifier during the current process. Email verification is
/// followed by a separate password sign-in in Komuna.
class _SignupVerifierStorage extends GotrueAsyncStorage {
  final Map<String, String> _items = {};

  @override
  Future<String?> getItem({required String key}) async => _items[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    _items[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _items.remove(key);
  }
}

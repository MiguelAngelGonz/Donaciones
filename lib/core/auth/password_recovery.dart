import 'dart:async';

import 'package:donaciones/core/auth/registration_auth_options.dart';
import 'package:donaciones/core/models/domain_exceptions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase/supabase.dart';

final passwordRecoveryProvider = Provider<PasswordRecovery?>((ref) => null);

class PasswordRecovery {
  static const _timeout = Duration(seconds: 20);

  final String url;
  final String key;
  final _storage = _AndroidRecoveryVerifierStorage();

  PasswordRecovery({required this.url, required this.key});

  GoTrueClient _createClient() => GoTrueClient(
    url: '$url/auth/v1',
    headers: {'apikey': key, 'Authorization': 'Bearer $key'},
    autoRefreshToken: false,
    asyncStorage: _storage,
  );

  Future<bool> hasPendingLink() async => await _storage.read() != null;

  Future<void> sendLink(String email) async {
    final address = email.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(address)) {
      throw const ValidationException('Ingresa un correo electrónico válido.');
    }
    final auth = _createClient();
    try {
      await auth
          .resetPasswordForEmail(
            address,
            redirectTo: androidEmailConfirmationUrl,
          )
          .timeout(_timeout);
    } on AuthException catch (error) {
      if (error.code == 'user_not_found') return;
      if (error.statusCode == '429') {
        throw const ValidationException(
          'Alcanzaste el límite de solicitudes. Espera antes de intentarlo de nuevo.',
        );
      }
      throw const NetworkException(
        'No se pudo enviar el enlace. Intenta de nuevo.',
      );
    } on Exception {
      throw const NetworkException(
        'No se pudo enviar el enlace. Intenta de nuevo.',
      );
    } finally {
      auth.dispose();
    }
  }

  Future<PasswordRecoverySession> openLink(String code) async {
    final auth = _createClient();
    try {
      final response = await auth
          .exchangeCodeForSession(code)
          .timeout(_timeout);
      if (response.redirectType == AuthChangeEvent.passwordRecovery.name) {
        return PasswordRecoverySession._(auth);
      }
    } on AuthRetryableFetchException {
      auth.dispose();
      throw const NetworkException();
    } on TimeoutException {
      auth.dispose();
      throw const NetworkException();
    } on Exception {
      auth.dispose();
      throw const ExpiredOrUsedTokenException();
    }
    auth.dispose();
    throw const ExpiredOrUsedTokenException();
  }
}

/// The recovery session stays separate from the app's normal sign-in session.
class PasswordRecoverySession {
  final GoTrueClient _auth;

  PasswordRecoverySession._(this._auth);

  Future<void> updatePassword(String password) async {
    if (password.length < 8 ||
        !RegExp('[A-Z]').hasMatch(password) ||
        !RegExp('[a-z]').hasMatch(password) ||
        !RegExp('[0-9]').hasMatch(password)) {
      throw const ValidationException(
        'Usa al menos 8 caracteres, una mayúscula, una minúscula y un número.',
      );
    }
    try {
      await _auth
          .updateUser(UserAttributes(password: password))
          .timeout(PasswordRecovery._timeout);
    } on AuthRetryableFetchException {
      throw const NetworkException();
    } on AuthException catch (error) {
      if (error.code == 'same_password') {
        throw const ValidationException(
          'Elige una contraseña diferente a la anterior.',
        );
      }
      if (error.code == 'weak_password') {
        throw const ValidationException('Elige una contraseña más segura.');
      }
      throw const ExpiredOrUsedTokenException();
    } on Exception {
      throw const NetworkException();
    }
    try {
      await _auth.signOut().timeout(const Duration(seconds: 3));
    } on Exception {
      // The password was already updated. The recovery session is never saved.
    }
  }

  void close() => _auth.dispose();
}

class _AndroidRecoveryVerifierStorage extends GotrueAsyncStorage {
  static const _channel = MethodChannel('donaplus/session');

  Future<String?> read() =>
      _channel.invokeMethod<String>('readRecoveryVerifier');

  @override
  Future<String?> getItem({required String key}) => read();

  @override
  Future<void> setItem({required String key, required String value}) =>
      _channel.invokeMethod<void>('saveRecoveryVerifier', value);

  @override
  Future<void> removeItem({required String key}) =>
      _channel.invokeMethod<void>('saveRecoveryVerifier');
}

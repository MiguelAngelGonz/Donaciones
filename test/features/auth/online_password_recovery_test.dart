import 'dart:convert';

import 'package:donaciones/core/auth/password_recovery.dart';
import 'package:donaciones/core/models/domain_exceptions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('recovery restores the PKCE verifier and updates through a recovery session', () async {
    const channel = MethodChannel('donaplus/session');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    String? verifier;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'readRecoveryVerifier') return verifier;
      expect(call.method, 'saveRecoveryVerifier');
      verifier = call.arguments as String?;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final requested = <String>[];
    final client = MockClient((request) async {
      final path = request.url.path;
      requested.add(path);
      final body = request.body.isEmpty ? {} : jsonDecode(request.body) as Map;
      Map<String, Object?> response;
      switch (path) {
        case '/auth/v1/recover':
          expect(
            request.url.queryParameters['redirect_to'],
            'komuna://auth/confirmacion-correo',
          );
          expect(body['email'], 'test@example.invalid');
          expect(body['code_challenge_method'], 's256');
          expect(body['code_challenge'], isNotEmpty);
          response = {};
        case '/auth/v1/token':
          expect(request.url.queryParameters['grant_type'], 'pkce');
          expect(body['code_verifier'], verifier!.split('/').first);
          expect(body['auth_code'], 'code-from-email');
          response = {
            'access_token': 'e30.e30.c2ln',
            'token_type': 'bearer',
            'refresh_token': 'test-refresh',
            'expires_in': 3600,
            'user': {'id': 'test-user', 'aud': 'authenticated'},
          };
        case '/auth/v1/user':
          expect(request.method, 'PUT');
          expect(request.headers['Authorization'], 'Bearer e30.e30.c2ln');
          expect(body['password'], 'Nueva123');
          response = {'id': 'test-user', 'aud': 'authenticated'};
        case '/auth/v1/logout':
          response = {};
        default:
          throw StateError('Unexpected request $path');
      }
      return http.Response(
        jsonEncode(response),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await http.runWithClient(() async {
      PasswordRecovery recovery() => PasswordRecovery(
        url: 'https://komuna.example.invalid',
        key: 'publishable-test-key',
      );
      expect(await recovery().hasPendingLink(), isFalse);
      await recovery().sendLink('test@example.invalid');
      expect(await recovery().hasPendingLink(), isTrue);
      final session = await recovery().openLink('code-from-email');
      addTearDown(session.close);
      expect(await recovery().hasPendingLink(), isFalse);
      await expectLater(
        session.updatePassword('corta'),
        throwsA(isA<ValidationException>()),
      );
      await session.updatePassword('Nueva123');
    }, () => client);
    expect(requested, [
      '/auth/v1/recover',
      '/auth/v1/token',
      '/auth/v1/user',
      '/auth/v1/logout',
    ]);
  });
}

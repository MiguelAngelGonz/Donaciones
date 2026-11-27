import 'dart:async';
import 'dart:convert';

import 'package:donaciones/core/auth/registration_auth_options.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_exceptions.dart';
import 'package:donaciones/core/models/dto_inputs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase/supabase.dart';

const registration = RegisterUserInput(
  nombreUsuario: 'prueba',
  nombreLegal: 'Cuenta de prueba',
  correo: 'account@example.invalid',
  telefono: '2221234567',
  password: 'UnaClaveDePrueba12!',
  ubicacionEtiqueta: '72000',
  avisoPrivacidadAceptado: true,
);

void main() {
  OnlineTenantStore createStore(MockClient httpClient) {
    final client = SupabaseClient(
      'https://komuna.example.invalid',
      'sb_publishable_registration_test',
      authOptions: registrationAuthOptions(),
      httpClient: httpClient,
    );
    final store = OnlineTenantStore(
      client,
      emailConfirmationUrl: androidEmailConfirmationUrl,
    );
    addTearDown(() async {
      store.dispose();
      await client.dispose();
    });
    return store;
  }

  test(
    'online signup sends a PKCE challenge and awaits email confirmation',
    () async {
      var requests = 0;
      final store = createStore(
        MockClient((request) async {
          requests++;
          expect(request.method, 'POST');
          expect(request.url.path, '/auth/v1/signup');
          expect(
            request.url.queryParameters['redirect_to'],
            androidEmailConfirmationUrl,
          );
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(
            body['code_challenge'],
            isA<String>().having((s) => s.length, 'length', 43),
          );
          expect(body['code_challenge_method'], 's256');
          expect(body['email'], registration.correo);
          return http.Response(
            jsonEncode({
              'id': '11111111-1111-4111-8111-111111111111',
              'aud': 'authenticated',
              'email': registration.correo,
              'created_at': '2026-11-26T12:00:00Z',
              'user_metadata': {},
              'app_metadata': {},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final user = await store.registerUser(registration);
      expect(requests, 1);
      expect(user.correoVerificado, isFalse);
    },
  );

  test('online signup explains when verification email is blocked', () async {
    final store = createStore(
      MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error_code': 'email_address_not_authorized',
            'msg': 'Email address not authorized',
          }),
          400,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await expectLater(
      store.registerUser(registration),
      throwsA(
        isA<ValidationException>().having(
          (error) => error.message,
          'message',
          contains('correo de verificación'),
        ),
      ),
    );
  });

  test('online signup stops waiting when the server does not reply', () async {
    final pendingResponse = Completer<http.Response>();
    final store = createStore(MockClient((_) => pendingResponse.future));

    await expectLater(
      store.registerUser(registration),
      throwsA(
        isA<NetworkException>().having(
          (error) => error.message,
          'message',
          contains('tardó en responder'),
        ),
      ),
    );
    pendingResponse.complete(http.Response('{}', 500));
  });

  test('email quota tells the user to sign in or wait up to an hour', () async {
    final store = createStore(
      MockClient(
        (_) async => http.Response(
          '{"error_code":"over_email_send_rate_limit","msg":"email rate limit exceeded"}',
          429,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    await expectLater(
      store.registerUser(registration),
      throwsA(
        isA<ValidationException>().having(
          (error) => error.message,
          'message',
          allOf(contains('inicia sesión'), contains('hasta una hora')),
        ),
      ),
    );
  });
}

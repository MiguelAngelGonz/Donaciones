import 'dart:convert';

import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase/supabase.dart';

void main() {
  test(
    'online snapshots resolve proximity, matches and read receipts',
    () async {
      const actor = '11111111-1111-4111-8111-111111111111';
      const other = '22222222-2222-4222-8222-222222222222';
      const notice = '33333333-3333-4333-8333-333333333333';
      const email = 'cuenta@example.invalid';
      const date = '2026-11-26T12:00:00Z';
      final expiry = DateTime.now().add(const Duration(hours: 1));
      final claims = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'sub': actor,
            'exp': expiry.millisecondsSinceEpoch ~/ 1000,
          }),
        ),
      );
      var markedRead = false;

      Map<String, Object> publication(
        String id,
        String author,
        String kind,
        String location,
      ) => {
        'id': id,
        'author': author,
        'category': 'cat-salud',
        'kind': kind,
        'title': id,
        'description': 'Prueba',
        'location': location,
        'state': 'activa',
        'created_at': date,
        'quantity': 1,
        'details': <String, String>{},
        if (kind == 'necesidad') 'urgency': 'alta',
      };

      final client = SupabaseClient(
        'https://komuna.example.invalid',
        'sb_publishable_community_test',
        httpClient: MockClient((request) async {
          final body = switch (request.url.path) {
            '/auth/v1/token' => {
              'access_token': 'e30.$claims.c2ln',
              'token_type': 'bearer',
              'refresh_token': 'test-refresh',
              'expires_in': 3600,
              'user': {'id': actor, 'email': email, 'aud': 'authenticated'},
            },
            '/rest/v1/rpc/donaplus_snapshot' => {
              'profiles': [
                {
                  'id': actor,
                  'name': 'Cuenta',
                  'username': 'cuenta',
                  'location': '72000',
                  'average_rating': 4.5,
                  'review_count': 2,
                },
              ],
              'publications': [
                publication('far', other, 'articulo', '74200'),
                publication('unknown', other, 'articulo', 'Sin CP'),
                publication('near', other, 'articulo', '72010'),
                publication('mine', actor, 'necesidad', '72000'),
              ],
              'notifications': [
                {
                  'id': notice,
                  'recipient': actor,
                  'publication': 'near',
                  'created_at': date,
                  'message': 'Nueva coincidencia',
                  'kind': 'nuevaCoincidencia',
                  'read_at': markedRead ? date : null,
                },
              ],
            },
            '/rest/v1/rpc/komuna_mark_notifications_read' => null,
            _ => throw StateError('Unexpected path ${request.url.path}'),
          };
          if (request.url.path.endsWith('komuna_mark_notifications_read')) {
            expect(jsonDecode(request.body), {
              'notification_ids': [notice],
            });
            markedRead = true;
          }
          return http.Response(
            jsonEncode(body),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final store = OnlineTenantStore(
        client,
        locationLookup: (label) async {
          final longitude = {
            '72000': -98.20,
            '72010': -98.22,
            '74200': -98.46,
          }[label];
          return longitude == null
              ? null
              : UbicacionMock(
                  etiqueta: label,
                  latitud: 19.04,
                  longitud: longitude,
                );
        },
      );
      addTearDown(() async {
        store.dispose();
        await client.dispose();
      });

      await store.login(usernameOrEmail: email, password: 'prueba');
      await Future<void>.delayed(Duration.zero);
      expect(store.activeUser?.perfilConfianzaOtorgado, isTrue);
      expect(store.activeUser?.promedioCalificacion, 4.5);
      expect(store.activeUser?.numeroResenas, 2);
      expect(store.canFilterByDistance, isTrue);
      expect(
        store.getDistanceForPublication(store.findPublicationById('unknown')!),
        isNull,
      );
      expect(
        store
            .filterActivePublications(
              type: TipoPublicacion.articulo,
              sortByDistance: true,
            )
            .map((p) => p.id),
        ['near', 'far', 'unknown'],
      );
      expect(
        store
            .filterActivePublications(
              type: TipoPublicacion.articulo,
              maxDistanceKm: 5,
            )
            .map((p) => p.id),
        ['near'],
      );
      expect(store.getMatchesForUser(actor).map((m) => m.publicacionParId), [
        'near',
        'far',
        'unknown',
      ]);
      expect(store.getNotificationsForUser(actor).single.leida, isFalse);
      await store.markNotificationsAsRead([notice]);
      expect(markedRead, isTrue);
      await store.login(usernameOrEmail: email, password: 'prueba');
      expect(store.getNotificationsForUser(actor).single.leida, isTrue);
    },
  );
}

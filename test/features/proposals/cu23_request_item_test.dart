import 'package:donaciones/app/router.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/features/proposals/presentation/request_item_controller.dart';
import 'package:donaciones/features/proposals/presentation/request_item_sheet.dart';
import 'package:donaciones/features/publications/presentation/publication_detail_screen.dart';
import 'package:donaciones/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<(MockTenantStore, ProviderContainer)> pumpAppAtPublication(
    WidgetTester tester,
    String publicationId,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DonaPlusApp()));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DonaPlusApp)),
    );
    final store = container.read(mockTenantStoreProvider);
    container.read(appRouterProvider).go('/publications/$publicationId');
    await tester.pumpAndSettle();
    return (store, container);
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('CU-23: Solicitar artículo', () {
    testWidgets(
      'TC-CU23-01: flujo principal completo registra Solicitud PENDIENTE, notifica al donante y muestra confirmación',
      (tester) async {
        final (store, _) = await pumpAppAtPublication(tester, 'pub-3');
        expect(find.byType(PublicationDetailScreen), findsOneWidget);

        await tapVisible(
          tester,
          find.byKey(const Key('detail_request_item_button')),
        );
        expect(find.byType(RequestItemSheet), findsOneWidget);

        // 95-character valid message
        const message95 =
            'Hola María, nos mudamos hace poco y necesitamos una mesa para cenar en familia todos los días..';
        expect(message95.length, 95);

        await tester.enterText(
          find.byKey(const Key('request_message_field')),
          message95,
        );
        await tester.pumpAndSettle();
        expect(find.text('95 / 300 caracteres'), findsOneWidget);

        await tapVisible(
          tester,
          find.byKey(const Key('request_submit_button')),
        );

        expect(find.textContaining('Solicitud enviada'), findsWidgets);
        expect(store.proposals.length, 1);

        final created = store.proposals.first;
        expect(created.publicacionId, 'pub-3');
        expect(created.remitenteId, 'usr-alondra');
        expect(created.tipo, TipoPropuesta.solicitud);
        expect(created.estado, EstadoPropuesta.pendiente);
        expect(created.texto, message95);
        expect(created.claveCliente, isNotEmpty);

        // Notification emitted for donor usr-maria
        final mariaNotifs = store.getNotificationsForUser('usr-maria');
        expect(
          mariaNotifs.any(
            (n) =>
                n.publicacionId == 'pub-3' &&
                n.tipo == TipoNotificacion.nuevaPropuesta,
          ),
          isTrue,
        );

        // Close confirmation sheet -> detail reflects pending state
        await tapVisible(tester, find.byTooltip('Cerrar'));
        expect(
          find.text('Ya tienes una Solicitud pendiente para este artículo'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TC-CU23-02: flujo alterno 3a rechaza mensaje vacío y mensaje de 305 caracteres',
      (tester) async {
        final (store, _) = await pumpAppAtPublication(tester, 'pub-3');

        await tapVisible(
          tester,
          find.byKey(const Key('detail_request_item_button')),
        );
        expect(find.byType(RequestItemSheet), findsOneWidget);

        // (a) Empty message
        await tapVisible(
          tester,
          find.byKey(const Key('request_submit_button')),
        );
        expect(find.textContaining('máximo 300 caracteres'), findsWidgets);
        expect(store.proposals, isEmpty);

        // (b) 305 characters (must not be silently truncated before validation)
        final longMessage = 'A' * 305;
        await tester.enterText(
          find.byKey(const Key('request_message_field')),
          longMessage,
        );
        await tester.pumpAndSettle();
        expect(find.text('305 / 300 caracteres'), findsOneWidget);

        await tapVisible(
          tester,
          find.byKey(const Key('request_submit_button')),
        );
        expect(find.textContaining('máximo 300 caracteres'), findsWidgets);
        expect(store.proposals, isEmpty);

        // (c) 298 trimmed chars + 5 trailing spaces -> counter shows 298/300 and passes
        await tester.enterText(
          find.byKey(const Key('request_message_field')),
          '${'B' * 298}     ',
        );
        await tester.pumpAndSettle();
        expect(find.text('298 / 300 caracteres'), findsOneWidget);
        await tapVisible(
          tester,
          find.byKey(const Key('request_submit_button')),
        );
        expect(find.textContaining('Solicitud enviada'), findsWidgets);
        expect(store.proposals.length, 1);
      },
    );

    testWidgets(
      'TC-CU23-03: flujo alterno 2a impide enviar una segunda Solicitud pendiente sobre el mismo Artículo',
      (tester) async {
        final (store, container) = await pumpAppAtPublication(tester, 'pub-3');

        // Send first valid request through UI
        await tapVisible(
          tester,
          find.byKey(const Key('detail_request_item_button')),
        );
        await tester.enterText(
          find.byKey(const Key('request_message_field')),
          'Necesito la mesa para mi comedor familiar.',
        );
        await tester.pumpAndSettle();
        await tapVisible(
          tester,
          find.byKey(const Key('request_submit_button')),
        );
        await tapVisible(tester, find.byTooltip('Cerrar'));

        expect(store.proposals.length, 1);
        expect(
          find.text('Ya tienes una Solicitud pendiente para este artículo'),
          findsOneWidget,
        );

        // Detail button is disabled
        final detailButton = tester.widget<ButtonStyleButton>(
          find.widgetWithText(FilledButton, 'Solicitar artículo'),
        );
        expect(detailButton.enabled, isFalse);

        // Also verify controller / sheet rejects duplicate pending proposal directly
        final sub = container.listen(
          requestItemControllerProvider('pub-3'),
          (_, _) {},
        );
        addTearDown(sub.close);
        final ctrl = container.read(
          requestItemControllerProvider('pub-3').notifier,
        );
        final second = await ctrl.submit('Segundo intento de solicitud');
        expect(second, isNull);
        expect(
          container.read(requestItemControllerProvider('pub-3')).submissionError,
          contains('solicitud pendiente'),
        );
        expect(store.proposals.length, 1);
      },
    );

    testWidgets(
      'TC-CU23-04: flujo alterno 2b impide solicitar un Artículo que ya está Reservado o Cerrado',
      (tester) async {
        final (store, _) = await pumpAppAtPublication(tester, 'pub-hist-1');

        // pub-hist-1 is CERRADA and owned by usr-alondra; switch to usr-diego
        store.setActiveUser('usr-diego');
        await tester.pumpAndSettle();

        expect(
          find.text('Este artículo ya no está disponible'),
          findsOneWidget,
        );
        final detailButton = tester.widget<ButtonStyleButton>(
          find.widgetWithText(FilledButton, 'Solicitar artículo'),
        );
        expect(detailButton.enabled, isFalse);

        // Direct RequestItemSheet also blocks inactive article
        await tester.pumpWidget(const SizedBox.shrink());
        final freshStore = MockTenantStore()..setActiveUser('usr-diego');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockTenantStoreProvider.overrideWith((ref) => freshStore),
            ],
            child: const MaterialApp(
              home: Scaffold(body: RequestItemSheet(publicationId: 'pub-hist-1')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('ya no está activo'), findsOneWidget);
        final sheetButton = tester.widget<ButtonStyleButton>(
          find.byKey(const Key('request_submit_button')),
        );
        expect(sheetButton.enabled, isFalse);
        expect(freshStore.proposals, isEmpty);
      },
    );

    testWidgets(
      'TC-CU23-05: flujo alterno 5a ante pérdida de conexión (RNF-12) no guarda la Solicitud',
      (tester) async {
        final (store, _) = await pumpAppAtPublication(tester, 'pub-3');

        await tapVisible(
          tester,
          find.byKey(const Key('detail_request_item_button')),
        );
        await tester.enterText(
          find.byKey(const Key('request_message_field')),
          'Solicito la mesa para apoyar a una familia vecina.',
        );
        await tester.pumpAndSettle();

        store.setSimulateNetworkError(true);
        await tester.pumpAndSettle();

        await tapVisible(
          tester,
          find.byKey(const Key('request_submit_button')),
        );

        expect(
          find.textContaining(
            'No se pudo completar la operación por pérdida de conexión',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Solicitud enviada'), findsNothing);
        expect(store.proposals, isEmpty);

        // Recovering network allows retry without retyping
        store.setSimulateNetworkError(false);
        await tester.pumpAndSettle();
        await tapVisible(
          tester,
          find.byKey(const Key('request_submit_button')),
        );
        expect(find.textContaining('Solicitud enviada'), findsWidgets);
        expect(store.proposals.length, 1);
      },
    );
  });
}

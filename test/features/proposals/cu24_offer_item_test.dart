import 'package:donaciones/app/router.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/features/proposals/presentation/offer_item_controller.dart';
import 'package:donaciones/features/proposals/presentation/offer_item_sheet.dart';
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

  group('CU-24: Ofertar artículo', () {
    testWidgets(
      'TC-CU24-01: flujo principal completo registra Oferta PENDIENTE con foto, notifica al autor y muestra confirmación',
      (tester) async {
        final (store, _) = await pumpAppAtPublication(tester, 'pub-1');
        expect(find.byType(PublicationDetailScreen), findsOneWidget);

        await tapVisible(
          tester,
          find.byKey(const Key('detail_offer_item_button')),
        );
        expect(find.byType(OfferItemSheet), findsOneWidget);

        // Attach 1 sample photo
        await tapVisible(
          tester,
          find.byKey(const Key('offer_add_photo_button')),
        );
        expect(find.textContaining('1/5'), findsOneWidget);

        const desc =
            'Tengo una silla de ruedas plegable de aluminio en buen estado, con frenos funcionando.';
        await tester.enterText(
          find.byKey(const Key('offer_description_field')),
          desc,
        );
        await tester.pumpAndSettle();

        await tapVisible(
          tester,
          find.byKey(const Key('offer_submit_button')),
        );

        expect(find.textContaining('Oferta enviada'), findsWidgets);
        expect(store.proposals.length, 1);

        final created = store.proposals.first;
        expect(created.publicacionId, 'pub-1');
        expect(created.remitenteId, 'usr-alondra');
        expect(created.tipo, TipoPropuesta.oferta);
        expect(created.estado, EstadoPropuesta.pendiente);
        expect(created.texto, desc);
        expect(created.fotografias.length, 1);
        expect(created.claveCliente, isNotEmpty);

        // Notification emitted for pub-1 author (usr-maria)
        final mariaNotifs = store.getNotificationsForUser('usr-maria');
        expect(
          mariaNotifs.any(
            (n) =>
                n.publicacionId == 'pub-1' &&
                n.tipo == TipoNotificacion.nuevaPropuesta,
          ),
          isTrue,
        );

        await tapVisible(tester, find.byTooltip('Cerrar'));
        expect(
          find.text('Ya enviaste una Oferta pendiente para esta necesidad'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TC-CU24-02: flujo alterno 3a rechaza Oferta con descripción válida pero 0 fotografías',
      (tester) async {
        final (store, _) = await pumpAppAtPublication(tester, 'pub-1');

        await tapVisible(
          tester,
          find.byKey(const Key('detail_offer_item_button')),
        );
        await tester.enterText(
          find.byKey(const Key('offer_description_field')),
          'Silla plegable con llantas nuevas.',
        );
        await tester.pumpAndSettle();

        await tapVisible(
          tester,
          find.byKey(const Key('offer_submit_button')),
        );

        expect(
          find.textContaining('al menos una fotografía'),
          findsOneWidget,
        );
        expect(store.proposals, isEmpty);
      },
    );

    testWidgets(
      'TC-CU24-03: flujo alterno 3a rechaza Oferta con fotografía pero sin descripción (y permite agregar/quitar fotos)',
      (tester) async {
        final (store, _) = await pumpAppAtPublication(tester, 'pub-1');

        await tapVisible(
          tester,
          find.byKey(const Key('detail_offer_item_button')),
        );

        // Add 2 photos, then remove 1
        await tapVisible(
          tester,
          find.byKey(const Key('offer_add_photo_button')),
        );
        await tapVisible(
          tester,
          find.byKey(const Key('offer_add_photo_button')),
        );
        expect(find.textContaining('2/5'), findsOneWidget);

        await tapVisible(tester, find.byTooltip('Eliminar foto').first);
        expect(find.textContaining('1/5'), findsOneWidget);

        // Submit with empty description
        await tapVisible(
          tester,
          find.byKey(const Key('offer_submit_button')),
        );

        expect(
          find.text('La descripción del artículo ofrecido es obligatoria.'),
          findsOneWidget,
        );
        expect(store.proposals, isEmpty);
      },
    );

    testWidgets(
      'TC-CU24-04: flujo alterno 2a impide enviar una segunda Oferta pendiente sobre la misma Necesidad',
      (tester) async {
        final (store, container) = await pumpAppAtPublication(tester, 'pub-1');

        await tapVisible(
          tester,
          find.byKey(const Key('detail_offer_item_button')),
        );
        await tapVisible(
          tester,
          find.byKey(const Key('offer_add_photo_button')),
        );
        await tester.enterText(
          find.byKey(const Key('offer_description_field')),
          'Silla de ruedas plegable disponible hoy.',
        );
        await tester.pumpAndSettle();
        await tapVisible(
          tester,
          find.byKey(const Key('offer_submit_button')),
        );
        await tapVisible(tester, find.byTooltip('Cerrar'));

        expect(store.proposals.length, 1);
        expect(
          find.text('Ya enviaste una Oferta pendiente para esta necesidad'),
          findsOneWidget,
        );

        final detailButton = tester.widget<ButtonStyleButton>(
          find.widgetWithText(FilledButton, 'Ofrecer artículo'),
        );
        expect(detailButton.enabled, isFalse);

        final sub = container.listen(
          offerItemControllerProvider('pub-1'),
          (_, _) {},
        );
        addTearDown(sub.close);
        final ctrl = container.read(
          offerItemControllerProvider('pub-1').notifier,
        );
        ctrl.addNextSamplePhoto();
        final second = await ctrl.submit('Segunda oferta duplicada');
        expect(second, isNull);
        expect(
          container.read(offerItemControllerProvider('pub-1')).submissionError,
          contains('oferta pendiente'),
        );
        expect(store.proposals.length, 1);
      },
    );

    testWidgets(
      'TC-CU24-05: flujo alterno 2b impide ofertar en una Necesidad Reservada o Cerrada',
      (tester) async {
        final (store, _) = await pumpAppAtPublication(tester, 'pub-1');

        // Accept a proposal from usr-diego to transition pub-1 to RESERVADA
        final prop = await store.createOfferProposal(
          publicationId: 'pub-1',
          senderId: 'usr-diego',
          description: 'Silla de ruedas nueva',
          photos: ['sample://silla_ruedas.jpg'],
          clientKey: 'ck-reserve-pub1',
        );
        store.setActiveUser('usr-maria');
        await store.acceptProposal(proposalId: prop.id, clientKey: 'ck-acc-1');
        store.setActiveUser('usr-alondra');
        await tester.pumpAndSettle();

        expect(find.text('Esta necesidad ya no está activa'), findsOneWidget);
        final detailButton = tester.widget<ButtonStyleButton>(
          find.widgetWithText(FilledButton, 'Ofrecer artículo'),
        );
        expect(detailButton.enabled, isFalse);

        // Direct OfferItemSheet also blocks inactive need
        await tester.pumpWidget(const SizedBox.shrink());
        final freshStore = MockTenantStore();
        final freshProp = await freshStore.createOfferProposal(
          publicationId: 'pub-1',
          senderId: 'usr-diego',
          description: 'Silla de ruedas nueva',
          photos: ['sample://silla_ruedas.jpg'],
          clientKey: 'ck-reserve-pub1-fresh',
        );
        freshStore.setActiveUser('usr-maria');
        await freshStore.acceptProposal(
          proposalId: freshProp.id,
          clientKey: 'ck-acc-1-fresh',
        );
        freshStore.setActiveUser('usr-alondra');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mockTenantStoreProvider.overrideWith((ref) => freshStore),
            ],
            child: const MaterialApp(
              home: Scaffold(body: OfferItemSheet(publicationId: 'pub-1')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('ya no está activa'), findsOneWidget);
        final sheetButton = tester.widget<ButtonStyleButton>(
          find.byKey(const Key('offer_submit_button')),
        );
        final addPhotoButton = tester.widget<ButtonStyleButton>(
          find.byKey(const Key('offer_add_photo_button')),
        );
        final sourcePhotoButton = tester.widget<ButtonStyleButton>(
          find.byKey(const Key('offer_photo_source_button')),
        );
        expect(sheetButton.enabled, isFalse);
        expect(addPhotoButton.enabled, isFalse);
        expect(sourcePhotoButton.enabled, isFalse);
        expect(freshStore.proposals.length, 1);
      },
    );

    testWidgets(
      'TC-CU24-06: flujo alterno 5a ante pérdida de conexión (RNF-12) no guarda la Oferta',
      (tester) async {
        final (store, _) = await pumpAppAtPublication(tester, 'pub-1');

        await tapVisible(
          tester,
          find.byKey(const Key('detail_offer_item_button')),
        );
        await tapVisible(
          tester,
          find.byKey(const Key('offer_add_photo_button')),
        );
        await tester.enterText(
          find.byKey(const Key('offer_description_field')),
          'Silla de ruedas plegable casi nueva.',
        );
        await tester.pumpAndSettle();

        store.setSimulateNetworkError(true);
        await tester.pumpAndSettle();

        await tapVisible(
          tester,
          find.byKey(const Key('offer_submit_button')),
        );

        expect(
          find.textContaining(
            'No se pudo completar la operación por pérdida de conexión',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Oferta enviada'), findsNothing);
        expect(store.proposals, isEmpty);

        // Recover network and retry
        store.setSimulateNetworkError(false);
        await tester.pumpAndSettle();
        await tapVisible(
          tester,
          find.byKey(const Key('offer_submit_button')),
        );
        expect(find.textContaining('Oferta enviada'), findsWidgets);
        expect(store.proposals.length, 1);
      },
    );
  });
}

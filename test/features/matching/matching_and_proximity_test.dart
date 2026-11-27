import 'package:donaciones/app/router.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/core/models/dto_inputs.dart';
import 'package:donaciones/core/widgets/notifications_sheet.dart';
import 'package:donaciones/features/matching/presentation/matches_screen.dart';
import 'package:donaciones/features/proposals/presentation/offer_item_sheet.dart';
import 'package:donaciones/features/proposals/presentation/request_item_sheet.dart';
import 'package:donaciones/features/publications/presentation/edit_publication_sheet.dart';
import 'package:donaciones/features/publications/presentation/publication_detail_screen.dart';
import 'package:donaciones/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<(MockTenantStore, ProviderContainer)> pumpAppAtRoute(
    WidgetTester tester,
    String route,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DonaPlusApp()));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DonaPlusApp)),
    );
    final store = container.read(mockTenantStoreProvider);
    final router = container.read(appRouterProvider);
    router.go(route);
    await tester.pumpAndSettle();
    return (store, container);
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('CU-15 & CU-16: Edición y retiro de publicaciones activas', () {
    testWidgets(
      'CU-15: autor edita su Necesidad activa, maneja error de red y puede retirarla rechazando propuestas pendientes',
      (tester) async {
        final (store, container) = await pumpAppAtRoute(tester, '/');

        // Alondra sends a proposal on pub-1 (authored by usr-maria)
        final pendingProp = await store.createOfferProposal(
          publicationId: 'pub-1',
          senderId: 'usr-alondra',
          description: 'Silla plegable de aluminio',
          photos: ['sample://silla_ruedas.jpg'],
          clientKey: 'cu15-prop-1',
        );

        // Switch to author usr-maria and open pub-1 detail
        store.setActiveUser('usr-maria');
        container.read(appRouterProvider).go('/publications/pub-1');
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('detail_edit_publication_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('detail_withdraw_publication_button')),
          findsOneWidget,
        );

        // Open EditPublicationSheet and test RNF-12 network error
        await tapVisible(
          tester,
          find.byKey(const Key('detail_edit_publication_button')),
        );
        expect(find.byType(EditPublicationSheet), findsOneWidget);

        store.setSimulateNetworkError(true);
        await tester.enterText(
          find.byKey(const Key('edit_pub_title_field')),
          'Silla de ruedas reforzada',
        );
        await tapVisible(tester, find.byKey(const Key('edit_pub_save_button')));

        expect(
          find.textContaining(
            'No se pudo completar la operación por pérdida de conexión',
          ),
          findsOneWidget,
        );
        expect(
          store.findPublicationById('pub-1')?.titulo,
          'Silla de ruedas plegable',
        );

        // Recover network and save
        store.setSimulateNetworkError(false);
        await tapVisible(tester, find.byKey(const Key('edit_pub_save_button')));

        expect(
          store.findPublicationById('pub-1')?.titulo,
          'Silla de ruedas reforzada',
        );
        expect(find.text('Silla de ruedas reforzada'), findsOneWidget);

        // Let SnackBar dismiss before withdrawing
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        // Withdraw active Need
        await tapVisible(
          tester,
          find.byKey(const Key('detail_withdraw_publication_button')),
        );

        await tester.tap(find.text('Confirmar retiro'));
        await tester.pumpAndSettle();

        expect(
          store.findPublicationById('pub-1')?.estado,
          EstadoPublicacion.retirada,
        );
        expect(
          store.proposals.firstWhere((p) => p.id == pendingProp.id).estado,
          EstadoPropuesta.rechazada,
        );

        // Withdrawn publication no longer appears in FeedScreen
        container.read(appRouterProvider).go('/');
        await tester.pumpAndSettle();
        expect(find.text('Silla de ruedas reforzada'), findsNothing);
      },
    );

    testWidgets(
      'CU-16: autor edita su Artículo activo y publicación reservada/cerrada no muestra botones de editar ni retirar',
      (tester) async {
        final (store, container) = await pumpAppAtRoute(tester, '/');

        // usr-maria edits her active item pub-3
        store.setActiveUser('usr-maria');
        container.read(appRouterProvider).go('/publications/pub-3');
        await tester.pumpAndSettle();

        await tapVisible(
          tester,
          find.byKey(const Key('detail_edit_publication_button')),
        );

        await tester.enterText(
          find.byKey(const Key('edit_pub_title_field')),
          'Mesa de comedor de pino',
        );
        await tapVisible(tester, find.byKey(const Key('edit_pub_save_button')));

        expect(
          store.findPublicationById('pub-3')?.titulo,
          'Mesa de comedor de pino',
        );

        // Closed historical publication owned by usr-alondra cannot be edited or withdrawn (1a/1b)
        store.setActiveUser('usr-alondra');
        container.read(appRouterProvider).go('/publications/pub-hist-1');
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('detail_edit_publication_button')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('detail_withdraw_publication_button')),
          findsNothing,
        );
        expect(
          find.textContaining('no puede editarse ni retirarse'),
          findsOneWidget,
        );
      },
    );
  });

  group('CU-46 & CU-47: Publicar Necesidad por intermediario', () {
    testWidgets(
      'CU-46 & CU-47: usuario no intermediario no ve el switch; intermediario debe ingresar alias obligatorio y muestra insignia',
      (tester) async {
        final (store, container) = await pumpAppAtRoute(tester, '/create');
        await tapVisible(tester, find.byKey(const Key('create_mode_need')));

        // usr-alondra is not an intermediary
        expect(find.byKey(const Key('need_intermediary_switch')), findsNothing);

        // Switch to usr-maria (authorized intermediary)
        store.setActiveUser('usr-maria');
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('need_intermediary_switch')),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const Key('need_title_field')),
          'Pañales etapa 3',
        );
        await tester.enterText(
          find.byKey(const Key('need_description_field')),
          'Para bebé de comunidad rural',
        );
        await tapVisible(
          tester,
          find.byKey(const Key('need_category_dropdown')),
        );
        await tester.tap(find.text('Salud').last);
        await tester.pumpAndSettle();

        await tapVisible(tester, find.byKey(const Key('need_urgency_alta')));
        await tapVisible(
          tester,
          find.byKey(const Key('need_intermediary_switch')),
        );

        expect(
          find.textContaining('Solo alias, sin datos personales'),
          findsOneWidget,
        );

        // CU-47 2a: submit without alias is blocked
        await tapVisible(tester, find.byKey(const Key('need_submit_button')));

        expect(
          find.text('El alias del beneficiario es obligatorio.'),
          findsOneWidget,
        );

        // Fill alias and publish
        await tester.enterText(
          find.byKey(const Key('need_beneficiary_alias_field')),
          'Familia Gómez',
        );
        await tapVisible(tester, find.byKey(const Key('need_submit_button')));

        final created = store.publications.firstWhere(
          (p) => p.titulo == 'Pañales etapa 3',
        );
        expect(created.gestionadaPorIntermediario, isTrue);
        expect(created.aliasBeneficiario, 'Familia Gómez');

        // Feed and detail display intermediary badge + beneficiary alias
        container.read(appRouterProvider).go('/');
        await tester.pumpAndSettle();
        expect(find.text('Gestionada por intermediario'), findsWidgets);
        expect(find.textContaining('Familia Gómez'), findsWidgets);

        container.read(appRouterProvider).go('/publications/${created.id}');
        await tester.pumpAndSettle();
        expect(find.text('Gestionada por intermediario'), findsOneWidget);
        expect(find.textContaining('Familia Gómez'), findsOneWidget);
      },
    );
  });

  group(
    'CU-20, CU-21 & CU-22: Cercanía, permiso GPS y urgencia en FeedScreen',
    () {
      testWidgets(
        'CU-20 & CU-21: filtro de radio 5/10/25 km, ordenamiento por distancia y diálogo de permiso de ubicación',
        (tester) async {
          final (store, _) = await pumpAppAtRoute(tester, '/');

          // Publish a far item in Atlixco (28.2 km)
          await store.createItemPublication(
            const CreateItemInput(
              titulo: 'Estufa portátil',
              descripcion: 'Dos quemadores',
              categoriaId: 'cat-hogar',
              fotografias: ['sample://mesa_comedor.jpg'],
              cantidad: 1,
              condicion: CondicionArticulo.usado,
              ubicacionEtiqueta: 'Atlixco, CP 74200',
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Estufa portátil'), findsOneWidget);
          await tapVisible(tester, find.text('Filtros'));
          expect(
            find.textContaining('Usando la ubicación de tu perfil'),
            findsOneWidget,
          );

          // Tap Usar ubicación del dispositivo -> Denegar (CU-21 / RNF-08)
          await tapVisible(
            tester,
            find.byKey(const Key('feed_device_location_button')),
          );
          await tester.tap(find.text('Denegar'));
          await tester.pumpAndSettle();
          expect(store.isDeviceLocationAuthorized, isFalse);

          // Tap again -> Permitir
          await tapVisible(
            tester,
            find.byKey(const Key('feed_device_location_button')),
          );
          await tester.tap(find.text('Permitir'));
          await tester.pumpAndSettle();
          expect(store.isDeviceLocationAuthorized, isTrue);

          // Filter <= 5 km excludes Atlixco (28.2 km)
          await tapVisible(tester, find.byKey(const Key('feed_dist_5')));
          expect(find.text('Estufa portátil'), findsNothing);
          expect(find.text('Mesa de comedor para 4 personas'), findsOneWidget);

          // Filter <= 25 km also excludes Atlixco
          await tapVisible(tester, find.byKey(const Key('feed_dist_25')));
          expect(find.text('Estufa portátil'), findsNothing);

          // Any distance restores it, and Sort by distance puts Mesa before Estufa
          await tapVisible(tester, find.byKey(const Key('feed_dist_all')));
          await tapVisible(tester, find.byKey(const Key('feed_sort_distance')));

          expect(find.text('Estufa portátil'), findsOneWidget);
          final mesaY = tester
              .getTopLeft(find.text('Mesa de comedor para 4 personas'))
              .dy;
          final estufaY = tester.getTopLeft(find.text('Estufa portátil')).dy;
          expect(mesaY, lessThan(estufaY));
        },
      );

      testWidgets('CU-22: filtra y ordena Necesidades por nivel de urgencia', (
        tester,
      ) async {
        final (store, _) = await pumpAppAtRoute(tester, '/');

        // Add a low urgency need so we have Alta, Media, Baja
        await store.createNeedPublication(
          const CreateNeedInput(
            titulo: 'Cuadernos profesionales',
            descripcion: 'Para secundaria',
            categoriaId: 'cat-educacion',
            cantidadRequerida: 3,
            detallesCaracteristicas: 'Raya',
            urgencia: Urgencia.baja,
            ubicacionEtiqueta: 'Col. Centro, CP 72000',
          ),
        );
        await tester.pumpAndSettle();

        // Sort by urgency: Alta (pub-1) appears above Media (pub-2) and Baja
        await tapVisible(tester, find.text('Filtros'));
        await tapVisible(tester, find.byKey(const Key('feed_sort_urgency')));

        final altaY = tester
            .getTopLeft(find.text('Silla de ruedas plegable'))
            .dy;
        final mediaY = tester
            .getTopLeft(find.text('Libros escolares de primaria'))
            .dy;
        final bajaY = tester
            .getTopLeft(find.text('Cuadernos profesionales'))
            .dy;
        expect(altaY, lessThan(mediaY));
        expect(mediaY, lessThan(bajaY));

        // Filter only Urgencia Baja
        await tapVisible(tester, find.byKey(const Key('feed_urgency_baja')));

        expect(find.text('Cuadernos profesionales'), findsOneWidget);
        expect(find.text('Silla de ruedas plegable'), findsNothing);
        expect(find.text('Libros escolares de primaria'), findsNothing);
      });
    },
  );

  group('CU-17 & CU-18: Coincidencias y notificaciones internas', () {
    testWidgets(
      'CU-17 & CU-18: estado vacío sin coincidencias, cruce por urgencia/distancia, notificación interna y navegación al detalle',
      (tester) async {
        final (store, _) = await pumpAppAtRoute(tester, '/matches');
        expect(find.byType(MatchesScreen), findsOneWidget);

        // Initially usr-alondra has 0 active publications -> empty state
        expect(
          find.text('No tienes coincidencias activas en este momento'),
          findsOneWidget,
        );

        // Create two matching items for usr-alondra: cat-educacion (Media) and cat-salud (Alta)
        await store.createItemPublication(
          const CreateItemInput(
            titulo: 'Paquete libros primaria',
            descripcion: 'Libros 3ro y 4to grado',
            categoriaId: 'cat-educacion',
            fotografias: ['sample://libros_primaria.jpg'],
            cantidad: 5,
            condicion: CondicionArticulo.usado,
            ubicacionEtiqueta: 'Col. Centro, CP 72000',
          ),
        );
        await store.createItemPublication(
          const CreateItemInput(
            titulo: 'Silla de ruedas aluminio',
            descripcion: 'Plegable para adulto',
            categoriaId: 'cat-salud',
            fotografias: ['sample://silla_ruedas.jpg'],
            cantidad: 1,
            condicion: CondicionArticulo.usado,
            ubicacionEtiqueta: 'Col. Centro, CP 72000',
          ),
        );
        await tester.pumpAndSettle();

        // Matches appear ordered Alta before Media
        expect(find.textContaining('Silla de ruedas plegable'), findsWidgets);
        expect(
          find.textContaining('Libros escolares de primaria'),
          findsWidgets,
        );
        final sillaY = tester
            .getTopLeft(find.byKey(const Key('match_card_match-pub-6-pub-1')))
            .dy;
        final librosY = tester
            .getTopLeft(find.byKey(const Key('match_card_match-pub-5-pub-2')))
            .dy;
        expect(sillaY, lessThan(librosY));

        // CU-18 notifications visible in NotificationsSheet
        await tester.tap(find.byType(NotificationsBellButton));
        await tester.pumpAndSettle();
        expect(find.textContaining('Nueva coincidencia'), findsWidgets);
        await tester.tap(find.byTooltip('Cerrar'));
        await tester.pumpAndSettle();

        // Tap action button on Alta match -> navigates to PublicationDetailScreen for pub-1
        await tapVisible(
          tester,
          find.byKey(const Key('match_action_match-pub-6-pub-1')),
        );

        expect(find.byType(PublicationDetailScreen), findsOneWidget);
        expect(find.text('Silla de ruedas plegable'), findsOneWidget);

        // Verify OfferItemSheet stub opens cleanly
        await tapVisible(
          tester,
          find.byKey(const Key('detail_offer_item_button')),
        );
        expect(find.byType(OfferItemSheet), findsOneWidget);
        await tester.tap(find.byTooltip('Cerrar'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Detail opens RequestItemSheet stub for Artículo and passes RNF-03 390x844 1.25x high-contrast check',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final (_, container) = await pumpAppAtRoute(tester, '/');
        final router = container.read(appRouterProvider);

        await tester.tap(find.text('Accesibilidad'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ampliado (1.25x)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Alto contraste'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Cerrar'));
        await tester.pumpAndSettle();

        for (final route in [
          '/',
          '/matches',
          '/create',
          '/publications/pub-3',
        ]) {
          router.go(route);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        // Open RequestItemSheet stub on pub-3
        await tapVisible(
          tester,
          find.byKey(const Key('detail_request_item_button')),
        );
        expect(find.byType(RequestItemSheet), findsOneWidget);
      },
    );
  });
}

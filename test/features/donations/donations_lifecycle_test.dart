import 'package:donaciones/app/router.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/features/donations/presentation/donation_tracking_screen.dart';
import 'package:donaciones/features/donations/presentation/donation_ui_helpers.dart';
import 'package:donaciones/features/donations/presentation/donations_hub_screen.dart';
import 'package:donaciones/features/proposals/presentation/offer_item_sheet.dart';
import 'package:donaciones/features/proposals/presentation/request_item_sheet.dart';
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
    container.read(appRouterProvider).go(route);
    await tester.pumpAndSettle();
    return (store, container);
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Mis publicaciones muestra las propias y abre su detalle', (
    tester,
  ) async {
    await pumpAppAtRoute(tester, '/donations');
    await tapVisible(
      tester,
      find.byKey(const Key('donations_tab_my_publications')),
    );

    expect(find.byKey(const Key('my_publication_pub-hist-1')), findsOneWidget);
    expect(find.byKey(const Key('my_publication_pub-3')), findsNothing);
    expect(find.text('Quiero donar · Cerrada'), findsWidgets);

    await tapVisible(
      tester,
      find.byKey(const Key('my_publication_pub-hist-1')),
    );
    final detail = tester.widget<PublicationDetailScreen>(
      find.byType(PublicationDetailScreen),
    );
    expect(detail.publicationId, 'pub-hist-1');
  });

  group('CU-25 a CU-29: Propuestas enviadas, recibidas, retiro, aceptación y rechazo', () {
    testWidgets(
      'CU-25 & CU-29: remitente retira propuesta enviada y autor rechaza propuesta con motivo opcional',
      (tester) async {
        final (store, container) = await pumpAppAtRoute(tester, '/donations');
        expect(find.byType(DonationsHubScreen), findsOneWidget);

        final alondraProp = await store.createRequestProposal(
          publicationId: 'pub-3',
          senderId: 'usr-alondra',
          message: 'Necesitamos la mesa para comedor comunitario.',
          clientKey: 'ck-cu25-1',
        );
        final diegoProp = await store.createRequestProposal(
          publicationId: 'pub-3',
          senderId: 'usr-diego',
          message: 'Puedo recogerla mañana por la tarde.',
          clientKey: 'ck-cu29-1',
        );
        await tester.pumpAndSettle();

        // Alondra sees her sent proposal in Enviadas and tests RNF-12 before withdrawing
        expect(find.text('Pendiente'), findsOneWidget);
        store.setSimulateNetworkError(true);
        await tapVisible(
          tester,
          find.byKey(Key('withdraw_proposal_${alondraProp.id}')),
        );
        expect(find.textContaining('pérdida de conexión'), findsOneWidget);
        expect(
          store.proposals.firstWhere((p) => p.id == alondraProp.id).estado,
          EstadoPropuesta.pendiente,
        );

        store.setSimulateNetworkError(false);
        await tapVisible(
          tester,
          find.byKey(Key('withdraw_proposal_${alondraProp.id}')),
        );
        expect(
          store.proposals.firstWhere((p) => p.id == alondraProp.id).estado,
          EstadoPropuesta.retirada,
        );
        expect(find.text('Retirada'), findsOneWidget);

        // Switch to pub-3 author (usr-maria) and inspect from PublicationDetailScreen (CU-26)
        store.setActiveUser('usr-maria');
        container.read(appRouterProvider).go('/publications/pub-3');
        await tester.pumpAndSettle();

        expect(find.text('Diego Ramírez Soto'), findsOneWidget);
        expect(find.textContaining('En progreso'), findsWidgets);

        // Reject Diego's proposal with reason (CU-29)
        await tapVisible(
          tester,
          find.byKey(Key('reject_proposal_${diegoProp.id}')),
        );
        await tester.enterText(
          find.byKey(const Key('reject_proposal_reason_field')),
          'Ya acordamos entrega con otro vecino.',
        );
        await tapVisible(
          tester,
          find.byKey(const Key('confirm_reject_proposal_button')),
        );

        final rejected = store.proposals.firstWhere(
          (p) => p.id == diegoProp.id,
        );
        expect(rejected.estado, EstadoPropuesta.rechazada);
        expect(rejected.motivoRechazo, 'Ya acordamos entrega con otro vecino.');
        expect(
          store.findPublicationById('pub-3')?.estado,
          EstadoPublicacion.activa,
        );
      },
    );
  });

  group('CU-26 a CU-37: Ciclo completo de donación, chat, privacidad de teléfono, reloj y reseñas', () {
    testWidgets(
      'Ciclo E2E en UI: aceptar propuesta, chatear y compartir teléfono, programar entrega, entregar, confirmar, historial y reseña',
      (tester) async {
        final (store, _) = await pumpAppAtRoute(tester, '/donations');

        final propAlondra = await store.createRequestProposal(
          publicationId: 'pub-3',
          senderId: 'usr-alondra',
          message: 'La mesa nos ayuda muchísimo para nuestra familia.',
          clientKey: 'ck-e2e-alondra',
        );
        final propDiego = await store.createRequestProposal(
          publicationId: 'pub-3',
          senderId: 'usr-diego',
          message: 'También me interesa la mesa.',
          clientKey: 'ck-e2e-diego',
        );

        // Author usr-maria opens /donations -> sees Trust Profile + metrics and accepts Alondra
        store.setActiveUser('usr-maria');
        await tester.pumpAndSettle();

        expect(find.text('Guadalupe Alondra Gutiérrez Paz'), findsOneWidget);
        expect(find.text('Perfil de Confianza'), findsOneWidget);

        await tapVisible(
          tester,
          find.byKey(Key('accept_proposal_${propAlondra.id}')),
        );

        expect(store.donations.length, 2); // seed + new
        final donation = store.donations.last;
        expect(donation.publicacionId, 'pub-3');
        expect(donation.donanteId, 'usr-maria');
        expect(donation.donatarioId, 'usr-alondra');
        expect(donation.estado, EstadoDonacion.aceptada);
        expect(
          store.findPublicationById('pub-3')?.estado,
          EstadoPublicacion.reservada,
        );
        expect(
          store.proposals.firstWhere((p) => p.id == propDiego.id).estado,
          EstadoPropuesta.rechazada,
        );

        // Navigate to DonationTrackingScreen via En curso tab
        await tapVisible(tester, find.byKey(const Key('donations_tab_active')));
        expect(find.text('Mesa de comedor para 4 personas'), findsOneWidget);
        await tapVisible(
          tester,
          find.byKey(Key('open_donation_${donation.id}')),
        );
        expect(find.byType(DonationTrackingScreen), findsOneWidget);

        // CU-31 & RNF-09: counterpart phone hidden by default
        expect(
          find.text('Teléfono oculto por privacidad (RNF-09)'),
          findsOneWidget,
        );
        expect(find.textContaining('******6543'), findsOneWidget);
        expect(find.textContaining('2229876543'), findsNothing);

        // Maria sends chat message and toggles phone sharing on
        await tester.enterText(
          find.byKey(const Key('chat_message_field')),
          'Hola Alondra, ¿en qué punto te queda bien entregarla?',
        );
        await tapVisible(tester, find.byKey(const Key('chat_send_button')));
        expect(
          find.text('Hola Alondra, ¿en qué punto te queda bien entregarla?'),
          findsOneWidget,
        );

        await tapVisible(tester, find.byKey(const Key('share_phone_switch')));
        expect(
          store.findDonationById(donation.id)?.telefonoDonanteCompartido,
          isTrue,
        );
        expect(find.textContaining('******6543'), findsOneWidget);
        expect(find.textContaining('2229876543'), findsNothing);

        // Switch to recipient usr-alondra -> sees Maria's phone and replies
        store.setActiveUser('usr-alondra');
        await tester.pumpAndSettle();

        expect(find.textContaining('2229876543'), findsOneWidget);
        expect(find.textContaining('******4457'), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('chat_message_field')),
          'En el Parque del Carmen a las 5pm.',
        );
        await tapVisible(tester, find.byKey(const Key('chat_send_button')));
        expect(find.text('En el Parque del Carmen a las 5pm.'), findsOneWidget);

        // CU-32: validate empty delivery place, then register valid place and date
        await tapVisible(
          tester,
          find.byKey(const Key('register_delivery_schedule_button')),
        );
        expect(
          find.text('El lugar de entrega es obligatorio.'),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const Key('delivery_place_field')),
          'Parque del Carmen, Puebla',
        );
        await tapVisible(
          tester,
          find.byKey(const Key('register_delivery_schedule_button')),
        );

        expect(
          store.findDonationById(donation.id)?.estado,
          EstadoDonacion.enEntrega,
        );
        expect(find.textContaining('Parque del Carmen, Puebla'), findsWidgets);

        // CU-33: switch to donor usr-maria and mark delivered
        store.setActiveUser('usr-maria');
        await tester.pumpAndSettle();
        await tapVisible(
          tester,
          find.byKey(const Key('mark_delivered_button')),
        );

        expect(
          store.findDonationById(donation.id)?.estado,
          EstadoDonacion.entregada,
        );
        // CU-31 1a: chat disabled once ENTREGADA
        expect(
          find.text('El chat ya no está disponible para esta donación'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('chat_send_button')), findsNothing);

        // CU-34: switch to recipient usr-alondra and confirm receipt
        store.setActiveUser('usr-alondra');
        await tester.pumpAndSettle();
        await tapVisible(
          tester,
          find.byKey(const Key('confirm_received_button')),
        );

        expect(
          store.findDonationById(donation.id)?.estado,
          EstadoDonacion.finalizada,
        );
        expect(
          store.findPublicationById('pub-3')?.estado,
          EstadoPublicacion.cerrada,
        );

        // CU-35: chronological change history shows all 4 transitions
        expect(find.textContaining('Inicio → Aceptada'), findsOneWidget);
        expect(find.textContaining('Aceptada → En entrega'), findsOneWidget);
        expect(find.textContaining('En entrega → Entregada'), findsOneWidget);
        expect(find.textContaining('Entregada → Finalizada'), findsOneWidget);

        // CU-37: review validation (0 stars, >500 chars) then valid 5-star review
        await tapVisible(tester, find.byKey(const Key('submit_review_button')));
        expect(
          find.text('La calificación debe estar entre 1 y 5 estrellas.'),
          findsOneWidget,
        );

        await tapVisible(tester, find.byKey(const Key('review_star_5')));
        await tester.enterText(
          find.byKey(const Key('review_comment_field')),
          'X' * 505,
        );
        await tapVisible(tester, find.byKey(const Key('submit_review_button')));
        expect(
          find.text('El comentario no puede superar los 500 caracteres.'),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const Key('review_comment_field')),
          'Excelente coordinación, mesa en muy buen estado.',
        );
        await tapVisible(tester, find.byKey(const Key('submit_review_button')));

        expect(
          find.text('Ya enviaste tu reseña para esta donación'),
          findsOneWidget,
        );
        expect(store.getReviewsForUser('usr-maria').length, 2);
      },
    );

    testWidgets(
      'CU-34 2a & CU-37 1b: reloj simulado +7d finaliza donación automáticamente como Sistema y +15d vence plazo de reseña',
      (tester) async {
        final (store, container) = await pumpAppAtRoute(tester, '/');

        final prop = await store.createOfferProposal(
          publicationId: 'pub-1',
          senderId: 'usr-alondra',
          description: 'Silla de ruedas aluminio',
          photos: ['sample://silla_ruedas.jpg'],
          clientKey: 'ck-auto-1',
        );
        store.setActiveUser('usr-maria');
        final don = await store.acceptProposal(
          proposalId: prop.id,
          clientKey: 'ck-auto-acc',
        );
        store.setActiveUser('usr-alondra');
        await store.registerDeliverySchedule(
          donationId: don.id,
          place: 'Zócalo',
          scheduledDate: store.currentTime.add(const Duration(days: 1)),
          clientKey: 'ck-auto-sched',
        );
        await store.markDonationDelivered(
          donationId: don.id,
          clientKey: 'ck-auto-deliv',
        );

        container.read(appRouterProvider).go('/donations/${don.id}');
        await tester.pumpAndSettle();

        // Advance +7d via DemoTenantToolbar -> automatic System finalization
        await tester.tap(find.text('+7d'));
        await tester.pumpAndSettle();

        expect(
          store.findDonationById(don.id)?.estado,
          EstadoDonacion.finalizada,
        );
        expect(find.textContaining('Sistema'), findsWidgets);
        expect(find.byKey(const Key('submit_review_button')), findsOneWidget);

        // Advance +15d -> 14-day review window expires
        await tester.tap(find.text('+15d'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'El plazo de 14 días para reseñar esta donación ha vencido',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('submit_review_button')), findsNothing);
      },
    );
  });

  group('CU-36, CU-38 & CU-39: Cancelación e Historial filtrable', () {
    testWidgets(
      'CU-36, CU-38 & CU-39: cancelar donación exige motivo, reactiva publicación y filtra historial por papel y estado',
      (tester) async {
        final (store, container) = await pumpAppAtRoute(tester, '/');

        final prop = await store.createRequestProposal(
          publicationId: 'pub-4',
          senderId: 'usr-alondra',
          message: 'Me interesa la chaqueta de invierno.',
          clientKey: 'ck-cancel-ui-1',
        );
        store.setActiveUser('usr-diego');
        final don = await store.acceptProposal(
          proposalId: prop.id,
          clientKey: 'ck-cancel-ui-acc',
        );

        container.read(appRouterProvider).go('/donations/${don.id}');
        await tester.pumpAndSettle();

        // Attempt cancel without reason -> blocked (CU-36 3a)
        await tapVisible(
          tester,
          find.byKey(const Key('cancel_donation_button')),
        );
        await tapVisible(
          tester,
          find.byKey(const Key('confirm_cancel_donation_button')),
        );
        expect(
          find.text('Debes indicar el motivo de la cancelación.'),
          findsOneWidget,
        );
        expect(store.findDonationById(don.id)?.estado, EstadoDonacion.aceptada);

        // Provide mandatory reason and confirm
        await tester.enterText(
          find.byKey(const Key('cancel_donation_reason_field')),
          'No podremos coincidir esta semana.',
        );
        await tapVisible(
          tester,
          find.byKey(const Key('confirm_cancel_donation_button')),
        );

        expect(
          store.findDonationById(don.id)?.estado,
          EstadoDonacion.cancelada,
        );
        expect(
          store.findPublicationById('pub-4')?.estado,
          EstadoPublicacion.activa,
        );
        expect(
          find.textContaining('No podremos coincidir esta semana.'),
          findsWidgets,
        );

        // Open DonationsHubScreen -> Historial tab as usr-alondra
        // usr-alondra has don-hist-1 (Finalizada, Como donante) and don (Cancelada, Como donatario)
        store.setActiveUser('usr-alondra');
        container.read(appRouterProvider).go('/donations');
        await tester.pumpAndSettle();

        await tapVisible(
          tester,
          find.byKey(const Key('donations_tab_history')),
        );

        expect(find.text('Mochila escolar reforzada'), findsOneWidget);
        expect(find.text('Chaqueta de invierno talla M'), findsOneWidget);

        // Filter by role: Como donatario -> only Chaqueta
        await tapVisible(
          tester,
          find.byKey(const Key('history_role_donatario')),
        );
        expect(find.text('Chaqueta de invierno talla M'), findsOneWidget);
        expect(find.text('Mochila escolar reforzada'), findsNothing);

        // Filter by state: Finalizadas -> empty combination
        await tapVisible(
          tester,
          find.byKey(const Key('history_state_finalizada')),
        );
        expect(find.text('Chaqueta de invierno talla M'), findsNothing);

        // Clear filters restores both, and tapping card opens DonationTrackingScreen
        await tapVisible(
          tester,
          find.byKey(const Key('history_clear_filters_button')),
        );
        expect(find.text('Mochila escolar reforzada'), findsOneWidget);
        expect(find.text('Chaqueta de invierno talla M'), findsOneWidget);

        await tapVisible(
          tester,
          find.byKey(const Key('history_donation_don-hist-1')),
        );
        expect(find.byType(DonationTrackingScreen), findsOneWidget);
      },
    );

    testWidgets(
      'RNF-03: pantallas de propuestas y donaciones sin desbordamiento en 390x844 a 1.25x y alto contraste',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final (store, container) = await pumpAppAtRoute(tester, '/');
        final router = container.read(appRouterProvider);

        // Create an active donation + a pending proposal so all sections render
        final propPending = await store.createRequestProposal(
          publicationId: 'pub-3',
          senderId: 'usr-alondra',
          message: 'Propuesta para probar vista móvil accesible.',
          clientKey: 'ck-rnf03-1',
        );
        final propForActive = await store.createOfferProposal(
          publicationId: 'pub-1',
          senderId: 'usr-alondra',
          description: 'Silla de ruedas plegable en buen estado.',
          photos: ['sample://silla_ruedas.jpg'],
          clientKey: 'ck-rnf03-2',
        );
        store.setActiveUser('usr-maria');
        final activeDon = await store.acceptProposal(
          proposalId: propForActive.id,
          clientKey: 'ck-rnf03-acc',
        );
        expect(propPending.estado, EstadoPropuesta.pendiente);

        await tester.tap(find.text('Accesibilidad'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ampliado (1.25x)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Alto contraste'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Cerrar'));
        await tester.pumpAndSettle();

        // DonationsHubScreen tabs
        router.go('/donations');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tapVisible(tester, find.byKey(const Key('donations_tab_active')));
        expect(tester.takeException(), isNull);

        await tapVisible(
          tester,
          find.byKey(const Key('donations_tab_history')),
        );
        expect(tester.takeException(), isNull);

        // DonationTrackingScreen (active & finalized)
        router.go('/donations/${activeDon.id}');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        store.setActiveUser('usr-alondra');
        router.go('/donations/don-hist-1');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // RequestItemSheet & OfferItemSheet at 390x844 1.25x high contrast
        router.go('/publications/pub-4');
        await tester.pumpAndSettle();
        await tapVisible(
          tester,
          find.byKey(const Key('detail_request_item_button')),
        );
        expect(find.byType(RequestItemSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tapVisible(tester, find.byTooltip('Cerrar'));

        router.go('/publications/pub-2');
        await tester.pumpAndSettle();
        await tapVisible(
          tester,
          find.byKey(const Key('detail_offer_item_button')),
        );
        expect(find.byType(OfferItemSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group(
    'Fix Round 1 Regressions: stale banner & RNF-11 retry clientKey reuse',
    () {
      testWidgets(
        'ocultar banner de Propuesta aceptada al cancelar la donación y regresar desde Tracking',
        (tester) async {
          final (store, container) = await pumpAppAtRoute(tester, '/donations');

          // Scenario A: DonationsHubScreen
          final prop1 = await store.createRequestProposal(
            publicationId: 'pub-3',
            senderId: 'usr-alondra',
            message: 'Solicitud para probar cancelación desde seguimiento.',
            clientKey: 'ck-fix1-hub',
          );
          store.setActiveUser('usr-maria');
          await tester.pumpAndSettle();

          await tapVisible(
            tester,
            find.byKey(Key('accept_proposal_${prop1.id}')),
          );
          expect(find.textContaining('¡Propuesta aceptada!'), findsOneWidget);

          await tapVisible(
            tester,
            find.byKey(const Key('accepted_donation_track_button')),
          );
          expect(find.byType(DonationTrackingScreen), findsOneWidget);

          await tapVisible(
            tester,
            find.byKey(const Key('cancel_donation_button')),
          );
          await tester.enterText(
            find.byKey(const Key('cancel_donation_reason_field')),
            'Cancelada por cambio de disponibilidad.',
          );
          await tapVisible(
            tester,
            find.byKey(const Key('confirm_cancel_donation_button')),
          );
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();

          await tapVisible(tester, find.byTooltip('Volver'));
          expect(find.byType(DonationsHubScreen), findsOneWidget);
          expect(find.textContaining('¡Propuesta aceptada!'), findsNothing);

          // Scenario B: PublicationDetailScreen
          final prop2 = await store.createRequestProposal(
            publicationId: 'pub-4',
            senderId: 'usr-alondra',
            message: 'Solicitud para pub-4.',
            clientKey: 'ck-fix1-detail',
          );
          store.setActiveUser('usr-diego');
          container.read(appRouterProvider).go('/publications/pub-4');
          await tester.pumpAndSettle();

          await tapVisible(
            tester,
            find.byKey(Key('accept_proposal_${prop2.id}')),
          );
          expect(find.textContaining('¡Propuesta aceptada!'), findsOneWidget);

          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          await tapVisible(tester, find.text('Ver seguimiento de donación'));
          expect(find.byType(DonationTrackingScreen), findsOneWidget);

          await tapVisible(
            tester,
            find.byKey(const Key('cancel_donation_button')),
          );
          await tester.enterText(
            find.byKey(const Key('cancel_donation_reason_field')),
            'Cancelada desde detalle.',
          );
          await tapVisible(
            tester,
            find.byKey(const Key('confirm_cancel_donation_button')),
          );
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();

          await tapVisible(tester, find.byTooltip('Volver'));
          expect(find.textContaining('¡Propuesta aceptada!'), findsNothing);
          expect(
            store.findPublicationById('pub-4')?.estado,
            EstadoPublicacion.activa,
          );
        },
      );

      testWidgets(
        'RNF-11: reintento tras NetworkException reutiliza el mismo clientKey en aceptación y ciclo de donación',
        (tester) async {
          final spyStore = _SpyClientKeyStore();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                mockTenantStoreProvider.overrideWith((ref) => spyStore),
              ],
              child: const DonaPlusApp(),
            ),
          );
          await tester.pumpAndSettle();

          final container = ProviderScope.containerOf(
            tester.element(find.byType(DonaPlusApp)),
          );
          final router = container.read(appRouterProvider);

          // 1. DonationsHubScreen._acceptProposal retries with same clientKey
          final propHub = await spyStore.createRequestProposal(
            publicationId: 'pub-3',
            senderId: 'usr-alondra',
            message: 'Propuesta hub idempotente.',
            clientKey: 'ck-spy-hub',
          );
          spyStore.setActiveUser('usr-maria');
          router.go('/donations');
          await tester.pumpAndSettle();

          spyStore.setSimulateNetworkError(true);
          await tapVisible(
            tester,
            find.byKey(Key('accept_proposal_${propHub.id}')),
          );
          expect(find.textContaining('pérdida de conexión'), findsOneWidget);

          spyStore.setSimulateNetworkError(false);
          await tapVisible(
            tester,
            find.byKey(Key('accept_proposal_${propHub.id}')),
          );
          final hubAcceptKeys = spyStore.keysFor('accept');
          expect(hubAcceptKeys.length, 2);
          expect(hubAcceptKeys[1], hubAcceptKeys[0]);

          final don1 = spyStore.donations.last;

          // 2. PublicationDetailScreen._acceptProposal retries with same clientKey
          final propDetail = await spyStore.createRequestProposal(
            publicationId: 'pub-4',
            senderId: 'usr-alondra',
            message: 'Propuesta detail idempotente.',
            clientKey: 'ck-spy-detail',
          );
          spyStore.setActiveUser('usr-diego');
          router.go('/publications/pub-4');
          await tester.pumpAndSettle();

          spyStore.setSimulateNetworkError(true);
          await tapVisible(
            tester,
            find.byKey(Key('accept_proposal_${propDetail.id}')),
          );
          expect(find.textContaining('pérdida de conexión'), findsOneWidget);

          spyStore.setSimulateNetworkError(false);
          await tapVisible(
            tester,
            find.byKey(Key('accept_proposal_${propDetail.id}')),
          );
          final allAcceptKeys = spyStore.keysFor('accept');
          expect(allAcceptKeys.length, 4);
          expect(allAcceptKeys[3], allAcceptKeys[2]);
          expect(allAcceptKeys[2], isNot(allAcceptKeys[0]));

          final don2 = spyStore.donations.last;

          // 3. DonationTrackingScreen: schedule, deliver, confirm retain key on retry
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          spyStore.setActiveUser('usr-maria');
          router.go('/donations/${don1.id}');
          await tester.pumpAndSettle();

          await tester.enterText(
            find.byKey(const Key('delivery_place_field')),
            'Parque del Carmen',
          );
          spyStore.setSimulateNetworkError(true);
          await tapVisible(
            tester,
            find.byKey(const Key('register_delivery_schedule_button')),
          );
          spyStore.setSimulateNetworkError(false);
          await tapVisible(
            tester,
            find.byKey(const Key('register_delivery_schedule_button')),
          );
          final schedKeys = spyStore.keysFor('schedule');
          expect(schedKeys.length, 2);
          expect(schedKeys[1], schedKeys[0]);

          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          spyStore.setSimulateNetworkError(true);
          await tapVisible(
            tester,
            find.byKey(const Key('mark_delivered_button')),
          );
          spyStore.setSimulateNetworkError(false);
          await tapVisible(
            tester,
            find.byKey(const Key('mark_delivered_button')),
          );
          final delivKeys = spyStore.keysFor('deliver');
          expect(delivKeys.length, 2);
          expect(delivKeys[1], delivKeys[0]);

          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          spyStore.setActiveUser('usr-alondra');
          await tester.pumpAndSettle();
          spyStore.setSimulateNetworkError(true);
          await tapVisible(
            tester,
            find.byKey(const Key('confirm_received_button')),
          );
          spyStore.setSimulateNetworkError(false);
          await tapVisible(
            tester,
            find.byKey(const Key('confirm_received_button')),
          );
          final confKeys = spyStore.keysFor('confirm');
          expect(confKeys.length, 2);
          expect(confKeys[1], confKeys[0]);

          // 4. DonationTrackingScreen: cancelDonation retains key across retry
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          router.go('/donations/${don2.id}');
          await tester.pumpAndSettle();

          await tapVisible(
            tester,
            find.byKey(const Key('cancel_donation_button')),
          );
          await tester.enterText(
            find.byKey(const Key('cancel_donation_reason_field')),
            'No disponible.',
          );
          spyStore.setSimulateNetworkError(true);
          await tapVisible(
            tester,
            find.byKey(const Key('confirm_cancel_donation_button')),
          );
          expect(find.textContaining('pérdida de conexión'), findsOneWidget);

          spyStore.setSimulateNetworkError(false);
          await tapVisible(
            tester,
            find.byKey(const Key('confirm_cancel_donation_button')),
          );
          final cancelKeys = spyStore.keysFor('cancel');
          expect(cancelKeys.length, 2);
          expect(cancelKeys[1], cancelKeys[0]);
        },
      );
    },
  );

  group('Final Review Fixes: date picker clock clamp, chat/review RNF-12 & route ID isolation', () {
    testWidgets(
      'selector de fecha tras +7d no falla assertion, resetea fecha pasada y chat/reseña manejan NetworkException',
      (tester) async {
        final (store, container) = await pumpAppAtRoute(tester, '/');

        final prop = await store.createRequestProposal(
          publicationId: 'pub-3',
          senderId: 'usr-alondra',
          message: 'Solicitud para probar date picker tras avanzar reloj.',
          clientKey: 'ck-dp-1',
        );
        store.setActiveUser('usr-maria');
        final don = await store.acceptProposal(
          proposalId: prop.id,
          clientKey: 'ck-dp-acc',
        );

        container.read(appRouterProvider).go('/donations/${don.id}');
        await tester.pumpAndSettle();

        // Pick "En 3 días" before advancing simulated clock
        await tapVisible(tester, find.text('En 3 días'));
        final staleDate = store.currentTime.add(const Duration(days: 3));
        expect(
          find.text('Fecha acordada: ${formatDonationDate(staleDate)}'),
          findsOneWidget,
        );

        // Advance clock by +7d via DemoTenantToolbar -> staleDate is now 4 days in the past!
        await tester.tap(find.text('+7d'));
        await tester.pumpAndSettle();

        final clampedFallback = store.currentTime.add(const Duration(days: 1));
        expect(
          find.text('Fecha acordada: ${formatDonationDate(clampedFallback)}'),
          findsOneWidget,
        );

        // Opening showDatePicker must not throw AssertionError (initialDate >= firstDate)
        await tapVisible(
          tester,
          find.byKey(const Key('delivery_date_picker_button')),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(DatePickerDialog), findsOneWidget);

        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Chat NetworkException (RNF-12) keeps typed text and allows retry
        await tester.enterText(
          find.byKey(const Key('chat_message_field')),
          'Nos vemos mañana en la entrada principal.',
        );
        store.setSimulateNetworkError(true);
        await tapVisible(tester, find.byKey(const Key('chat_send_button')));
        expect(
          find.textContaining(
            'No se pudo completar la operación por pérdida de conexión',
          ),
          findsOneWidget,
        );
        expect(store.findDonationById(don.id)?.mensajes, isEmpty);
        final chatField = tester.widget<TextField>(
          find.byKey(const Key('chat_message_field')),
        );
        expect(
          chatField.controller?.text,
          'Nos vemos mañana en la entrada principal.',
        );

        store.setSimulateNetworkError(false);
        await tapVisible(tester, find.byKey(const Key('chat_send_button')));
        expect(store.findDonationById(don.id)?.mensajes.length, 1);

        // Schedule, mark delivered, and confirm receipt so review card appears
        await tester.enterText(
          find.byKey(const Key('delivery_place_field')),
          'Entrada Parque Juárez',
        );
        await tapVisible(
          tester,
          find.byKey(const Key('register_delivery_schedule_button')),
        );
        final scheduled = store.findDonationById(don.id)!;
        expect(scheduled.estado, EstadoDonacion.enEntrega);
        expect(
          scheduled.fechaEntregaAcordada!.isAfter(
            store.currentTime.subtract(const Duration(days: 1)),
          ),
          isTrue,
        );

        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tapVisible(
          tester,
          find.byKey(const Key('mark_delivered_button')),
        );

        store.setActiveUser('usr-alondra');
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tapVisible(
          tester,
          find.byKey(const Key('confirm_received_button')),
        );
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        // Trimmed review comment counter: 498 chars + 5 trailing spaces -> 498 / 500 (valid!)
        await tapVisible(tester, find.byKey(const Key('review_star_5')));
        await tester.enterText(
          find.byKey(const Key('review_comment_field')),
          '${'A' * 498}     ',
        );
        await tester.pumpAndSettle();
        expect(find.text('498 / 500 caracteres'), findsOneWidget);

        // Review NetworkException (RNF-12) preserves state and retries cleanly
        store.setSimulateNetworkError(true);
        await tapVisible(tester, find.byKey(const Key('submit_review_button')));
        expect(
          find.textContaining(
            'No se pudo completar la operación por pérdida de conexión',
          ),
          findsOneWidget,
        );
        expect(store.reviews.where((r) => r.donacionId == don.id), isEmpty);

        store.setSimulateNetworkError(false);
        await tapVisible(tester, find.byKey(const Key('submit_review_button')));
        expect(
          find.text('Ya enviaste tu reseña para esta donación'),
          findsOneWidget,
        );
        expect(store.reviews.where((r) => r.donacionId == don.id).length, 1);
      },
    );

    testWidgets(
      'navegación directa entre IDs en /publications/:id y /donations/:id no arrastra estado previo',
      (tester) async {
        final (store, container) = await pumpAppAtRoute(tester, '/');
        final router = container.read(appRouterProvider);

        // Create two active donations for usr-alondra
        final propA = await store.createRequestProposal(
          publicationId: 'pub-3',
          senderId: 'usr-alondra',
          message: 'Propuesta A',
          clientKey: 'ck-nav-a',
        );
        store.setActiveUser('usr-maria');
        final donA = await store.acceptProposal(
          proposalId: propA.id,
          clientKey: 'ck-nav-acc-a',
        );

        final propB = await store.createRequestProposal(
          publicationId: 'pub-4',
          senderId: 'usr-alondra',
          message: 'Propuesta B',
          clientKey: 'ck-nav-b',
        );
        store.setActiveUser('usr-diego');
        final donB = await store.acceptProposal(
          proposalId: propB.id,
          clientKey: 'ck-nav-acc-b',
        );

        store.setActiveUser('usr-alondra');
        router.go('/donations/${donA.id}');
        await tester.pumpAndSettle();

        // Populate place field and trigger validation error on donA
        await tester.enterText(
          find.byKey(const Key('delivery_place_field')),
          'Lugar Donación A',
        );
        await tester.pumpAndSettle();
        await tapVisible(tester, find.byKey(const Key('chat_send_button')));
        expect(find.text('El mensaje no puede estar vacío.'), findsOneWidget);

        // Navigate directly to donB -> no leaked errors or place text
        router.go('/donations/${donB.id}');
        await tester.pumpAndSettle();
        expect(find.text('ID: ${donB.id}'), findsOneWidget);
        expect(find.text('El mensaje no puede estar vacío.'), findsNothing);
        final placeFieldB = tester.widget<TextField>(
          find.byKey(const Key('delivery_place_field')),
        );
        expect(placeFieldB.controller?.text, isEmpty);

        // Direct navigation between /publications/pub-1 and /publications/pub-2
        router.go('/publications/pub-1');
        await tester.pumpAndSettle();
        expect(find.text('Silla de ruedas plegable'), findsOneWidget);
        router.go('/publications/pub-2');
        await tester.pumpAndSettle();
        expect(find.text('Libros escolares de primaria'), findsOneWidget);
        expect(find.text('Silla de ruedas plegable'), findsNothing);
      },
    );
  });
}

class _SpyClientKeyStore extends MockTenantStore {
  final List<(String op, String key)> recordedCalls = [];

  List<String> keysFor(String op) =>
      recordedCalls.where((e) => e.$1 == op).map((e) => e.$2).toList();

  @override
  Future<DonacionMock> acceptProposal({
    required String proposalId,
    required String clientKey,
  }) {
    recordedCalls.add(('accept', clientKey));
    return super.acceptProposal(proposalId: proposalId, clientKey: clientKey);
  }

  @override
  Future<DonacionMock> registerDeliverySchedule({
    required String donationId,
    required String place,
    required DateTime scheduledDate,
    required String clientKey,
  }) {
    recordedCalls.add(('schedule', clientKey));
    return super.registerDeliverySchedule(
      donationId: donationId,
      place: place,
      scheduledDate: scheduledDate,
      clientKey: clientKey,
    );
  }

  @override
  Future<DonacionMock> markDonationDelivered({
    required String donationId,
    required String clientKey,
  }) {
    recordedCalls.add(('deliver', clientKey));
    return super.markDonationDelivered(
      donationId: donationId,
      clientKey: clientKey,
    );
  }

  @override
  Future<DonacionMock> confirmDonationReceived({
    required String donationId,
    required String clientKey,
  }) {
    recordedCalls.add(('confirm', clientKey));
    return super.confirmDonationReceived(
      donationId: donationId,
      clientKey: clientKey,
    );
  }

  @override
  Future<DonacionMock> cancelDonation({
    required String donationId,
    required String reason,
    required String clientKey,
  }) {
    recordedCalls.add(('cancel', clientKey));
    return super.cancelDonation(
      donationId: donationId,
      reason: reason,
      clientKey: clientKey,
    );
  }
}

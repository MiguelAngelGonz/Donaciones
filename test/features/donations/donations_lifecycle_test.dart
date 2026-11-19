import 'package:donaciones/app/router.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/features/donations/presentation/donation_tracking_screen.dart';
import 'package:donaciones/features/donations/presentation/donations_hub_screen.dart';
import 'package:donaciones/features/proposals/presentation/offer_item_sheet.dart';
import 'package:donaciones/features/proposals/presentation/request_item_sheet.dart';
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

  group('CU-25 a CU-29: Propuestas enviadas, recibidas, retiro, aceptación y rechazo',
      () {
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
        expect(
          find.textContaining('pérdida de conexión'),
          findsOneWidget,
        );
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

        final rejected =
            store.proposals.firstWhere((p) => p.id == diegoProp.id);
        expect(rejected.estado, EstadoPropuesta.rechazada);
        expect(rejected.motivoRechazo, 'Ya acordamos entrega con otro vecino.');
        expect(
          store.findPublicationById('pub-3')?.estado,
          EstadoPublicacion.activa,
        );
      },
    );
  });

  group('CU-26 a CU-37: Ciclo completo de donación, chat, privacidad de teléfono, reloj y reseñas',
      () {
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

        // Switch to recipient usr-alondra -> sees Maria's phone and replies
        store.setActiveUser('usr-alondra');
        await tester.pumpAndSettle();

        expect(find.textContaining('2229876543'), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('chat_message_field')),
          'En el Parque del Carmen a las 5pm.',
        );
        await tapVisible(tester, find.byKey(const Key('chat_send_button')));
        expect(
          find.text('En el Parque del Carmen a las 5pm.'),
          findsOneWidget,
        );

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
        await tapVisible(tester, find.byKey(const Key('mark_delivered_button')));

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
        await tapVisible(tester, find.byKey(const Key('confirm_received_button')));

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
          find.text('El plazo de 14 días para reseñar esta donación ha vencido'),
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
        expect(
          store.findDonationById(don.id)?.estado,
          EstadoDonacion.aceptada,
        );

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

        await tapVisible(tester, find.byKey(const Key('donations_tab_history')));
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
}

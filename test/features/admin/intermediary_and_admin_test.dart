import 'package:donaciones/app/router.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/core/models/dto_inputs.dart';
import 'package:donaciones/features/admin/presentation/admin_panel_screen.dart';
import 'package:donaciones/features/intermediary/presentation/request_intermediary_sheet.dart';
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

  Future<void> enterTextAndSettle(
    WidgetTester tester,
    Finder finder,
    String text,
  ) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.enterText(finder, text);
    await tester.pumpAndSettle();
  }

  group('CU-40 & CU-41: Solicitud de rol de intermediario', () {
    testWidgets(
      'CU-40 & CU-41: valida campos obligatorios, formato y tamaño máx 5 MB, error de red RNF-12 y envío válido',
      (tester) async {
        final (store, _) = await pumpAppAtRoute(tester, '/profile');
        store.setActiveUser('usr-diego');
        await tester.pumpAndSettle();

        expect(store.intermediaryRequests.length, 1);

        // Open RequestIntermediarySheet from ProfileScreen
        await tapVisible(tester, find.text('Solicitar rol de intermediario'));
        expect(find.byType(RequestIntermediarySheet), findsOneWidget);

        // CU-40 4a: missing organization and missing document
        await tapVisible(
          tester,
          find.byKey(const Key('intermediary_submit_button')),
        );
        expect(
          find.text('El nombre de la organización o comunidad es obligatorio.'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Debes adjuntar un documento de respaldo (.pdf, .jpg, .png, máx. 5 MB).',
          ),
          findsOneWidget,
        );
        expect(store.intermediaryRequests.length, 1);

        // Enter organization, keep "Sin documento" -> still rejected for missing doc
        await enterTextAndSettle(
          tester,
          find.byKey(const Key('intermediary_organization_field')),
          'Comedor Comunitario San Manuel',
        );
        await tapVisible(
          tester,
          find.byKey(const Key('intermediary_submit_button')),
        );
        expect(
          find.text(
            'Debes adjuntar un documento de respaldo (.pdf, .jpg, .png, máx. 5 MB).',
          ),
          findsOneWidget,
        );
        expect(store.intermediaryRequests.length, 1);

        // CU-41: invalid file extension (.exe)
        await tapVisible(
          tester,
          find.byKey(const Key('intermediary_doc_invalid_ext')),
        );
        await tapVisible(
          tester,
          find.byKey(const Key('intermediary_submit_button')),
        );
        expect(
          find.text('El documento de respaldo debe ser .pdf, .jpg, .jpeg o .png.'),
          findsOneWidget,
        );
        expect(store.intermediaryRequests.length, 1);

        // CU-41: file exceeding 5 MB (6.0 MB)
        await tapVisible(
          tester,
          find.byKey(const Key('intermediary_doc_oversized')),
        );
        await tapVisible(
          tester,
          find.byKey(const Key('intermediary_submit_button')),
        );
        expect(
          find.text('El documento de respaldo debe pesar máximo 5 MB.'),
          findsOneWidget,
        );
        expect(store.intermediaryRequests.length, 1);

        // Select valid .pdf document + test RNF-12 network error (5a)
        await tapVisible(
          tester,
          find.byKey(const Key('intermediary_doc_pdf')),
        );
        store.setSimulateNetworkError(true);
        await tapVisible(
          tester,
          find.byKey(const Key('intermediary_submit_button')),
        );
        expect(
          find.textContaining('pérdida de conexión'),
          findsOneWidget,
        );
        expect(find.byType(RequestIntermediarySheet), findsOneWidget);
        expect(store.intermediaryRequests.length, 1);

        // Recover network and submit valid request
        store.setSimulateNetworkError(false);
        await tapVisible(
          tester,
          find.byKey(const Key('intermediary_submit_button')),
        );
        expect(
          find.textContaining('Solicitud enviada'),
          findsOneWidget,
        );
        expect(store.intermediaryRequests.length, 2);

        final createdReq = store.intermediaryRequests.last;
        expect(createdReq.usuarioId, 'usr-diego');
        expect(createdReq.organizacion, 'Comedor Comunitario San Manuel');
        expect(createdReq.documentoNombre, 'constancia_comunitaria.pdf');
        expect(createdReq.documentoBytesSimulados, 1258291);
        expect(createdReq.estado, EstadoSolicitudRol.pendiente);

        // Close sheet and verify ProfileScreen updates to pending status
        await tapVisible(
          tester,
          find.byKey(const Key('intermediary_done_close_button')),
        );
        expect(find.byType(RequestIntermediarySheet), findsNothing);
        expect(
          find.textContaining('Solicitud pendiente de revisión'),
          findsOneWidget,
        );
        expect(find.text('Solicitar rol de intermediario'), findsNothing);
      },
    );

    testWidgets(
      'CU-40 & CU-41: permite adjuntar foto de respaldo desde cámara/galería del dispositivo',
      (tester) async {
        final (store, _) = await pumpAppAtRoute(tester, '/profile');
        store.setActiveUser('usr-diego');
        await tester.pumpAndSettle();

        await tapVisible(tester, find.text('Solicitar rol de intermediario'));
        await enterTextAndSettle(
          tester,
          find.byKey(const Key('intermediary_organization_field')),
          'Brigada Comunitaria BUAP',
        );
        await tapVisible(
          tester,
          find.byKey(const Key('intermediary_doc_device_photo')),
        );
        await tapVisible(
          tester,
          find.byKey(const Key('intermediary_submit_button')),
        );

        expect(find.textContaining('Solicitud enviada'), findsOneWidget);
        final createdReq = store.intermediaryRequests.last;
        expect(createdReq.documentoNombre, 'constancia_camara_dispositivo.jpg');
        expect(createdReq.documentoBytesSimulados, 942080);
      },
    );
  });

  group('CU-42 a CU-45: Panel de Administración - Intermediarios', () {
    testWidgets(
      'CU-42 a CU-45: protege acceso a no administradores, aprueba, rechaza y revoca intermediarios manejando RNF-12',
      (tester) async {
        final (store, container) = await pumpAppAtRoute(tester, '/');

        // Register a second applicant so we can test both Approve and Reject in UI
        final secondApplicant = await store.registerUser(
          const RegisterUserInput(
            nombreUsuario: 'lucia.ayuda',
            nombreLegal: 'Lucía Fernández',
            correo: 'lucia.ayuda@donaplus.app',
            telefono: '2224445566',
            password: 'Password1',
            ubicacionEtiqueta: 'Col. Centro, CP 72000',
            avisoPrivacidadAceptado: true,
          ),
        );
        await store.verifyEmailForTest(secondApplicant.id);

        // Create two pending intermediary requests
        store.setActiveUser('usr-diego');
        final reqDiego = await store.requestIntermediaryRole(
          organization: 'Comedor San Manuel',
          documentName: 'constancia_comunitaria.pdf',
          documentBytes: 1258291,
        );
        store.setActiveUser(secondApplicant.id);
        final reqLucia = await store.requestIntermediaryRole(
          organization: 'Red Vecinal Centro',
          documentName: 'credencial_asociacion.jpg',
          documentBytes: 870400,
        );

        // Prepare intermediary-managed needs for usr-maria (CU-45 verification)
        store.setActiveUser('usr-maria');
        final mariaActiveNeed = await store.createNeedPublication(
          const CreateNeedInput(
            titulo: 'Cobijas para albergue',
            descripcion: 'Para adultos mayores del albergue.',
            categoriaId: 'cat-ropa',
            cantidadRequerida: 5,
            detallesCaracteristicas: 'Térmicas',
            urgencia: Urgencia.alta,
            ubicacionEtiqueta: 'Col. La Paz, CP 72160',
            gestionadaPorIntermediario: true,
            aliasBeneficiario: 'Albergue Esperanza',
          ),
        );
        final mariaNeedInDonation = await store.createNeedPublication(
          const CreateNeedInput(
            titulo: 'Leche infantil en polvo',
            descripcion: 'Para casa cuna comunitaria.',
            categoriaId: 'cat-alimentacion',
            cantidadRequerida: 3,
            detallesCaracteristicas: 'Latas selladas',
            urgencia: Urgencia.alta,
            ubicacionEtiqueta: 'Col. La Paz, CP 72160',
            gestionadaPorIntermediario: true,
            aliasBeneficiario: 'Casa Cuna Sur',
          ),
        );

        store.setActiveUser('usr-alondra');
        final pendingOffer = await store.createOfferProposal(
          publicationId: mariaActiveNeed.id,
          senderId: 'usr-alondra',
          description: '5 cobijas nuevas',
          photos: ['sample://cobijas_termicas.jpg'],
          clientKey: 'ck-admin-offer-1',
        );
        final acceptedOffer = await store.createOfferProposal(
          publicationId: mariaNeedInDonation.id,
          senderId: 'usr-alondra',
          description: '3 latas selladas',
          photos: ['sample://libros_primaria.jpg'],
          clientKey: 'ck-admin-offer-2',
        );
        store.setActiveUser('usr-maria');
        final inProgressDonation = await store.acceptProposal(
          proposalId: acceptedOffer.id,
          clientKey: 'ck-admin-acc-2',
        );

        // CU-42: Non-admin user sees guard message on /admin
        store.setActiveUser('usr-diego');
        container.read(appRouterProvider).go('/admin');
        await tester.pumpAndSettle();

        expect(find.byType(AdminPanelScreen), findsOneWidget);
        expect(find.text('Acceso restringido a administradores'), findsOneWidget);
        expect(find.byKey(Key('approve_request_${reqDiego.id}')), findsNothing);

        // Navigate back to Profile and switch to admin usr-alondra
        await tapVisible(
          tester,
          find.byKey(const Key('admin_unauthorized_home_button')),
        );
        store.setActiveUser('usr-alondra');
        container.read(appRouterProvider).go('/profile');
        await tester.pumpAndSettle();

        await tapVisible(tester, find.text('Panel de Administración'));
        expect(find.byType(AdminPanelScreen), findsOneWidget);
        expect(find.text('Intermediarios'), findsOneWidget);
        expect(find.text('Categorías'), findsOneWidget);

        // Pending requests & authorized intermediaries are visible
        expect(find.text('Comedor San Manuel'), findsOneWidget);
        expect(find.text('Red Vecinal Centro'), findsOneWidget);
        expect(find.text('Fundación Apoyo Comunitario Puebla'), findsOneWidget);

        // RNF-12: network error on approve does not approve
        store.setSimulateNetworkError(true);
        await tapVisible(tester, find.byKey(Key('approve_request_${reqDiego.id}')));
        expect(find.textContaining('pérdida de conexión'), findsOneWidget);
        expect(store.findUserById('usr-diego')?.esIntermediario, isFalse);

        // CU-43: Approve Diego's request
        store.setSimulateNetworkError(false);
        await tapVisible(tester, find.byKey(Key('approve_request_${reqDiego.id}')));
        expect(store.findUserById('usr-diego')?.esIntermediario, isTrue);
        expect(
          store.intermediaryRequests
              .firstWhere((r) => r.id == reqDiego.id)
              .estado,
          EstadoSolicitudRol.aprobada,
        );
        expect(
          find.byKey(const Key('authorized_intermediary_usr-diego')),
          findsOneWidget,
        );

        // CU-44: Reject Lucia's request with optional reason (test RNF-12 first)
        await tapVisible(tester, find.byKey(Key('reject_request_${reqLucia.id}')));
        await enterTextAndSettle(
          tester,
          find.byKey(const Key('reject_intermediary_reason_field')),
          'Documento borroso',
        );
        store.setSimulateNetworkError(true);
        await tapVisible(
          tester,
          find.byKey(const Key('confirm_reject_intermediary_button')),
        );
        expect(find.textContaining('pérdida de conexión'), findsOneWidget);
        expect(
          store.intermediaryRequests
              .firstWhere((r) => r.id == reqLucia.id)
              .estado,
          EstadoSolicitudRol.pendiente,
        );

        store.setSimulateNetworkError(false);
        await tapVisible(tester, find.byKey(Key('reject_request_${reqLucia.id}')));
        await enterTextAndSettle(
          tester,
          find.byKey(const Key('reject_intermediary_reason_field')),
          'Documento borroso',
        );
        await tapVisible(
          tester,
          find.byKey(const Key('confirm_reject_intermediary_button')),
        );
        final rejectedLucia = store.intermediaryRequests.firstWhere(
          (r) => r.id == reqLucia.id,
        );
        expect(rejectedLucia.estado, EstadoSolicitudRol.rechazada);
        expect(rejectedLucia.motivoDecision, 'Documento borroso');

        //CU-44 verification: rejected user (Lucia) can view rejection reason in Profile and submit a new request
        store.setActiveUser(secondApplicant.id);
        container.read(appRouterProvider).go('/profile');
        await tester.pumpAndSettle();
        expect(find.textContaining('Documento borroso'), findsOneWidget);
        await tapVisible(tester, find.text('Solicitar rol de intermediario'));
        await enterTextAndSettle(
          tester,
          find.byKey(const Key('intermediary_organization_field')),
          'Red Vecinal Centro Renovada',
        );
        await tapVisible(tester, find.byKey(const Key('intermediary_doc_jpg')));
        await tapVisible(
          tester,
          find.byKey(const Key('intermediary_submit_button')),
        );
        expect(find.textContaining('Solicitud enviada'), findsOneWidget);
        await tapVisible(
          tester,
          find.byKey(const Key('intermediary_done_close_button')),
        );
        expect(
          find.textContaining(
            'Solicitud pendiente de revisión para "Red Vecinal Centro Renovada"',
          ),
          findsOneWidget,
        );

        // Return to admin to finish CU-45 revocation check
        store.setActiveUser('usr-alondra');
        container.read(appRouterProvider).go('/admin');
        await tester.pumpAndSettle();

        // CU-45: Revoke usr-maria's intermediary role (test RNF-12 first)
        store.setSimulateNetworkError(true);
        await tapVisible(
          tester,
          find.byKey(const Key('revoke_intermediary_usr-maria')),
        );
        await tapVisible(
          tester,
          find.byKey(const Key('confirm_revoke_intermediary_button')),
        );
        expect(find.textContaining('pérdida de conexión'), findsOneWidget);
        expect(store.findUserById('usr-maria')?.esIntermediario, isTrue);

        store.setSimulateNetworkError(false);
        await tapVisible(
          tester,
          find.byKey(const Key('revoke_intermediary_usr-maria')),
        );
        await tapVisible(
          tester,
          find.byKey(const Key('confirm_revoke_intermediary_button')),
        );

        expect(store.findUserById('usr-maria')?.esIntermediario, isFalse);
        expect(
          store.findPublicationById(mariaActiveNeed.id)?.estado,
          EstadoPublicacion.retirada,
        );
        expect(
          store.proposals.firstWhere((p) => p.id == pendingOffer.id).estado,
          EstadoPropuesta.rechazada,
        );
        expect(
          store.findDonationById(inProgressDonation.id)?.estado,
          EstadoDonacion.aceptada,
        );
      },
    );
  });

  group('CU-48 a CU-51: Panel de Administración - Categorías', () {
    testWidgets(
      'CU-48 a CU-51: crea, valida vacío/duplicado, renombra y desactiva categorías con RNF-12',
      (tester) async {
        final (store, container) = await pumpAppAtRoute(tester, '/admin');

        await tapVisible(
          tester,
          find.byKey(const Key('admin_tab_categories')),
        );

        // Verify all 7 seed categories are listed (6 active + 1 inactive).
        expect(find.text('Salud'), findsOneWidget);
        expect(find.text('Electrónica antigua'), findsOneWidget);
        expect(find.text('Activa'), findsNWidgets(6));
        expect(find.text('Inactiva'), findsOneWidget);

        // CU-49 3a: empty name rejected
        await tapVisible(
          tester,
          find.byKey(const Key('admin_create_category_button')),
        );
        expect(
          find.text('El nombre de la categoría es obligatorio.'),
          findsOneWidget,
        );
        expect(store.categories.length, 7);

        // CU-49: duplicate case-insensitive name rejected
        await enterTextAndSettle(
          tester,
          find.byKey(const Key('admin_new_category_field')),
          '  salud  ',
        );
        await tapVisible(
          tester,
          find.byKey(const Key('admin_create_category_button')),
        );
        expect(
          find.text('Ya existe una categoría con ese nombre.'),
          findsOneWidget,
        );
        expect(store.categories.length, 7);

        // RNF-12: network error on create
        await enterTextAndSettle(
          tester,
          find.byKey(const Key('admin_new_category_field')),
          'Tecnología Escolar',
        );
        store.setSimulateNetworkError(true);
        await tapVisible(
          tester,
          find.byKey(const Key('admin_create_category_button')),
        );
        expect(find.textContaining('pérdida de conexión'), findsOneWidget);
        expect(store.categories.length, 7);

        // CU-49: create valid category
        store.setSimulateNetworkError(false);
        await tapVisible(
          tester,
          find.byKey(const Key('admin_create_category_button')),
        );
        expect(store.categories.length, 8);
        final createdCat = store.categories.last;
        expect(createdCat.nombre, 'Tecnología Escolar');
        expect(createdCat.activa, isTrue);
        expect(
          store.getActiveCategories().any((c) => c.id == createdCat.id),
          isTrue,
        );

        // Publish an active Need using the new category before renaming/deactivating (CU-51 check)
        await store.createNeedPublication(
          CreateNeedInput(
            titulo: 'Tableta para clases en línea',
            descripcion: 'Para estudiante de secundaria.',
            categoriaId: createdCat.id,
            cantidadRequerida: 1,
            detallesCaracteristicas: 'WiFi funcional',
            urgencia: Urgencia.media,
            ubicacionEtiqueta: 'Col. Centro, CP 72000',
          ),
        );

        // CU-50: rename category (rejects empty, duplicate, and RNF-12 network error, then renames validly)
        await tapVisible(
          tester,
          find.byKey(Key('rename_category_${createdCat.id}')),
        );
        await enterTextAndSettle(
          tester,
          find.byKey(const Key('rename_category_field')),
          '   ',
        );
        await tapVisible(
          tester,
          find.byKey(const Key('confirm_rename_category_button')),
        );
        expect(
          find.text('El nombre de la categoría es obligatorio.'),
          findsOneWidget,
        );

        await enterTextAndSettle(
          tester,
          find.byKey(const Key('rename_category_field')),
          'Educación',
        );
        await tapVisible(
          tester,
          find.byKey(const Key('confirm_rename_category_button')),
        );
        expect(
          find.text('Ya existe una categoría con ese nombre.'),
          findsOneWidget,
        );

        await enterTextAndSettle(
          tester,
          find.byKey(const Key('rename_category_field')),
          'Cómputo Educativo',
        );
        store.setSimulateNetworkError(true);
        await tapVisible(
          tester,
          find.byKey(const Key('confirm_rename_category_button')),
        );
        expect(find.textContaining('pérdida de conexión'), findsOneWidget);
        expect(
          store.findCategoryById(createdCat.id)?.nombre,
          'Tecnología Escolar',
        );

        store.setSimulateNetworkError(false);
        await tapVisible(
          tester,
          find.byKey(const Key('confirm_rename_category_button')),
        );
        expect(
          store.findCategoryById(createdCat.id)?.nombre,
          'Cómputo Educativo',
        );
        expect(find.text('Cómputo Educativo'), findsOneWidget);

        // CU-51: deactivate active category (test RNF-12 first)
        store.setSimulateNetworkError(true);
        await tapVisible(
          tester,
          find.byKey(Key('deactivate_category_${createdCat.id}')),
        );
        await tapVisible(
          tester,
          find.byKey(const Key('confirm_deactivate_category_button')),
        );
        expect(find.textContaining('pérdida de conexión'), findsOneWidget);
        expect(store.findCategoryById(createdCat.id)?.activa, isTrue);

        store.setSimulateNetworkError(false);
        await tapVisible(
          tester,
          find.byKey(Key('deactivate_category_${createdCat.id}')),
        );
        await tapVisible(
          tester,
          find.byKey(const Key('confirm_deactivate_category_button')),
        );
        expect(store.findCategoryById(createdCat.id)?.activa, isFalse);
        expect(
          store.getActiveCategories().any((c) => c.id == createdCat.id),
          isFalse,
        );
        expect(
          find.byKey(Key('deactivate_category_${createdCat.id}')),
          findsNothing,
        );
        expect(find.text('Inactiva'), findsNWidgets(2));

        // Existing publication in deactivated category stays visible in Feed,
        // while filter tiles and /create dropdown omit the deactivated category.
        container.read(appRouterProvider).go('/');
        await tester.pumpAndSettle();
        expect(find.text('Tableta para clases en línea'), findsOneWidget);
        expect(
          find.byKey(Key('feed_cat_${createdCat.id}')),
          findsNothing,
        );

        container.read(appRouterProvider).go('/create');
        await tester.pumpAndSettle();
        await tapVisible(tester, find.byKey(const Key('create_mode_need')));
        await tapVisible(
          tester,
          find.byKey(const Key('need_category_dropdown')),
        );
        expect(find.text('Cómputo Educativo'), findsNothing);
        expect(find.text('Salud'), findsWidgets);
      },
    );
  });

  group('RNF-03: Accesibilidad y layout móvil', () {
    testWidgets(
      'RNF-03: RequestIntermediarySheet y AdminPanelScreen sin desbordamiento en 390x844 a 1.25x y alto contraste',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final (store, container) = await pumpAppAtRoute(tester, '/');
        final router = container.read(appRouterProvider);

        // Seed a pending request so all AdminPanelScreen sections render
        store.setActiveUser('usr-diego');
        await store.requestIntermediaryRole(
          organization: 'Comedor Comunitario San Manuel',
          documentName: 'constancia_comunitaria.pdf',
          documentBytes: 1258291,
        );
        store.setActiveUser('usr-alondra');

        // Enable 1.25x text scale & high contrast
        await tapVisible(tester, find.text('Accesibilidad'));
        await tapVisible(tester, find.text('Ampliado (1.25x)'));
        await tapVisible(tester, find.text('Alto contraste'));
        await tapVisible(tester, find.byTooltip('Cerrar'));

        // Check RequestIntermediarySheet at 390x844 1.25x + high contrast
        // Use a newly registered user who has no pending request yet
        final testerUser = await store.registerUser(
          const RegisterUserInput(
            nombreUsuario: 'ana.accesible',
            nombreLegal: 'Ana Pérez',
            correo: 'ana.acc@donaplus.app',
            telefono: '2227778899',
            password: 'Password1',
            ubicacionEtiqueta: 'Col. Centro, CP 72000',
            avisoPrivacidadAceptado: true,
          ),
        );
        await store.verifyEmailForTest(testerUser.id);
        store.setActiveUser(testerUser.id);
        router.go('/profile');
        await tester.pumpAndSettle();

        await tapVisible(tester, find.text('Solicitar rol de intermediario'));
        expect(find.byType(RequestIntermediarySheet), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tapVisible(tester, find.byTooltip('Cerrar'));

        // Check AdminPanelScreen both tabs at 390x844 1.25x + high contrast
        store.setActiveUser('usr-alondra');
        router.go('/admin');
        await tester.pumpAndSettle();
        expect(find.byType(AdminPanelScreen), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tapVisible(
          tester,
          find.byKey(const Key('admin_tab_categories')),
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_exceptions.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/core/models/dto_inputs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Domain models & exceptions', () {
    test('preserve immutability, defaults, and derived trust getters', () {
      const loc = UbicacionMock(etiqueta: 'Col. Centro, CP 72000');
      expect(loc.distanciaKmSimulada, 2.4);
      expect(loc.latitud, 19.0414);
      expect(loc.longitud, -98.2063);

      const err = NetworkException();
      expect(
        err.message,
        'No se pudo completar la operación por pérdida de conexión',
      );
      expect(const DuplicateUsernameException().message, isNotEmpty);
      expect(const InvalidCredentialsException().message, isNotEmpty);
      expect(const AccountLockedException().message, isNotEmpty);
      expect(const UnverifiedEmailException().message, isNotEmpty);
      expect(const ExpiredOrUsedTokenException().message, isNotEmpty);
      expect(const UnauthorizedActionException().message, isNotEmpty);

      const userMissingTrust = UsuarioMock(
        id: 'u-1',
        nombreUsuario: 'diego',
        nombreLegal: 'Diego',
        correo: 'diego@test.com',
        telefono: '2225550199',
        ubicacionAproximada: loc,
        avisoPrivacidadAceptado: true,
        correoVerificado: true,
        perfilConfianzaOtorgado: false,
        promedioCalificacion: 3.7,
        donacionesFinalizadas: 2,
        numeroResenas: 1,
      );
      expect(userMissingTrust.faltantesDonaciones, 3);
      expect(userMissingTrust.faltantesResenas, 2);
      expect(userMissingTrust.faltantePromedio, 0.3);
    });
  });

  group('MockTenantStore seed data & immutability', () {
    test('loads exact initial seed data for CU-01 to CU-51', () {
      final store = MockTenantStore();

      expect(store.users.length, 3);
      expect(store.activeUser?.id, 'usr-alondra');
      expect(store.activeUser?.esAdministrador, isTrue);

      final maria = store.users.firstWhere((u) => u.id == 'usr-maria');
      expect(maria.esIntermediario, isTrue);

      final diego = store.users.firstWhere((u) => u.id == 'usr-diego');
      expect(diego.esIntermediario, isFalse);
      expect(diego.perfilConfianzaOtorgado, isFalse);
      expect(diego.faltantesDonaciones, 3);
      expect(diego.faltantesResenas, 1);

      expect(store.categories.length, 6);
      expect(store.getActiveCategories().length, 5);
      expect(
        store.getActiveCategories().map((c) => c.id),
        isNot(contains('cat-inactiva')),
      );
      expect(
        store.getCategoriesForFilter().map((c) => c.id),
        isNot(contains('cat-inactiva')),
      );

      expect(store.filterActivePublications().length, 4);
      expect(
        store.publications.any(
          (p) =>
              p.id == 'pub-hist-1' && p.estado == EstadoPublicacion.cerrada,
        ),
        isTrue,
      );
      expect(store.proposals, isEmpty);
      expect(store.donations.length, 1);
      expect(store.donations.first.id, 'don-hist-1');
      expect(store.donations.first.estado, EstadoDonacion.finalizada);
      expect(store.donations.first.historialCambios.length, 4);
      expect(store.reviews.length, 3);
      expect(store.getReviewsForUser('usr-alondra').length, 2);
      expect(store.getReviewsForUser('usr-maria').length, 1);
      expect(store.intermediaryRequests.length, 1);
      expect(
        store.intermediaryRequests.first.estado,
        EstadoSolicitudRol.aprobada,
      );
    });

    test('normalizes username/email uniqueness and returns unmodifiable lists',
        () {
      final store = MockTenantStore();

      expect(store.isUsernameTaken(' @Alondra.Dona '), isTrue);
      expect(store.isUsernameTaken('nonexistent_user'), isFalse);
      expect(store.isEmailTaken(' ALONDRA.DEMO@donaplus.app '), isTrue);
      expect(store.isEmailTaken('missing@donaplus.app'), isFalse);

      expect(() => store.users.clear(), throwsUnsupportedError);
      expect(() => store.categories.clear(), throwsUnsupportedError);
      expect(() => store.publications.clear(), throwsUnsupportedError);
      expect(() => store.proposals.clear(), throwsUnsupportedError);
      expect(() => store.donations.clear(), throwsUnsupportedError);
      expect(() => store.reviews.clear(), throwsUnsupportedError);
      expect(() => store.intermediaryRequests.clear(), throwsUnsupportedError);
      expect(() => store.notifications.clear(), throwsUnsupportedError);
      expect(() => store.resetTokens.clear(), throwsUnsupportedError);
      expect(() => store.getActiveCategories().clear(), throwsUnsupportedError);
      expect(
        () => store.getCategoriesForFilter().clear(),
        throwsUnsupportedError,
      );
      expect(
        () => store.filterActivePublications().clear(),
        throwsUnsupportedError,
      );
    });
  });

  group('Bloque 1: Auth, lockouts, password reset, and profile', () {
    test('registers user with SHA-256 hash and enforces CU-02 email verification',
        () async {
      final store = MockTenantStore();
      final user = await store.registerUser(
        const RegisterUserInput(
          nombreUsuario: 'miguel_buap',
          nombreLegal: 'Miguel Ángel González',
          correo: 'miguel@buap.mx',
          telefono: '2223334455',
          password: 'Password1',
          ubicacionEtiqueta: 'Col. Universidades, CP 72589',
          avisoPrivacidadAceptado: true,
        ),
      );

      expect(user.correoVerificado, isFalse);
      final account = store.findAccountByUserId(user.id)!;
      final expectedHash = sha256.convert(utf8.encode('Password1')).toString();
      expect(account.passwordHash, expectedHash);
      expect(account.passwordHash, isNot('Password1'));

      await expectLater(
        () => store.login(usernameOrEmail: 'miguel_buap', password: 'Password1'),
        throwsA(isA<UnverifiedEmailException>()),
      );

      await store.verifyEmailForTest(user.id);
      final logged = await store.login(
        usernameOrEmail: 'MIGUEL@buap.mx',
        password: 'Password1',
      );
      expect(logged.id, user.id);
      expect(store.activeUser?.id, user.id);
    });

    test(
        'Review Focus 2 (CU-07, CU-09): resets counter before 5th failure, locks for 15 min on 5th failure, unlocks after 16 min',
        () async {
      final store = MockTenantStore();

      // 4 failed attempts followed by success resets intentosFallidos to 0
      for (var i = 0; i < 4; i++) {
        await expectLater(
          () => store.login(
            usernameOrEmail: 'diego.solidario',
            password: 'WrongPassword1',
          ),
          throwsA(isA<InvalidCredentialsException>()),
        );
      }
      expect(store.findAccountByUserId('usr-diego')?.intentosFallidos, 4);

      await store.login(
        usernameOrEmail: 'diego@donaplus.app',
        password: 'DonaPlus1',
      );
      expect(store.findAccountByUserId('usr-diego')?.intentosFallidos, 0);

      // Now 5 consecutive failures trigger 15-minute lock
      for (var i = 0; i < 4; i++) {
        await expectLater(
          () => store.login(
            usernameOrEmail: '@diego.solidario',
            password: 'WrongPassword1',
          ),
          throwsA(isA<InvalidCredentialsException>()),
        );
      }
      await expectLater(
        () => store.login(
          usernameOrEmail: 'diego.solidario',
          password: 'WrongPassword1',
        ),
        throwsA(isA<AccountLockedException>()),
      );

      // Even with correct password, access stays blocked during the 15 minutes
      await expectLater(
        () => store.login(
          usernameOrEmail: 'diego.solidario',
          password: 'DonaPlus1',
        ),
        throwsA(isA<AccountLockedException>()),
      );

      // Advance clock 16 minutes -> unlocks and logs in
      store.advanceClock(const Duration(minutes: 16));
      final unlocked = await store.login(
        usernameOrEmail: 'diego.solidario',
        password: 'DonaPlus1',
      );
      expect(unlocked.id, 'usr-diego');
      expect(store.findAccountByUserId('usr-diego')?.intentosFallidos, 0);
    });

    test(
        'Review Focus 5 (CU-08): reset token works within 30 min, is single-use, and expires at 31 min',
        () async {
      final store = MockTenantStore();
      final token1 = await store.requestPasswordReset('diego@donaplus.app');

      // Advance 20 min -> still valid
      store.advanceClock(const Duration(minutes: 20));
      await store.confirmPasswordReset(
        token: token1.token,
        newPassword: 'NewPassword2',
      );

      // Reusing same token fails
      await expectLater(
        () => store.confirmPasswordReset(
          token: token1.token,
          newPassword: 'AnotherPass3',
        ),
        throwsA(isA<ExpiredOrUsedTokenException>()),
      );

      // Login works with new password
      final logged = await store.login(
        usernameOrEmail: 'diego.solidario',
        password: 'NewPassword2',
      );
      expect(logged.id, 'usr-diego');

      // Request second token and advance 31 min -> expires
      final token2 = await store.requestPasswordReset('diego@donaplus.app');
      store.advanceClock(const Duration(minutes: 31));
      await expectLater(
        () => store.confirmPasswordReset(
          token: token2.token,
          newPassword: 'AnotherPass4',
        ),
        throwsA(isA<ExpiredOrUsedTokenException>()),
      );
    });

    test('CU-06 & CU-10: logout clears activeUser and updateProfile validates phone',
        () async {
      final store = MockTenantStore();
      final updated = await store.updateProfile(telefono: '2229998877');
      expect(updated.telefono, '2229998877');
      expect(updated.nombreUsuario, 'alondra.dona');
      expect(updated.nombreLegal, 'Guadalupe Alondra Gutiérrez Paz');

      await expectLater(
        () => store.updateProfile(telefono: '222-123'),
        throwsA(isA<ValidationException>()),
      );

      store.logout();
      expect(store.activeUser, isNull);
    });
  });

  group('Bloque 2 & 3: Publications, filters, proximity, intermediary needs, matching',
      () {
    test('CU-11..14 & CU-46..47: creates need/item, validates intermediary alias and active categories',
        () async {
      final store = MockTenantStore();

      // Rejects inactive category
      await expectLater(
        () => store.createNeedPublication(
          const CreateNeedInput(
            titulo: 'Radio portátil',
            descripcion: 'Para noticias locales',
            categoriaId: 'cat-inactiva',
            cantidadRequerida: 1,
            detallesCaracteristicas: 'Pilas AA',
            urgencia: Urgencia.baja,
            ubicacionEtiqueta: 'Col. Centro, CP 72000',
          ),
        ),
        throwsA(isA<ValidationException>()),
      );

      // Non-intermediary cannot publish on behalf of beneficiary
      await expectLater(
        () => store.createNeedPublication(
          const CreateNeedInput(
            titulo: 'Despensa básica',
            descripcion: 'Para familia en situación vulnerable',
            categoriaId: 'cat-alimentacion',
            cantidadRequerida: 2,
            detallesCaracteristicas: 'No perecederos',
            urgencia: Urgencia.alta,
            ubicacionEtiqueta: 'Col. Centro, CP 72000',
            gestionadaPorIntermediario: true,
            aliasBeneficiario: 'Familia López',
          ),
        ),
        throwsA(isA<UnauthorizedActionException>()),
      );

      // Authorized intermediary usr-maria must provide non-empty alias
      store.setActiveUser('usr-maria');
      await expectLater(
        () => store.createNeedPublication(
          const CreateNeedInput(
            titulo: 'Despensa básica',
            descripcion: 'Para familia en situación vulnerable',
            categoriaId: 'cat-alimentacion',
            cantidadRequerida: 2,
            detallesCaracteristicas: 'No perecederos',
            urgencia: Urgencia.alta,
            ubicacionEtiqueta: 'Col. La Paz, CP 72160',
            gestionadaPorIntermediario: true,
            aliasBeneficiario: '   ',
          ),
        ),
        throwsA(isA<ValidationException>()),
      );

      final intermediaryNeed = await store.createNeedPublication(
        const CreateNeedInput(
          titulo: 'Despensa básica',
          descripcion: 'Para familia en situación vulnerable',
          categoriaId: 'cat-alimentacion',
          cantidadRequerida: 2,
          detallesCaracteristicas: 'No perecederos',
          urgencia: Urgencia.alta,
          ubicacionEtiqueta: 'Col. La Paz, CP 72160',
          gestionadaPorIntermediario: true,
          aliasBeneficiario: 'Familia López',
        ),
      );
      expect(intermediaryNeed.gestionadaPorIntermediario, isTrue);
      expect(intermediaryNeed.aliasBeneficiario, 'Familia López');

      // Item requires 1..5 photos
      await expectLater(
        () => store.createItemPublication(
          const CreateItemInput(
            titulo: 'Cobija',
            descripcion: 'Nueva',
            categoriaId: 'cat-ropa',
            fotografias: [],
            cantidad: 1,
            condicion: CondicionArticulo.nuevo,
            ubicacionEtiqueta: 'Col. La Paz, CP 72160',
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('CU-17..22: proximity, urgency filters, matching order, and match notifications',
        () async {
      final store = MockTenantStore();

      // Seed filter by distance and urgency
      final within2Km = store.filterActivePublications(
        maxDistanceKm: 2.0,
        sortByDistance: true,
      );
      expect(within2Km.map((p) => p.id), ['pub-3', 'pub-4']);

      final highUrgency = store.filterActivePublications(
        urgency: Urgencia.alta,
      );
      expect(highUrgency.map((p) => p.id), ['pub-1']);

      // Device location authorization toggle (CU-21)
      expect(store.isDeviceLocationAuthorized, isFalse);
      final nearbyPublication = within2Km.first;
      final profileDistance = store.getDistanceForPublication(nearbyPublication);
      store.setDeviceLocationAuthorized(
        true,
        location: nearbyPublication.ubicacion,
      );
      expect(store.getDistanceForPublication(nearbyPublication), 0);
      store.setDeviceLocationAuthorized(false);
      expect(store.getDistanceForPublication(nearbyPublication), profileDistance);
      store.setDeviceLocationAuthorized(true);
      expect(store.isDeviceLocationAuthorized, isTrue);

      // usr-alondra publishes an item in cat-salud -> matches pub-1 (Necesidad Alta, cat-salud)
      await store.createItemPublication(
        const CreateItemInput(
          titulo: 'Silla de ruedas aluminio',
          descripcion: 'Plegable adulto en excelente estado',
          categoriaId: 'cat-salud',
          fotografias: ['sample://silla_ruedas.jpg'],
          cantidad: 1,
          condicion: CondicionArticulo.comoNuevo,
          ubicacionEtiqueta: 'Col. Centro, CP 72000',
        ),
      );

      // usr-alondra also publishes an item in cat-educacion -> matches pub-2 (Necesidad Media, cat-educacion)
      await store.createItemPublication(
        const CreateItemInput(
          titulo: 'Colección libros primaria',
          descripcion: 'Grados 3ro y 4to completos',
          categoriaId: 'cat-educacion',
          fotografias: ['sample://libros_primaria.jpg'],
          cantidad: 5,
          condicion: CondicionArticulo.usado,
          ubicacionEtiqueta: 'Col. Centro, CP 72000',
        ),
      );

      final matches = store.getMatchesForUser('usr-alondra');
      expect(matches.length, 2);
      expect(matches.first.urgencia, Urgencia.alta);
      expect(matches.first.necesidadId, 'pub-1');
      expect(matches.last.urgencia, Urgencia.media);
      expect(matches.last.necesidadId, 'pub-2');

      // Notifications generated for matches (CU-18)
      final alondraMatchNotifs = store
          .getNotificationsForUser('usr-alondra')
          .where((n) => n.tipo == TipoNotificacion.nuevaCoincidencia)
          .toList();
      expect(alondraMatchNotifs.length, 2);

      store.markNotificationAsRead(alondraMatchNotifs.first.id);
      expect(
        store
            .getNotificationsForUser('usr-alondra')
            .firstWhere((n) => n.id == alondraMatchNotifs.first.id)
            .leida,
        isTrue,
      );
    });
  });

  group('Bloque 4 & Review Focus 1, 3, 5: Proposals, donations, chat, reviews',
      () {
    test(
        'Review Focus 1 (RNF-11): acceptProposal is idempotent by clientKey/proposalId and rejects competing pending proposals',
        () async {
      final store = MockTenantStore();

      // usr-alondra sends request on pub-3 (author usr-maria)
      final propAlondra = await store.createRequestProposal(
        publicationId: 'pub-3',
        senderId: 'usr-alondra',
        message: 'Necesitamos la mesa para nuestro hogar',
        clientKey: 'req-alondra-1',
      );
      // usr-diego sends competing request on pub-3
      final propDiego = await store.createRequestProposal(
        publicationId: 'pub-3',
        senderId: 'usr-diego',
        message: 'La puedo recoger hoy mismo',
        clientKey: 'req-diego-1',
      );

      store.setActiveUser('usr-maria');
      expect(
        store.getReceivedPendingProposals('usr-maria', publicationId: 'pub-3').length,
        2,
      );

      final don1 = await store.acceptProposal(
        proposalId: propAlondra.id,
        clientKey: 'accept-key-1',
      );
      final don2 = await store.acceptProposal(
        proposalId: propAlondra.id,
        clientKey: 'accept-key-1',
      );
      // Even repeating on same already-accepted proposal returns same donation without duplicating
      final don3 = await store.acceptProposal(
        proposalId: propAlondra.id,
        clientKey: 'accept-key-2',
      );

      expect(don1.id, don2.id);
      expect(don1.id, don3.id);
      expect(store.donations.where((d) => d.publicacionId == 'pub-3').length, 1);
      expect(don1.historialCambios.length, 1);
      expect(
        store.findPublicationById('pub-3')?.estado,
        EstadoPublicacion.reservada,
      );
      expect(
        store.proposals.firstWhere((p) => p.id == propDiego.id).estado,
        EstadoPropuesta.rechazada,
      );
    });

    test(
        'Review Focus 5 (CU-34, CU-37) & Review Focus 3 (RF-03): auto-finalization at 7 days, review blocked at 15 days, and trust badge revoked when avg drops < 4.0',
        () async {
      final store = MockTenantStore();

      // Proposal from usr-alondra on pub-3 (author usr-maria)
      final proposal = await store.createRequestProposal(
        publicationId: 'pub-3',
        senderId: 'usr-alondra',
        message: 'Mesa para comedor familiar',
        clientKey: 'ck-prop-1',
      );

      store.setActiveUser('usr-maria');
      final don = await store.acceptProposal(
        proposalId: proposal.id,
        clientKey: 'ck-acc-1',
      );

      // Chat works in ACEPTADA and toggles phone visibility (CU-31)
      await store.sendChatMessage(
        donationId: don.id,
        content: 'Hola, coordinemos la entrega',
      );
      await store.toggleSharePhoneInDonation(donationId: don.id, share: true);
      expect(
        store.findDonationById(don.id)?.telefonoDonanteCompartido,
        isTrue,
      );

      // Schedule delivery (CU-32)
      final inDelivery = await store.registerDeliverySchedule(
        donationId: don.id,
        place: 'Zócalo de Puebla',
        scheduledDate: store.currentTime.add(const Duration(days: 1)),
        clientKey: 'ck-sched-1',
      );
      expect(inDelivery.estado, EstadoDonacion.enEntrega);

      // Mark delivered by donor usr-maria (CU-33)
      final delivered = await store.markDonationDelivered(
        donationId: don.id,
        clientKey: 'ck-deliv-1',
      );
      expect(delivered.estado, EstadoDonacion.entregada);

      // Advance clock 7 days -> automatic system finalization (CU-34 2a)
      store.advanceClock(const Duration(days: 7));
      final autoFinalized = store.findDonationById(don.id)!;
      expect(autoFinalized.estado, EstadoDonacion.finalizada);
      expect(autoFinalized.historialCambios.last.actorId, isNull);
      expect(
        store.findPublicationById('pub-3')?.estado,
        EstadoPublicacion.cerrada,
      );

      // Chat is disabled once FINALIZADA
      await expectLater(
        () => store.sendChatMessage(
          donationId: don.id,
          content: 'Mensaje tardío',
        ),
        throwsA(isA<ValidationException>()),
      );

      // Review Focus 3: usr-maria starts with trust badge (4.8 avg, 6 donations, 5 reviews -> sum 24.0).
      // One 1-star review -> 25/6 = 4.17 (still >= 4.0); second 1-star review on another donation -> 26/7 = 3.71 < 4.0 -> badge revoked!
      store.setActiveUser('usr-alondra');
      await store.submitReview(
        donationId: don.id,
        rating: 1,
        comment: 'No llegó en el estado esperado',
      );
      expect(
        store.findUserById('usr-maria')?.perfilConfianzaOtorgado,
        isTrue,
      );

      // Second donation with usr-maria so she gets a second 1-star review
      final prop2 = await store.createOfferProposal(
        publicationId: 'pub-2',
        senderId: 'usr-alondra',
        description: 'Libros de primaria completos',
        photos: ['sample://libros_primaria.jpg'],
        clientKey: 'ck-prop-2',
      );
      // Wait: pub-2 is authored by usr-diego; let's use pub-1 authored by usr-maria!
      expect(prop2.estado, EstadoPropuesta.pendiente);

      final propMariaNeed = await store.createOfferProposal(
        publicationId: 'pub-1',
        senderId: 'usr-alondra',
        description: 'Silla de ruedas plegable de aluminio',
        photos: ['sample://silla_ruedas.jpg'],
        clientKey: 'ck-prop-maria-1',
      );
      store.setActiveUser('usr-maria');
      final donMariaNeed = await store.acceptProposal(
        proposalId: propMariaNeed.id,
        clientKey: 'ck-acc-maria-1',
      );
      store.setActiveUser('usr-alondra');
      await store.registerDeliverySchedule(
        donationId: donMariaNeed.id,
        place: 'Parque Juárez',
        scheduledDate: store.currentTime.add(const Duration(days: 1)),
        clientKey: 'ck-sched-maria-1',
      );
      await store.markDonationDelivered(
        donationId: donMariaNeed.id,
        clientKey: 'ck-deliv-maria-1',
      );
      store.setActiveUser('usr-maria');
      final confirmed = await store.confirmDonationReceived(
        donationId: donMariaNeed.id,
        clientKey: 'ck-conf-maria-1',
      );
      expect(confirmed.estado, EstadoDonacion.finalizada);

      store.setActiveUser('usr-alondra');
      await store.submitReview(
        donationId: donMariaNeed.id,
        rating: 1,
        comment: 'Segunda mala experiencia',
      );
      final mariaUpdated = store.findUserById('usr-maria')!;
      expect(mariaUpdated.promedioCalificacion, lessThan(4.0));
      expect(mariaUpdated.perfilConfianzaOtorgado, isFalse);

      // Review Focus 5 (CU-37 1b): after 15 days from finalization, usr-maria can no longer review donMariaNeed
      store.setActiveUser('usr-maria');
      store.advanceClock(const Duration(days: 15));
      await expectLater(
        () => store.submitReview(
          donationId: donMariaNeed.id,
          rating: 5,
          comment: 'Reseña fuera de tiempo',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('CU-36 & CU-38/39: cancelDonation reactivates publication and filters history',
        () async {
      final store = MockTenantStore();

      final prop = await store.createRequestProposal(
        publicationId: 'pub-4',
        senderId: 'usr-alondra',
        message: 'Me interesa la chaqueta',
        clientKey: 'ck-cancel-prop',
      );
      store.setActiveUser('usr-diego');
      final don = await store.acceptProposal(
        proposalId: prop.id,
        clientKey: 'ck-cancel-acc',
      );
      expect(
        store.findPublicationById('pub-4')?.estado,
        EstadoPublicacion.reservada,
      );

      final cancelled = await store.cancelDonation(
        donationId: don.id,
        reason: 'El donatario ya no pudo acudir',
        clientKey: 'ck-cancel-1',
      );
      expect(cancelled.estado, EstadoDonacion.cancelada);
      expect(
        store.findPublicationById('pub-4')?.estado,
        EstadoPublicacion.activa,
      );

      final historyAllDiego = store.getDonationHistoryForUser('usr-diego');
      expect(historyAllDiego.length, 2); // don-hist-1 + cancelled don

      final historyCancelledDonor = store.getDonationHistoryForUser(
        'usr-diego',
        role: PapelDonacion.donante,
        finalState: EstadoDonacion.cancelada,
      );
      expect(historyCancelledDonor.map((d) => d.id), [don.id]);
    });
  });

  group('Bloque 5, Review Focus 4 & RNF-12 Atomicity', () {
    test(
        'CU-40..44 & CU-48..51: intermediary request validation, admin approval/rejection, and category management',
        () async {
      final store = MockTenantStore();

      store.setActiveUser('usr-diego');
      await expectLater(
        () => store.requestIntermediaryRole(
          organization: 'Comedor Comunitario',
          documentName: 'comprobante.exe',
          documentBytes: 1024,
        ),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        () => store.requestIntermediaryRole(
          organization: 'Comedor Comunitario',
          documentName: 'comprobante.pdf',
          documentBytes: 6 * 1024 * 1024,
        ),
        throwsA(isA<ValidationException>()),
      );

      final req = await store.requestIntermediaryRole(
        organization: 'Comedor Comunitario San Manuel',
        documentName: 'constancia.pdf',
        documentBytes: 256 * 1024,
      );
      expect(req.estado, EstadoSolicitudRol.pendiente);

      // Non-admin cannot approve
      await expectLater(
        () => store.approveIntermediaryRequest(req.id),
        throwsA(isA<UnauthorizedActionException>()),
      );

      // Admin usr-alondra approves
      store.setActiveUser('usr-alondra');
      await store.approveIntermediaryRequest(req.id);
      expect(store.findUserById('usr-diego')?.esIntermediario, isTrue);

      // Categories (CU-49..51)
      final newCat = await store.createCategory(name: 'Tecnología Escolar');
      await expectLater(
        () => store.createCategory(name: '  tecnología escolar  '),
        throwsA(isA<ValidationException>()),
      );

      final renamed = await store.renameCategory(
        categoryId: newCat.id,
        newName: 'Cómputo Educativo',
      );
      expect(renamed.nombre, 'Cómputo Educativo');

      await store.deactivateCategory(newCat.id);
      expect(
        store.getActiveCategories().any((c) => c.id == newCat.id),
        isFalse,
      );
    });

    test(
        'Review Focus 4 (CU-15, CU-45): revokeIntermediaryRole withdraws active intermediary needs and rejects pending offers while preserving active donations',
        () async {
      final store = MockTenantStore();

      // usr-maria creates 2 intermediary-managed needs
      store.setActiveUser('usr-maria');
      final activeNeed = await store.createNeedPublication(
        const CreateNeedInput(
          titulo: 'Cobijas para albergue',
          descripcion: 'Para adultos mayores',
          categoriaId: 'cat-ropa',
          cantidadRequerida: 10,
          detallesCaracteristicas: 'Matrimonial',
          urgencia: Urgencia.alta,
          ubicacionEtiqueta: 'Col. La Paz, CP 72160',
          gestionadaPorIntermediario: true,
          aliasBeneficiario: 'Albergue Esperanza',
        ),
      );
      final needInDonation = await store.createNeedPublication(
        const CreateNeedInput(
          titulo: 'Leche en polvo',
          descripcion: 'Etapa infantil',
          categoriaId: 'cat-alimentacion',
          cantidadRequerida: 4,
          detallesCaracteristicas: 'Latas selladas',
          urgencia: Urgencia.alta,
          ubicacionEtiqueta: 'Col. La Paz, CP 72160',
          gestionadaPorIntermediario: true,
          aliasBeneficiario: 'Casa Cuna Sur',
        ),
      );

      // usr-alondra submits offers on both
      store.setActiveUser('usr-alondra');
      final pendingOfferOnActive = await store.createOfferProposal(
        publicationId: activeNeed.id,
        senderId: 'usr-alondra',
        description: '10 cobijas nuevas',
        photos: ['sample://cobijas_termicas.jpg'],
        clientKey: 'ck-int-1',
      );
      final offerForDonation = await store.createOfferProposal(
        publicationId: needInDonation.id,
        senderId: 'usr-alondra',
        description: '4 latas selladas',
        photos: ['sample://libros_primaria.jpg'],
        clientKey: 'ck-int-2',
      );

      // usr-maria accepts offer on needInDonation -> creates active donation
      store.setActiveUser('usr-maria');
      final activeDonation = await store.acceptProposal(
        proposalId: offerForDonation.id,
        clientKey: 'ck-int-acc',
      );

      // Admin revokes usr-maria's intermediary role
      store.setActiveUser('usr-alondra');
      await store.revokeIntermediaryRole('usr-maria');

      expect(store.findUserById('usr-maria')?.esIntermediario, isFalse);
      // activeNeed (ACTIVA + gestionadaPorIntermediario) becomes RETIRADA and its pending offer is RECHAZADA
      expect(
        store.findPublicationById(activeNeed.id)?.estado,
        EstadoPublicacion.retirada,
      );
      expect(
        store.proposals
            .firstWhere((p) => p.id == pendingOfferOnActive.id)
            .estado,
        EstadoPropuesta.rechazada,
      );
      // In-progress donation continues normally
      expect(
        store.findDonationById(activeDonation.id)?.estado,
        EstadoDonacion.aceptada,
      );
      // Non-intermediary active need (pub-1) remains ACTIVA
      expect(
        store.findPublicationById('pub-1')?.estado,
        EstadoPublicacion.activa,
      );
    });

    test('RNF-12: simulateNetworkError throws NetworkException without mutating state and resetToSeed restores defaults',
        () async {
      final store = MockTenantStore()..setSimulateNetworkError(true);

      await expectLater(
        () => store.createRequestProposal(
          publicationId: 'pub-3',
          senderId: 'usr-alondra',
          message: 'Hola',
          clientKey: 'key-net-1',
        ),
        throwsA(isA<NetworkException>()),
      );
      expect(store.proposals, isEmpty);
      expect(store.notifications, isEmpty);

      await expectLater(
        () => store.createNeedPublication(
          const CreateNeedInput(
            titulo: 'Prueba red',
            descripcion: 'Descripción',
            categoriaId: 'cat-salud',
            cantidadRequerida: 1,
            detallesCaracteristicas: 'Detalle',
            urgencia: Urgencia.media,
            ubicacionEtiqueta: 'Col. Centro, CP 72000',
          ),
        ),
        throwsA(isA<NetworkException>()),
      );
      expect(store.filterActivePublications().length, 4);

      await expectLater(
        () => store.createCategory(name: 'Nueva Cat'),
        throwsA(isA<NetworkException>()),
      );
      expect(store.categories.length, 6);

      store.setSimulateNetworkError(false);
      await store.createCategory(name: 'Nueva Cat');
      expect(store.categories.length, 7);

      store.resetToSeed();
      expect(store.categories.length, 6);
      expect(store.users.length, 3);
      expect(store.activeUser?.id, 'usr-alondra');
      expect(store.filterActivePublications().length, 4);
      expect(store.proposals, isEmpty);
    });

    test('CU-15, CU-16, CU-25, CU-29, CU-44 & Riverpod provider + transition idempotency',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final store = container.read(mockTenantStoreProvider);
      expect(store.users.length, 3);

      // Update & withdraw need/item (CU-15, CU-16)
      final need = await store.createNeedPublication(
        const CreateNeedInput(
          titulo: 'Muletas ajustables',
          descripcion: 'Para adulto',
          categoriaId: 'cat-salud',
          cantidadRequerida: 1,
          detallesCaracteristicas: 'Aluminio',
          urgencia: Urgencia.media,
          ubicacionEtiqueta: 'Col. Centro, CP 72000',
        ),
      );
      final updatedNeed = await store.updateNeedPublication(
        publicationId: need.id,
        input: const CreateNeedInput(
          titulo: 'Muletas canadienses',
          descripcion: 'Para adulto, urgentes',
          categoriaId: 'cat-salud',
          cantidadRequerida: 2,
          detallesCaracteristicas: 'Aluminio ligeras',
          urgencia: Urgencia.alta,
          ubicacionEtiqueta: 'Col. Centro, CP 72000',
        ),
      );
      expect(updatedNeed.titulo, 'Muletas canadienses');
      expect(updatedNeed.urgencia, Urgencia.alta);

      final item = await store.createItemPublication(
        const CreateItemInput(
          titulo: 'Suéter azul',
          descripcion: 'Lana suave',
          categoriaId: 'cat-ropa',
          fotografias: ['sample://chaqueta_invierno.jpg'],
          cantidad: 1,
          condicion: CondicionArticulo.usado,
          ubicacionEtiqueta: 'Col. Centro, CP 72000',
        ),
      );
      final updatedItem = await store.updateItemPublication(
        publicationId: item.id,
        input: const CreateItemInput(
          titulo: 'Suéter térmico azul',
          descripcion: 'Lana suave talla G',
          categoriaId: 'cat-ropa',
          fotografias: ['sample://chaqueta_invierno.jpg'],
          cantidad: 1,
          condicion: CondicionArticulo.comoNuevo,
          ubicacionEtiqueta: 'Col. Centro, CP 72000',
        ),
      );
      expect(updatedItem.titulo, 'Suéter térmico azul');

      // Pending offer on need gets rejected when publication is withdrawn (CU-15)
      store.setActiveUser('usr-diego');
      final diegoOffer = await store.createOfferProposal(
        publicationId: need.id,
        senderId: 'usr-diego',
        description: 'Par de muletas nuevas',
        photos: ['sample://silla_ruedas.jpg'],
        clientKey: 'ck-with-1',
      );
      expect(store.getSentProposals('usr-diego').length, 1);

      store.setActiveUser('usr-alondra');
      await store.withdrawPublication(need.id);
      expect(
        store.findPublicationById(need.id)?.estado,
        EstadoPublicacion.retirada,
      );
      expect(
        store.proposals.firstWhere((p) => p.id == diegoOffer.id).estado,
        EstadoPropuesta.rechazada,
      );

      // Withdraw own proposal (CU-25) & reject proposal (CU-29)
      store.setActiveUser('usr-diego');
      final reqToWithdraw = await store.createRequestProposal(
        publicationId: item.id,
        senderId: 'usr-diego',
        message: '¿Aún disponible?',
        clientKey: 'ck-withdraw-prop',
      );
      await store.withdrawProposal(reqToWithdraw.id);
      expect(
        store.proposals.firstWhere((p) => p.id == reqToWithdraw.id).estado,
        EstadoPropuesta.retirada,
      );

      store.setActiveUser('usr-maria');
      final reqToReject = await store.createRequestProposal(
        publicationId: item.id,
        senderId: 'usr-maria',
        message: 'Lo necesito para un beneficiario',
        clientKey: 'ck-reject-prop',
      );
      store.setActiveUser('usr-alondra');
      await store.rejectProposal(
        proposalId: reqToReject.id,
        reason: 'Ya fue apartado localmente',
      );
      expect(
        store.proposals.firstWhere((p) => p.id == reqToReject.id).estado,
        EstadoPropuesta.rechazada,
      );
      expect(
        store.findPublicationById(item.id)?.estado,
        EstadoPublicacion.activa,
      );

      // Transition idempotency across schedule, deliver, confirm, and cancel
      store.setActiveUser('usr-diego');
      final reqForFlow = await store.createRequestProposal(
        publicationId: item.id,
        senderId: 'usr-diego',
        message: 'Paso hoy por el suéter',
        clientKey: 'ck-flow-prop',
      );
      store.setActiveUser('usr-alondra');
      final don = await store.acceptProposal(
        proposalId: reqForFlow.id,
        clientKey: 'ck-flow-acc',
      );
      expect(store.getActiveDonationsForUser('usr-alondra').length, 1);

      final s1 = await store.registerDeliverySchedule(
        donationId: don.id,
        place: 'CU BUAP',
        scheduledDate: store.currentTime.add(const Duration(hours: 6)),
        clientKey: 'ck-sched-idem',
      );
      final s2 = await store.registerDeliverySchedule(
        donationId: don.id,
        place: 'CU BUAP',
        scheduledDate: store.currentTime.add(const Duration(hours: 6)),
        clientKey: 'ck-sched-idem',
      );
      expect(s1.historialCambios.length, s2.historialCambios.length);

      final d1 = await store.markDonationDelivered(
        donationId: don.id,
        clientKey: 'ck-deliv-idem',
      );
      final d2 = await store.markDonationDelivered(
        donationId: don.id,
        clientKey: 'ck-deliv-idem',
      );
      expect(d1.historialCambios.length, d2.historialCambios.length);

      store.setActiveUser('usr-diego');
      final c1 = await store.confirmDonationReceived(
        donationId: don.id,
        clientKey: 'ck-conf-idem',
      );
      final c2 = await store.confirmDonationReceived(
        donationId: don.id,
        clientKey: 'ck-conf-idem',
      );
      expect(c1.historialCambios.length, c2.historialCambios.length);
      expect(store.getActiveDonationsForUser('usr-alondra'), isEmpty);

      // Reject intermediary request (CU-44)
      final rolReq = await store.requestIntermediaryRole(
        organization: 'Grupo Vecinal',
        documentName: 'foto.png',
        documentBytes: 1024,
      );
      store.setActiveUser('usr-alondra');
      await store.rejectIntermediaryRequest(
        rolReq.id,
        reason: 'Documento ilegible',
      );
      expect(
        store.intermediaryRequests
            .firstWhere((r) => r.id == rolReq.id)
            .estado,
        EstadoSolicitudRol.rechazada,
      );
    });
  });
}

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_exceptions.dart';
import 'package:donaciones/features/auth/presentation/register_controller.dart';
import 'package:donaciones/features/auth/presentation/register_screen.dart';
import 'package:donaciones/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RegisterController unit validations (CU-01 / RF-01)', () {
    test('TC-CU01-03 & duplicate email: Step 1 blocks existing username or email',
        () {
      final store = MockTenantStore();
      final controller = RegisterController(store);

      expect(
        controller.validateStep1(
          username: 'alondra.dona',
          email: 'nuevo@buap.mx',
          password: 'Password1',
        ),
        isFalse,
      );
      expect(controller.state.usernameError, isNotNull);

      expect(
        controller.validateStep1(
          username: '  miguel_nuevo  ',
          email: '  ALONDRA.DEMO@donaplus.app  ',
          password: 'Password1',
        ),
        isFalse,
      );
      expect(controller.state.emailError, isNotNull);
    });

    test(
        'TC-CU01-04: rejects invalid email, non-10-digit phone, and weak password',
        () {
      final store = MockTenantStore();
      final controller = RegisterController(store);

      expect(
        controller.validateStep1(
          username: 'nuevo_usr',
          email: 'invalido@',
          password: 'donar2026',
        ),
        isFalse,
      );
      expect(controller.state.emailError, isNotNull);
      expect(controller.state.passwordError, isNotNull);

      expect(
        controller.validateStep2(
          legalName: 'Miguel Ángel González',
          phone: '222-123-45',
          location: 'Col. Centro, CP 72000',
        ),
        isFalse,
      );
      expect(controller.state.phoneError, isNotNull);

      expect(
        controller.validateStep2(
          legalName: 'Miguel Ángel González',
          phone: '22212345',
          location: 'Col. Centro, CP 72000',
        ),
        isFalse,
      );
      expect(controller.state.phoneError, isNotNull);
    });

    test('trims leading/trailing whitespace on username and email when valid',
        () {
      final store = MockTenantStore();
      final controller = RegisterController(store);

      expect(
        controller.validateStep1(
          username: '  miguel_buap  ',
          email: '  miguel@buap.mx  ',
          password: 'Donar2026',
        ),
        isTrue,
      );
      expect(controller.state.username, 'miguel_buap');
      expect(controller.state.email, 'miguel@buap.mx');
      expect(controller.state.currentStep, 1);
    });
  });

  group('RegisterScreen widget flow (TC-CU01-01 to TC-CU01-07)', () {
    Future<MockTenantStore> pumpRegisterInApp(WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: DonaPlusApp()));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DonaPlusApp)),
      );
      final store = container.read(mockTenantStoreProvider);
      store.setActiveUser(null);
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Perfil'),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrarse'));
      await tester.pumpAndSettle();
      return store;
    }

    Future<void> fillStep1(
      WidgetTester tester, {
      required String username,
      required String email,
      required String password,
    }) async {
      await tester.enterText(
        find.byKey(const Key('register_username_field')),
        username,
      );
      await tester.enterText(
        find.byKey(const Key('register_email_field')),
        email,
      );
      await tester.enterText(
        find.byKey(const Key('register_password_field')),
        password,
      );
      await tester.pumpAndSettle();
    }

    Future<void> fillStep2(
      WidgetTester tester, {
      required String legalName,
      required String phone,
      required String location,
      String? avatarChipLabel,
    }) async {
      await tester.enterText(
        find.byKey(const Key('register_legal_name_field')),
        legalName,
      );
      await tester.enterText(
        find.byKey(const Key('register_phone_field')),
        phone,
      );
      await tester.enterText(
        find.byKey(const Key('register_location_field')),
        location,
      );
      if (avatarChipLabel != null) {
        final chip = find.text(avatarChipLabel);
        await tester.ensureVisible(chip);
        await tester.tap(chip);
      }
      await tester.pumpAndSettle();
    }

    testWidgets(
      'TC-CU01-01, TC-CU01-05, TC-CU01-06 & TC-CU01-07: full 3-step flow, privacy block, network error recovery, and CU-02 verification',
      (tester) async {
        final store = await pumpRegisterInApp(tester);

        expect(find.byType(RegisterScreen), findsOneWidget);
        expect(find.text('Paso 1 de 3'), findsOneWidget);

        // Step 1 valid
        await fillStep1(
          tester,
          username: 'miguel_buap',
          email: 'miguel@buap.mx',
          password: 'Donar2026',
        );
        await tester.ensureVisible(find.text('Continuar'));
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        // Step 2 valid with optional photo
        expect(find.text('Paso 2 de 3'), findsOneWidget);
        await fillStep2(
          tester,
          legalName: 'Miguel Ángel González Hernández',
          phone: '2223334455',
          location: 'Col. Universidades, CP 72589',
          avatarChipLabel: 'Avatar Comunidad',
        );
        await tester.ensureVisible(find.text('Continuar'));
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        // Step 3
        expect(find.text('Paso 3 de 3'), findsOneWidget);
        expect(find.textContaining('miguel_buap'), findsWidgets);

        // TC-CU01-05 (5a): confirm without accepting privacy notice
        final confirmBtn = find.text('Confirmar registro');
        await tester.ensureVisible(confirmBtn);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();
        expect(find.textContaining('aviso de privacidad'), findsWidgets);
        expect(store.users.length, 3);

        // Accept privacy notice
        final checkbox = find.text('He leído y acepto el aviso de privacidad');
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await tester.pumpAndSettle();

        // TC-CU01-06 (6c): simulate network failure (RNF-12)
        store.setSimulateNetworkError(true);
        await tester.pumpAndSettle();
        await tester.ensureVisible(confirmBtn);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'No se pudo completar la operación por pérdida de conexión',
          ),
          findsOneWidget,
        );
        expect(find.text('Paso 3 de 3'), findsOneWidget);
        expect(store.users.length, 3);

        // Recover network and confirm registration
        store.setSimulateNetworkError(false);
        await tester.pumpAndSettle();
        await tester.ensureVisible(confirmBtn);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        // TC-CU01-01 assertions on created user & password hash
        expect(store.users.length, 4);
        final createdUser =
            store.users.firstWhere((u) => u.nombreUsuario == 'miguel_buap');
        expect(createdUser.nombreLegal, 'Miguel Ángel González Hernández');
        expect(createdUser.telefono, '2223334455');
        expect(createdUser.correoVerificado, isFalse);
        expect(createdUser.fotoPerfil, isNotNull);

        final account = store.findAccountByUserId(createdUser.id)!;
        expect(
          account.passwordHash,
          sha256.convert(utf8.encode('Donar2026')).toString(),
        );
        expect(account.passwordHash, isNot('Donar2026'));

        expect(
          find.textContaining('¡Cuenta creada con éxito!'),
          findsOneWidget,
        );

        // TC-CU01-07 (a): continue without verifying -> blocked (CU-02 2a)
        final unverifiedBtn = find.text(
          'Continuar sin verificar (probar restricción CU-02 2a)',
        );
        await tester.ensureVisible(unverifiedBtn);
        await tester.tap(unverifiedBtn);
        await tester.pumpAndSettle();

        expect(store.findUserById(createdUser.id)?.correoVerificado, isFalse);
        expect(store.activeUser, isNull);
        expect(
          find.textContaining('verificar tu correo'),
          findsWidgets,
        );
        await expectLater(
          () => store.login(
            usernameOrEmail: 'miguel_buap',
            password: 'Donar2026',
          ),
          throwsA(isA<UnverifiedEmailException>()),
        );

        // TC-CU01-07 (b): simulate email verification (CU-02) and enter feed
        final verifyBtn = find.text(
          'Simular verificación de correo (CU-02) y entrar',
        );
        await tester.ensureVisible(verifyBtn);
        await tester.tap(verifyBtn);
        await tester.pumpAndSettle();

        expect(store.findUserById(createdUser.id)?.correoVerificado, isTrue);
        expect(store.activeUser?.id, createdUser.id);
        expect(find.byType(NavigationBar), findsOneWidget);
      },
    );

    testWidgets(
      'TC-CU01-02: registration without optional profile photo saves fotoPerfil == null',
      (tester) async {
        final store = await pumpRegisterInApp(tester);

        await fillStep1(
          tester,
          username: 'ana_solidaria',
          email: 'ana@buap.mx',
          password: 'Donar2026',
        );
        await tester.ensureVisible(find.text('Continuar'));
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        await fillStep2(
          tester,
          legalName: 'Ana Sofía Pérez',
          phone: '2227778899',
          location: 'Col. Centro, CP 72000',
        );
        await tester.ensureVisible(find.text('Continuar'));
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        final checkbox = find.text('He leído y acepto el aviso de privacidad');
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await tester.pumpAndSettle();

        final confirmBtn = find.text('Confirmar registro');
        await tester.ensureVisible(confirmBtn);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        final createdUser =
            store.users.firstWhere((u) => u.nombreUsuario == 'ana_solidaria');
        expect(createdUser.fotoPerfil, isNull);
      },
    );

    testWidgets(
      'TC-CU01-03 & TC-CU01-04: duplicate username (6a) and field validation rules (6b)',
      (tester) async {
        final store = await pumpRegisterInApp(tester);

        // TC-CU01-03 (6a): duplicate username
        await fillStep1(
          tester,
          username: 'alondra.dona',
          email: 'nuevo@buap.mx',
          password: 'Donar2026',
        );
        await tester.ensureVisible(find.text('Continuar'));
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        expect(find.text('Paso 1 de 3'), findsOneWidget);
        expect(find.textContaining('ya existe'), findsOneWidget);

        // TC-CU01-04 (6b): invalid email & weak password
        await fillStep1(
          tester,
          username: 'carlos_buap',
          email: 'invalido@',
          password: 'donar2026',
        );
        await tester.ensureVisible(find.text('Continuar'));
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        expect(find.text('Paso 1 de 3'), findsOneWidget);
        expect(find.textContaining('correo electrónico válido'), findsOneWidget);
        expect(find.textContaining('mayúscula'), findsWidgets);

        // Fix Step 1 -> proceed to Step 2
        await fillStep1(
          tester,
          username: 'carlos_buap',
          email: 'carlos@buap.mx',
          password: 'Donar2026',
        );
        await tester.ensureVisible(find.text('Continuar'));
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();
        expect(find.text('Paso 2 de 3'), findsOneWidget);

        // TC-CU01-04 (6b): 8-digit phone
        await fillStep2(
          tester,
          legalName: 'Carlos Méndez',
          phone: '22212345',
          location: 'Col. La Paz, CP 72160',
        );
        await tester.ensureVisible(find.text('Continuar'));
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        expect(find.text('Paso 2 de 3'), findsOneWidget);
        expect(find.textContaining('10 dígitos'), findsWidgets);
        expect(store.users.length, 3);
      },
    );
  });
}

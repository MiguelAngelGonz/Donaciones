import 'package:donaciones/app/router.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/dto_inputs.dart';
import 'package:donaciones/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<(MockTenantStore, ProviderContainer)> pumpAppAtRoute(
    WidgetTester tester,
    String initialRoute,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DonaPlusApp()));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DonaPlusApp)),
    );
    final store = container.read(mockTenantStoreProvider);
    final router = container.read(appRouterProvider);
    router.go(initialRoute);
    await tester.pumpAndSettle();
    return (store, container);
  }

  group('Login, lockouts (CU-07, CU-09) and Password Reset (CU-08)', () {
    testWidgets(
      'CU-07 & CU-09: login succeeds with username/email, blocks after 5 failures for 15 min, unlocks after +15m',
      (tester) async {
        final (store, _) = await pumpAppAtRoute(tester, '/login');
        store.setActiveUser(null);
        await tester.pumpAndSettle();

        // RNF-12: network error on login does not authenticate
        store.setSimulateNetworkError(true);
        await tester.enterText(
          find.byKey(const Key('login_identifier_field')),
          'diego.solidario',
        );
        await tester.enterText(
          find.byKey(const Key('login_password_field')),
          'DonaPlus1',
        );
        await tester.ensureVisible(
          find.byKey(const Key('login_submit_button')),
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            'No se pudo completar la operación por pérdida de conexión',
          ),
          findsOneWidget,
        );
        expect(store.activeUser, isNull);
        store.setSimulateNetworkError(false);
        await tester.pumpAndSettle();

        // Wrong password 4 times -> invalid credentials
        for (var i = 0; i < 4; i++) {
          await tester.enterText(
            find.byKey(const Key('login_identifier_field')),
            'diego.solidario',
          );
          await tester.enterText(
            find.byKey(const Key('login_password_field')),
            'WrongPass1',
          );
          await tester.ensureVisible(
            find.byKey(const Key('login_submit_button')),
          );
          await tester.tap(find.byKey(const Key('login_submit_button')));
          await tester.pumpAndSettle();

          expect(find.textContaining('Credenciales inválidas'), findsOneWidget);
        }

        // 5th consecutive failed attempt -> AccountLockedException
        await tester.enterText(
          find.byKey(const Key('login_password_field')),
          'WrongPass1',
        );
        await tester.ensureVisible(
          find.byKey(const Key('login_submit_button')),
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('bloqueado temporalmente por 15 minutos'),
          findsOneWidget,
        );

        // Even correct password remains blocked during 15 minutes
        await tester.enterText(
          find.byKey(const Key('login_password_field')),
          'DonaPlus1',
        );
        await tester.ensureVisible(
          find.byKey(const Key('login_submit_button')),
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('bloqueado temporalmente por 15 minutos'),
          findsOneWidget,
        );
        expect(store.activeUser, isNull);

        // Advance clock by 16 minutes using DemoTenantToolbar (+15m twice)
        await tester.tap(find.text('+15m'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('+15m'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const Key('login_submit_button')),
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        expect(store.activeUser?.id, 'usr-diego');
        expect(find.byType(NavigationBar), findsOneWidget);
      },
    );

    testWidgets(
      'CU-02 2a on LoginScreen: unverified account shows verification helper button',
      (tester) async {
        final (store, _) = await pumpAppAtRoute(tester, '/login');
        store.setActiveUser(null);
        final unverified = await store.registerUser(
          const RegisterUserInput(
            nombreUsuario: 'lucia_puebla',
            nombreLegal: 'Lucía Morales',
            correo: 'lucia@donaplus.app',
            telefono: '2224445566',
            password: 'Password1',
            ubicacionEtiqueta: 'Col. Centro, CP 72000',
            avisoPrivacidadAceptado: true,
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('login_identifier_field')),
          'lucia_puebla',
        );
        await tester.enterText(
          find.byKey(const Key('login_password_field')),
          'Password1',
        );
        await tester.ensureVisible(
          find.byKey(const Key('login_submit_button')),
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        expect(find.textContaining('verificar tu correo'), findsOneWidget);
        final verifyHelper = find.text('Simular verificación de correo (CU-02)');
        expect(verifyHelper, findsOneWidget);

        await tester.ensureVisible(verifyHelper);
        await tester.tap(verifyHelper);
        await tester.pumpAndSettle();

        expect(store.findUserById(unverified.id)?.correoVerificado, isTrue);

        await tester.ensureVisible(
          find.byKey(const Key('login_submit_button')),
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();
        expect(store.activeUser?.id, unverified.id);
      },
    );

    testWidgets(
      'CU-08: ResetPasswordScreen requests 30-min token, enforces RF-01 password rules, updates password, and rejects reused/expired tokens',
      (tester) async {
        final (store, _) = await pumpAppAtRoute(tester, '/login');
        store.setActiveUser(null);
        await tester.pumpAndSettle();

        // RNF-12: network error on login does not authenticate
        store.setSimulateNetworkError(true);
        await tester.enterText(
          find.byKey(const Key('login_identifier_field')),
          'diego.solidario',
        );
        await tester.enterText(
          find.byKey(const Key('login_password_field')),
          'DonaPlus1',
        );
        await tester.ensureVisible(
          find.byKey(const Key('login_submit_button')),
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            'No se pudo completar la operación por pérdida de conexión',
          ),
          findsOneWidget,
        );
        expect(store.activeUser, isNull);
        store.setSimulateNetworkError(false);
        await tester.pumpAndSettle();

        // Navigate via link on LoginScreen
        final forgotBtn = find.text('¿Olvidaste tu contraseña?');
        await tester.ensureVisible(forgotBtn);
        await tester.tap(forgotBtn);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('reset_email_field')),
          'diego@donaplus.app',
        );
        await tester.ensureVisible(
          find.text('Enviar enlace de restablecimiento'),
        );
        await tester.tap(find.text('Enviar enlace de restablecimiento'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Válido por 30 minutos y de un solo uso'),
          findsOneWidget,
        );
        final generatedToken = store.resetTokens.last.token;
        expect(find.textContaining(generatedToken), findsWidgets);

        // Weak password rejected (4b)
        await tester.enterText(
          find.byKey(const Key('reset_new_password_field')),
          'weak',
        );
        await tester.ensureVisible(find.text('Actualizar contraseña'));
        await tester.tap(find.text('Actualizar contraseña'));
        await tester.pumpAndSettle();
        expect(find.textContaining('8 caracteres'), findsWidgets);

        // Valid password updates password
        await tester.enterText(
          find.byKey(const Key('reset_new_password_field')),
          'DiegoReset2026',
        );
        await tester.ensureVisible(find.text('Actualizar contraseña'));
        await tester.tap(find.text('Actualizar contraseña'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Contraseña actualizada'),
          findsOneWidget,
        );

        // Reusing the same token is rejected (4a)
        await tester.enterText(
          find.byKey(const Key('reset_new_password_field')),
          'OtraClave2026',
        );
        await tester.ensureVisible(find.text('Actualizar contraseña'));
        await tester.tap(find.text('Actualizar contraseña'));
        await tester.pumpAndSettle();
        expect(find.textContaining('ya venció o ya fue utilizado'), findsOneWidget);

        // Request new token and advance clock past 30 min -> rejected (4a)
        await tester.ensureVisible(
          find.text('Enviar enlace de restablecimiento'),
        );
        await tester.tap(find.text('Enviar enlace de restablecimiento'));
        await tester.pumpAndSettle();
        store.advanceClock(const Duration(minutes: 31));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('reset_new_password_field')),
          'Expirada2026',
        );
        await tester.ensureVisible(find.text('Actualizar contraseña'));
        await tester.tap(find.text('Actualizar contraseña'));
        await tester.pumpAndSettle();
        expect(find.textContaining('ya venció o ya fue utilizado'), findsOneWidget);

        // New password works for login
        final logged = await store.login(
          usernameOrEmail: 'diego@donaplus.app',
          password: 'DiegoReset2026',
        );
        expect(logged.id, 'usr-diego');
      },
    );
  });

  group('ProfileScreen, Trust Profile, Reviews, Edit Profile & Logout (CU-03 to CU-06, CU-10)',
      () {
    testWidgets(
      'CU-03, CU-04, CU-05: shows Trust Profile metrics/badge & verified reviews for usr-alondra and missing thresholds for usr-diego',
      (tester) async {
        final (store, _) = await pumpAppAtRoute(tester, '/profile');

        // Alondra (default activeUser, admin, Trust Profile granted, 2 reviews)
        expect(
          find.text('Guadalupe Alondra Gutiérrez Paz'),
          findsOneWidget,
        );
        expect(find.text('@alondra.dona'), findsWidgets);
        expect(find.text('alondra.demo@donaplus.app'), findsOneWidget);
        expect(find.text('2221234457'), findsOneWidget);
        expect(find.text('Col. Centro, CP 72000'), findsWidgets);
        expect(find.text('Perfil de Confianza'), findsWidgets);
        expect(find.text('Donación verificada'), findsNWidgets(2));
        expect(find.text('Panel de Administración'), findsOneWidget);

        // Switch to Diego (no Trust Profile, missing 3 donations & 1 review, no reviews)
        store.setActiveUser('usr-diego');
        await tester.pumpAndSettle();

        expect(find.text('Diego Ramírez Soto'), findsOneWidget);
        expect(find.text('En progreso'), findsNothing); // TrustBadgeChip shows En progreso (...)
        expect(find.textContaining('En progreso'), findsOneWidget);
        expect(find.textContaining('3 donaciones'), findsOneWidget);
        expect(find.textContaining('1 reseña'), findsOneWidget);
        expect(find.text('Aún no has recibido reseñas'), findsOneWidget);
        expect(find.text('Solicitar rol de intermediario'), findsOneWidget);
        expect(find.text('Panel de Administración'), findsNothing);

        // Switch to Maria (authorized intermediary)
        store.setActiveUser('usr-maria');
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Intermediario comunitario autorizado'),
          findsOneWidget,
        );
        expect(find.text('Donación verificada'), findsOneWidget);
      },
    );

    testWidgets(
      'CU-06 & CU-10: EditProfileSheet keeps username/legalName read-only, handles cancel and network error, updates phone/photo/password, and logout navigates to /login',
      (tester) async {
        final (store, _) = await pumpAppAtRoute(tester, '/profile');
        store.setActiveUser('usr-diego');
        await tester.pumpAndSettle();

        // Open EditProfileSheet
        await tester.ensureVisible(find.text('Editar perfil'));
        await tester.tap(find.text('Editar perfil'));
        await tester.pumpAndSettle();

        // Verify read-only username & legal name fields
        final usernameField = tester.widget<TextFormField>(
          find.byKey(const Key('edit_profile_username_field')),
        );
        final legalNameField = tester.widget<TextFormField>(
          find.byKey(const Key('edit_profile_legal_name_field')),
        );
        expect(usernameField.enabled, isFalse);
        expect(legalNameField.enabled, isFalse);

        // Modify phone and cancel (4a) -> no changes saved
        await tester.enterText(
          find.byKey(const Key('edit_profile_phone_field')),
          '2220001122',
        );
        await tester.ensureVisible(find.text('Cancelar'));
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(store.findUserById('usr-diego')?.telefono, '2225550199');

        // Open again, test network error (5b / RNF-12)
        await tester.ensureVisible(find.text('Editar perfil'));
        await tester.tap(find.text('Editar perfil'));
        await tester.pumpAndSettle();

        store.setSimulateNetworkError(true);
        await tester.enterText(
          find.byKey(const Key('edit_profile_phone_field')),
          '2229998877',
        );
        await tester.ensureVisible(find.text('Guardar cambios'));
        await tester.tap(find.text('Guardar cambios'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'No se pudo completar la operación por pérdida de conexión',
          ),
          findsOneWidget,
        );
        expect(store.findUserById('usr-diego')?.telefono, '2225550199');

        // Recover network, select avatar, update phone & optional password
        store.setSimulateNetworkError(false);
        await tester.tap(find.text('Avatar Solidaridad'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('edit_profile_password_field')),
          'DiegoNuevo1',
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Guardar cambios'));
        await tester.tap(find.text('Guardar cambios'));
        await tester.pumpAndSettle();

        final updatedDiego = store.findUserById('usr-diego')!;
        expect(updatedDiego.telefono, '2229998877');
        expect(updatedDiego.fotoPerfil, isNotNull);

        // Let floating SnackBar clear before tapping Cerrar sesión
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        // CU-10: Logout -> clears activeUser and routes to /login
        final logoutBtn = find.text('Cerrar sesión');
        await tester.ensureVisible(logoutBtn);
        await tester.tap(logoutBtn);
        await tester.pumpAndSettle();

        expect(store.activeUser, isNull);
        expect(find.byKey(const Key('login_identifier_field')), findsOneWidget);

        // Verify updated password from CU-06 works for login
        await tester.enterText(
          find.byKey(const Key('login_identifier_field')),
          'diego.solidario',
        );
        await tester.enterText(
          find.byKey(const Key('login_password_field')),
          'DiegoNuevo1',
        );
        await tester.ensureVisible(
          find.byKey(const Key('login_submit_button')),
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();
        expect(store.activeUser?.id, 'usr-diego');
      },
    );

    testWidgets(
      'RNF-03: Auth and Profile screens have no overflow on 390x844 at 1.25x text scale and high contrast',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final (store, container) = await pumpAppAtRoute(tester, '/');
        final router = container.read(appRouterProvider);

        await tester.tap(find.text('Accesibilidad'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ampliado (1.25x)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Alto contraste'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Cerrar'));
        await tester.pumpAndSettle();

        for (final route in ['/profile', '/login', '/register', '/reset-password']) {
          router.go(route);
          await tester.pumpAndSettle();
        }

        // Also check ProfileScreen for usr-diego and EditProfileSheet at 1.25x + high contrast
        store.setActiveUser('usr-diego');
        router.go('/profile');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Editar perfil'));
        await tester.tap(find.text('Editar perfil'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Cancelar'));
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
      },
    );
  });
}

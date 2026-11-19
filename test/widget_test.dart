import 'package:donaciones/app/router.dart';
import 'package:donaciones/app/theme.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/widgets/notifications_sheet.dart';
import 'package:donaciones/core/widgets/trust_badge_chip.dart';
import 'package:donaciones/features/donations/presentation/donations_hub_screen.dart';
import 'package:donaciones/features/matching/presentation/matches_screen.dart';
import 'package:donaciones/features/profile/presentation/profile_screen.dart';
import 'package:donaciones/features/publications/presentation/create_publication_screen.dart';
import 'package:donaciones/features/publications/presentation/feed_screen.dart';
import 'package:donaciones/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'DonaPlusApp renders DemoTenantToolbar, Accesibilidad chip, notifications bell, and 5 bottom tabs',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: DonaPlusApp()));
      await tester.pumpAndSettle();

      // DemoTenantToolbar controls
      expect(find.textContaining('Simular fallo de red'), findsOneWidget);
      expect(find.text('+15m'), findsOneWidget);
      expect(find.text('+7d'), findsOneWidget);
      expect(find.text('+15d'), findsOneWidget);
      expect(find.text('Reiniciar'), findsOneWidget);

      // Header controls
      expect(find.text('Accesibilidad'), findsOneWidget);
      expect(find.byType(NotificationsBellButton), findsOneWidget);

      // 5 bottom navigation destinations
      final navBar = find.byType(NavigationBar);
      expect(navBar, findsOneWidget);
      expect(
        find.descendant(of: navBar, matching: find.text('Inicio')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: navBar, matching: find.text('Coincidencias')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: navBar, matching: find.text('Publicar')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: navBar, matching: find.text('Donaciones')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: navBar, matching: find.text('Perfil')),
        findsOneWidget,
      );

      // Initial Inicio tab renders FeedScreen content
      expect(find.byType(FeedScreen), findsOneWidget);
      expect(find.text('¿Cómo podemos ayudarte hoy?'), findsOneWidget);

      // Verify switching each of the 5 bottom tabs renders its destination screen content
      await tester.tap(
        find.descendant(of: navBar, matching: find.text('Coincidencias')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MatchesScreen), findsOneWidget);
      expect(find.textContaining('Coincidencias ('), findsOneWidget);

      await tester.tap(
        find.descendant(of: navBar, matching: find.text('Publicar')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CreatePublicationScreen), findsOneWidget);
      expect(find.text('Crear publicación'), findsOneWidget);

      await tester.tap(
        find.descendant(of: navBar, matching: find.text('Donaciones')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DonationsHubScreen), findsOneWidget);
      expect(find.byKey(const Key('donations_tab_proposals')), findsOneWidget);

      await tester.tap(
        find.descendant(of: navBar, matching: find.text('Perfil')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Guadalupe Alondra Gutiérrez Paz'), findsOneWidget);

      await tester.tap(
        find.descendant(of: navBar, matching: find.text('Inicio')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FeedScreen), findsOneWidget);
      expect(find.text('¿Cómo podemos ayudarte hoy?'), findsOneWidget);
    },
  );

  testWidgets(
    'DemoTenantToolbar switches active user, toggles network error, and advances/resets clock',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: DonaPlusApp()));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DonaPlusApp)),
      );
      final store = container.read(mockTenantStoreProvider);
      final initialTime = store.currentTime;

      expect(store.activeUser?.id, 'usr-alondra');
      expect(find.text('@alondra.dona'), findsOneWidget);

      // Switch to @maria.lopez
      await tester.tap(find.text('@alondra.dona'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('@maria.lopez').last);
      await tester.pumpAndSettle();
      expect(store.activeUser?.id, 'usr-maria');

      // Switch to Sin sesión
      await tester.tap(find.text('@maria.lopez'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sin sesión').last);
      await tester.pumpAndSettle();
      expect(store.activeUser, isNull);

      // Toggle simulateNetworkError
      expect(store.simulateNetworkError, isFalse);
      await tester.tap(find.textContaining('Simular fallo de red'));
      await tester.pumpAndSettle();
      expect(store.simulateNetworkError, isTrue);

      // Advance clock with +15m, +7d, +15d
      await tester.tap(find.text('+15m'));
      await tester.pumpAndSettle();
      expect(store.currentTime, initialTime.add(const Duration(minutes: 15)));

      await tester.tap(find.text('+7d'));
      await tester.pumpAndSettle();
      expect(
        store.currentTime,
        initialTime.add(const Duration(minutes: 15, days: 7)),
      );

      await tester.tap(find.text('+15d'));
      await tester.pumpAndSettle();
      expect(
        store.currentTime,
        initialTime.add(const Duration(minutes: 15, days: 22)),
      );

      // Reset demo state
      await tester.tap(find.text('Reiniciar'));
      await tester.pumpAndSettle();
      expect(store.currentTime, initialTime);
      expect(store.activeUser?.id, 'usr-alondra');
      expect(store.simulateNetworkError, isFalse);
    },
  );

  testWidgets(
    'Accessibility chip opens AccessibilitySheet and updates text scale, high contrast, and reduce motion',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: DonaPlusApp()));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DonaPlusApp)),
      );

      expect(container.read(accessibilityProvider).textScaleFactor, 1.0);
      expect(container.read(accessibilityProvider).highContrast, isFalse);
      expect(container.read(accessibilityProvider).reduceMotion, isFalse);

      await tester.tap(find.text('Accesibilidad'));
      await tester.pumpAndSettle();

      expect(find.text('Tamaño de texto'), findsOneWidget);
      expect(find.text('Normal (1.0x)'), findsOneWidget);
      expect(find.text('Ampliado (1.25x)'), findsOneWidget);
      expect(find.text('Alto contraste'), findsOneWidget);
      expect(find.text('Reducir animaciones'), findsOneWidget);

      await tester.tap(find.text('Ampliado (1.25x)'));
      await tester.pumpAndSettle();
      expect(container.read(accessibilityProvider).textScaleFactor, 1.25);

      final navBarContext = tester.element(find.byType(NavigationBar));
      expect(
        MediaQuery.textScalerOf(navBarContext),
        const TextScaler.linear(1.25),
      );

      await tester.tap(find.text('Alto contraste'));
      await tester.pumpAndSettle();
      expect(container.read(accessibilityProvider).highContrast, isTrue);

      await tester.tap(find.text('Reducir animaciones'));
      await tester.pumpAndSettle();
      expect(container.read(accessibilityProvider).reduceMotion, isTrue);
    },
  );

  testWidgets(
    'NotificationsBellButton opens NotificationsSheet and marks notifications as read',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: DonaPlusApp()));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DonaPlusApp)),
      );
      final store = container.read(mockTenantStoreProvider);

      // Generate a real notification for usr-maria by sending a proposal from usr-alondra
      await store.createRequestProposal(
        publicationId: 'pub-3',
        senderId: 'usr-alondra',
        message: 'Me interesa recoger la mesa para una familia.',
        clientKey: 'test-notif-key',
      );
      store.setActiveUser('usr-maria');
      await tester.pumpAndSettle();

      expect(
        store.getNotificationsForUser('usr-maria').where((n) => !n.leida),
        isNotEmpty,
      );

      await tester.tap(find.byType(NotificationsBellButton));
      await tester.pumpAndSettle();

      expect(find.text('Notificaciones'), findsOneWidget);
      expect(find.textContaining('envió una solicitud'), findsOneWidget);

      // Tap notification to mark as read
      await tester.tap(find.textContaining('envió una solicitud'));
      await tester.pumpAndSettle();

      expect(
        store.getNotificationsForUser('usr-maria').where((n) => !n.leida),
        isEmpty,
      );
    },
  );

  testWidgets(
    'TrustBadgeChip shows Perfil de Confianza when granted and progress otherwise',
    (tester) async {
      final store = MockTenantStore();
      final alondra = store.findUserById('usr-alondra')!;
      final diego = store.findUserById('usr-diego')!;
      final sevenDonationsPendingReviews = diego.copyWith(
        id: 'usr-seven',
        donacionesFinalizadas: 7,
        numeroResenas: 2,
        promedioCalificacion: 4.9,
        perfilConfianzaOtorgado: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildDonaPlusTheme(highContrast: false, reduceMotion: false),
          home: Scaffold(
            body: Column(
              children: [
                TrustBadgeChip(usuario: alondra),
                TrustBadgeChip(usuario: diego),
                TrustBadgeChip(usuario: sevenDonationsPendingReviews),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Perfil de Confianza'), findsOneWidget);
      expect(find.textContaining('4.8'), findsOneWidget);
      expect(find.textContaining('12'), findsOneWidget);
      expect(find.textContaining('En progreso (2/5 donaciones'), findsOneWidget);
      expect(find.textContaining('7/5'), findsNothing);
      expect(
        find.textContaining('5/5 donaciones · 2/3 reseñas'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Shell layout has no overflow on mobile viewport at 1.25x text scale and all routes resolve',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const ProviderScope(child: DonaPlusApp()));
      await tester.pumpAndSettle();

      // Enable 1.25x text scale and high contrast on mobile width
      await tester.tap(find.text('Accesibilidad'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ampliado (1.25x)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alto contraste'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();

      // Verify standalone routes resolve cleanly via GoRouter
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DonaPlusApp)),
      );
      final router = container.read(appRouterProvider);

      for (final path in [
        '/login',
        '/register',
        '/reset-password',
        '/publications/pub-1',
        '/donations/don-hist-1',
        '/admin',
      ]) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );
}

import 'package:donaciones/app/router.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/features/publications/presentation/create_publication_screen.dart';
import 'package:donaciones/features/publications/presentation/publish_need_form.dart';
import 'package:donaciones/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Future<void> switchToNeedTab(WidgetTester tester) async {
    final needToggle = find.byKey(const Key('create_mode_need'));
    expect(needToggle, findsOneWidget);
    await tapVisible(tester, needToggle);
    expect(find.byType(PublishNeedForm), findsOneWidget);
  }

  group('CU-11, CU-12, CU-13: Publicar Necesidad', () {
    testWidgets(
      'TC-CU11-01: flujo principal completo crea Necesidad ACTIVA con categoría y urgencia y aparece en el feed',
      (tester) async {
        final (store, container) = await pumpAppAtRoute(tester, '/create');
        expect(find.byType(CreatePublicationScreen), findsOneWidget);
        await switchToNeedTab(tester);

        await tester.enterText(
          find.byKey(const Key('need_title_field')),
          'Cobijas térmicas',
        );
        await tester.enterText(
          find.byKey(const Key('need_description_field')),
          'Para temporada invernal',
        );

        await tester.ensureVisible(
          find.byKey(const Key('need_category_dropdown')),
        );
        await tester.tap(find.byKey(const Key('need_category_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ropa').last);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('need_quantity_field')),
          '2',
        );
        await tester.enterText(
          find.byKey(const Key('need_details_field')),
          'Matrimonial',
        );

        await tester.ensureVisible(find.byKey(const Key('need_urgency_alta')));
        await tester.tap(find.byKey(const Key('need_urgency_alta')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('need_location_field')),
          'Col. Centro, CP 72000',
        );

        await tester.ensureVisible(find.byKey(const Key('need_submit_button')));
        await tester.tap(find.byKey(const Key('need_submit_button')));
        await tester.pumpAndSettle();

        expect(find.textContaining('Necesidad publicada'), findsWidgets);

        final created = store.publications.firstWhere(
          (p) => p.titulo == 'Cobijas térmicas',
        );
        expect(created.tipo, TipoPublicacion.necesidad);
        expect(created.estado, EstadoPublicacion.activa);
        expect(created.categoriaId, 'cat-ropa');
        expect(created.cantidad, 2);
        expect(created.condicion, isNull);
        expect(created.urgencia, Urgencia.alta);
        expect(created.caracteristicas['Detalles'], 'Matrimonial');

        // Appears immediately on FeedScreen
        container.read(appRouterProvider).go('/');
        await tester.pumpAndSettle();
        expect(find.text('Cobijas térmicas'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-CU11-02: flujo alterno 7a bloquea envío cuando falta título o descripción obligatoria',
      (tester) async {
        final (store, _) = await pumpAppAtRoute(tester, '/create');
        await switchToNeedTab(tester);
        final initialCount = store.publications.length;

        // Leave title & description empty, fill category and urgency
        await tester.ensureVisible(
          find.byKey(const Key('need_category_dropdown')),
        );
        await tester.tap(find.byKey(const Key('need_category_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ropa').last);
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byKey(const Key('need_urgency_media')));
        await tester.tap(find.byKey(const Key('need_urgency_media')));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byKey(const Key('need_submit_button')));
        await tester.tap(find.byKey(const Key('need_submit_button')));
        await tester.pumpAndSettle();

        expect(
          find.text('El nombre del artículo requerido es obligatorio.'),
          findsOneWidget,
        );
        expect(
          find.text('La descripción de la necesidad es obligatoria.'),
          findsOneWidget,
        );
        expect(store.publications.length, initialCount);
      },
    );

    testWidgets(
      'TC-CU11-03: CU-12 flujo alterno 2a impide publicar si no se selecciona nivel de urgencia',
      (tester) async {
        final (store, _) = await pumpAppAtRoute(tester, '/create');
        await switchToNeedTab(tester);
        final initialCount = store.publications.length;

        await tester.enterText(
          find.byKey(const Key('need_title_field')),
          'Colchón individual',
        );
        await tester.enterText(
          find.byKey(const Key('need_description_field')),
          'Para adulto mayor',
        );

        await tester.ensureVisible(
          find.byKey(const Key('need_category_dropdown')),
        );
        await tester.tap(find.byKey(const Key('need_category_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Artículos para el hogar').last);
        await tester.pumpAndSettle();

        // Do not pick urgency
        await tester.ensureVisible(find.byKey(const Key('need_submit_button')));
        await tester.tap(find.byKey(const Key('need_submit_button')));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('nivel de urgencia'),
          findsWidgets,
        );
        expect(store.publications.length, initialCount);
      },
    );

    testWidgets(
      'TC-CU11-04: CU-13 solo ofrece las 5 categorías activas (excluye Electrónica antigua) y bloquea envío sin categoría',
      (tester) async {
        final (store, _) = await pumpAppAtRoute(tester, '/create');
        await switchToNeedTab(tester);
        final initialCount = store.publications.length;

        // Open dropdown and verify active categories only
        await tester.ensureVisible(
          find.byKey(const Key('need_category_dropdown')),
        );
        await tester.tap(find.byKey(const Key('need_category_dropdown')));
        await tester.pumpAndSettle();

        expect(find.text('Salud'), findsWidgets);
        expect(find.text('Educación'), findsWidgets);
        expect(find.text('Alimentación'), findsWidgets);
        expect(find.text('Ropa'), findsWidgets);
        expect(find.text('Artículos para el hogar'), findsWidgets);
        expect(find.text('Electrónica antigua'), findsNothing);

        // Dismiss dropdown without choosing
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('need_title_field')),
          'Despensa familiar',
        );
        await tester.enterText(
          find.byKey(const Key('need_description_field')),
          'Alimentos básicos',
        );
        await tapVisible(tester, find.byKey(const Key('need_urgency_baja')));
        await tapVisible(tester, find.byKey(const Key('need_submit_button')));

        expect(
          find.text('Debes seleccionar una categoría activa.'),
          findsOneWidget,
        );
        expect(store.publications.length, initialCount);
      },
    );

    testWidgets(
      'TC-CU11-05: flujo alterno 6a protege privacidad de domicilio (RNF-09) y exige colonia o CP',
      (tester) async {
        final (store, _) = await pumpAppAtRoute(tester, '/create');
        await switchToNeedTab(tester);
        final initialCount = store.publications.length;

        expect(
          find.textContaining('Solo colonia o CP, nunca domicilio exacto'),
          findsOneWidget,
        );
        expect(find.textContaining('Calle y número'), findsNothing);

        await tester.enterText(
          find.byKey(const Key('need_title_field')),
          'Bastón ortopédico',
        );
        await tester.enterText(
          find.byKey(const Key('need_description_field')),
          'Con soporte firme',
        );
        await tester.ensureVisible(
          find.byKey(const Key('need_category_dropdown')),
        );
        await tester.tap(find.byKey(const Key('need_category_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Salud').last);
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byKey(const Key('need_urgency_alta')));
        await tester.tap(find.byKey(const Key('need_urgency_alta')));
        await tester.pumpAndSettle();

        // Clear prefilled approximate location
        await tester.enterText(find.byKey(const Key('need_location_field')), '');
        await tester.ensureVisible(find.byKey(const Key('need_submit_button')));
        await tester.tap(find.byKey(const Key('need_submit_button')));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('colonia o código postal'),
          findsWidgets,
        );
        expect(store.publications.length, initialCount);
      },
    );

    testWidgets(
      'TC-CU11-06: flujo alterno 8a ante pérdida de conexión (RNF-12) no publica la Necesidad',
      (tester) async {
        final (store, _) = await pumpAppAtRoute(tester, '/create');
        await switchToNeedTab(tester);
        final initialCount = store.publications.length;

        await tester.enterText(
          find.byKey(const Key('need_title_field')),
          'Suéter escolar',
        );
        await tester.enterText(
          find.byKey(const Key('need_description_field')),
          'Talla 10 color azul marino',
        );
        await tester.ensureVisible(
          find.byKey(const Key('need_category_dropdown')),
        );
        await tester.tap(find.byKey(const Key('need_category_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ropa').last);
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byKey(const Key('need_urgency_media')));
        await tester.tap(find.byKey(const Key('need_urgency_media')));
        await tester.pumpAndSettle();

        store.setSimulateNetworkError(true);
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byKey(const Key('need_submit_button')));
        await tester.tap(find.byKey(const Key('need_submit_button')));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'No se pudo completar la operación por pérdida de conexión',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Necesidad publicada'), findsNothing);
        expect(store.publications.length, initialCount);
      },
    );

    testWidgets(
      'TC-CU11-07: formulario de Necesidad se reinicia tras publicar y evita duplicar al volver a enviar',
      (tester) async {
        final (store, _) = await pumpAppAtRoute(tester, '/create');
        await switchToNeedTab(tester);
        final initialCount = store.publications.length;

        await tester.enterText(
          find.byKey(const Key('need_title_field')),
          'Colchoneta ortopédica',
        );
        await tester.enterText(
          find.byKey(const Key('need_description_field')),
          'Para recuperación en casa',
        );
        await tester.ensureVisible(
          find.byKey(const Key('need_category_dropdown')),
        );
        await tester.tap(find.byKey(const Key('need_category_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Salud').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('need_quantity_field')),
          '4',
        );
        await tapVisible(tester, find.byKey(const Key('need_urgency_media')));
        await tapVisible(tester, find.byKey(const Key('need_submit_button')));

        expect(store.publications.length, initialCount + 1);
        expect(find.textContaining('Necesidad publicada'), findsWidgets);

        final titleField = tester.widget<TextFormField>(
          find.byKey(const Key('need_title_field')),
        );
        final descField = tester.widget<TextFormField>(
          find.byKey(const Key('need_description_field')),
        );
        final qtyField = tester.widget<TextFormField>(
          find.byKey(const Key('need_quantity_field')),
        );
        expect(titleField.controller?.text, isEmpty);
        expect(descField.controller?.text, isEmpty);
        expect(qtyField.controller?.text, '1');

        await tapVisible(tester, find.byKey(const Key('need_submit_button')));
        expect(store.publications.length, initialCount + 1);
        expect(
          find.text('El nombre del artículo requerido es obligatorio.'),
          findsOneWidget,
        );
      },
    );
  });
}

import 'package:donaciones/app/router.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/features/publications/presentation/publish_item_form.dart';
import 'package:donaciones/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<(MockTenantStore, ProviderContainer)> pumpAppAtCreateItem(
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DonaPlusApp()));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DonaPlusApp)),
    );
    final store = container.read(mockTenantStoreProvider);
    final router = container.read(appRouterProvider);
    router.go('/create');
    await tester.pumpAndSettle();

    final itemToggle = find.byKey(const Key('create_mode_item'));
    expect(itemToggle, findsOneWidget);
    await tester.ensureVisible(itemToggle);
    await tester.tap(itemToggle);
    await tester.pumpAndSettle();
    expect(find.byType(PublishItemForm), findsOneWidget);

    return (store, container);
  }

  group('CU-14 & CU-13: Publicar Artículo', () {
    testWidgets(
      'TC-CU14-01: flujo principal completo crea Artículo ACTIVA con 2 fotos y aparece en el listado',
      (tester) async {
        final (store, container) = await pumpAppAtCreateItem(tester);

        // Add 2 photos
        await tester.ensureVisible(
          find.byKey(const Key('item_add_photo_button')),
        );
        await tester.tap(find.byKey(const Key('item_add_photo_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('item_add_photo_button')));
        await tester.pumpAndSettle();
        expect(find.textContaining('2/5'), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('item_title_field')),
          'Bicicleta urbana',
        );
        await tester.enterText(
          find.byKey(const Key('item_description_field')),
          'Rodada 26 en buen estado',
        );

        await tester.ensureVisible(
          find.byKey(const Key('item_category_dropdown')),
        );
        await tester.tap(find.byKey(const Key('item_category_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Salud').last);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('item_quantity_field')),
          '1',
        );

        await tester.ensureVisible(
          find.byKey(const Key('item_condition_comoNuevo')),
        );
        await tester.tap(find.byKey(const Key('item_condition_comoNuevo')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('item_location_field')),
          'Col. Centro, CP 72000',
        );

        await tester.ensureVisible(find.byKey(const Key('item_submit_button')));
        await tester.tap(find.byKey(const Key('item_submit_button')));
        await tester.pumpAndSettle();

        expect(find.textContaining('Artículo publicado'), findsWidgets);

        final created = store.publications.firstWhere(
          (p) => p.titulo == 'Bicicleta urbana',
        );
        expect(created.tipo, TipoPublicacion.articulo);
        expect(created.estado, EstadoPublicacion.activa);
        expect(created.fotografias.length, 2);
        expect(created.categoriaId, 'cat-salud');
        expect(created.condicion, CondicionArticulo.comoNuevo);

        // Appears on FeedScreen
        container.read(appRouterProvider).go('/');
        await tester.pumpAndSettle();
        expect(find.text('Bicicleta urbana'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-CU14-02: flujo alterno 3a rechaza publicar Artículo con 0 fotografías',
      (tester) async {
        final (store, _) = await pumpAppAtCreateItem(tester);
        final initialCount = store.publications.length;

        await tester.enterText(
          find.byKey(const Key('item_title_field')),
          'Lámpara de escritorio',
        );
        await tester.enterText(
          find.byKey(const Key('item_description_field')),
          'Luz cálida funcional',
        );
        await tester.ensureVisible(
          find.byKey(const Key('item_category_dropdown')),
        );
        await tester.tap(find.byKey(const Key('item_category_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Artículos para el hogar').last);
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byKey(const Key('item_submit_button')));
        await tester.tap(find.byKey(const Key('item_submit_button')));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('primera fotografía'),
          findsWidgets,
        );
        expect(store.publications.length, initialCount);
      },
    );

    testWidgets(
      'TC-CU14-03: flujo alterno 3b impide agregar más de 5 fotografías y muestra 5/5',
      (tester) async {
        await pumpAppAtCreateItem(tester);

        final addButtonFinder = find.byKey(const Key('item_add_photo_button'));
        for (var i = 0; i < 5; i++) {
          await tester.ensureVisible(addButtonFinder);
          await tester.tap(addButtonFinder);
          await tester.pumpAndSettle();
        }

        expect(find.textContaining('5/5'), findsWidgets);
        final addButton = tester.widget<ButtonStyleButton>(addButtonFinder);
        expect(addButton.enabled, isFalse);

        // Attempting a 6th tap keeps 5/5 and does not show 6/5
        await tester.tap(addButtonFinder, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.textContaining('6/5'), findsNothing);
        expect(find.textContaining('5/5'), findsWidgets);
      },
    );

    testWidgets(
      'TC-CU14-04: flujo alterno 7a y CU-13 2a valida datos obligatorios y solo muestra categorías activas',
      (tester) async {
        final (store, _) = await pumpAppAtCreateItem(tester);
        final initialCount = store.publications.length;

        // Add 1 photo
        await tester.ensureVisible(
          find.byKey(const Key('item_add_photo_button')),
        );
        await tester.tap(find.byKey(const Key('item_add_photo_button')));
        await tester.pumpAndSettle();

        // Check category dropdown excludes Electrónica antigua
        await tester.ensureVisible(
          find.byKey(const Key('item_category_dropdown')),
        );
        await tester.tap(find.byKey(const Key('item_category_dropdown')));
        await tester.pumpAndSettle();
        expect(find.text('Electrónica antigua'), findsNothing);
        expect(find.text('Salud'), findsWidgets);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        // Submit without title, description, or category
        await tester.ensureVisible(find.byKey(const Key('item_submit_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('item_submit_button')));
        await tester.pumpAndSettle();

        expect(
          find.text('El nombre del artículo es obligatorio.'),
          findsOneWidget,
        );
        expect(
          find.text('Debes seleccionar una categoría activa.'),
          findsOneWidget,
        );
        expect(store.publications.length, initialCount);
      },
    );

    testWidgets(
      'TC-CU14-05: flujo alterno 8a ante pérdida de conexión (RNF-12) no publica el Artículo',
      (tester) async {
        final (store, _) = await pumpAppAtCreateItem(tester);
        final initialCount = store.publications.length;

        await tester.ensureVisible(
          find.byKey(const Key('item_add_photo_button')),
        );
        await tester.tap(find.byKey(const Key('item_add_photo_button')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('item_title_field')),
          'Cafetera eléctrica',
        );
        await tester.enterText(
          find.byKey(const Key('item_description_field')),
          'Capacidad 8 tazas',
        );
        await tester.ensureVisible(
          find.byKey(const Key('item_category_dropdown')),
        );
        await tester.tap(find.byKey(const Key('item_category_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Artículos para el hogar').last);
        await tester.pumpAndSettle();

        store.setSimulateNetworkError(true);
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byKey(const Key('item_submit_button')));
        await tester.tap(find.byKey(const Key('item_submit_button')));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'No se pudo completar la operación por pérdida de conexión',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Artículo publicado'), findsNothing);
        expect(store.publications.length, initialCount);
      },
    );

    testWidgets(
      'TC-CU14-06: selector secundario de galería/muestra agrega fotos y el formulario se reinicia tras publicar sin duplicar',
      (tester) async {
        final (store, _) = await pumpAppAtCreateItem(tester);
        final initialCount = store.publications.length;

        // Open secondary photo source picker sheet
        await tester.ensureVisible(
          find.byKey(const Key('item_pick_photo_source_button')),
        );
        await tester.tap(find.byKey(const Key('item_pick_photo_source_button')));
        await tester.pumpAndSettle();

        expect(
          find.text('Elegir foto de muestra del tenant'),
          findsOneWidget,
        );
        final galleryTile = find.text(
          'Seleccionar desde galería del dispositivo',
        );
        await tester.ensureVisible(galleryTile);
        await tester.pumpAndSettle();
        await tester.tap(galleryTile);
        await tester.pumpAndSettle();
        expect(find.textContaining('1/5'), findsOneWidget);

        // Pick a tenant sample from the secondary sheet as well
        await tester.ensureVisible(
          find.byKey(const Key('item_pick_photo_source_button')),
        );
        await tester.tap(find.byKey(const Key('item_pick_photo_source_button')));
        await tester.pumpAndSettle();
        final sampleTile = find.text('sample://silla_ruedas.jpg');
        await tester.ensureVisible(sampleTile);
        await tester.pumpAndSettle();
        await tester.tap(sampleTile);
        await tester.pumpAndSettle();
        expect(find.textContaining('2/5'), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('item_title_field')),
          'Andadera plegable',
        );
        await tester.enterText(
          find.byKey(const Key('item_description_field')),
          'Estructura ligera de aluminio',
        );
        await tester.ensureVisible(
          find.byKey(const Key('item_category_dropdown')),
        );
        await tester.tap(find.byKey(const Key('item_category_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Salud').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('item_quantity_field')),
          '3',
        );

        await tester.ensureVisible(find.byKey(const Key('item_submit_button')));
        await tester.tap(find.byKey(const Key('item_submit_button')));
        await tester.pumpAndSettle();

        expect(store.publications.length, initialCount + 1);
        final created = store.publications.last;
        expect(created.titulo, 'Andadera plegable');
        expect(
          created.fotografias,
          ['device://galeria_1.jpg', 'sample://silla_ruedas.jpg'],
        );

        // Success banner remains visible while draft inputs are reset
        expect(find.textContaining('Artículo publicado'), findsWidgets);
        expect(find.textContaining('0/5'), findsOneWidget);
        final titleField = tester.widget<TextFormField>(
          find.byKey(const Key('item_title_field')),
        );
        final descField = tester.widget<TextFormField>(
          find.byKey(const Key('item_description_field')),
        );
        final qtyField = tester.widget<TextFormField>(
          find.byKey(const Key('item_quantity_field')),
        );
        expect(titleField.controller?.text, isEmpty);
        expect(descField.controller?.text, isEmpty);
        expect(qtyField.controller?.text, '1');

        // Re-tapping submit immediately blocks empty form instead of duplicating
        await tester.ensureVisible(find.byKey(const Key('item_submit_button')));
        await tester.tap(find.byKey(const Key('item_submit_button')));
        await tester.pumpAndSettle();
        expect(store.publications.length, initialCount + 1);
        expect(
          find.text('El nombre del artículo es obligatorio.'),
          findsOneWidget,
        );
        expect(
          find.text('La primera fotografía del artículo es obligatoria.'),
          findsOneWidget,
        );
      },
    );
  });
}

import 'package:donaciones/app/router.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/core/models/dto_inputs.dart';
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
      'Alimentación cambia el cuestionario y guarda la presentación',
      (tester) async {
        final (store, container) = await pumpAppAtCreateItem(tester);
        final initialCount = store.publications.length;
        final category = find.byKey(const Key('item_category_dropdown'));
        final title = find.byKey(const Key('item_title_field'));
        final description = find.byKey(const Key('item_description_field'));
        final package = find.byKey(const Key('item_food_package_field'));
        final expiration = find.byKey(const Key('item_food_expiration_field'));
        final condition = find.byKey(const Key('item_condition_nuevo'));
        final quantity = find.byKey(const Key('item_quantity_field'));
        final submit = find.byKey(const Key('item_submit_button'));

        Future<void> tapVisible(Finder finder) async {
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        expect(
          tester.getTopLeft(category).dy,
          greaterThan(tester.getTopLeft(title).dy),
        );
        expect(
          tester.getTopLeft(category).dy,
          lessThan(tester.getTopLeft(description).dy),
        );
        expect(condition, findsOneWidget);
        expect(expiration, findsNothing);
        await tapVisible(find.byKey(const Key('item_add_photo_button')));
        await tester.enterText(title, 'Atún en agua');

        await tapVisible(category);
        await tapVisible(find.text('Alimentación').last);
        expect(package, findsOneWidget);
        expect(expiration, findsOneWidget);
        expect(condition, findsNothing);
        expect(find.text('Número de envases *'), findsOneWidget);
        await tester.enterText(description, 'Envases cerrados');

        await tapVisible(submit);
        expect(
          find.text('Selecciona la presentación del alimento.'),
          findsOneWidget,
        );
        expect(store.publications.length, initialCount);

        await tapVisible(package);
        expect(find.text('Botellas'), findsOneWidget);
        expect(find.text('Sobres'), findsOneWidget);
        await tapVisible(find.text('Latas').last);
        await tester.enterText(
          find.byKey(const Key('item_food_package_content_field')),
          '140 g',
        );
        await tester.enterText(quantity, '6');

        await tester.enterText(expiration, '31/02/2028');
        await tapVisible(submit);
        expect(
          find.text('Ingresa una fecha válida con el formato DD/MM/AAAA.'),
          findsOneWidget,
        );
        expect(store.publications.length, initialCount);
        await tester.enterText(expiration, '29/02/2028');

        await tapVisible(category);
        await tapVisible(find.text('Ropa').last);
        expect(package, findsNothing);
        expect(expiration, findsNothing);
        expect(condition, findsOneWidget);
        await tapVisible(category);
        await tapVisible(find.text('Alimentación').last);
        expect(find.text('Latas'), findsOneWidget);

        await tapVisible(submit);
        expect(store.publications.length, initialCount + 1);
        final created = store.publications.last;
        expect(created.titulo, 'Atún en agua');
        expect(created.cantidad, 6);
        expect(created.condicion, isNull);
        expect(created.caracteristicas, {
          'Presentación': 'Latas',
          'Contenido por envase': '140 g',
          'Fecha de caducidad': '29/02/2028',
        });
        expect(package, findsNothing);
        expect(condition, findsOneWidget);

        container.read(appRouterProvider).go('/publications/${created.id}');
        await tester.pumpAndSettle();
        expect(find.textContaining('Presentación: Latas'), findsOneWidget);
        expect(find.textContaining('Contenido por envase: 140 g'), findsOneWidget);
        expect(
          find.textContaining('Fecha de caducidad: 29/02/2028'),
          findsOneWidget,
        );
        expect(find.text('Estado físico'), findsNothing);
      },
    );

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

    testWidgets(
      'CU-16 Alimentación: EditPublicationSheet precarga, valida y actualiza presentación, contenido y caducidad, y maneja cambio de categoría',
      (tester) async {
        final (store, container) = await pumpAppAtCreateItem(tester);

        // Crear un artículo de Alimentación para editarlo
        final createdFood = await store.createItemPublication(
          const CreateItemInput(
            titulo: 'Arroz integral',
            descripcion: 'Sobres sellados',
            categoriaId: CategoriaMock.alimentacionId,
            fotografias: ['sample://despensa_1.jpg'],
            cantidad: 4,
            condicion: null,
            ubicacionEtiqueta: 'Col. Centro, CP 72000',
            caracteristicas: {
              'Presentación': 'Sobres',
              'Contenido por envase': '1 kg',
              'Fecha de caducidad': '15/10/2027',
            },
          ),
        );

        container.read(appRouterProvider).go('/publications/${createdFood.id}');
        await tester.pumpAndSettle();

        final editBtn = find.byKey(const Key('detail_edit_publication_button'));
        await tester.ensureVisible(editBtn);
        await tester.tap(editBtn);
        await tester.pumpAndSettle();

        final packageField = find.byKey(const Key('edit_pub_food_package_field'));
        final contentField =
            find.byKey(const Key('edit_pub_food_package_content_field'));
        final expirationField =
            find.byKey(const Key('edit_pub_food_expiration_field'));
        final saveBtn = find.byKey(const Key('edit_pub_save_button'));

        expect(packageField, findsOneWidget);
        expect(contentField, findsOneWidget);
        expect(expirationField, findsOneWidget);
        expect(find.text('Número de envases *'), findsOneWidget);
        expect(find.text('Sobres'), findsOneWidget);

        // Fecha de caducidad inválida es rechazada
        await tester.enterText(expirationField, '31/02/2028');
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();
        expect(
          find.text('Ingresa una fecha válida con el formato DD/MM/AAAA.'),
          findsOneWidget,
        );

        // Actualizar presentación, contenido y caducidad válida
        await tester.ensureVisible(packageField);
        await tester.pumpAndSettle();
        await tester.tap(packageField);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Latas').last);
        await tester.pumpAndSettle();
        await tester.enterText(contentField, '2 kg');
        await tester.enterText(expirationField, '20/12/2027');
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        final updatedFood = store.findPublicationById(createdFood.id)!;
        expect(updatedFood.condicion, isNull);
        expect(updatedFood.caracteristicas, {
          'Presentación': 'Latas',
          'Contenido por envase': '2 kg',
          'Fecha de caducidad': '20/12/2027',
        });

        // Reabrir edición y cambiar categoría de Alimentación a Ropa -> exige condición y limpia características de alimento
        await tester.ensureVisible(editBtn);
        await tester.tap(editBtn);
        await tester.pumpAndSettle();

        final catDropdown = find.byKey(const Key('edit_pub_category_dropdown'));
        await tester.ensureVisible(catDropdown);
        await tester.tap(catDropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ropa').last);
        await tester.pumpAndSettle();

        expect(packageField, findsNothing);
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();
        expect(
          find.text('Selecciona el estado físico del artículo.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Nuevo'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        final switchedToClothes = store.findPublicationById(createdFood.id)!;
        expect(switchedToClothes.categoriaId, 'cat-ropa');
        expect(switchedToClothes.condicion, CondicionArticulo.nuevo);
        expect(switchedToClothes.caracteristicas, isEmpty);

        // Reabrir edición en Ropa y cambiar de vuelta a Alimentación -> limpia condicion, exige presentación y limpia _condicionError
        await tester.ensureVisible(editBtn);
        await tester.tap(editBtn);
        await tester.pumpAndSettle();

        // Deseleccionar condición no aplica, pero cambiar categoría a Alimentación y luego volver a Ropa limpia _condicionError
        await tester.ensureVisible(catDropdown);
        await tester.tap(catDropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Alimentación').last);
        await tester.pumpAndSettle();

        expect(packageField, findsOneWidget);
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();
        expect(
          find.text('Selecciona la presentación del alimento.'),
          findsOneWidget,
        );

        await tester.ensureVisible(packageField);
        await tester.pumpAndSettle();
        await tester.tap(packageField);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Botellas').last);
        await tester.pumpAndSettle();
        await tester.enterText(contentField, '500 ml');
        await tester.enterText(expirationField, '10/05/2028');
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        final switchedBackToFood = store.findPublicationById(createdFood.id)!;
        expect(switchedBackToFood.categoriaId, CategoriaMock.alimentacionId);
        expect(switchedBackToFood.condicion, isNull);
        expect(switchedBackToFood.caracteristicas, {
          'Presentación': 'Botellas',
          'Contenido por envase': '500 ml',
          'Fecha de caducidad': '10/05/2028',
        });
      },
    );
  });
}

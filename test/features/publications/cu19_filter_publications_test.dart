import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/features/publications/presentation/publication_detail_screen.dart';
import 'package:donaciones/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<MockTenantStore> pumpFeed(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: DonaPlusApp()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DonaPlusApp)),
    );
    return container.read(mockTenantStoreProvider);
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('CU-19: Filtrar publicaciones por categoría y tipo', () {
    testWidgets(
      'TC-CU19-01: estado inicial muestra las 4 publicaciones activas y oculta cerradas o inactivas',
      (tester) async {
        await pumpFeed(tester);

        expect(find.text('Publicaciones disponibles (4)'), findsOneWidget);
        expect(find.text('Silla de ruedas plegable'), findsOneWidget);
        expect(find.text('Libros escolares de primaria'), findsOneWidget);
        expect(find.text('Mesa de comedor para 4 personas'), findsOneWidget);
        expect(find.text('Chaqueta de invierno talla M'), findsOneWidget);
        expect(find.text('Mochila escolar reforzada'), findsNothing);
        expect(find.text('Electrónica antigua'), findsNothing);
      },
    );

    testWidgets(
      'TC-CU19-02, TC-CU19-03, TC-CU19-04, TC-CU19-05, TC-CU19-06: filtra por categoría, tipo, ambos, estado vacío y Quitar filtros',
      (tester) async {
        await pumpFeed(tester);

        // TC-CU19-02: Filter only by category Salud
        await tapVisible(tester, find.byKey(const Key('feed_cat_cat-salud')));

        expect(find.text('Publicaciones disponibles (1)'), findsOneWidget);
        expect(find.text('Silla de ruedas plegable'), findsOneWidget);
        expect(find.text('Libros escolares de primaria'), findsNothing);
        expect(find.text('Mesa de comedor para 4 personas'), findsNothing);
        expect(find.text('Chaqueta de invierno talla M'), findsNothing);

        // Reset via Quitar filtros
        await tapVisible(
          tester,
          find.byKey(const Key('feed_clear_filters_button')),
        );
        expect(find.text('Publicaciones disponibles (4)'), findsOneWidget);

        // TC-CU19-03: Filter only by type Artículos
        await tapVisible(tester, find.byKey(const Key('feed_type_articulo')));

        expect(find.text('Publicaciones disponibles (2)'), findsOneWidget);
        expect(find.text('Mesa de comedor para 4 personas'), findsOneWidget);
        expect(find.text('Chaqueta de invierno talla M'), findsOneWidget);
        expect(find.text('Silla de ruedas plegable'), findsNothing);
        expect(find.text('Libros escolares de primaria'), findsNothing);

        // TC-CU19-04: Combined category Ropa + type Artículos
        await tapVisible(tester, find.byKey(const Key('feed_cat_cat-ropa')));

        expect(find.text('Publicaciones disponibles (1)'), findsOneWidget);
        expect(find.text('Chaqueta de invierno talla M'), findsOneWidget);
        expect(find.text('Mesa de comedor para 4 personas'), findsNothing);

        // TC-CU19-05: Empty state when Alimentación + Artículos has 0 results
        await tapVisible(
          tester,
          find.byKey(const Key('feed_cat_cat-alimentacion')),
        );

        expect(
          find.text('Ninguna publicación cumple los filtros seleccionados'),
          findsOneWidget,
        );

        // TC-CU19-06: Quitar filtros restores all 4 active publications
        await tapVisible(
          tester,
          find.byKey(const Key('feed_clear_filters_button')),
        );

        expect(find.text('Publicaciones disponibles (4)'), findsOneWidget);
        expect(find.text('Silla de ruedas plegable'), findsOneWidget);
        expect(find.text('Chaqueta de invierno talla M'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-CU19-07: tocar una tarjeta navega al detalle mostrando descripción, autor y botón de acción',
      (tester) async {
        await pumpFeed(tester);

        await tapVisible(tester, find.byKey(const Key('feed_pub_pub-1')));

        expect(find.byType(PublicationDetailScreen), findsOneWidget);
        expect(find.text('Silla de ruedas plegable'), findsOneWidget);
        expect(
          find.textContaining('Silla de ruedas en buen estado'),
          findsOneWidget,
        );
        expect(find.text('María López Hernández'), findsOneWidget);
        expect(find.text('Ofrecer artículo'), findsOneWidget);
      },
    );
  });
}

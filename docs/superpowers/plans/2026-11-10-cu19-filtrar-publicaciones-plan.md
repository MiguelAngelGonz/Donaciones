# CU-19 · Filtrar necesidades y artículos por categoría y tipo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar el listado principal de exploración (`FeedScreen`) y su controlador de filtrado (`FeedFilterController`) permitiendo filtrar publicaciones activas por categoría, por tipo (`Necesidad` / `Artículo`) o ambos a la vez, además de limpiar filtros (`2a`) y mostrar estado vacío (`3a`).

**Architecture:** `FeedFilterController` mantiene el estado inmutable `(selectedCategoryId, selectedType)` en Riverpod y consulta `MockTenantStore.filterActivePublications(categoryId: ..., type: ...)`. `FeedScreen` renderiza los chips de tipo, tarjetas de categoría y listado reactivo.

**Tech Stack:** Flutter (`sdk: ^3.13.5`), `flutter_riverpod`, `go_router`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-11-10-cu19-filtrar-publicaciones-design.md`

## Global Constraints

- **Solo publicaciones `ACTIVA`:** Publicaciones en estado `RESERVADA`, `CERRADA` o `RETIRADA` nunca aparecen en el listado (`TC-CU19-07`).
- **Combinación de filtros (`RF-07`):** Permite filtrar solo por categoría, solo por tipo, o ambos simultáneamente.
- **Flujo alterno `2a` (Quitar filtros):** Tocar el chip `Todos` o el botón `Limpiar filtros` restablece `(selectedCategoryId: null, selectedType: null)`.
- **Flujo alterno `3a` (Sin coincidencias):** Cuando la combinación devuelve 0 elementos, muestra el mensaje `No hay publicaciones activas que coincidan con los filtros seleccionados` y el botón `Limpiar filtros`.

## Review Focus

1. **Tocar de nuevo la categoría ya seleccionada:** Si el usuario toca la tarjeta `Salud` cuando ya está activa, debe deseleccionarla (`selectedCategoryId = null`) además de poder usar el botón `Limpiar filtros`.
2. **Exclusión inmediata al cambiar estado de publicación:** Si una publicación pasa de `ACTIVA` a `RESERVADA` o `CERRADA`, desaparece automáticamente del listado filtrado (`TC-CU19-07`).
3. **Nuevas publicaciones de `CU-11` o `CU-14` reflejadas al instante:** Al agregarse una Necesidad o Artículo en `MockTenantStore`, el feed actualizado lo incluye si coincide con el filtro activo.
4. **Distintivos visuales por tipo en cada tarjeta:** Las tarjetas de `Necesidad` muestran su nivel de urgencia (`Urgencia Alta/Media/Baja`) y las de `Artículo` muestran su condición (`Nuevo`, `Como nuevo`, `Usado`).
5. **Navegación al detalle (`/publications/:id`):** Tocar cualquier tarjeta abre `PublicationDetailScreen` para conectar con `CU-23` o `CU-24`.

---

### Task 1: `FeedFilterController` y Lógica de Combinación de Filtros

**Files:**
- Create: `lib/features/publications/presentation/feed_filter_controller.dart`
- Create: `test/features/publications/cu19_filter_publications_test.dart`

**Interfaces:**
- Consumes: `mockTenantStoreProvider`, `MockTenantStore.filterActivePublications`, `MockTenantStore.getCategoriesForFilter`.
- Produces:
  - `FeedFilterState` (`selectedCategoryId`, `selectedType`, `hasActiveFilters`).
  - `FeedFilterController` (`selectCategory(String? id)`, `selectType(TipoPublicacion? type)`, `clearFilters()`).
  - `filteredPublicationsProvider`.

- [ ] **Step 1: Write failing unit tests for `TC-CU19-01` through `TC-CU19-07` filter combinations in `test/features/publications/cu19_filter_publications_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/features/publications/presentation/feed_filter_controller.dart';

void main() {
  test('TC-CU19-01..07: filters by category, type, both, empty state, and excludes non-active', () {
    final store = MockTenantStore();
    final filter = FeedFilterController();

    // TC-CU19-01: Salud only -> pub-1
    filter.selectCategory('cat-salud');
    expect(
      store.filterActivePublications(categoryId: filter.state.selectedCategoryId).map((p) => p.id),
      ['pub-1'],
    );

    // TC-CU19-03: Salud + Necesidad -> pub-1
    filter.selectType(TipoPublicacion.necesidad);
    expect(
      store.filterActivePublications(
        categoryId: filter.state.selectedCategoryId,
        type: filter.state.selectedType,
      ).map((p) => p.id),
      ['pub-1'],
    );

    // TC-CU19-05: Alimentación (cat-alimentacion) -> empty (3a)
    filter.selectCategory('cat-alimentacion');
    filter.selectType(null);
    expect(store.filterActivePublications(categoryId: filter.state.selectedCategoryId), isEmpty);

    // TC-CU19-04: clearFilters -> all 4 seed publications
    filter.clearFilters();
    expect(store.filterActivePublications().length, 4);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/publications/cu19_filter_publications_test.dart`
Expected: FAIL (`feed_filter_controller.dart` not found).

- [ ] **Step 3: Implement `FeedFilterState` and `FeedFilterController` in `lib/features/publications/presentation/feed_filter_controller.dart`**

Implement `selectCategory` (toggling off if the same category is tapped again), `selectType`, `clearFilters`, and Riverpod providers watching `mockTenantStoreProvider`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/publications/cu19_filter_publications_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/publications/presentation/feed_filter_controller.dart test/features/publications/cu19_filter_publications_test.dart
git commit -m "feat(cu19): add FeedFilterController for category and type filtering"
```

---

### Task 2: Pantalla `FeedScreen` y Pruebas de Widget (`TC-CU19-01` a `TC-CU19-07`)

**Files:**
- Modify: `lib/features/publications/presentation/feed_screen.dart`
- Modify: `test/features/publications/cu19_filter_publications_test.dart`

**Interfaces:**
- Consumes: `feedFilterControllerProvider`, `filteredPublicationsProvider`, `mockTenantStoreProvider`.
- Produces: `const FeedScreen({super.key})`.

- [ ] **Step 1: Add widget tests for `TC-CU19-01` through `TC-CU19-07` in `test/features/publications/cu19_filter_publications_test.dart`**

```dart
testWidgets('TC-CU19-01..06 widget filtering, empty state (3a), and clear filters (2a)', (tester) async {
  // Pumps DonaPlusApp, taps 'Salud' category, taps 'Necesidades' chip,
  // taps 'Alimentación' to verify empty state message and 'Limpiar filtros' button,
  // and verifies tapping a card navigates to PublicationDetailScreen.
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/publications/cu19_filter_publications_test.dart`
Expected: FAIL (stub `FeedScreen` does not render category cards, type chips, or publication cards).

- [ ] **Step 3: Implement `FeedScreen` in `lib/features/publications/presentation/feed_screen.dart`**

Render the DonaPlus header (`¿Qué te gustaría hacer hoy?`), type filter chips (`Todos`, `Necesidades`, `Artículos`), horizontal category cards (`Salud`, `Educación`, `Alimentación`, `Ropa`, `Artículos para el hogar`), empty state view (`3a`) with `Limpiar filtros` button (`2a`), and publication cards navigating to `/publications/${pub.id}`.

- [ ] **Step 4: Run test to verify all 7 test cases (`TC-CU19-01` to `TC-CU19-07`) pass**

Run: `flutter test test/features/publications/cu19_filter_publications_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/publications/presentation/feed_screen.dart test/features/publications/cu19_filter_publications_test.dart
git commit -m "feat(cu19): implement FeedScreen with category/type filters and empty state"
```

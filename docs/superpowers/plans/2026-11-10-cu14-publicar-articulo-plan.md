# CU-14 · Publicar Artículo (incluye CU-13) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar el formulario y controlador de «Quiero donar» (`CU-14`) con validación de 1 a 5 fotografías, asignación de categoría activa (`CU-13`), cantidad y estado físico del artículo, publicándolo como `ACTIVA` en el `MockTenantStore`.

**Architecture:** `PublishItemController` valida la lista de fotografías (`1 <= length <= 5`), la categoría activa (`CU-13`), la condición física (`CondicionArticulo`) y los campos de texto/cantidad, delegando la creación a `MockTenantStore.createItemPublication(CreateItemInput)`.

**Tech Stack:** Flutter (`sdk: ^3.13.5`), `flutter_riverpod`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-11-10-cu14-publicar-articulo-design.md`

## Global Constraints

- **Firma del widget:** `const PublishItemForm({super.key, this.onPublished})`.
- **Fotografías (`RF-06` / `CU-14`):** Mínimo 1 foto obligatoria (`3a`), máximo 5 fotos (`3b`). Selector híbrido con fotos de muestra del tenant (`getSampleItemPhotos()`).
- **Categorías (`CU-13`):** Solo categorías con `activa == true` (`getActiveCategories()`).
- **Condición física obligatoria:** `CondicionArticulo.nuevo`, `CondicionArticulo.comoNuevo` o `CondicionArticulo.usado`.
- **Recuperación ante errores (`RNF-12`):** Si `simulateNetworkError == true`, lanza `NetworkException` sin guardar ni mostrar éxito (`8a`).

## Review Focus

1. **Eliminar fotografías antes de publicar:** Si el usuario agrega 2 fotos y elimina ambas, el contador vuelve a `0/5` y el intento de publicar dispara el bloqueo `3a` (primera foto obligatoria).
2. **Intento de agregar una 6.ª fotografía (`3b`):** Al tener 5 fotos seleccionadas, llamar a `addPhoto` no agrega la 6.ª foto y expone el mensaje de límite (`Máximo 5 fotografías permitidas`).
3. **Cantidad cero o negativa (`0`, `-1`):** Se rechaza con error de validación (`7a`).
4. **Sin condición física seleccionada:** Si el usuario no selecciona `Nuevo`, `Como nuevo` o `Usado`, se bloquea el envío (`7a`).
5. **Categoría inactiva excluida:** `Electrónica antigua` (`cat-inactiva`) no aparece en el selector de categoría (`CU-13`).

---

### Task 1: `PublishItemController` y Reglas de 1 a 5 Fotografías (`3a`, `3b`, `7a`, `8a`)

**Files:**
- Create: `lib/features/publications/presentation/publish_item_controller.dart`
- Create: `test/features/publications/cu14_publish_item_test.dart`

**Interfaces:**
- Consumes: `MockTenantStore.getActiveCategories()`, `MockTenantStore.getSampleItemPhotos()`, `MockTenantStore.createItemPublication(CreateItemInput)`.
- Produces:
  - `PublishItemState` (`photos`, `photosError`, `titleError`, `descriptionError`, `categoryError`, `quantityError`, `conditionError`, `locationError`, `submissionError`, `createdPublication`).
  - `PublishItemController` (`addSamplePhoto()`, `removePhotoAt(int index)`, `submitItem(...)`).

- [ ] **Step 1: Write failing unit tests for `TC-CU14-02` (0 photos) and `TC-CU14-03` (>5 photos) in `test/features/publications/cu14_publish_item_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/features/publications/presentation/publish_item_controller.dart';

void main() {
  test('TC-CU14-02 & TC-CU14-03: enforces minimum 1 photo and maximum 5 photos', () async {
    final store = MockTenantStore();
    final controller = PublishItemController(store);

    final okWithoutPhotos = await controller.submitItem(
      title: 'Bicicleta urbana',
      description: 'Rodada 26',
      categoryId: 'cat-salud',
      quantityText: '1',
      condition: CondicionArticulo.comoNuevo,
      location: 'Col. Centro, CP 72000',
    );
    expect(okWithoutPhotos, isFalse);
    expect(controller.state.photosError, isNotNull);

    for (var i = 0; i < 6; i++) {
      controller.addSamplePhoto();
    }
    expect(controller.state.photos.length, 5);
    expect(controller.state.photosError, contains('5'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/publications/cu14_publish_item_test.dart`
Expected: FAIL (`publish_item_controller.dart` not found).

- [ ] **Step 3: Implement `PublishItemState` and `PublishItemController` in `lib/features/publications/presentation/publish_item_controller.dart`**

Implement `addSamplePhoto`, `removePhotoAt`, and `submitItem` enforcing `1 <= photos.length <= 5`, active category (`CU-13`), `quantity >= 1`, `CondicionArticulo`, and `NetworkException` handling (`8a`).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/publications/cu14_publish_item_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/publications/presentation/publish_item_controller.dart test/features/publications/cu14_publish_item_test.dart
git commit -m "feat(cu14): add PublishItemController enforcing 1..5 photos and CU-13 category"
```

---

### Task 2: Widget `PublishItemForm` y Pruebas Completas (`TC-CU14-01` a `TC-CU14-05`)

**Files:**
- Modify: `lib/features/publications/presentation/publish_item_form.dart`
- Modify: `test/features/publications/cu14_publish_item_test.dart`

**Interfaces:**
- Consumes: `PublishItemController`, `mockTenantStoreProvider`.
- Produces: `const PublishItemForm({super.key, this.onPublished})`.

- [ ] **Step 1: Add widget tests for `TC-CU14-01`, `TC-CU14-04`, and `TC-CU14-05` in `test/features/publications/cu14_publish_item_test.dart`**

```dart
testWidgets('TC-CU14-01, TC-CU14-04 & TC-CU14-05 widget flow', (tester) async {
  // Tests missing title/category validation (TC-CU14-04),
  // tests network error recovery with simulateNetworkError = true (TC-CU14-05),
  // then publishes 'Bicicleta urbana' with 2 sample photos (TC-CU14-01).
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/publications/cu14_publish_item_test.dart`
Expected: FAIL (stub `PublishItemForm` does not render photo picker or inputs).

- [ ] **Step 3: Implement `PublishItemForm` in `lib/features/publications/presentation/publish_item_form.dart`**

Render the 1–5 photo strip with counter (`(${photos.length}/5)`), remove button on each thumbnail, `+ Agregar foto` button, title, description, active category selector (`CU-13`), quantity, condition radio/choice chips (`Nuevo`, `Como nuevo`, `Usado`), and approximate location (`Colonia o CP`).

- [ ] **Step 4: Run test to verify all 5 test cases (`TC-CU14-01` to `TC-CU14-05`) pass**

Run: `flutter test test/features/publications/cu14_publish_item_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/publications/presentation/publish_item_form.dart test/features/publications/cu14_publish_item_test.dart
git commit -m "feat(cu14): implement PublishItemForm with 1-5 photo selector and tests"
```

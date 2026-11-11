# CU-24 · Ofertar artículo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar la hoja modal `OfferItemSheet` y su controlador `OfferItemController` (`CU-24`) para que un donante envíe una Oferta con descripción obligatoria y al menos una fotografía para cubrir una Necesidad activa, validando duplicados (`2a`), estado activo (`2b`) y errores de red (`5a`).

**Architecture:** `OfferItemController` administra las fotografías adjuntas (`>= 1`) y la descripción del artículo ofrecido, genera una `claveCliente` única (`RNF-11`) e invoca `MockTenantStore.createOfferProposal(...)`, registrando la `PropuestaMock` en estado `PENDIENTE` y la notificación para el autor de la Necesidad.

**Tech Stack:** Flutter (`sdk: ^3.13.5`), `flutter_riverpod`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-11-10-cu24-ofertar-articulo-design.md`

## Global Constraints

- **Firma del widget:** `const OfferItemSheet({super.key, required this.publicationId})`.
- **Datos obligatorios (`RF-11` / `CU-24` `3a`):** Descripción no vacía (`description.trim().isNotEmpty`) y al menos 1 fotografía (`photos.isNotEmpty`).
- **Unicidad de Oferta pendiente (`2a`):** Solo puede existir una Oferta `PENDIENTE` por donante y Necesidad.
- **Solo Necesidades `ACTIVA` (`2b`):** Si la Necesidad está `RESERVADA`, `CERRADA` o `RETIRADA`, no permite enviar la Oferta.
- **Recuperación ante errores (`RNF-12` / `5a`):** Si `simulateNetworkError == true`, lanza `NetworkException` sin guardar ni mostrar la Oferta como enviada.

## Review Focus

1. **Agregar una fotografía y luego quitarla antes de confirmar:** Si el donante agrega 1 foto y la elimina, la lista queda vacía y al confirmar debe dispararse `3a` (fotografía obligatoria).
2. **Descripción compuesta solo por espacios (`"   "`):** Aunque adjunte 1 fotografía, una descripción en blanco debe rechazarse (`TC-CU24-03`).
3. **El autor de la Necesidad intenta ofertarse a sí mismo:** Si `activeUser.id == need.autorId`, se bloquea la Oferta.
4. **Límite superior de fotografías en la Oferta (hasta 5 fotos):** Permite adjuntar entre 1 y 5 fotos de muestra/galería sin desbordar la vista.
5. **Notificación interna al autor de la Necesidad:** Al crearse la Oferta sobre `pub-1`, `MockTenantStore.notifications` registra un aviso para `usr-maria`.

---

### Task 1: `OfferItemController` y Reglas de Negocio (`2a`, `2b`, `3a`, `5a`)

**Files:**
- Create: `lib/features/proposals/presentation/offer_item_controller.dart`
- Create: `test/features/proposals/cu24_offer_item_test.dart`

**Interfaces:**
- Consumes: `MockTenantStore.hasPendingProposal`, `MockTenantStore.getSampleItemPhotos`, `MockTenantStore.createOfferProposal`.
- Produces:
  - `OfferItemState` (`photos`, `photosError`, `descriptionError`, `submissionError`, `isSubmitting`, `createdProposal`).
  - `OfferItemController` (`addSamplePhoto()`, `removePhotoAt(int index)`, `submitOffer({required String publicationId, required String description})`).

- [ ] **Step 1: Write failing unit tests for `TC-CU24-02` (no photo), `TC-CU24-03` (empty description), `TC-CU24-04` (duplicate pending), and `TC-CU24-05` (inactive need) in `test/features/proposals/cu24_offer_item_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/features/proposals/presentation/offer_item_controller.dart';

void main() {
  test('TC-CU24-02 & TC-CU24-03: requires at least 1 photo and non-empty description', () async {
    final store = MockTenantStore();
    final controller = OfferItemController(store);

    // TC-CU24-02: description without photo
    expect(
      await controller.submitOffer(
        publicationId: 'pub-1',
        description: 'Silla de ruedas plegable en buen estado',
      ),
      isFalse,
    );
    expect(controller.state.photosError, isNotNull);

    // TC-CU24-03: photo without description
    controller.addSamplePhoto();
    expect(
      await controller.submitOffer(publicationId: 'pub-1', description: '   '),
      isFalse,
    );
    expect(controller.state.descriptionError, isNotNull);
  });

  test('TC-CU24-04: blocks duplicate pending offer on same Need', () async {
    final store = MockTenantStore();
    final controller = OfferItemController(store)..addSamplePhoto();

    expect(
      await controller.submitOffer(
        publicationId: 'pub-1',
        description: 'Silla de aluminio con frenos',
      ),
      isTrue,
    );
    controller.addSamplePhoto();
    expect(
      await controller.submitOffer(
        publicationId: 'pub-1',
        description: 'Otra oferta repetida',
      ),
      isFalse,
    );
    expect(controller.state.submissionError, isNotNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/proposals/cu24_offer_item_test.dart`
Expected: FAIL (`offer_item_controller.dart` not found).

- [ ] **Step 3: Implement `OfferItemState` and `OfferItemController` in `lib/features/proposals/presentation/offer_item_controller.dart`**

Implement `addSamplePhoto`, `removePhotoAt`, and `submitOffer` validating `photos.isNotEmpty`, `description.trim().isNotEmpty`, generating `clientKey`, calling `store.createOfferProposal(...)`, and catching `ValidationException` and `NetworkException` (`5a`).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/proposals/cu24_offer_item_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/proposals/presentation/offer_item_controller.dart test/features/proposals/cu24_offer_item_test.dart
git commit -m "feat(cu24): add OfferItemController with mandatory photo and duplicate guard"
```

---

### Task 2: Widget `OfferItemSheet` y Pruebas Completas (`TC-CU24-01` a `TC-CU24-06`)

**Files:**
- Modify: `lib/features/proposals/presentation/offer_item_sheet.dart`
- Modify: `test/features/proposals/cu24_offer_item_test.dart`

**Interfaces:**
- Consumes: `OfferItemController`, `mockTenantStoreProvider`.
- Produces: `const OfferItemSheet({super.key, required this.publicationId})`.

- [ ] **Step 1: Add widget tests for `TC-CU24-01`, `TC-CU24-05`, and `TC-CU24-06` in `test/features/proposals/cu24_offer_item_test.dart`**

```dart
testWidgets('TC-CU24-01, TC-CU24-05 & TC-CU24-06: OfferItemSheet photo picker, network error, and offer creation', (tester) async {
  // Opens OfferItemSheet(publicationId: 'pub-1'),
  // tests network error recovery with simulateNetworkError = true (TC-CU24-06),
  // disables network error, attaches 1 photo + description, submits (TC-CU24-01),
  // and verifies proposal + notification in MockTenantStore.
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/proposals/cu24_offer_item_test.dart`
Expected: FAIL (stub `OfferItemSheet` does not render photo selector or description field).

- [ ] **Step 3: Implement `OfferItemSheet` in `lib/features/proposals/presentation/offer_item_sheet.dart`**

Render the target Need title (`Para cubrir: ...`), photo picker strip (`Agregar foto` + remove button on each thumbnail), description `TextField`, validation/network error message banner, and `Confirmar Oferta` button.

- [ ] **Step 4: Run test to verify all 6 test cases (`TC-CU24-01` to `TC-CU24-06`) pass**

Run: `flutter test test/features/proposals/cu24_offer_item_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/proposals/presentation/offer_item_sheet.dart test/features/proposals/cu24_offer_item_test.dart
git commit -m "feat(cu24): implement OfferItemSheet modal and widget tests"
```

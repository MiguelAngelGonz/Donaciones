# CU-11 · Publicar Necesidad (incluye CU-12 y CU-13) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar el formulario y controlador de «Necesito» (`CU-11`) con asignación obligatoria de nivel de urgencia (`CU-12`) y de categoría activa (`CU-13`), publicando la Necesidad como `ACTIVA` en el `MockTenantStore`.

**Architecture:** `PublishNeedController` gestiona el estado y la validación del formulario (incluyendo `CU-12` y `CU-13`) y delega el guardado a `MockTenantStore.createNeedPublication(CreateNeedInput)`. El widget `PublishNeedForm` se monta dentro de `CreatePublicationScreen`.

**Tech Stack:** Flutter (`sdk: ^3.13.5`), `flutter_riverpod`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-11-10-cu11-publicar-necesidad-design.md`

## Global Constraints

- **Firma del widget:** `const PublishNeedForm({super.key, this.onPublished})`.
- **Categorías (`CU-13`):** Solo ofrecer categorías con `activa == true` (`getActiveCategories()`); `cat-inactiva` (`Electrónica antigua`) no debe mostrarse.
- **Urgencia (`CU-12`):** Selección obligatoria entre `Urgencia.alta`, `Urgencia.media` y `Urgencia.baja`, con distintivo visual de color y texto.
- **Mapeo a `PublicacionMock`:** Seleccionar *"Cualquiera"* en condición aceptable guarda `condicion: null`; el texto de características se guarda en `caracteristicas: {'Detalles': detallesCaracteristicas.trim()}`.
- **Privacidad (`RNF-09`) y Red (`RNF-12`):** Solo pide colonia o CP; ante `simulateNetworkError == true` lanza `NetworkException` sin guardar ni mostrar éxito (`8a`).

## Review Focus

1. **Cantidad menor a 1 o no numérica (`0`, `-2`, `abc`):** Debe rechazarse en `PublishNeedController` con mensaje de error sin intentar llamar al store.
2. **Título o descripción con puros espacios (`"   "`):** Debe tratarse como campo vacío (`7a`) tras aplicar `.trim()`.
3. **Ubicación prellenada del usuario activo pero borrada manualmente:** Si el usuario borra la colonia/CP prellenada, el formulario debe bloquear el envío (`6a`).
4. **Categoría desactivada inyectada por error:** `MockTenantStore.createNeedPublication` debe validar también que `categoriaId` corresponda a una categoría con `activa == true`.
5. **Reinicio del formulario tras publicar con éxito:** Después de publicar una Necesidad, el formulario limpia los campos de texto y llama a `onPublished?.call()`.

---

### Task 1: `PublishNeedController` y Reglas de Negocio (`CU-11`, `CU-12`, `CU-13`)

**Files:**
- Create: `lib/features/publications/presentation/publish_need_controller.dart`
- Create: `test/features/publications/cu11_publish_need_test.dart`

**Interfaces:**
- Consumes: `MockTenantStore.getActiveCategories()`, `MockTenantStore.createNeedPublication(CreateNeedInput)`.
- Produces:
  - `PublishNeedState` (`titleError`, `descriptionError`, `categoryError`, `quantityError`, `urgencyError`, `locationError`, `submissionError`, `createdPublication`).
  - `PublishNeedController` (`submitNeed(...)`).

- [ ] **Step 1: Write failing unit tests for `TC-CU11-02`, `TC-CU11-03`, `TC-CU11-04`, and quantity validation in `test/features/publications/cu11_publish_need_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/features/publications/presentation/publish_need_controller.dart';

void main() {
  test('TC-CU11-03 & TC-CU11-04: requires active category and urgency level', () async {
    final store = MockTenantStore();
    final controller = PublishNeedController(store);
    final ok = await controller.submitNeed(
      title: 'Cobijas térmicas',
      description: 'Para temporada invernal',
      categoryId: null,
      quantityText: '2',
      acceptableCondition: null,
      details: 'Matrimonial',
      urgency: null,
      location: 'Col. Centro, CP 72000',
    );
    expect(ok, isFalse);
    expect(controller.state.categoryError, isNotNull);
    expect(controller.state.urgencyError, isNotNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/publications/cu11_publish_need_test.dart`
Expected: FAIL (`publish_need_controller.dart` not found).

- [ ] **Step 3: Implement `PublishNeedState` and `PublishNeedController` in `lib/features/publications/presentation/publish_need_controller.dart`**

Validate non-empty `title`, `description`, `location`, integer `quantity >= 1`, active `categoryId` (`CU-13`), and non-null `urgency` (`CU-12`); call `store.createNeedPublication(CreateNeedInput(...))` and catch `NetworkException` (`8a`).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/publications/cu11_publish_need_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/publications/presentation/publish_need_controller.dart test/features/publications/cu11_publish_need_test.dart
git commit -m "feat(cu11): add PublishNeedController with CU-12 and CU-13 validations"
```

---

### Task 2: Widget `PublishNeedForm` y Pruebas Completas (`TC-CU11-01` a `TC-CU11-06`)

**Files:**
- Modify: `lib/features/publications/presentation/publish_need_form.dart`
- Modify: `test/features/publications/cu11_publish_need_test.dart`

**Interfaces:**
- Consumes: `PublishNeedController`, `mockTenantStoreProvider`.
- Produces: `const PublishNeedForm({super.key, this.onPublished})`.

- [ ] **Step 1: Add widget tests for `TC-CU11-01` through `TC-CU11-06` in `test/features/publications/cu11_publish_need_test.dart`**

```dart
testWidgets('TC-CU11-01, TC-CU11-04, TC-CU11-05 & TC-CU11-06 widget flow', (tester) async {
  // Verifies inactive category 'Electrónica antigua' is absent,
  // verifies RNF-09 approximate location helper text,
  // tests RNF-12 network error (TC-CU11-06),
  // then publishes 'Cobijas térmicas' (TC-CU11-01) and checks store state.
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/publications/cu11_publish_need_test.dart`
Expected: FAIL (stub `PublishNeedForm` does not render form inputs).

- [ ] **Step 3: Implement `PublishNeedForm` in `lib/features/publications/presentation/publish_need_form.dart`**

Render fields for title, description, active category dropdown (`CU-13`), required quantity, acceptable condition (`Cualquiera` -> `null`, `Nuevo`, `Como nuevo`, `Usado`), characteristics details, urgency selector with color+text badges (`Urgencia Alta`, `Urgencia Media`, `Urgencia Baja` for `CU-12`), and approximate location (`Colonia o CP`, `RNF-09`).

- [ ] **Step 4: Run test to verify all 6 test cases (`TC-CU11-01` to `TC-CU11-06`) pass**

Run: `flutter test test/features/publications/cu11_publish_need_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/publications/presentation/publish_need_form.dart test/features/publications/cu11_publish_need_test.dart
git commit -m "feat(cu11): implement PublishNeedForm with urgency badges and active categories"
```

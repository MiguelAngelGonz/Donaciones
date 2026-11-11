# CU-23 · Solicitar artículo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar la hoja modal `RequestItemSheet` y su controlador `RequestItemController` (`CU-23`) para que un donatario envíe una Solicitud con un mensaje de hasta 300 caracteres sobre un Artículo activo, validando duplicados (`2a`), estado activo (`2b`) y errores de red (`5a`).

**Architecture:** `RequestItemController` valida el mensaje (`1 <= length <= 300`), genera una `claveCliente` única (`RNF-11`) e invoca `MockTenantStore.createRequestProposal(...)`, el cual registra la `PropuestaMock` en estado `PENDIENTE` y agrega una notificación interna para el donante.

**Tech Stack:** Flutter (`sdk: ^3.13.5`), `flutter_riverpod`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-11-10-cu23-solicitar-articulo-design.md`

## Global Constraints

- **Firma del widget:** `const RequestItemSheet({super.key, required this.publicationId})`.
- **Longitud del mensaje (`3a`):** Obligatorio, `1 <= mensaje.trim().length <= 300`.
- **Unicidad de propuesta pendiente (`RF-11` / `2a`):** Un usuario no puede tener más de una Solicitud `PENDIENTE` sobre el mismo Artículo.
- **Solo Artículos `ACTIVA` (`2b`):** Si el Artículo está `RESERVADA`, `CERRADA` o `RETIRADA`, se bloquea la Solicitud.
- **Recuperación ante errores (`RNF-12` / `5a`):** Si `simulateNetworkError == true`, lanza `NetworkException` sin guardar la Solicitud ni mostrarla como enviada.

## Review Focus

1. **Mensaje compuesto solo por espacios (`"     "`):** Debe rechazarse como mensaje vacío (`3a`) tras aplicar `.trim()`.
2. **Mensaje de exactamente 300 caracteres vs 301 caracteres:** 300 caracteres es válido (frontera inclusiva); 301 caracteres debe rechazarse (`3a`).
3. **El propio autor intenta solicitar su Artículo:** Si `activeUser.id == publication.autorId`, el sistema debe impedir que el autor se solicite su propio artículo.
4. **Doble pulsación rápida en «Confirmar envío» (`RNF-11`):** El botón se deshabilita mientras `isSubmitting == true` y se usa `claveCliente` para evitar duplicidad.
5. **Notificación interna al donante:** Al completarse la Solicitud, `MockTenantStore.notifications` contiene un nuevo aviso dirigido a `publication.autorId`.

---

### Task 1: `RequestItemController` y Reglas de Negocio (`2a`, `2b`, `3a`, `5a`)

**Files:**
- Create: `lib/features/proposals/presentation/request_item_controller.dart`
- Create: `test/features/proposals/cu23_request_item_test.dart`

**Interfaces:**
- Consumes: `MockTenantStore.hasPendingProposal`, `MockTenantStore.createRequestProposal`.
- Produces:
  - `RequestItemState` (`messageError`, `submissionError`, `isSubmitting`, `createdProposal`).
  - `RequestItemController` (`submitRequest({required String publicationId, required String message})`).

- [ ] **Step 1: Write failing unit tests for `TC-CU23-02` (>300 chars / empty), `TC-CU23-03` (duplicate pending), and `TC-CU23-04` (inactive item) in `test/features/proposals/cu23_request_item_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/features/proposals/presentation/request_item_controller.dart';

void main() {
  test('TC-CU23-02: rejects empty message and message > 300 chars', () async {
    final store = MockTenantStore();
    final controller = RequestItemController(store);

    expect(await controller.submitRequest(publicationId: 'pub-3', message: '   '), isFalse);
    expect(controller.state.messageError, isNotNull);

    final tooLong = 'a' * 301;
    expect(await controller.submitRequest(publicationId: 'pub-3', message: tooLong), isFalse);
    expect(controller.state.messageError, contains('300'));
  });

  test('TC-CU23-03 & TC-CU23-04: blocks duplicate pending request and non-active item', () async {
    final store = MockTenantStore();
    final controller = RequestItemController(store);

    expect(
      await controller.submitRequest(publicationId: 'pub-3', message: 'Me interesa la mesa'),
      isTrue,
    );
    expect(
      await controller.submitRequest(publicationId: 'pub-3', message: 'Segundo intento'),
      isFalse,
    );
    expect(controller.state.submissionError, isNotNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/proposals/cu23_request_item_test.dart`
Expected: FAIL (`request_item_controller.dart` not found).

- [ ] **Step 3: Implement `RequestItemState` and `RequestItemController` in `lib/features/proposals/presentation/request_item_controller.dart`**

Validate `1 <= message.trim().length <= 300`, generate `clientKey`, call `store.createRequestProposal(...)`, and catch `ValidationException` (`2a`, `2b`, `3a`) and `NetworkException` (`5a`).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/proposals/cu23_request_item_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/proposals/presentation/request_item_controller.dart test/features/proposals/cu23_request_item_test.dart
git commit -m "feat(cu23): add RequestItemController with 300-char limit and duplicate guard"
```

---

### Task 2: Widget `RequestItemSheet` y Pruebas Completas (`TC-CU23-01` a `TC-CU23-05`)

**Files:**
- Modify: `lib/features/proposals/presentation/request_item_sheet.dart`
- Modify: `test/features/proposals/cu23_request_item_test.dart`

**Interfaces:**
- Consumes: `RequestItemController`, `mockTenantStoreProvider`.
- Produces: `const RequestItemSheet({super.key, required this.publicationId})`.

- [ ] **Step 1: Add widget tests for `TC-CU23-01` through `TC-CU23-05` in `test/features/proposals/cu23_request_item_test.dart`**

```dart
testWidgets('TC-CU23-01 & TC-CU23-05: RequestItemSheet live counter, network failure, and successful submission', (tester) async {
  // Opens RequestItemSheet(publicationId: 'pub-3'),
  // tests network error recovery with simulateNetworkError = true (TC-CU23-05),
  // then disables network error, submits a valid 95-char message (TC-CU23-01),
  // and verifies proposal + donor notification in MockTenantStore.
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/proposals/cu23_request_item_test.dart`
Expected: FAIL (stub `RequestItemSheet` does not render message input or submit button).

- [ ] **Step 3: Implement `RequestItemSheet` in `lib/features/proposals/presentation/request_item_sheet.dart`**

Render the item title, message `TextField` with live character counter (`${length} / 300 caracteres`), validation/network error message banner, and `Confirmar envío` button.

- [ ] **Step 4: Run test to verify all 5 test cases (`TC-CU23-01` to `TC-CU23-05`) pass**

Run: `flutter test test/features/proposals/cu23_request_item_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/proposals/presentation/request_item_sheet.dart test/features/proposals/cu23_request_item_test.dart
git commit -m "feat(cu23): implement RequestItemSheet modal and widget tests"
```

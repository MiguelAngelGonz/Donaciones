# Base Compartida del MVP (Modo Mock / Tenant de Prueba) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir la base compartida (Sprint 0) de DonaPlus en Flutter con los modelos de dominio, el almacén en memoria `MockTenantStore` precargado con datos semilla, el tema DonaPlus con panel de accesibilidad y los contenedores de navegación con stubs para que los 6 casos de uso del MVP se integren sin conflictos de Git.

**Architecture:** Arquitectura `feature-first` con estado reactivo en memoria mediante `flutter_riverpod` y enrutamiento declarativo con `go_router`. Todos los contratos de modelos, DTOs, excepciones y firmas de widgets quedan fijos en `lib/core/` y `lib/app/`.

**Tech Stack:** Flutter (`sdk: ^3.13.5`), `flutter_riverpod`, `go_router`, `crypto` (para hash SHA-256 de contraseñas en `RNF-07`), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-11-10-mvp-base-compartida-design.md`

## Global Constraints

- **SDK y Plataforma:** Flutter `sdk: ^3.13.5`, orientado a Android (`RNF-13`).
- **Paleta DonaPlus:** `primary: #004D64`, `secondary: #00A896`, `accentMint: #A7E6A6`, `accentYellow: #FFF86A`.
- **Navegación en ≤ 3 interacciones (`RNF-02`):** Rutas `/`, `/register`, `/create`, `/publications/:id`.
- **Recuperación ante errores (`RNF-12`):** Cuando `simulateNetworkError == true`, toda operación de escritura lanza `NetworkException('No se pudo completar la operación por pérdida de conexión')` sin mutar el estado.
- **Privacidad (`RNF-07`, `RNF-09`):** Contraseñas almacenadas solo como hash en `CuentaAccesoMock`; ubicación limitada a colonia o código postal en `UbicacionMock`.

## Review Focus

1. **Espacios y mayúsculas en unicidad de usuario/correo:** `isUsernameTaken('@Alondra.Dona ')` y `isEmailTaken(' ALONDRA.DEMO@donaplus.app ')` deben normalizar (`trim().toLowerCase()` y quitar `@` inicial en usuario) para no permitir duplicados visuales.
2. **Inmutabilidad de listas devueltas por `MockTenantStore`:** Modificar la lista retornada por `getActiveCategories()` o `filterActivePublications()` desde fuera no debe mutar la colección interna del store.
3. **Categoría inactiva excluida en creación y filtro:** `cat-inactiva` (`Electrónica antigua`, `activa: false`) nunca debe aparecer en `getActiveCategories()` ni en `getCategoriesForFilter()`.
4. **Atomicidad ante `simulateNetworkError`:** Cuando `simulateNetworkError == true`, fallar en `registerUser`, `createNeedPublication`, `createItemPublication`, `createRequestProposal` o `createOfferProposal` no debe incrementar listas ni agregar notificaciones.
5. **Reinicio determinista entre pruebas (`resetToSeed()`):** El store debe exponer `resetToSeed()` para restaurar exactamente los 3 usuarios, 6 categorías y 4 publicaciones semilla.

---

### Task 1: Dependencias, Modelos del Dominio y Excepciones Canónicas

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/models/domain_models.dart`
- Create: `lib/core/models/dto_inputs.dart`
- Create: `lib/core/models/domain_exceptions.dart`
- Test: `test/core/mock_tenant_store_test.dart`

**Interfaces:**
- Consumes: SDK estándar de Dart/Flutter.
- Produces:
  - Enums: `Urgencia`, `EstadoPublicacion`, `CondicionArticulo`, `TipoPublicacion`, `TipoPropuesta`, `EstadoPropuesta`.
  - Clases: `UbicacionMock`, `UsuarioMock`, `CategoriaMock`, `PublicacionMock`, `PropuestaMock`, `CuentaAccesoMock`, `NotificacionMock`.
  - DTOs: `RegisterUserInput`, `CreateNeedInput`, `CreateItemInput`.
  - Excepciones: `NetworkException`, `DuplicateUsernameException`, `ValidationException`.

- [ ] **Step 1: Write the failing test for domain models and exceptions**

```dart
// test/core/mock_tenant_store_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/core/models/domain_exceptions.dart';

void main() {
  test('Domain models preserve immutability and default copyWith values', () {
    const loc = UbicacionMock(etiqueta: 'Col. Centro, CP 72000');
    expect(loc.distanciaKmSimulada, 2.4);
    const err = NetworkException();
    expect(err.message, 'No se pudo completar la operación por pérdida de conexión');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/mock_tenant_store_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'package:donaciones/core/models/domain_models.dart'".

- [ ] **Step 3: Add dependencies in `pubspec.yaml` and implement `domain_models.dart`, `dto_inputs.dart`, and `domain_exceptions.dart`**

Add `flutter_riverpod: ^2.4.9`, `go_router: ^13.0.0`, and `crypto: ^3.0.3` in `pubspec.yaml`, then implement the exact models, DTOs, and exceptions specified in Section 6 of `docs/superpowers/specs/2026-11-10-mvp-base-compartida-design.md`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter pub get && flutter test test/core/mock_tenant_store_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/models/ test/core/mock_tenant_store_test.dart
git commit -m "feat(core): add shared domain models, DTOs, and exceptions"
```

---

### Task 2: `MockTenantStore` con Datos Semilla y Contratos para los 6 CU

**Files:**
- Create: `lib/core/mock/mock_tenant_store.dart`
- Modify: `test/core/mock_tenant_store_test.dart`

**Interfaces:**
- Consumes: `lib/core/models/domain_models.dart`, `lib/core/models/dto_inputs.dart`, `lib/core/models/domain_exceptions.dart`.
- Produces:
  - `final mockTenantStoreProvider = ChangeNotifierProvider<MockTenantStore>((ref) => MockTenantStore());`
  - Métodos públicos exactos definidos en la Sección 6 de `2026-11-10-mvp-base-compartida-design.md` más `void resetToSeed()`, `void setActiveUser(String? userId)` y `void setSimulateNetworkError(bool value)`.

- [ ] **Step 1: Write failing unit tests for seed data and all 5 Review Focus cases in `test/core/mock_tenant_store_test.dart`**

```dart
test('Seed data loads 3 users, 5 active categories (excluding cat-inactiva), and 4 active publications', () {
  final store = MockTenantStore();
  expect(store.users.length, 3);
  expect(store.activeUser?.id, 'usr-alondra');
  expect(store.getActiveCategories().map((c) => c.id), isNot(contains('cat-inactiva')));
  expect(store.filterActivePublications().length, 4);
});

test('Normalizes username and email uniqueness checks and returns unmodifiable lists', () {
  final store = MockTenantStore();
  expect(store.isUsernameTaken(' @Alondra.Dona '), isTrue);
  expect(store.isEmailTaken(' ALONDRA.DEMO@donaplus.app '), isTrue);
  expect(() => store.getActiveCategories().clear(), throwsUnsupportedError);
});

test('simulateNetworkError throws NetworkException without mutating state', () async {
  final store = MockTenantStore()..setSimulateNetworkError(true);
  await expectLater(
    () => store.createRequestProposal(
      publicationId: 'pub-3',
      senderId: 'usr-alondra',
      message: 'Hola',
      clientKey: 'key-1',
    ),
    throwsA(isA<NetworkException>()),
  );
  expect(store.proposals, isEmpty);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/mock_tenant_store_test.dart`
Expected: FAIL with `MockTenantStore` undefined.

- [ ] **Step 3: Implement `MockTenantStore` in `lib/core/mock/mock_tenant_store.dart`**

Implement seed users (`usr-alondra`, `usr-maria`, `usr-diego`), seed categories (`cat-salud`, `cat-educacion`, `cat-alimentacion`, `cat-ropa`, `cat-hogar`, `cat-inactiva`), seed publications (`pub-1`..`pub-4`), SHA-256 password hashing (`RNF-07`), and all canonical methods from Section 6 of the spec.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/mock_tenant_store_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/mock/mock_tenant_store.dart test/core/mock_tenant_store_test.dart
git commit -m "feat(mock): implement MockTenantStore with seed data and RNF-12 network simulation"
```

---

### Task 3: Tema Visual DonaPlus, Panel de Accesibilidad, `DemoTenantToolbar` y Puntos de Unión

**Files:**
- Create: `lib/app/theme.dart`
- Create: `lib/app/router.dart`
- Create: `lib/core/widgets/accessibility_sheet.dart`
- Create: `lib/core/widgets/demo_tenant_toolbar.dart`
- Create: `lib/features/publications/presentation/create_publication_screen.dart`
- Create: `lib/features/publications/presentation/publication_detail_screen.dart`
- Create: `lib/features/auth/presentation/register_screen.dart` (stub inicial)
- Create: `lib/features/publications/presentation/publish_need_form.dart` (stub inicial)
- Create: `lib/features/publications/presentation/publish_item_form.dart` (stub inicial)
- Create: `lib/features/publications/presentation/feed_screen.dart` (stub inicial)
- Create: `lib/features/proposals/presentation/request_item_sheet.dart` (stub inicial)
- Create: `lib/features/proposals/presentation/offer_item_sheet.dart` (stub inicial)
- Modify: `lib/main.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: `mockTenantStoreProvider`.
- Produces:
  - `DonaPlusApp` en `lib/main.dart`.
  - Stubs con las firmas exactas de la Sección 8 del spec (`PublishNeedForm({super.key, this.onPublished})`, `PublishItemForm({super.key, this.onPublished})`, `RequestItemSheet({super.key, required this.publicationId})`, `OfferItemSheet({super.key, required this.publicationId})`).

- [ ] **Step 1: Write the failing smoke test in `test/widget_test.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:donaciones/main.dart';

void main() {
  testWidgets('DonaPlus shell renders DemoTenantToolbar and bottom navigation', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DonaPlusApp()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Simular fallo de red'), findsOneWidget);
    expect(find.text('Accesibilidad'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart`
Expected: FAIL (`DonaPlusApp` not found).

- [ ] **Step 3: Implement `theme.dart`, `accessibility_sheet.dart`, `demo_tenant_toolbar.dart`, shell screens, feature stubs, and `main.dart`**

Configure colors `#004D64`, `#00A896`, `#A7E6A6`, `#FFF86A`, the `DemoTenantToolbar` (active user selector + network error switch), `CreatePublicationScreen` (toggle `Quiero donar` / `Necesito`), `PublicationDetailScreen` (opens `RequestItemSheet` or `OfferItemSheet`), and `go_router` routes `/`, `/register`, `/create`, `/publications/:id`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test`
Expected: PASS (all tests in `test/core/mock_tenant_store_test.dart` and `test/widget_test.dart`).

- [ ] **Step 5: Commit**

```bash
git add lib/ test/widget_test.dart
git commit -m "feat(app): add DonaPlus theme, accessibility sheet, tenant toolbar, and feature stubs"
```

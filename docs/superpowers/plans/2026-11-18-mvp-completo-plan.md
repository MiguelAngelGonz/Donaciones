# MVP Completo de DonaPlus (CU-01 a CU-51 en Modo Mock) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir el MVP Completo de DonaPlus en Flutter cubriendo los 51 casos de uso (`CU-01` a `CU-51`), los 15 requerimientos funcionales (`RF-01` a `RF-15`) y los 15 no funcionales (`RNF-01` a `RNF-15`) sobre un `MockTenantStore` reactivo en memoria, 100% compatible con las pruebas y firmas de los 7 planes iniciales.

**Architecture:** Aplicación Flutter modular `feature-first` con gestión de estado mediante `flutter_riverpod` (`ChangeNotifierProvider<MockTenantStore>`) y navegación declarativa con `go_router` (shell de 5 pestañas inferiores + rutas de autenticación, detalle y administración). Todas las reglas de negocio, validaciones, reloj simulado y simulación de pérdida de conexión (`RNF-12`) residen de forma atómica en `MockTenantStore`.

**Tech Stack:** Flutter (`sdk: ^3.13.5`), `flutter_riverpod: ^2.4.9`, `go_router: ^13.0.0`, `crypto: ^3.0.3` (hash SHA-256 para `RNF-07`), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-11-18-mvp-completo-design.md`

## Global Constraints

- **SDK y Plataforma (`RNF-13`):** Flutter `sdk: ^3.13.5`, orientado a Android.
- **Paleta DonaPlus (`RNF-03`):** `primary: #004D64`, `secondary: #00A896`, `accentMint: #A7E6A6`, `accentYellow: #FFF86A`.
- **Retrocompatibilidad con Sprint 0:** `store.users.length == 3` (`usr-alondra`, `usr-maria`, `usr-diego`), `store.activeUser?.id == 'usr-alondra'`, `store.getActiveCategories()` con 5 categorías activas (excluyendo `cat-inactiva`), `store.filterActivePublications().length == 4` (`pub-1` a `pub-4`), `store.proposals` inicialmente vacía (`[]`).
- **Firmas canónicas de widgets:** `PublishNeedForm({super.key, this.onPublished})`, `PublishItemForm({super.key, this.onPublished})`, `RequestItemSheet({super.key, required this.publicationId})`, `OfferItemSheet({super.key, required this.publicationId})`.
- **Seguridad y Privacidad (`RNF-07`, `RNF-08`, `RNF-09`):** Contraseñas solo como hash SHA-256; ubicación limitada a colonia o CP; beneficiarios solo con alias; teléfono en chat oculto salvo que su dueño active compartirlo.
- **Atomicidad ante fallo de red (`RNF-12`):** Cuando `simulateNetworkError == true`, toda operación de escritura lanza `NetworkException('No se pudo completar la operación por pérdida de conexión')` antes de mutar cualquier colección.

## Review Focus

1. **Idempotencia al aceptar propuesta o transicionar donación (`RNF-11`):** Llamar dos veces seguidas a `acceptProposal`, `registerDeliverySchedule`, `markDonationDelivered`, `confirmDonationReceived` o `cancelDonation` con el mismo `clientKey` (o sobre la misma propuesta ya aceptada) debe devolver la misma `DonacionMock` sin duplicar registros ni eventos en `historialCambios`.
2. **Reinicio del contador de intentos fallidos y desbloqueo por tiempo (`CU-07`, `CU-09`):** Un login exitoso en el intento 4 debe reiniciar `intentosFallidos = 0`; si llega al 5.º intento fallido, debe bloquear por 15 minutos incluso con contraseña correcta, y permitir el acceso al avanzar el reloj simulado `advanceClock(Duration(minutes: 16))`.
3. **Recálculo dinámico del Perfil de Confianza (`CU-04`, `CU-34`, `CU-37`, `RF-03`):** Si un usuario con Perfil de Confianza otorgado recibe una reseña de `1` estrella que baja su promedio de `4.0`, `recalculateTrustProfile` debe retirar de inmediato `perfilConfianzaOtorgado = false`.
4. **Efecto cascada al retirar publicación o revocar intermediario (`CU-15`, `CU-16`, `CU-45`):** Retirar una publicación activa o revocar el rol de un intermediario debe rechazar automáticamente todas las propuestas `PENDIENTE` asociadas a esas publicaciones retiradas, sin cancelar las Donaciones que ya estaban en curso (`ACEPTADA`, `EN_ENTREGA`, `ENTREGADA`).
5. **Expiración de ventana de 14 días para reseñas y 30 minutos para token de contraseña (`CU-08`, `CU-37`):** Avanzar el reloj simulado más de 30 minutos invalida el token de `confirmPasswordReset` (`ExpiredOrUsedTokenException`), y avanzar más de 14 días tras `fechaFinalizacion` impide `submitReview` (`ValidationException`).

---

### Task 1: Modelos del Dominio Completos, DTOs, Excepciones y `MockTenantStore` (CU-01 a CU-51)

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/models/domain_models.dart`
- Create: `lib/core/models/dto_inputs.dart`
- Create: `lib/core/models/domain_exceptions.dart`
- Create: `lib/core/mock/mock_tenant_store.dart`
- Create: `test/core/mock_tenant_store_test.dart`

**Interfaces:**
- Consumes: SDK estándar de Dart/Flutter + `crypto: ^3.0.3` + `flutter_riverpod: ^2.4.9`.
- Produces:
  - Todas las enumeraciones, entidades y excepciones definidas en la Sección 6 de `docs/superpowers/specs/2026-11-18-mvp-completo-design.md`.
  - DTOs en `dto_inputs.dart`: `RegisterUserInput`, `CreateNeedInput` (con `bool gestionadaPorIntermediario = false` y `String? aliasBeneficiario`), `CreateItemInput`.
  - `final mockTenantStoreProvider = ChangeNotifierProvider<MockTenantStore>((ref) => MockTenantStore());` con todos los métodos públicos de la Sección 7.2 del spec.

- [ ] **Step 1: Write failing unit tests for domain models, seed data, and all 5 Review Focus cases in `test/core/mock_tenant_store_test.dart`**

Incluye pruebas unitarias que verifiquen:
1. Semilla inicial (`store.users.length == 3`, `store.activeUser?.id == 'usr-alondra'`, `getActiveCategories()` sin `cat-inactiva`, `filterActivePublications().length == 4`, `store.proposals` vacía, `don-hist-1` en historial).
2. Normalización de unicidad `isUsernameTaken(' @Alondra.Dona ') == true` e inmutabilidad de colecciones devueltas.
3. **Review Focus 1 (`RNF-11`):** `acceptProposal` llamada dos veces con el mismo `clientKey` genera una sola `DonacionMock`, pasa la publicación a `RESERVADA` y rechaza las demás propuestas pendientes.
4. **Review Focus 2 (`CU-07`, `CU-09`):** 5 intentos fallidos de `login` lanzan `AccountLockedException`; durante los 15 minutos rechaza incluso la contraseña correcta (`DonaPlus1`); tras `advanceClock(const Duration(minutes: 16))` autentica con éxito.
5. **Review Focus 3, 4 y 5 (`CU-08`, `CU-15`, `CU-34`, `CU-37`, `CU-45`):** Expiración de token a los 31 min; finalización automática a los 7 días de `markDonationDelivered`; bloqueo de reseña a los 15 días de finalizada; retiro de Necesidades activas gestionadas por intermediario al ejecutar `revokeIntermediaryRole('usr-maria')` conservando donaciones en curso; y atomicidad ante `setSimulateNetworkError(true)`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/mock_tenant_store_test.dart`
Expected: FAIL with missing imports `package:donaciones/core/models/domain_models.dart`.

- [ ] **Step 3: Add dependencies in `pubspec.yaml` and implement `domain_models.dart`, `dto_inputs.dart`, `domain_exceptions.dart`, and `mock_tenant_store.dart`**

Agrega `flutter_riverpod: ^2.4.9`, `go_router: ^13.0.0` y `crypto: ^3.0.3` en `pubspec.yaml`. Implementa todas las clases de la Sección 6 y los métodos de la Sección 7.2 del spec en `lib/core/`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter pub get && flutter test test/core/mock_tenant_store_test.dart`
Expected: PASS (all unit tests in `mock_tenant_store_test.dart` green).

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/ test/core/mock_tenant_store_test.dart
git commit -m "feat(core): implement complete domain models and MockTenantStore for CU-01 to CU-51"
```

---

### Task 2: Tema DonaPlus, Accesibilidad, `DemoTenantToolbar`, Notificaciones y Shell de Navegación

**Files:**
- Create: `lib/app/theme.dart`
- Create: `lib/app/shell_scaffold.dart`
- Create: `lib/app/router.dart`
- Create: `lib/core/widgets/accessibility_sheet.dart`
- Create: `lib/core/widgets/demo_tenant_toolbar.dart`
- Create: `lib/core/widgets/notifications_sheet.dart`
- Create: `lib/core/widgets/trust_badge_chip.dart`
- Modify: `lib/main.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: `mockTenantStoreProvider` de `lib/core/mock/mock_tenant_store.dart`.
- Produces:
  - `DonaPlusApp` en `lib/main.dart` y `accessibilityProvider` en `lib/app/theme.dart` (`textScaleFactor: 1.0 | 1.25`, `highContrast: bool`, `reduceMotion: bool`).
  - `DemoTenantToolbar` con selector de usuario activo (`@alondra.dona`, `@maria.lopez`, `@diego.solidario`, cuentas nuevas o `Sin sesión`), switch `Simular fallo de red` y botones de reloj (`+15m`, `+7d`, `+15d`).
  - `ShellScaffold` con las 5 pestañas inferiores (`Inicio`, `Coincidencias`, `Publicar`, `Donaciones`, `Perfil`) y rutas en `lib/app/router.dart`.

- [ ] **Step 1: Write failing widget test for shell, accessibility sheet, and demo toolbar in `test/widget_test.dart`**

Verifica que `DonaPlusApp` renderice `DemoTenantToolbar` (con `Simular fallo de red` y botones de reloj), el chip `Accesibilidad` (que abre `AccessibilitySheet` y permite alternar tamaño de texto y alto contraste) y las 5 pestañas de la barra inferior.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart`
Expected: FAIL (`DonaPlusApp` not defined).

- [ ] **Step 3: Implement `theme.dart`, `accessibility_sheet.dart`, `demo_tenant_toolbar.dart`, `notifications_sheet.dart`, `trust_badge_chip.dart`, `shell_scaffold.dart`, `router.dart` (with screen stubs), and `main.dart`**

Implementa el tema DonaPlus (`#004D64`, `#00A896`, `#A7E6A6`, `#FFF86A`), los widgets compartidos y el router con las rutas `/`, `/matches`, `/create`, `/donations`, `/profile`, `/login`, `/register`, `/reset-password`, `/publications/:id`, `/donations/:id`, `/admin`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ test/widget_test.dart
git commit -m "feat(app): add DonaPlus theme, accessibility sheet, demo toolbar, and navigation shell"
```

---

### Task 3: Bloque 1 — Registro (CU-01, CU-02), Login y Bloqueo (CU-07 a CU-09) y Perfil con Confianza y Reseñas (CU-03 a CU-06, CU-10)

**Files:**
- Create: `lib/features/auth/presentation/register_controller.dart`
- Create: `lib/features/auth/presentation/register_screen.dart`
- Create: `lib/features/auth/presentation/login_screen.dart`
- Create: `lib/features/auth/presentation/reset_password_screen.dart`
- Create: `lib/features/profile/presentation/profile_screen.dart`
- Create: `lib/features/profile/presentation/edit_profile_sheet.dart`
- Create: `test/features/auth/cu01_register_test.dart`
- Create: `test/features/auth/auth_and_profile_test.dart`

**Interfaces:**
- Consumes: `mockTenantStoreProvider`, `TrustBadgeChip`.
- Produces:
  - `RegisterScreen` (3 pasos de `RNF-01` + botón de verificación simulada de correo `CU-02`).
  - `LoginScreen` (`CU-07`, aviso de bloqueo `CU-09`, navegación a `/register` y `/reset-password`).
  - `ResetPasswordScreen` (`CU-08`: solicitar enlace y aplicar nueva contraseña con token).
  - `ProfileScreen` (`CU-03`: datos, tarjeta de `Perfil de Confianza` con métricas y faltantes `CU-04`, lista de reseñas recibidas con etiqueta `Donación verificada` `CU-05`, botón `Editar perfil` `CU-06`, botón `Cerrar sesión` `CU-10`, y accesos a solicitud de intermediario / panel admin).

- [ ] **Step 1: Write failing widget tests in `test/features/auth/cu01_register_test.dart` and `test/features/auth/auth_and_profile_test.dart`**

En `cu01_register_test.dart` incluye los 7 casos `TC-CU01-01` a `TC-CU01-07` de `2026-11-10-cu01-registrarse-plan.md` (registro en 3 pasos + verificación `CU-02`, usuario duplicado `6a`, reglas de teléfono/contraseña `6b`, aviso de privacidad `5a`, fallo de red `6c`).
En `auth_and_profile_test.dart` prueba: login exitoso y bloqueo tras 5 intentos (`CU-07`, `CU-09`), restablecimiento de contraseña (`CU-08`), visualización de métricas y faltantes del Perfil de Confianza (`CU-04` con `usr-diego` y `usr-alondra`), reseñas verificadas (`CU-05`), edición de teléfono con campos `nombreUsuario`/`nombreLegal` en solo lectura (`CU-06`) y cierre de sesión (`CU-10`).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/auth/`
Expected: FAIL.

- [ ] **Step 3: Implement auth and profile screens and controllers**

Implementa `register_controller.dart`, `register_screen.dart`, `login_screen.dart`, `reset_password_screen.dart`, `profile_screen.dart` y `edit_profile_sheet.dart`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/auth/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/ lib/features/profile/ lib/app/router.dart test/features/auth/
git commit -m "feat(auth,profile): implement CU-01 to CU-10 registration, login, password reset, and profile"
```

---

### Task 4: Bloques 2 y 3 — Publicar Necesidad/Artículo (CU-11 a CU-16, CU-46, CU-47), Feed con Filtros/Cercanía/Urgencia (CU-19 a CU-22) y Coincidencias (CU-17, CU-18)

**Files:**
- Create: `lib/features/publications/presentation/create_publication_screen.dart`
- Create: `lib/features/publications/presentation/publish_need_controller.dart`
- Create: `lib/features/publications/presentation/publish_need_form.dart`
- Create: `lib/features/publications/presentation/publish_item_controller.dart`
- Create: `lib/features/publications/presentation/publish_item_form.dart`
- Create: `lib/features/publications/presentation/edit_publication_sheet.dart`
- Create: `lib/features/publications/presentation/publication_detail_screen.dart`
- Create: `lib/features/publications/presentation/feed_filter_controller.dart`
- Create: `lib/features/publications/presentation/feed_screen.dart`
- Create: `lib/features/matching/presentation/matches_screen.dart`
- Create: `test/features/publications/cu11_publish_need_test.dart`
- Create: `test/features/publications/cu14_publish_item_test.dart`
- Create: `test/features/publications/cu19_filter_publications_test.dart`
- Create: `test/features/matching/matching_and_proximity_test.dart`

**Interfaces:**
- Consumes: `mockTenantStoreProvider`.
- Produces:
  - `PublishNeedForm({super.key, this.onPublished})` (`CU-11`, `CU-12`, `CU-13`, y cuando `activeUser.esIntermediario == true`, switch `Publicar en nombre de un beneficiario` con campo obligatorio `Alias del beneficiario` para `CU-46` y `CU-47`).
  - `PublishItemForm({super.key, this.onPublished})` (`CU-14`, `CU-13` con 1 a 5 fotografías).
  - `FeedScreen` (`CU-19` categorías y tipo, `CU-20`/`CU-21` filtro por radio `5 km`, `10 km`, `25 km` y autorización de ubicación del dispositivo, `CU-22` filtro y ordenamiento por urgencia).
  - `PublicationDetailScreen` (muestra detalle, insignia de confianza y etiqueta `Gestionada por intermediario` cuando aplica; si el usuario activo es el autor y está `ACTIVA`, permite `Editar` o `Retirar` `CU-15`/`CU-16`; si no es el autor, abre `RequestItemSheet` `CU-23` u `OfferItemSheet` `CU-24`).
  - `MatchesScreen` (`CU-17`, `CU-18`: lista coincidencias ordenadas por urgencia y distancia y permite navegar al detalle para solicitar u ofertar).

- [ ] **Step 1: Write failing widget tests in `cu11_publish_need_test.dart`, `cu14_publish_item_test.dart`, `cu19_filter_publications_test.dart`, and `matching_and_proximity_test.dart`**

Incluye todas las matrices de prueba `TC-CU11-01..06`, `TC-CU14-01..05` y `TC-CU19-01..05` de los planes originales, más pruebas en `matching_and_proximity_test.dart` para: edición y retiro de publicación activa (`CU-15`, `CU-16`), publicación por intermediario con alias obligatorio (`CU-46`, `CU-47`), filtro de cercanía con permiso de GPS (`CU-20`, `CU-21`), filtro/orden por urgencia (`CU-22`), y cruce de coincidencias con notificación (`CU-17`, `CU-18`).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/publications/ test/features/matching/`
Expected: FAIL.

- [ ] **Step 3: Implement publications and matching screens and controllers**

Implementa los formularios, controladores, pantalla de detalle, hoja de edición/retiro, feed con filtros extendidos y pantalla de coincidencias.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/publications/ test/features/matching/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/publications/ lib/features/matching/ lib/app/router.dart test/features/publications/ test/features/matching/
git commit -m "feat(publications,matching): implement CU-11 to CU-22 and CU-46/47 publications, filters, proximity, and matching"
```

---

### Task 5: Bloque 4 — Propuestas (CU-23 a CU-29), Seguimiento de Donación y Chat (CU-30 a CU-36), Reseñas (CU-37) e Historial (CU-38, CU-39)

**Files:**
- Create: `lib/features/proposals/presentation/request_item_controller.dart`
- Create: `lib/features/proposals/presentation/request_item_sheet.dart`
- Create: `lib/features/proposals/presentation/offer_item_controller.dart`
- Create: `lib/features/proposals/presentation/offer_item_sheet.dart`
- Create: `lib/features/donations/presentation/donations_hub_screen.dart`
- Create: `lib/features/donations/presentation/donation_tracking_screen.dart`
- Create: `test/features/proposals/cu23_request_item_test.dart`
- Create: `test/features/proposals/cu24_offer_item_test.dart`
- Create: `test/features/donations/donations_lifecycle_test.dart`

**Interfaces:**
- Consumes: `mockTenantStoreProvider`, `PublicationDetailScreen`.
- Produces:
  - `RequestItemSheet({super.key, required this.publicationId})` (`CU-23`: mensaje `1..300` caracteres).
  - `OfferItemSheet({super.key, required this.publicationId})` (`CU-24`: descripción + `1..5` fotografías).
  - `DonationsHubScreen` con 3 pestañas:
    1. *Propuestas*: recibidas (`CU-26` con Perfil de Confianza del remitente, botones `Aceptar` `CU-27`/`CU-28` y `Rechazar` `CU-29`) y enviadas (`CU-25` con botón `Retirar`).
    2. *En curso*: tarjetas de donaciones activas (`ACEPTADA`, `EN_ENTREGA`, `ENTREGADA`) que abren `DonationTrackingScreen`.
    3. *Historial* (`CU-38`, `CU-39`): donaciones `FINALIZADA` o `CANCELADA` con chips de filtro por papel (*Todos*, *Donante*, *Donatario*) y estado (*Todos*, *Finalizada*, *Cancelada*).
  - `DonationTrackingScreen` (`CU-30 a CU-37`): estado actual e historial cronológico de cambios (`CU-35`), formulario para registrar lugar y fecha acordados (`CU-32`), botón `Marcar como Entregada` para el donante (`CU-33`), botón `Confirmar recepción` para el donatario/intermediario (`CU-34`), botón `Cancelar donación` con motivo obligatorio en `ACEPTADA`/`EN_ENTREGA` (`CU-36`), chat activo en `ACEPTADA`/`EN_ENTREGA` con switch `Compartir mi teléfono` (`CU-31`), y formulario de reseña de 1 a 5 estrellas y comentario `<= 500` caracteres cuando está `FINALIZADA` (`CU-37`).

- [ ] **Step 1: Write failing widget tests in `cu23_request_item_test.dart`, `cu24_offer_item_test.dart`, and `donations_lifecycle_test.dart`**

Incluye `TC-CU23-01..05` y `TC-CU24-01..06` de los planes originales, y en `donations_lifecycle_test.dart` verifica el ciclo completo en UI: retirar propuesta enviada (`CU-25`), consultar y aceptar propuesta recibida creando la donación (`CU-26`, `CU-27`, `CU-28`), enviar mensaje en el chat y compartir teléfono (`CU-31`), registrar lugar y fecha de entrega (`CU-32`), marcar como entregada por el donante (`CU-33`), confirmar recepción por el donatario (`CU-34`), consultar historial de cambios (`CU-35`), dejar reseña verificada recalculando confianza (`CU-37`), cancelar donación con motivo reactivando la publicación (`CU-36`), y filtrar historial por papel y estado (`CU-38`, `CU-39`).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/proposals/ test/features/donations/`
Expected: FAIL.

- [ ] **Step 3: Implement proposal sheets, donations hub, and donation tracking screen**

Implementa `request_item_controller.dart`, `request_item_sheet.dart`, `offer_item_controller.dart`, `offer_item_sheet.dart`, `donations_hub_screen.dart` y `donation_tracking_screen.dart`, conectándolos a `PublicationDetailScreen` y `router.dart`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/proposals/ test/features/donations/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/proposals/ lib/features/donations/ lib/features/publications/presentation/publication_detail_screen.dart lib/app/router.dart test/features/proposals/ test/features/donations/
git commit -m "feat(proposals,donations): implement CU-23 to CU-39 proposals, donation lifecycle, chat, reviews, and history"
```

---

### Task 6: Bloque 5 — Solicitud de Rol de Intermediario (CU-40, CU-41) y Panel de Administración (CU-42 a CU-45, CU-48 a CU-51)

**Files:**
- Create: `lib/features/intermediary/presentation/request_intermediary_sheet.dart`
- Create: `lib/features/admin/presentation/admin_panel_screen.dart`
- Create: `test/features/admin/intermediary_and_admin_test.dart`

**Interfaces:**
- Consumes: `mockTenantStoreProvider`, `ProfileScreen`.
- Produces:
  - `RequestIntermediarySheet` (`CU-40`, `CU-41`: captura organización/comunidad y selector de documento de respaldo `.pdf/.jpg/.png` `<= 5 MB`, incluyendo opciones de prueba para simular documento válido o documento que excede 5 MB / formato inválido).
  - `AdminPanelScreen` accesible desde `/admin` (y desde el botón `Panel de Administración` en `ProfileScreen` cuando `activeUser.esAdministrador == true`) con 2 pestañas:
    1. *Intermediarios* (`CU-42 a CU-45`): lista solicitudes pendientes con botones `Aprobar` (`CU-43`) y `Rechazar` (`CU-44`), y lista intermediarios activos con botón `Revocar rol` (`CU-45`).
    2. *Categorías* (`CU-48 a CU-51`): formulario para crear categoría (`CU-49`), acción para renombrar categoría existente (`CU-50`) y acción para desactivar categoría activa (`CU-51`).

- [ ] **Step 1: Write failing widget tests in `test/features/admin/intermediary_and_admin_test.dart`**

Verifica en UI:
1. Usuario `usr-diego` abre `RequestIntermediarySheet` desde su perfil, valida rechazo si falta documento o organización (`4a`), envía solicitud válida con documento `.pdf` (`CU-40`, `CU-41`).
2. Administrador `usr-alondra` abre `AdminPanelScreen`, aprueba la solicitud de `usr-diego` (`CU-43`), rechaza una solicitud (`CU-44`) y revoca el rol de un intermediario autorizado (`CU-45`).
3. Administrador crea una categoría nueva (`CU-49`), verifica rechazo por nombre vacío o duplicado, renombra una categoría existente (`CU-50`) y desactiva una categoría activa verificando que deje de ofrecerse en `getActiveCategories()` (`CU-51`).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/admin/intermediary_and_admin_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `request_intermediary_sheet.dart` and `admin_panel_screen.dart` and wire them into `profile_screen.dart` and `router.dart`**

Implementa ambos widgets y conéctalos a la sección correspondiente de `ProfileScreen` y a la ruta `/admin`.

- [ ] **Step 4: Run full test suite and static analysis**

Run: `flutter test && flutter analyze`
Expected: PASS (all unit and widget tests across all 6 tasks pass with 0 analyzer issues).

- [ ] **Step 5: Commit**

```bash
git add lib/ test/
git commit -m "feat(intermediary,admin): implement CU-40 to CU-45 and CU-48 to CU-51 intermediary requests and admin panel"
```

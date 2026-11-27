# Términos, Permisos del Dispositivo y Edición de Alimentos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Incorporar el modal de **Aviso de Privacidad y Términos y Condiciones de Uso** (en Registro y Perfil), el panel de **Permisos del Dispositivo** y captura desde cámara/galería para foto de perfil y documento de intermediario, y completar los campos de **Alimentación** en `EditPublicationSheet`.

**Architecture:** Se añade un módulo visual compartido en `lib/core/widgets/legal_documents_sheet.dart` (`LegalDocumentsSheet` + `LegalAndPermissionsCard`) conectado a `MockTenantStore` y `GeolocatorAndroid`. Se extienden `ProfileAvatarCircle`, `ProfileAvatarSelector` y `RequestIntermediarySheet` reutilizando `ImagePickerAndroid` (`usesAndroidDeviceAccess`), y se sincroniza `EditPublicationSheet` con `PresentacionAlimento` e `isValidExpirationDate`.

**Tech Stack:** Flutter (`sdk: ^3.13.5`), `flutter_riverpod`, `go_router`, `image_picker_android`, `image_picker_platform_interface`, `geolocator_android`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-11-26-terminos-permisos-alimentos-design.md`

## Global Constraints

- No modificar `pubspec.yaml`, Gradle ni `AndroidManifest.xml`; usar únicamente `image_picker_android`, `image_picker_platform_interface` y `geolocator_android`.
- Conservar en `RegisterScreen` (Paso 3) el texto exacto del `CheckboxListTile` `'He leído y acepto el aviso de privacidad'` para mantener compatible `TC-CU01-01`.
- Conservar todos los chips de muestra en `ProfileAvatarSelector` y `RequestIntermediarySheet` para no romper `TC-CU01-01`, `CU-06` ni `CU-40/41`.
- Respetar minimización de datos (**RNF-09**), autorización explícita de ubicación (**RNF-08**) y soporte de alto contraste / escala de texto `1.25x` sin overflow (**RNF-03**).

## Review Focus

- **Usuario sin sesión activa en `ProfileScreen` (`_LoggedOutProfileView`):** También debe mostrar `LegalAndPermissionsCard` y permitir abrir tanto el *Aviso de Privacidad* como los *Términos y Condiciones de Uso* antes de iniciar sesión o registrarse (cubierto en Task 1).
- **Diálogo de autorización/denegación de ubicación (`CU-21 / RNF-08`) desde `ProfileScreen`:** Si el usuario pulsa el control de ubicación en Perfil y elige *Denegar*, `store.isDeviceLocationAuthorized` permanece `false`; si elige *Permitir*, pasa a `true`, y si vuelve a pulsar cuando ya está autorizada, se desactiva a `false` (cubierto en Task 1).
- **Ruta `file://` inexistente o inválida en `ProfileAvatarCircle`:** Cuando `fotoPerfil` tiene un URI `file:///ruta/inexistente.jpg`, `Image.file` debe degradar limpiamente al ícono de avatar mediante `errorBuilder` sin lanzar excepción en el árbol de widgets (cubierto en Task 2).
- **Edición de un artículo de `Alimentación` (`cat-alimentacion`) existente en `EditPublicationSheet`:** Al abrir `EditPublicationSheet` sobre un alimento publicado, debe precargar `Presentación`, `Contenido por envase` y `Fecha de caducidad`, rechazar fechas inválidas (`31/02/2028`), y guardar conservando `condicion == null` (cubierto en Task 3).
- **Cambio de categoría en `EditPublicationSheet` entre `Alimentación` y otra categoría:** Si un artículo cambia de `Ropa` a `Alimentación`, debe ocultar `ItemConditionSelector`, exigir `PresentacionAlimento` y limpiar `condicion` a `null`; si cambia de `Alimentación` a `Ropa`, debe exigir `CondicionArticulo` y limpiar las características de alimento (cubierto en Task 3).

---

### Task 1: Documentos Legales (`Aviso de Privacidad` y `Términos y Condiciones`) y Panel de Permisos en Registro y Perfil

**Files:**
- Create: `lib/core/widgets/legal_documents_sheet.dart`
- Modify: `lib/features/auth/presentation/register_screen.dart:301-415`
- Modify: `lib/features/profile/presentation/profile_screen.dart:1-166`
- Test: `test/features/auth/auth_and_profile_test.dart`

**Interfaces:**
- Consumes: `MockTenantStore` (`isDeviceLocationAuthorized`, `setDeviceLocationAuthorized`), `usesAndroidDeviceAccess` de `lib/features/publications/presentation/publication_ui_helpers.dart`.
- Produces in `lib/core/widgets/legal_documents_sheet.dart`:
  - `enum LegalDocumentTab { privacy, terms }`
  - `Future<void> showLegalDocumentsSheet(BuildContext context, {LegalDocumentTab initialTab = LegalDocumentTab.privacy})`
  - `class LegalDocumentsSheet extends StatefulWidget` (con pestañas `Key('legal_tab_privacy')` y `Key('legal_tab_terms')`)
  - `class LegalAndPermissionsCard extends ConsumerStatefulWidget` (con switch/botón `Key('profile_device_location_switch')`, botón `Key('open_privacy_notice_button')` y botón `Key('open_terms_conditions_button')`)
- Produces in `lib/features/auth/presentation/register_screen.dart`:
  - Botones `Key('register_open_privacy_button')` y `Key('register_open_terms_button')` en Paso 3 que abren `showLegalDocumentsSheet`.

- [ ] **Step 1: Write the failing test in `test/features/auth/auth_and_profile_test.dart`**

Agregar al final de `group('Profile (CU-03..06, CU-10)', ...)` en `test/features/auth/auth_and_profile_test.dart`:

```dart
    testWidgets(
      'LegalDocumentsSheet y LegalAndPermissionsCard funcionan en Perfil (con y sin sesión) y en Registro Paso 3',
      (tester) async {
        final (store, container) = await pumpAppAtRoute(tester, '/profile');
        final router = container.read(appRouterProvider);

        // 1. Logged-in Profile shows LegalAndPermissionsCard & toggles location (CU-21 / RNF-08)
        expect(find.text('Privacidad, Términos y Permisos'), findsOneWidget);
        expect(store.isDeviceLocationAuthorized, isFalse);

        final locSwitch = find.byKey(const Key('profile_device_location_switch'));
        await tester.ensureVisible(locSwitch);
        await tester.tap(locSwitch);
        await tester.pumpAndSettle();

        expect(find.text('Autorizar ubicación del dispositivo'), findsOneWidget);
        await tester.tap(find.text('Denegar'));
        await tester.pumpAndSettle();
        expect(store.isDeviceLocationAuthorized, isFalse);

        await tester.tap(locSwitch);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Permitir'));
        await tester.pumpAndSettle();
        expect(store.isDeviceLocationAuthorized, isTrue);

        // Turning it off disables device location immediately
        await tester.tap(locSwitch);
        await tester.pumpAndSettle();
        expect(store.isDeviceLocationAuthorized, isFalse);

        // 2. Open Términos y Condiciones modal and switch to Aviso de Privacidad tab
        final termsBtn = find.byKey(const Key('open_terms_conditions_button'));
        await tester.ensureVisible(termsBtn);
        await tester.tap(termsBtn);
        await tester.pumpAndSettle();

        expect(find.textContaining('Gratuidad obligatoria'), findsOneWidget);
        await tester.tap(find.byKey(const Key('legal_tab_privacy')));
        await tester.pumpAndSettle();
        expect(find.textContaining('Minimización de datos (RNF-09)'), findsOneWidget);
        await tester.tap(find.byTooltip('Cerrar'));
        await tester.pumpAndSettle();

        // 3. Logged-out Profile also allows opening LegalDocumentsSheet
        store.setActiveUser(null);
        await tester.pumpAndSettle();
        expect(find.text('No has iniciado sesión'), findsOneWidget);
        final loggedOutPrivacyBtn =
            find.byKey(const Key('open_privacy_notice_button'));
        await tester.ensureVisible(loggedOutPrivacyBtn);
        await tester.tap(loggedOutPrivacyBtn);
        await tester.pumpAndSettle();
        expect(find.textContaining('Minimización de datos (RNF-09)'), findsOneWidget);
        await tester.tap(find.byTooltip('Cerrar'));
        await tester.pumpAndSettle();

        // 4. RegisterScreen Step 3 exposes both legal documents
        router.go('/register');
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('register_username_field')),
          'carlos_legal',
        );
        await tester.enterText(
          find.byKey(const Key('register_email_field')),
          'carlos.legal@buap.mx',
        );
        await tester.enterText(
          find.byKey(const Key('register_password_field')),
          'Donar2026',
        );
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('register_legal_name_field')),
          'Carlos Mendoza',
        );
        await tester.enterText(
          find.byKey(const Key('register_phone_field')),
          '2221112233',
        );
        await tester.enterText(
          find.byKey(const Key('register_location_field')),
          'Col. Centro, CP 72000',
        );
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        expect(
          find.text('Incluye los Términos y Condiciones de Uso de DonaPlus.'),
          findsOneWidget,
        );
        final regTermsBtn = find.byKey(const Key('register_open_terms_button'));
        await tester.ensureVisible(regTermsBtn);
        await tester.tap(regTermsBtn);
        await tester.pumpAndSettle();
        expect(find.textContaining('Gratuidad obligatoria'), findsOneWidget);
      },
    );
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/auth_and_profile_test.dart`
Expected: FAIL (`Privacidad, Términos y Permisos` / `profile_device_location_switch` not found).

- [ ] **Step 3: Implement `lib/core/widgets/legal_documents_sheet.dart`, update `register_screen.dart` and `profile_screen.dart`**

1. Crear `lib/core/widgets/legal_documents_sheet.dart`:
   - `LegalDocumentsSheet(initialTab: initialTab)` con encabezado, botón `IconButton(tooltip: 'Cerrar', ...)` y selector de 2 pestañas (`ChoiceChip` o `SegmentedButton` con `Key('legal_tab_privacy')` y `Key('legal_tab_terms')`).
   - Pestaña **Aviso de Privacidad** incluye secciones: *1. Minimización de datos (RNF-09)*, *2. Ubicación aproximada y permiso del dispositivo (RNF-08 / CU-21)*, *3. Privacidad de teléfono y beneficiarios (CU-31 / CU-47)* y *4. Seguridad de credenciales (RNF-07)*.
   - Pestaña **Términos y Condiciones de Uso** incluye secciones: *1. Gratuidad obligatoria y prohibición de venta*, *2. Artículos permitidos y reglas de Alimentación (envases cerrados y caducidad vigente)*, *3. Coordinación, entregas seguras y cierre automático a los 7 días (CU-34)* y *4. Rol de intermediario comunitario (CU-40 a CU-47)*.
   - `LegalAndPermissionsCard` muestra:
     - Título `'Privacidad, Términos y Permisos'`.
     - `SwitchListTile` con `key: const Key('profile_device_location_switch')` para `'Ubicación aproximada del dispositivo (CU-21 / RNF-08)'` usando el mismo flujo de diálogo de autorización (`'Autorizar ubicación del dispositivo'`, botones `'Denegar'` y `'Permitir'`) y `GeolocatorAndroid` cuando `usesAndroidDeviceAccess == true`.
     - Fila informativa de `'Cámara y Galería del dispositivo'` indicando que se solicita al tomar o elegir fotografías de perfil, artículos, ofertas o documentos de respaldo.
     - Botones `OutlinedButton.icon` con `Key('open_privacy_notice_button')` (`'Aviso de Privacidad'`) y `Key('open_terms_conditions_button')` (`'Términos y Condiciones'`).
2. En `lib/features/auth/presentation/register_screen.dart` (Paso 3):
   - Actualizar el recuadro de texto para resumir tanto el *Aviso de Privacidad* como los *Términos y Condiciones de Uso*.
   - Añadir debajo del recuadro un `Wrap` con `TextButton.icon` (`Key('register_open_privacy_button')` y `Key('register_open_terms_button')`) que invocan `showLegalDocumentsSheet`.
   - En el `CheckboxListTile` existente, conservar `title: const Text('He leído y acepto el aviso de privacidad')` y añadir `subtitle: const Text('Incluye los Términos y Condiciones de Uso de DonaPlus.')`.
3. En `lib/features/profile/presentation/profile_screen.dart`:
   - Insertar `const LegalAndPermissionsCard()` tanto en la vista autenticada (debajo de `_IntermediarySectionCard` / `_AdminAccessCard`) como en `_LoggedOutProfileView` (debajo de la tarjeta de inicio de sesión).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/auth/auth_and_profile_test.dart test/features/auth/cu01_register_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/legal_documents_sheet.dart lib/features/auth/presentation/register_screen.dart lib/features/profile/presentation/profile_screen.dart test/features/auth/auth_and_profile_test.dart
git commit -m "feat(legal,permissions): add terms and conditions sheet and device permissions card"
```

---

### Task 2: Cámara, Galería y Archivos Locales en Foto de Perfil y Documento de Intermediario

**Files:**
- Modify: `lib/features/auth/presentation/auth_form_widgets.dart:170-292`
- Modify: `lib/features/auth/presentation/register_screen.dart:307-314`
- Modify: `lib/features/intermediary/presentation/request_intermediary_sheet.dart:70-420`
- Test: `test/features/auth/auth_and_profile_test.dart`, `test/features/admin/intermediary_and_admin_test.dart`

**Interfaces:**
- Consumes: `usesAndroidDeviceAccess` de `lib/features/publications/presentation/publication_ui_helpers.dart`, `ImagePickerAndroid` y `ImageSource`.
- Produces in `lib/features/auth/presentation/auth_form_widgets.dart`:
  - `ProfileAvatarCircle`: renderiza `file://` con `ClipOval` + `Image.file(File.fromUri(Uri.parse(fotoPerfil!)), errorBuilder: ...)` cuando `!kIsWeb && fotoPerfil!.startsWith('file://')`.
  - `ProfileAvatarSelector`: añade chip/botón `Key('profile_avatar_device_photo_chip')` (`'Cámara o galería'`) que en Android abre cámara/galería con `ImagePickerAndroid` y fuera de Android selecciona `'device://avatar_galeria.jpg'`.
- Produces in `lib/features/intermediary/presentation/request_intermediary_sheet.dart`:
  - Botón/chip `Key('intermediary_doc_device_photo')` (`'Tomar foto o elegir de galería'`) que en Android captura con `ImagePickerAndroid`, obtiene el nombre y longitud en bytes de `File(photo.path)` y lo valida con `_validateDocument`, y fuera de Android selecciona un documento de cámara simulado (`'constancia_camara_dispositivo.jpg'`, `942080` bytes, `'920 KB'`).

- [ ] **Step 1: Write the failing tests in `test/features/auth/auth_and_profile_test.dart` and `test/features/admin/intermediary_and_admin_test.dart`**

1. En `test/features/auth/auth_and_profile_test.dart`, agregar:

```dart
    testWidgets(
      'ProfileAvatarSelector permite elegir foto de cámara/galería y ProfileAvatarCircle maneja file:// inexistente sin error',
      (tester) async {
        final (store, _) = await pumpAppAtRoute(tester, '/profile');
        store.setActiveUser('usr-diego');
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Editar perfil'));
        await tester.tap(find.text('Editar perfil'));
        await tester.pumpAndSettle();

        final devicePhotoChip =
            find.byKey(const Key('profile_avatar_device_photo_chip'));
        await tester.ensureVisible(devicePhotoChip);
        await tester.tap(devicePhotoChip);
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Guardar cambios'));
        await tester.tap(find.text('Guardar cambios'));
        await tester.pumpAndSettle();

        expect(
          store.findUserById('usr-diego')?.fotoPerfil,
          'device://avatar_galeria.jpg',
        );

        // Fallback safety when fotoPerfil has a non-existent file:// URI
        await store.updateProfile(
          fotoPerfil: 'file:///non_existent_avatar_test.jpg',
          telefono: '2225550199',
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
```

2. En `test/features/admin/intermediary_and_admin_test.dart`, dentro de `group('CU-40 & CU-41: Solicitud de rol de intermediario', ...)`, agregar:

```dart
    testWidgets(
      'CU-40 & CU-41: permite adjuntar foto de respaldo desde cámara/galería del dispositivo',
      (tester) async {
        final (store, _) = await pumpAppAtRoute(tester, '/profile');
        store.setActiveUser('usr-diego');
        await tester.pumpAndSettle();

        await tapVisible(tester, find.text('Solicitar rol de intermediario'));
        await enterTextAndSettle(
          tester,
          find.byKey(const Key('intermediary_organization_field')),
          'Brigada Comunitaria BUAP',
        );
        await tapVisible(
          tester,
          find.byKey(const Key('intermediary_doc_device_photo')),
        );
        await tapVisible(
          tester,
          find.byKey(const Key('intermediary_submit_button')),
        );

        expect(find.textContaining('Solicitud enviada'), findsOneWidget);
        final createdReq = store.intermediaryRequests.last;
        expect(createdReq.documentoNombre, 'constancia_camara_dispositivo.jpg');
        expect(createdReq.documentoBytesSimulados, 942080);
      },
    );
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/auth/auth_and_profile_test.dart test/features/admin/intermediary_and_admin_test.dart`
Expected: FAIL (`profile_avatar_device_photo_chip` and `intermediary_doc_device_photo` not found).

- [ ] **Step 3: Implement camera/gallery support in `auth_form_widgets.dart`, `register_screen.dart` and `request_intermediary_sheet.dart`**

1. En `lib/features/auth/presentation/auth_form_widgets.dart`:
   - En `ProfileAvatarCircle`, detectar `final isLocalFile = !kIsWeb && fotoPerfil != null && fotoPerfil!.startsWith('file://');`. Si es verdadero, renderizar `ClipOval` dentro de `CircleAvatar` con `Image.file(File.fromUri(Uri.parse(fotoPerfil!)), width: radius * 2, height: radius * 2, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.account_circle, size: radius * 1.1))`.
   - Convertir `ProfileAvatarSelector` en `StatefulWidget` con método `_pickDeviceAvatar()` que cuando `usesAndroidDeviceAccess == true` abre el modal de `ImageSource.camera` / `ImageSource.gallery` con `ImagePickerAndroid` y pasa `File(photo.path).uri.toString()` a `widget.onChanged`, y cuando `usesAndroidDeviceAccess == false` pasa `'device://avatar_galeria.jpg'`.
   - Agregar el `ChoiceChip` con `key: const Key('profile_avatar_device_photo_chip')`, `avatar: const Icon(Icons.add_a_photo_outlined, size: 16)`, `label: const Text('Cámara o galería')`.
2. En `lib/features/auth/presentation/register_screen.dart`:
   - Actualizar `avatarLabel` en `_buildStep3` para que si `state.photoPerfil` empieza con `'file://'` o `'device://'` muestre `'Fotografía del dispositivo'`.
3. En `lib/features/intermediary/presentation/request_intermediary_sheet.dart`:
   - Añadir un método `_pickDeviceDocument()` que cuando `usesAndroidDeviceAccess == true` abre el selector de cámara/galería con `ImagePickerAndroid`, obtiene el archivo `File(photo.path)`, su tamaño real con `await file.length()` y su nombre con `photo.path.split(Platform.pathSeparator).last`, y llama a `_selectDocument(...)`; cuando `usesAndroidDeviceAccess == false`, selecciona `_SimulatedDocumentOption(chipKey: const Key('intermediary_doc_device_photo'), name: 'constancia_camara_dispositivo.jpg', bytes: 942080, sizeLabel: '920 KB')`.
   - Añadir el `ChoiceChip` / `ActionChip` con `key: const Key('intermediary_doc_device_photo')`, `avatar: const Icon(Icons.add_a_photo_outlined, size: 16)`, `label: const Text('Cámara o galería')`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/auth/auth_and_profile_test.dart test/features/admin/intermediary_and_admin_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/presentation/auth_form_widgets.dart lib/features/auth/presentation/register_screen.dart lib/features/intermediary/presentation/request_intermediary_sheet.dart test/features/auth/auth_and_profile_test.dart test/features/admin/intermediary_and_admin_test.dart
git commit -m "feat(profile,intermediary): support device camera and gallery for profile avatars and backup documents"
```

---

### Task 3: Edición de Artículos de la Categoría Alimentación (`EditPublicationSheet`)

**Files:**
- Modify: `lib/features/publications/presentation/edit_publication_sheet.dart:35-448`
- Test: `test/features/publications/cu14_publish_item_test.dart`

**Interfaces:**
- Consumes: `PresentacionAlimento`, `CategoriaMock.alimentacionId`, `isValidExpirationDate` de `lib/features/publications/presentation/publication_form_validators.dart`, `MockTenantStore.updateItemPublication`.
- Produces in `lib/features/publications/presentation/edit_publication_sheet.dart`:
  - `DropdownButtonFormField<PresentacionAlimento>` con `Key('edit_pub_food_package_field')`
  - `TextFormField` con `Key('edit_pub_food_package_content_field')`
  - `TextFormField` con `Key('edit_pub_food_expiration_field')`

- [ ] **Step 1: Write the failing test in `test/features/publications/cu14_publish_item_test.dart`**

Agregar al final de `group('CU-14 & CU-13: Publicar Artículo', ...)` en `test/features/publications/cu14_publish_item_test.dart`:

```dart
    testWidgets(
      'CU-16 Alimentación: EditPublicationSheet precarga, valida y actualiza presentación, contenido y caducidad, y maneja cambio de categoría',
      (tester) async {
        final (store, container) = await pumpAppAtCreateItem(tester);

        // Crear un artículo de Alimentación para editarlo
        final createdFood = await store.createItemPublication(
          const CreateItemInput(
            titulo: 'Arroz integral',
            descripcion: 'Bolsas selladas',
            categoriaId: CategoriaMock.alimentacionId,
            fotografias: ['sample://despensa_1.jpg'],
            cantidad: 4,
            condicion: null,
            ubicacionEtiqueta: 'Col. Centro, CP 72000',
            caracteristicas: {
              'Presentación': 'Bolsas',
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
        await tester.tap(packageField);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cajas').last);
        await tester.pumpAndSettle();
        await tester.enterText(contentField, '2 kg');
        await tester.enterText(expirationField, '20/12/2027');
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        final updatedFood = store.findPublicationById(createdFood.id)!;
        expect(updatedFood.condicion, isNull);
        expect(updatedFood.caracteristicas, {
          'Presentación': 'Cajas',
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
      },
    );
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/publications/cu14_publish_item_test.dart`
Expected: FAIL (`edit_pub_food_package_field` not found).

- [ ] **Step 3: Implement food fields and validation in `lib/features/publications/presentation/edit_publication_sheet.dart`**

En `lib/features/publications/presentation/edit_publication_sheet.dart`:
- Añadir en `_EditPublicationSheetState`:
  - `late final TextEditingController _packageContentController;`
  - `late final TextEditingController _expirationDateController;`
  - `PresentacionAlimento? _presentacionAlimento;`
  - `String? _presentacionError;`
  - `String? _caducidadError;`
  - `bool get _isFoodItem => !_isNeed && _categoryId == CategoriaMock.alimentacionId;`
- En `initState()`:
  - Inicializar `_presentacionAlimento` buscando en `PresentacionAlimento.values` aquel cuyo `etiqueta == pub.caracteristicas['Presentación']`.
  - Inicializar `_packageContentController = TextEditingController(text: pub.caracteristicas['Contenido por envase'] ?? '')`.
  - Inicializar `_expirationDateController = TextEditingController(text: pub.caracteristicas['Fecha de caducidad'] ?? '')`.
  - Liberar ambos controladores en `dispose()`.
- En `_save()` para artículos (`!_isNeed`):
  - Si `_isFoodItem`, validar `_presentacionError = _presentacionAlimento == null ? 'Selecciona la presentación del alimento.' : null;` y `_caducidadError = caducidad.isNotEmpty && !isValidExpirationDate(caducidad) ? 'Ingresa una fecha válida con el formato DD/MM/AAAA.' : null;`.
  - Pasar `condicion: _isFoodItem ? null : _condition` tanto a `validateItemFields` como a `CreateItemInput`.
  - Pasar a `CreateItemInput` el mapa `caracteristicas`: si `_isFoodItem`, `{ 'Presentación': _presentacionAlimento!.etiqueta, if (contenido.isNotEmpty) 'Contenido por envase': contenido, if (caducidad.isNotEmpty) 'Fecha de caducidad': caducidad }`; si no es `_isFoodItem`, `null` (para que `updateItemPublication` limpie características cuando sale de `cat-alimentacion`).
- En `build()`:
  - Cuando `_isFoodItem` es verdadero, mostrar debajo de `ActiveCategoryDropdown` los 3 campos (`Key('edit_pub_food_package_field')`, `Key('edit_pub_food_package_content_field')`, `Key('edit_pub_food_expiration_field')`) y usar la etiqueta `'Número de envases *'` en el campo de cantidad.

- [ ] **Step 4: Run the full test suite to verify everything passes**

Run: `flutter test`
Expected: PASS (todos los tests del proyecto en verde).

- [ ] **Step 5: Commit**

```bash
git add lib/features/publications/presentation/edit_publication_sheet.dart test/features/publications/cu14_publish_item_test.dart
git commit -m "fix(publications): support food presentation and expiration fields in EditPublicationSheet"
```

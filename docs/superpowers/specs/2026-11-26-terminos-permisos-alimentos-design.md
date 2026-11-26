# Especificación de Diseño — Términos y Condiciones, Permisos del Dispositivo y Edición de Alimentos

## 1. Intención y el porqué
Completar para la entrega final de **DonaPlus** tres aspectos pendientes tras la integración de ubicación y cámara (`Mod_Alo`):
1. Incorporar los **Términos y Condiciones de Uso** junto con el **Aviso de Privacidad** completo tanto en el flujo de registro como para consulta permanente desde el perfil.
2. Extender el acceso a **cámara, galería y control de permisos en Android** hacia la fotografía de perfil, el documento de respaldo del intermediario comunitario y una tarjeta de estado de permisos en el perfil.
3. Completar el cuestionario de la categoría **Alimentación** en la hoja de edición de artículos (`EditPublicationSheet`) para mantener paridad con el formulario de publicación (`PublishItemForm`).

## 2. Objetivos, No-objetivos y Anti-objetivos
- **Objetivos:**
  - Proveer un modal reutilizable (`LegalDocumentsSheet`) con pestañas de **Aviso de Privacidad** y **Términos y Condiciones de Uso**, accesible desde el Paso 3 de `RegisterScreen` y desde `ProfileScreen` (con o sin sesión activa).
  - Permitir capturar o elegir fotografía de perfil desde cámara/galería en Android (`ProfileAvatarSelector`) y renderizar rutas `file://` en `ProfileAvatarCircle`.
  - Permitir en Android adjuntar una fotografía/imagen real de respaldo en `RequestIntermediarySheet` leyendo su tamaño real en bytes para validarlo contra el límite de 5 MB (**CU-41**).
  - Mostrar en `ProfileScreen` el estado y controles de permisos del dispositivo (**Ubicación aproximada RNF-08 / CU-21** y **Cámara / Galería**).
  - Soportar en `EditPublicationSheet` los campos de **Presentación del alimento**, **Contenido por envase** y **Fecha de caducidad (DD/MM/AAAA)** cuando la categoría sea `cat-alimentacion`.
- **No-objetivos:**
  - No se agregan paquetes ni plugins nativos adicionales en `pubspec.yaml`.
- **Anti-objetivos:**
  - No cambiar el texto principal de la casilla `'He leído y acepto el aviso de privacidad'` en `RegisterScreen` ni eliminar los chips simulados de avatar o documentos, para no romper ningún test automatizado existente (`TC-CU01-01`, `CU-40/41`, `CU-14`).

## 3. Restricciones
- Conservar intacta la configuración de compilación Android (`pubspec.yaml`, Gradle y `AndroidManifest.xml`) usando únicamente `image_picker_android` y `geolocator_android`.
- Respetar el principio de minimización de datos (**RNF-09**), autorización explícita de ubicación (**RNF-08**) y soporte de alto contraste (**RNF-03**).
- Mantener el 100% de las pruebas actuales de `flutter test` en verde.

## 4. Enfoques Evaluados y Elección
- **Enfoque 1 (Elegido): Componentes compartidos en `lib/core/widgets/` reutilizando `image_picker_android` y `geolocator_android` sin nuevas dependencias.**
  - *Ventajas:* Cero riesgo de conflictos de compilación en Gradle/APK, paridad con el código de `Mod_Alo` y compatibilidad total con `flutter test`.
  - *Compromiso:* En Android físico, la captura real de documento para intermediario se realiza como imagen (`.jpg`/`.png`) desde cámara o galería, manteniendo `.pdf` en las opciones de muestra del tenant.
- **Enfoque 2 (Descartado): Agregar `permission_handler` y `file_picker` en `pubspec.yaml`.**
  - *Ventajas:* Selector nativo de archivos `.pdf` del almacenamiento local.
  - *Compromiso:* Introduce dos plugins nativos adicionales con riesgo de incompatibilidad de Gradle/Kotlin al generar el APK.

## 5. Diseño Acordado («El cómo»)
1. **`lib/core/widgets/legal_documents_sheet.dart` (Nuevo):**
   - `showLegalDocumentsSheet(BuildContext context, {LegalDocumentTab initialTab})`: abre un `ModalBottomSheet` con dos pestañas:
     - **Aviso de Privacidad:** detalla minimización de datos (**RNF-09**), ubicación aproximada por colonia/CP (**RNF-08**), teléfono oculto por defecto en chat (**CU-31**), alias de beneficiarios (**CU-47**) y resguardo criptográfico SHA-256 (**RNF-07**).
     - **Términos y Condiciones de Uso:** detalla gratuidad obligatoria (prohibición de venta o cobro), artículos permitidos y reglas para alimentos (envases cerrados y caducidad vigente), responsabilidad y seguridad en entregas, cierre automático a los 7 días (**CU-34**) y obligaciones del intermediario comunitario (**CU-40 a CU-47**).
   - `LegalAndPermissionsCard`: tarjeta para `ProfileScreen` que muestra el estado del permiso de **Ubicación aproximada (RNF-08)** (con botón para autorizar/desactivar o abrir Ajustes de Android en `usesAndroidDeviceAccess`), estado de **Cámara y Galería**, y botones para abrir el **Aviso de Privacidad** y los **Términos y Condiciones**.
2. **`lib/features/auth/presentation/register_screen.dart` (Paso 3):**
   - Amplía el recuadro informativo del Paso 3 para resumir tanto el **Aviso de Privacidad** como los **Términos y Condiciones de Uso**, añade botones para abrir `showLegalDocumentsSheet` en cualquiera de las dos pestañas, y mantiene el `CheckboxListTile` con `title: Text('He leído y acepto el aviso de privacidad')` agregando `subtitle: Text('Incluye los Términos y Condiciones de Uso de DonaPlus.')`.
3. **`lib/features/auth/presentation/auth_form_widgets.dart`:**
   - `ProfileAvatarCircle`: cuando `fotoPerfil` inicia con `file://` (y `!kIsWeb`), muestra la imagen local con `Image.file(File.fromUri(Uri.parse(fotoPerfil!)))` y fallback seguro en `errorBuilder`.
   - `ProfileAvatarSelector`: añade la acción para tomar foto o elegir de galería (`ImagePickerAndroid` en Android, o foto simulada `device://avatar_galeria.jpg` cuando se invoque desde selector secundario/pruebas), conservando los chips `'Sin foto'` y los 3 `sampleProfileAvatars`.
4. **`lib/features/intermediary/presentation/request_intermediary_sheet.dart`:**
   - Añade en Android (`usesAndroidDeviceAccess`) un botón **«Tomar foto o elegir imagen del dispositivo»** que captura la imagen con `ImagePickerAndroid`, calcula su tamaño real (`File(photo.path).length()`) y nombre de archivo, y lo pasa por la misma validación de extensión (`.pdf`, `.jpg`, `.jpeg`, `.png`) y tamaño (`<= 5 MB`) de **CU-41**, conservando los chips simulados.
5. **`lib/features/publications/presentation/edit_publication_sheet.dart`:**
   - Cuando `!_isNeed && _categoryId == CategoriaMock.alimentacionId`:
     - Precarga `PresentacionAlimento` desde `publication.caracteristicas['Presentación']`, contenido desde `publication.caracteristicas['Contenido por envase']` y caducidad desde `publication.caracteristicas['Fecha de caducidad']`.
     - Muestra `DropdownButtonFormField<PresentacionAlimento>` (`Key('edit_pub_food_package_field')`), campo de contenido por envase (`Key('edit_pub_food_package_content_field')`) y campo de fecha de caducidad (`Key('edit_pub_food_expiration_field')`), cambiando la etiqueta de cantidad a `'Número de envases *'` y ocultando `ItemConditionSelector`.
     - Valida que `PresentacionAlimento` no sea nula y que la fecha de caducidad (si no está vacía) cumpla `isValidExpirationDate` (`DD/MM/AAAA`), enviando `condicion: null` y el mapa `caracteristicas` actualizado a `store.updateItemPublication`.

## 6. Qué queda a criterio del implementador
- La redacción exacta por cláusulas dentro de las pestañas de `LegalDocumentsSheet`, siempre que cubra todos los puntos de privacidad y términos listados en la Sección 5.1.
- Las claves (`Key`) de los botones nuevos para facilitar pruebas de widgets deterministas.

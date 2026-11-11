# Especificación de Diseño — Base Compartida del MVP (Modo Mock / Tenant de Prueba)

## 1. Intención y contexto («El porqué»)
El equipo de 5 integrantes implementará en paralelo los primeros 6 casos de uso del MVP de **DonaPlus** (**CU-01**, **CU-11**, **CU-14**, **CU-19**, **CU-23** y **CU-24**) operando en **modo mock con un tenant de prueba en memoria**.

Esta especificación define la base común (tema visual DonaPlus, modelos del dominio, almacén en memoria `MockTenantStore`, datos semilla, enrutador y fronteras de archivos) para que cada integrante pueda desarrollar y probar su caso de uso de forma independiente sin conflictos de integración (`merge conflicts`) ni discrepancias de datos.

---

## 2. Objetivos, No-objetivos y Anti-objetivos

### Objetivos
- Proveer los modelos inmutables del dominio alineados con `docs/uml/01_diagrama_clases_dominio.puml` y `docs/Arquitectura_Donaciones.docx`.
- Proveer un `MockTenantStore` centralizado con `flutter_riverpod` que contenga los datos semilla de `docs/DISEÑO UI (1).pdf` (usuarios, categorías activas, Necesidades, Artículos y propuestas).
- Implementar la identidad visual **DonaPlus** (paleta `#004D64`, `#00A896`, `#A7E6A6`, `#FFF86A`) y el panel de **Accesibilidad** (tamaño de texto, alto contraste, reducir animaciones).
- Incluir un **Selector de Usuario de Prueba (Tenant Switcher)** y un **Interruptor de Simulación de Fallo de Red** en la barra superior para poder demostrar todos los flujos principales y alternos (**RNF-12**) sin levantar servidores externos.

### No-objetivos
- No se conectará en este corte a una instancia remota de Supabase (Postgres/Auth/Storage).
- No se implementarán los casos de uso fuera del alcance del MVP (como chat **CU-31**, aceptación de propuestas **CU-27**, emparejamiento automático **CU-17** o panel de administrador **CU-42 a CU-51**).

### Anti-objetivos (lo que haría fallar el diseño aunque compile)
- Que cada integrante cree sus propios modelos `Publicacion` o `Usuario` incompatibles entre sí.
- Que dos casos de uso editen el mismo archivo de pantalla monolítico provocando conflictos de Git al unir las ramas.
- Que las operaciones modifiquen la interfaz antes de validar las reglas del repositorio, violando **RNF-12**.

---

## 3. Restricciones
- **Plataforma y SDK:** Flutter (`sdk: ^3.13.5`), orientado a Android (**RNF-13**).
- **Navegación en ≤ 3 interacciones (RNF-02):** Barra de navegación inferior con acceso directo a *Inicio/Explorar* (**CU-19**), botón central `+` para *Crear publicación* (**CU-11**, **CU-14**) y selector de cuenta/perfil.
- **Legibilidad y accesibilidad (RNF-03):** Textos escalables y modo de alto contraste desde el control de accesibilidad.
- **Recuperación ante errores (RNF-12):** El `MockTenantStore` debe permitir activar un modo `simulateNetworkError` para verificar que ninguna pantalla dé por completada una operación cuando falla la conexión.

---

## 4. Enfoques Evaluados y Decisión

| Enfoque | Descripción | Ventajas | Compromisos |
|---|---|---|---|
| **1. Arquitectura por capas (`feature-first` + `flutter_riverpod` + `go_router`) con `MockTenantStore` en memoria (Elegido)** | Respeta la estructura de `docs/Arquitectura_Donaciones.docx` (`domain`, `data`, `presentation`) usando repositorios mock en memoria con datos semilla. | Aísla el trabajo de cada integrante, facilita pruebas de widget deterministas y permite migrar a Supabase cambiando solo la capa `data/`. | Al cerrar por completo la app, el estado vuelve a los datos semilla iniciales. |
| **2. Misma arquitectura con persistencia en JSON local** | Serializa el `MockTenantStore` en almacenamiento local del dispositivo. | Conserva registros entre reinicios de la app. | Añade código repetitivo de serialización y obliga a limpiar manualmente el estado entre pruebas. |
| **3. Prototipo monolítico con `StatefulWidget` sin paquetes** | Usa solo estado local y `Navigator` básico sin `Riverpod` ni `go_router`. | Cero dependencias nuevas en `pubspec.yaml`. | Se desvía de la arquitectura oficial del proyecto y dificulta el trabajo en paralelo. |

**Elección:** Se eligió el **Enfoque 1** porque mantiene intacta la arquitectura del equipo y permite delegar cada caso de uso en archivos separados con pruebas reproducibles.

---

## 5. Identidad Visual DonaPlus y Accesibilidad (`lib/app/theme.dart`)

Basado en las diapositivas 9, 11 y 13 de `docs/DISEÑO UI (1).pdf`:

- **Colores de marca:**
  - `primary`: `#004D64` (Azul petróleo oscuro — confiabilidad y encabezados).
  - `secondary`: `#00A896` (Verde azulado — botones de acción principal, botón `+` central, pestaña activa).
  - `accentMint`: `#A7E6A6` (Verde menta — insignias de confianza, confirmaciones y tarjetas de categoría).
  - `accentYellow`: `#FFF86A` (Amarillo suave — acentos de energía y tarjetas destacadas).
- **Control personal de Accesibilidad (`lib/core/widgets/accessibility_sheet.dart`):**
  - Accesible desde el chip `Accesibilidad` en el encabezado.
  - Permite alternar en tiempo real:
    1. **Tamaño de texto:** Normal (`1.0x`) / Ampliado (`1.25x`).
    2. **Alto contraste:** Normal / Alto contraste.
    3. **Reducir animaciones:** Normal / Transiciones instantáneas.

---

## 6. Modelos Compartidos del Dominio (`lib/core/models/`)

Todos los casos de uso importan únicamente estos modelos:

```dart
enum Urgencia { alta, media, baja }
enum EstadoPublicacion { activa, reservada, cerrada, retirada }
enum CondicionArticulo { nuevo, comoNuevo, usado }
enum TipoPublicacion { necesidad, articulo }
enum TipoPropuesta { solicitud, oferta }
enum EstadoPropuesta { pendiente, aceptada, rechazada, retirada }

class UbicacionMock {
  final String etiqueta; // Colonia o Código Postal (nunca domicilio exacto, RNF-09)
  final double distanciaKmSimulada;
  const UbicacionMock({required this.etiqueta, this.distanciaKmSimulada = 2.4});
}

class UsuarioMock {
  final String id;
  final String nombreUsuario; // único, no editable
  final String nombreLegal;   // no editable
  final String correo;
  final String telefono;      // 10 dígitos
  final String? fotoPerfil;
  final UbicacionMock ubicacionAproximada;
  final bool avisoPrivacidadAceptado;
  final bool correoVerificado;
  final bool perfilConfianzaOtorgado;
  final double promedioCalificacion;
  final int donacionesFinalizadas;
  final int numeroResenas;
  // Constructor y copyWith...
}

class CategoriaMock {
  final String id;
  final String nombre; // único
  final String iconoClave;
  final bool activa;
  // Constructor...
}

class PublicacionMock {
  final String id;
  final TipoPublicacion tipo;
  final String autorId;
  final String categoriaId;
  final String titulo;
  final String descripcion;
  final EstadoPublicacion estado;
  final UbicacionMock ubicacion;
  final DateTime fechaPublicacion;
  final int cantidad; // cantidadRequerida en Necesidad, cantidad disponible en Artículo
  final CondicionArticulo? condicion; // obligatorio en Artículo, aceptable opcional en Necesidad
  final Urgencia? urgencia; // obligatorio en Necesidad (CU-12), nulo en Artículo
  final Map<String, String> caracteristicas; // ej. {"Talla": "M"}
  final List<String> fotografias; // 1..5 obligatorio en Artículo (CU-14)
  // Constructor y copyWith...
}

class PropuestaMock {
  final String id;
  final String publicacionId;
  final String remitenteId;
  final TipoPropuesta tipo; // solicitud (CU-23) u oferta (CU-24)
  final String texto;       // mensaje (<=300 en Solicitud) o descripción (en Oferta)
  final List<String> fotografias; // vacío en Solicitud, >=1 en Oferta (CU-24)
  final EstadoPropuesta estado;
  final DateTime fechaEnvio;
  final String claveCliente; // evita duplicados (RNF-11)
  // Constructor...
}

class CuentaAccesoMock {
  final String usuarioId;
  final String passwordHash; // nunca texto plano (RNF-07)
  const CuentaAccesoMock({required this.usuarioId, required this.passwordHash});
}

class NotificacionMock {
  final String id;
  final String destinatarioId;
  final String publicacionId;
  final String mensaje;
  final DateTime fecha;
  const NotificacionMock({
    required this.id,
    required this.destinatarioId,
    required this.publicacionId,
    required this.mensaje,
    required this.fecha,
  });
}

// Excepciones canónicas del dominio mock
class NetworkException implements Exception {
  final String message;
  const NetworkException([this.message = 'No se pudo completar la operación por pérdida de conexión']);
}

class DuplicateUsernameException implements Exception {
  final String message;
  const DuplicateUsernameException([this.message = 'El nombre de usuario ya existe']);
}

class ValidationException implements Exception {
  final String message;
  const ValidationException(this.message);
}
```

### DTOs de Entrada y Contrato Canónico de `MockTenantStore` (Decisión técnica de diseño)
Para que las 6 ramas de casos de uso compilen sin modificar `mock_tenant_store.dart`, el almacén base incluye desde el Sprint 0:
- **DTOs:**
  - `RegisterUserInput({required String nombreUsuario, required String nombreLegal, required String correo, required String telefono, required String password, required String ubicacionEtiqueta, String? fotoPerfil, required bool avisoPrivacidadAceptado})`
  - `CreateNeedInput({required String titulo, required String descripcion, required String categoriaId, required int cantidadRequerida, CondicionArticulo? condicionAceptable, required String detallesCaracteristicas, required Urgencia urgencia, required String ubicacionEtiqueta})`
  - `CreateItemInput({required String titulo, required String descripcion, required String categoriaId, required List<String> fotografias, required int cantidad, required CondicionArticulo condicion, required String ubicacionEtiqueta})`
- **Métodos públicos:**
  - `bool isUsernameTaken(String username)` y `bool isEmailTaken(String email)`
  - `Future<UsuarioMock> registerUser(RegisterUserInput input)` y `Future<void> verifyEmailForTest(String userId)`
  - `List<CategoriaMock> getActiveCategories()` y `List<CategoriaMock> getCategoriesForFilter()`
  - `List<String> getSampleItemPhotos()`
  - `Future<PublicacionMock> createNeedPublication(CreateNeedInput input)`
  - `Future<PublicacionMock> createItemPublication(CreateItemInput input)`
  - `List<PublicacionMock> filterActivePublications({String? categoryId, TipoPublicacion? type})`
  - `bool hasPendingProposal({required String publicationId, required String userId})`
  - `Future<PropuestaMock> createRequestProposal({required String publicationId, required String senderId, required String message, required String clientKey})`
  - `Future<PropuestaMock> createOfferProposal({required String publicationId, required String senderId, required String description, required List<String> photos, required String clientKey})`

---

## 7. Tenant de Prueba y Datos Semilla (`lib/core/mock/mock_tenant_store.dart`)

El `MockTenantStore` (expuesto mediante un `NotifierProvider` de Riverpod) arranca con estos datos listos para usar:

### Usuarios Semilla
1. **`usr-alondra` (Usuario activo por defecto):** `@alondra.dona` · *Guadalupe Alondra Gutiérrez Paz* · `alondra.demo@donaplus.app` · Tel: `2221234457` · Ubicación: `Col. Centro, CP 72000` · Perfil de Confianza otorgado (`★ 4.8`, 12 donaciones, 10 reseñas).
2. **`usr-maria`:** `@maria.lopez` · *María López Hernández* · `maria@donaplus.app` · Tel: `2229876543` · Ubicación: `Col. La Paz, CP 72160` · Perfil de Confianza otorgado (`★ 4.8`, 6 donaciones, 5 reseñas).
3. **`usr-diego`:** `@diego.solidario` · *Diego Ramírez Soto* · `diego@donaplus.app` · Tel: `2225550199` · Ubicación: `Col. San Manuel, CP 72570` · Sin insignia aún (`★ 4.2`, 2 donaciones, 2 reseñas).

### Categorías Semilla (`CU-13`, `CU-19`)
1. `cat-salud`: **Salud** (`activa: true`)
2. `cat-educacion`: **Educación** (`activa: true`)
3. `cat-alimentacion`: **Alimentación** (`activa: true`)
4. `cat-ropa`: **Ropa** (`activa: true`)
5. `cat-hogar`: **Artículos para el hogar** (`activa: true`)
6. `cat-inactiva`: **Electrónica antigua** (`activa: false` — sirve para comprobar en **CU-13** que las categorías desactivadas no se ofrecen al publicar).

### Publicaciones Semilla Activas
1. **`pub-1` (Necesidad · Salud · Urgencia Alta):** *«Silla de ruedas plegable»* — Autor: `usr-maria`, distancia `2.4 km`, descripción: *«Silla de ruedas en buen estado disponible para una persona adulta que la necesite.»* (idéntica a la diapositiva 11 de `DISEÑO UI (1).pdf`, lista para probar **CU-24** con `usr-alondra`).
2. **`pub-2` (Necesidad · Educación · Urgencia Media):** *«Libros escolares de primaria»* — Autor: `usr-diego`, distancia `3.1 km`.
3. **`pub-3` (Artículo · Hogar · Como nuevo):** *«Mesa de comedor para 4 personas»* — Autor: `usr-maria`, distancia `1.1 km`, 2 fotografías de muestra (lista para probar **CU-23** con `usr-alondra`).
4. **`pub-4` (Artículo · Ropa · Nuevo):** *«Chaqueta de invierno talla M»* — Autor: `usr-diego`, distancia `1.3 km`, 1 fotografía de muestra.

### Barra de Herramientas del Tenant de Prueba (`DemoTenantToolbar`)
Visible en la parte superior durante el modo mock:
- **Selector de cuenta activa:** Permite cambiar en un toque entre `@alondra.dona`, `@maria.lopez`, `@diego.solidario`, cualquier cuenta recién creada en **CU-01**, o el estado *«Sin sesión (Ir a Registro CU-01)»*.
- **Switch «Simular fallo de red (RNF-12)»:** Cuando está activo, cualquier operación de escritura (`CU-01`, `CU-11`, `CU-14`, `CU-23`, `CU-24`) lanza `NetworkException('No se pudo completar la operación por pérdida de conexión')` sin alterar el estado guardado.

---

## 8. División de Archivos por Caso de Uso y Contratos de Unión (Sin Conflictos de Git)

Cada integrante trabaja exclusivamente en su carpeta/archivo asignado:

| Integrante / Entrega | Caso de Uso | Archivos exclusivos que construye |
|---|---|---|
| Base compartida (Sprint 0 corto) | Base Mock + Shell UI | `lib/main.dart`, `lib/app/*`, `lib/core/models/*`, `lib/core/mock/*`, `lib/core/widgets/*` |
| Especificación 1 | **CU-01 · Registrarse** | `lib/features/auth/presentation/register_screen.dart`, `lib/features/auth/presentation/register_controller.dart`, `test/features/auth/cu01_register_test.dart` |
| Especificación 2 | **CU-11 · Publicar Necesidad** | `lib/features/publications/presentation/publish_need_form.dart`, `lib/features/publications/presentation/publish_need_controller.dart`, `test/features/publications/cu11_publish_need_test.dart` |
| Especificación 3 | **CU-14 · Publicar Artículo** | `lib/features/publications/presentation/publish_item_form.dart`, `lib/features/publications/presentation/publish_item_controller.dart`, `test/features/publications/cu14_publish_item_test.dart` |
| Especificación 4 | **CU-19 · Filtrar publicaciones** | `lib/features/publications/presentation/feed_screen.dart`, `lib/features/publications/presentation/feed_filter_controller.dart`, `test/features/publications/cu19_filter_publications_test.dart` |
| Especificación 5 | **CU-23 · Solicitar artículo** | `lib/features/proposals/presentation/request_item_sheet.dart`, `lib/features/proposals/presentation/request_item_controller.dart`, `test/features/proposals/cu23_request_item_test.dart` |
| Especificación 6 | **CU-24 · Ofertar artículo** | `lib/features/proposals/presentation/offer_item_sheet.dart`, `lib/features/proposals/presentation/offer_item_controller.dart`, `test/features/proposals/cu24_offer_item_test.dart` |

### Rutas Canónicas de `go_router` y Firmas de Widgets (Decisión técnica de diseño)
- **Rutas en `lib/app/router.dart`:**
  - `/`: `FeedScreen` (**CU-19**) dentro del shell con barra inferior.
  - `/register`: `RegisterScreen` (**CU-01**).
  - `/create`: `CreatePublicationScreen` (contenedor compartido para **CU-11** y **CU-14**).
  - `/publications/:id`: `PublicationDetailScreen` (contenedor compartido que invoca **CU-23** o **CU-24**).
- **Firmas exactas de los puntos de unión (con stubs iniciales en Sprint 0):**
  - `const PublishNeedForm({super.key, this.onPublished})` (`VoidCallback? onPublished`) en `publish_need_form.dart` (**CU-11**).
  - `const PublishItemForm({super.key, this.onPublished})` (`VoidCallback? onPublished`) en `publish_item_form.dart` (**CU-14**).
  - `const RequestItemSheet({super.key, required this.publicationId})` (`final String publicationId`) en `request_item_sheet.dart` (**CU-23**).
  - `const OfferItemSheet({super.key, required this.publicationId})` (`final String publicationId`) en `offer_item_sheet.dart` (**CU-24**).

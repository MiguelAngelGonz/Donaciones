# Especificación de Diseño — MVP Completo de DonaPlus (CU-01 a CU-51 en Modo Mock)

## 1. Intención y contexto («El porqué»)
Construir el **MVP Completo de DonaPlus** en Flutter cubriendo la totalidad de los **51 casos de uso específicos (CU-01 a CU-51)**, los **15 requerimientos funcionales (RF-01 a RF-15)** y los **15 requerimientos no funcionales (RNF-01 a RNF-15)** definidos en `docs/Descripción de casos de uso específicos — Aplicación de Donaciones.pdf`, `docs/Arquitectura_Donaciones.docx`, `docs/uml/01_diagrama_clases_dominio.puml` y `docs/DISEÑO UI (1).pdf`.

El sistema opera de manera **100% autocontenida en Modo Mock / Tenant de Prueba en memoria (`MockTenantStore`)**, conservando retrocompatibilidad absoluta con la especificación y los planes ya existentes de la base compartida (`docs/superpowers/specs/2026-11-10-mvp-base-compartida-design.md`) y de los primeros 6 casos de uso (**CU-01**, **CU-11**, **CU-14**, **CU-19**, **CU-23** y **CU-24**). Esto permite demostrar en vivo todos los flujos principales, alternos y de excepción de los 5 bloques funcionales del proyecto sin depender de servidores externos.

---

## 2. Objetivos, No-objetivos y Anti-objetivos

### Objetivos
- Implementar los **5 bloques funcionales** de `docs/Arquitectura_Donaciones.docx` (Sección 10), cubriendo los 51 casos de uso:
  1. **Bloque 1 — Acceso, Perfil y Confianza (CU-01 a CU-10 / RF-01 a RF-04):** Registro en 3 pasos (**CU-01**), verificación simulada de correo (**CU-02**), consulta de perfil (**CU-03**), estado y métricas del Perfil de Confianza (**CU-04**), consulta de reseñas recibidas (**CU-05**), edición de foto/teléfono/contraseña (**CU-06**), inicio de sesión con usuario o correo (**CU-07**), restablecimiento de contraseña con token de 30 minutos y un solo uso (**CU-08**), bloqueo temporal de 15 minutos tras 5 intentos fallidos consecutivos (**CU-09**) y cierre de sesión (**CU-10**).
  2. **Bloque 2 — Publicaciones, Búsqueda, Cercanía y Urgencia (CU-11 a CU-16, CU-19 a CU-22 / RF-05 a RF-09):** Publicar Necesidad con urgencia y categoría activa (**CU-11**, **CU-12**, **CU-13**), publicar Artículo con 1 a 5 fotografías y categoría activa (**CU-14**, **CU-13**), editar o retirar Necesidad (**CU-15**) y Artículo (**CU-16**) mientras estén Activos, filtrar por categoría y tipo (**CU-19**), consultar publicaciones cercanas por radio de 5, 10 o 25 km (**CU-20**) con autorización simulada de ubicación del dispositivo (**CU-21**), y ordenar/filtrar Necesidades por urgencia (**CU-22**).
  3. **Bloque 3 — Coincidencias y Notificaciones (CU-17, CU-18 / RF-10):** Cruce automático entre publicaciones Activas del usuario y publicaciones Activas de la misma categoría y tipo opuesto, ordenadas por urgencia y luego por distancia (**CU-17**), con generación automática de notificaciones internas al surgir nuevas coincidencias (**CU-18**) y bandeja de notificaciones leídas/no leídas.
  4. **Bloque 4 — Propuestas, Ciclo de Vida de la Donación, Chat, Historial y Reseñas (CU-23 a CU-39 / RF-11 a RF-14):** Enviar Solicitud (**CU-23**) y Oferta (**CU-24**), retirar propuesta pendiente (**CU-25**), consultar propuestas recibidas junto con el Perfil de Confianza del remitente (**CU-26**), aceptar propuesta (**CU-27**) originando la Donación (**CU-28**) con rechazo automático de las demás pendientes, rechazar propuesta con motivo opcional (**CU-29**), coordinar entrega (**CU-30**), chatear con opción de compartir teléfono (**CU-31**), registrar lugar y fecha acordados pasando a `En entrega` (**CU-32**), marcar como `Entregada` por el donante (**CU-33**), confirmar recepción por donatario/intermediario o cierre automático del Sistema a los 7 días (**CU-34**), consultar estado e historial cronológico de cambios (**CU-35**), cancelar donación en `Aceptada` o `En entrega` con motivo obligatorio reactivando la publicación (**CU-36**), reseñar donación finalizada dentro de 14 días recalculando el Perfil de Confianza (**CU-37**), y consultar/filtrar el historial de donaciones por papel y estado (**CU-38**, **CU-39**).
  5. **Bloque 5 — Intermediarios Comunitarios y Administración (CU-40 a CU-51 / RF-07, RF-15):** Solicitar rol de intermediario adjuntando organización y documento de respaldo (**CU-40**, **CU-41**), panel de Administrador para aprobar (**CU-43**), rechazar (**CU-44**) o revocar (**CU-45**) el rol de intermediario (**CU-42**), publicar Necesidad en nombre de un beneficiario registrando solo su alias (**CU-46**, **CU-47**), y gestionar categorías: crear (**CU-49**), renombrar (**CU-50**) y desactivar (**CU-51**) (**CU-48**).
- Conservar intactos todos los contratos de `MockTenantStore`, firmas de widgets y casos de prueba de `2026-11-10-mvp-base-compartida-plan.md` y de los planes `CU-01`, `CU-11`, `CU-14`, `CU-19`, `CU-23` y `CU-24`.
- Ampliar la barra de herramientas del tenant (`DemoTenantToolbar`) con selector rápido de usuario/sesión, interruptor de fallo de red (**RNF-12**) y controles de reloj simulado (`+15 min`, `+7 días`, `+15 días`, `Reiniciar demo`) para demostrar bloqueos temporales (**CU-09**), expiración de tokens (**CU-08**), finalización automática (**CU-34 2a**) y ventana de 14 días de reseñas (**CU-37 1b**).

### No-objetivos
- No se conectará a una instancia remota de Supabase ni a servicios externos de correo SMTP, almacenamiento en la nube o notificaciones push FCM.
- No se persistirá el estado en disco local entre reinicios completos del proceso (el estado vive en memoria durante la sesión con reinicio determinista `resetToSeed()`).

### Anti-objetivos
- Romper cualquiera de las firmas de métodos, DTOs o aserciones de datos semilla (`users.length == 3`, `filterActivePublications().length == 4`, `proposals.isEmpty`) definidas en los planes existentes.
- Permitir que la interfaz muestre como completada una operación de escritura cuando `simulateNetworkError == true` (**RNF-12**).
- Exponer el teléfono de una parte en el chat sin su consentimiento explícito (**CU-31 4a**, **RNF-09**) o pedir/mostrar domicilios exactos en publicaciones o beneficiarios (**RNF-09**).

---

## 3. Restricciones y Cumplimiento de Requerimientos No Funcionales

- **Plataforma y SDK (RNF-13):** Flutter (`sdk: ^3.13.5`), orientado a Android.
- **Eficiencia del registro (RNF-01):** Registro en máximo 3 pasos principales (**CU-01**).
- **Navegación (RNF-02):** Barra inferior con 5 destinos principales (*Inicio*, *Coincidencias*, *+ Publicar*, *Donaciones*, *Perfil*) que dejan todas las funciones principales a ≤ 3 interacciones.
- **Legibilidad y Accesibilidad (RNF-03):** Paleta oficial DonaPlus (`#004D64`, `#00A896`, `#A7E6A6`, `#FFF86A`) y hoja de Accesibilidad (`AccessibilitySheet`) con tamaño de texto (`1.0x` / `1.25x`), alto contraste y reducción de animaciones.
- **Tiempos de respuesta (RNF-04, RNF-05, RNF-06):** Filtrado, coincidencias, cálculo de cercanía y publicación instantáneos en memoria (< 100 ms, cumpliendo los umbrales de 3 s y 5 s).
- **Protección de contraseñas (RNF-07):** Contraseñas transformadas con hash SHA-256 (`crypto`) en `CuentaAccesoMock`; nunca guardadas ni mostradas en texto plano.
- **Autorización de ubicación (RNF-08):** El cálculo con ubicación del dispositivo (**CU-21**) exige autorización explícita del usuario; si la niega, usa la ubicación aproximada registrada en su perfil (**CU-20**).
- **Protección de información personal (RNF-09):** Ubicación limitada a colonia o código postal; beneficiarios identificados únicamente por alias (**CU-47**); teléfono en chat oculto salvo que su dueño active compartirlo (**CU-31**).
- **Integridad, Idempotencia y Trazabilidad (RNF-10, RNF-11, RNF-15):** Prevención de duplicidad mediante `claveCliente` e idempotencia en transiciones de estado; historial inmutable `CambioEstadoMock` con fecha, hora y actor (o `null` cuando actúa el Sistema).
- **Recuperación ante errores (RNF-12):** Cuando `simulateNetworkError == true`, toda operación de escritura lanza `NetworkException` antes de mutar cualquier colección del `MockTenantStore`.
- **Escalabilidad de categorías (RNF-14):** Las categorías se crean, renombran y desactivan dinámicamente como datos en `MockTenantStore` sin alterar la lógica de negocio, y nunca se eliminan físicamente.

---

## 4. Enfoques Evaluados y Decisión

| Enfoque | Descripción | Ventajas | Compromisos |
|---|---|---|---|
| **1. `MockTenantStore` unificado (organizado por secciones/mixins de dominio) + arquitectura `feature-first` con `flutter_riverpod` y `go_router` (Elegido)** | Mantiene un único almacén reactivo en memoria que conserva al 100% los métodos de los 6 casos ya planeados y añade los modelos y métodos para los 45 casos restantes, con pantallas separadas por módulo en `lib/features/<modulo>/`. | Garantiza atomicidad ante `simulateNetworkError` (**RNF-12**) en operaciones que cruzan varios módulos (**CU-27**, **CU-34**, **CU-36**, **CU-37**, **CU-45**), respeta los 7 planes existentes y facilita pruebas deterministas con `resetToSeed()`. | El estado vive en memoria durante la ejecución de la app. |
| **2. Repositorios Mock separados por módulo (`AuthRepo`, `PublicationsRepo`, `DonationsRepo`, `AdminRepo`)** | Cada módulo administra sus propias listas en providers independientes y sincroniza efectos laterales mediante lecturas cruzadas. | Archivos de datos más pequeños por carpeta. | Rompe el contrato único de `MockTenantStore` de los planes existentes y complica la atomicidad transaccional cuando una acción modifica 4 colecciones a la vez. |
| **3. `MockTenantStore` con persistencia automática en JSON local (`shared_preferences`)** | Serializa todo el almacén a disco local tras cada operación. | Conserva cambios si se cierra la app por completo. | Añade código repetitivo de serialización para todas las entidades y obliga a borrar almacenamiento local para reiniciar cada demostración. |

**Elección:** Se eligió el **Enfoque 1** por acuerdo en la sesión de diseño, ya que protege todo el trabajo previo del repositorio y ofrece transacciones en memoria limpias y fáciles de probar.

---

## 5. Decisiones de Negocio Confirmadas (Resolución de Puntos «Por confirmar»)

Adoptando las propuestas por defecto de la Sección 9 de `docs/Arquitectura_Donaciones.docx`:

1. **Ubicación aproximada del usuario (CU-20):** Se captura en el Paso 2 del registro (**CU-01**) como colonia o código postal y se muestra en el perfil. Cada ubicación aproximada tiene coordenadas simuladas deterministas para calcular distancias en kilómetros.
2. **Retiro de publicación activa (CU-15, CU-16):** Al retirar una Necesidad o Artículo en estado `ACTIVA`, su estado pasa a `EstadoPublicacion.retirada` (deja de aparecer en el feed y en coincidencias) y todas sus Solicitudes u Ofertas `PENDIENTE` pasan automáticamente a `EstadoPropuesta.rechazada` con notificación a sus remitentes.
3. **Aviso al recibir Solicitud u Oferta nueva (CU-23, CU-24):** Sí; el sistema genera una `NotificacionMock` (`TipoNotificacion.nuevaPropuesta`) para el autor de la publicación.
4. **Motivo al rechazar una Solicitud u Oferta (CU-29):** Es opcional (`String? motivo`).
5. **Quién registra lugar y fecha de entrega (CU-32):** Cualquiera de las dos partes de la Donación (Donante o Donatario/Intermediario) mientras la Donación esté en estado `ACEPTADA`.
6. **Cómputo de los 7 días para finalización automática (CU-34):** Se cuentan 7 días exactos desde `fechaEntregada` (momento en que el Donante marca la Donación como `ENTREGADA` en **CU-33**). Si se cumple el plazo sin confirmación manual, el Sistema pasa la Donación a `FINALIZADA`, la publicación a `CERRADA`, registra el cambio en el historial a nombre del `Sistema` (`actorId: null`), notifica a ambas partes y recalcula el Perfil de Confianza.
7. **Solicitudes de rol de intermediario (CU-40, CU-44):** Un usuario solo puede tener una solicitud de rol en estado `PENDIENTE` a la vez. Recibe notificación interna con la decisión (`APROBADA`, `RECHAZADA`, `REVOCADA`). Si su solicitud fue rechazada (o su rol revocado), puede enviar una nueva solicitud.
8. **Formato y tamaño del documento de respaldo (CU-41):** Solo se aceptan documentos con extensión `.pdf`, `.jpg`, `.jpeg` o `.png` y tamaño simulado `<= 5 MB` (`5 * 1024 * 1024` bytes).
9. **Efecto de revocar a un intermediario (CU-45):** Sus Necesidades en estado `ACTIVA` que tengan `gestionadaPorIntermediario == true` pasan automáticamente a `RETIRADA` (rechazando sus Ofertas pendientes); las Donaciones que ya estaban en curso (`ACEPTADA`, `EN_ENTREGA`, `ENTREGADA`) continúan normalmente hasta finalizar o cancelarse.
10. **Unicidad del nombre de categoría (CU-49, CU-50):** El nombre de toda categoría debe ser único sin distinguir mayúsculas, minúsculas ni espacios iniciales/finales (`trim().toLowerCase()`), tanto al crear como al renombrar.
11. **Desactivación de categorías (CU-51):** Las publicaciones existentes de una categoría desactivada conservan su categoría y siguen visibles en el listado general; la categoría desactivada no se ofrece al crear/editar publicaciones (`getActiveCategories()`) ni en los chips de categorías activas (`getCategoriesForFilter()`).

---

## 6. Modelo de Dominio Completo (`lib/core/models/`)

### 6.1 Enumeraciones (`domain_models.dart`)

```dart
enum Urgencia { alta, media, baja }
enum EstadoPublicacion { activa, reservada, cerrada, retirada }
enum CondicionArticulo { nuevo, comoNuevo, usado }
enum TipoPublicacion { necesidad, articulo }
enum TipoPropuesta { solicitud, oferta }
enum EstadoPropuesta { pendiente, aceptada, rechazada, retirada }
enum EstadoDonacion { aceptada, enEntrega, entregada, finalizada, cancelada }
enum EstadoSolicitudRol { pendiente, aprobada, rechazada, revocada }
enum PapelDonacion { donante, donatario }
enum TipoNotificacion {
  nuevaCoincidencia,
  nuevaPropuesta,
  propuestaAceptada,
  propuestaRechazada,
  cambioEstadoDonacion,
  decisionRolIntermediario,
}
```

### 6.2 Entidades Inmutables (`domain_models.dart`)

Todos los campos nuevos tienen valores por defecto en los constructores para mantener **100% de compatibilidad** con el código de los 6 planes ya escritos:

- **`UbicacionMock`**:
  - `final String etiqueta;` (Colonia o CP, nunca domicilio exacto, **RNF-09**)
  - `final double distanciaKmSimulada;` (default `2.4`)
  - `final double latitud;` (default `19.0414`)
  - `final double longitud;` (default `-98.2063`)
- **`UsuarioMock`**:
  - Campos base: `id`, `nombreUsuario`, `nombreLegal`, `correo`, `telefono`, `fotoPerfil`, `ubicacionAproximada`, `avisoPrivacidadAceptado`, `correoVerificado`, `perfilConfianzaOtorgado`, `promedioCalificacion`, `donacionesFinalizadas`, `numeroResenas`.
  - Campos adicionales con default:
    - `final bool telefonoCompartido;` (default `false`)
    - `final bool esAdministrador;` (default `false`)
    - `final bool esIntermediario;` (default `false`)
    - `final DateTime? fechaRegistro;`
  - Getters derivados para **CU-04**:
    - `int get faltantesDonaciones => (5 - donacionesFinalizadas).clamp(0, 5);`
    - `int get faltantesResenas => (3 - numeroResenas).clamp(0, 3);`
    - `double get faltantePromedio => promedioCalificacion >= 4.0 ? 0.0 : double.parse((4.0 - promedioCalificacion).toStringAsFixed(1));`
- **`CuentaAccesoMock`**:
  - `final String usuarioId;`
  - `final String passwordHash;`
  - `final bool correoVerificado;` (default `true`)
  - `final int intentosFallidos;` (default `0`)
  - `final DateTime? bloqueadaHasta;`
- **`TokenRestablecimientoMock`** (**CU-08**):
  - `final String token;`
  - `final String usuarioId;`
  - `final String correo;`
  - `final DateTime expiraEn;` (creado con `now.add(Duration(minutes: 30))`)
  - `final bool usado;` (default `false`)
- **`CategoriaMock`** (**CU-13**, **CU-48 a CU-51**):
  - `final String id;`
  - `final String nombre;`
  - `final String iconoClave;`
  - `final bool activa;`
- **`PublicacionMock`** (**CU-11 a CU-22**, **CU-46**, **CU-47**):
  - Campos base: `id`, `tipo`, `autorId`, `categoriaId`, `titulo`, `descripcion`, `estado`, `ubicacion`, `fechaPublicacion`, `cantidad`, `condicion`, `urgencia`, `caracteristicas`, `fotografias`.
  - Campos adicionales con default para **CU-46 / CU-47**:
    - `final bool gestionadaPorIntermediario;` (default `false`)
    - `final String? aliasBeneficiario;` (default `null`)
- **`CoincidenciaMock`** (**CU-17**):
  - `final String id;`
  - `final String publicacionPropiaId;`
  - `final String publicacionParId;`
  - `final String necesidadId;`
  - `final String articuloId;`
  - `final String categoriaId;`
  - `final Urgencia urgencia;`
  - `final double distanciaKm;`
  - `final List<String> caracteristicasCumplidas;`
- **`PropuestaMock`** (**CU-23 a CU-29**):
  - Campos base: `id`, `publicacionId`, `remitenteId`, `tipo`, `texto`, `fotografias`, `estado`, `fechaEnvio`, `claveCliente`.
  - Campo adicional con default: `final String? motivoRechazo;`
- **`CambioEstadoMock`** (**CU-28**, **CU-35**, **RNF-15**):
  - `final EstadoDonacion? estadoAnterior;`
  - `final EstadoDonacion estadoNuevo;`
  - `final DateTime fechaHora;`
  - `final String? actorId;` (`null` representa al `Sistema`)
  - `final String? nota;`
- **`MensajeMock`** (**CU-31**):
  - `final String id;`
  - `final String donacionId;`
  - `final String remitenteId;`
  - `final String contenido;`
  - `final DateTime fechaHora;`
- **`DonacionMock`** (**CU-28**, **CU-30 a CU-39**):
  - `final String id;`
  - `final String publicacionId;`
  - `final String propuestaId;`
  - `final String donanteId;`
  - `final String donatarioId;` (si la Necesidad es gestionada por intermediario, `donatarioId == intermediarioId == autorId` según `01_diagrama_clases_dominio.puml` línea 402)
  - `final String? intermediarioId;`
  - `final EstadoDonacion estado;`
  - `final String? lugarEntrega;`
  - `final DateTime? fechaEntregaAcordada;`
  - `final DateTime? fechaEntregada;`
  - `final DateTime? fechaFinalizacion;`
  - `final String? motivoCancelacion;`
  - `final bool telefonoDonanteCompartido;` (default `false`)
  - `final bool telefonoDonatarioCompartido;` (default `false`)
  - `final List<CambioEstadoMock> historialCambios;`
  - `final List<MensajeMock> mensajes;`
  - `bool get chatDisponible => estado == EstadoDonacion.aceptada || estado == EstadoDonacion.enEntrega;`
- **`ResenaMock`** (**CU-05**, **CU-37**):
  - `final String id;`
  - `final String donacionId;`
  - `final String autorId;`
  - `final String resenadoId;`
  - `final int calificacion;` (`1..5`)
  - `final String? comentario;` (máx. 500 caracteres)
  - `final DateTime fecha;`
  - `final bool verificada;` (default `true` — etiqueta «Donación verificada»)
- **`SolicitudRolIntermediarioMock`** (**CU-40 a CU-45**):
  - `final String id;`
  - `final String usuarioId;`
  - `final String organizacion;`
  - `final String documentoNombre;`
  - `final int documentoBytesSimulados;`
  - `final EstadoSolicitudRol estado;`
  - `final DateTime fechaSolicitud;`
  - `final DateTime? fechaDecision;`
  - `final String? revisadaPorAdminId;`
  - `final String? motivoDecision;`
- **`NotificacionMock`** (**CU-18**, **CU-27**, **CU-29**, **CU-32 a CU-36**, **CU-43 a CU-45**):
  - Campos base: `id`, `destinatarioId`, `publicacionId`, `mensaje`, `fecha`.
  - Campos adicionales con default:
    - `final TipoNotificacion tipo;` (default `TipoNotificacion.nuevaPropuesta`)
    - `final bool leida;` (default `false`)
    - `final String? donacionId;`

### 6.3 Excepciones Canónicas (`domain_exceptions.dart`)
- `NetworkException([String message = 'No se pudo completar la operación por pérdida de conexión'])`
- `DuplicateUsernameException([String message = 'El nombre de usuario ya existe'])`
- `ValidationException(String message)`
- `InvalidCredentialsException([String message = 'Credenciales inválidas. Verifica tus datos.'])`
- `AccountLockedException([String message = 'Acceso bloqueado temporalmente por 15 minutos tras 5 intentos fallidos.'])`
- `UnverifiedEmailException([String message = 'Debes verificar tu correo electrónico antes de iniciar sesión.'])`
- `ExpiredOrUsedTokenException([String message = 'El enlace de restablecimiento ya venció o ya fue utilizado.'])`
- `UnauthorizedActionException([String message = 'No tienes permiso para realizar esta acción.'])`

---

## 7. Datos Semilla y Contrato Completo de `MockTenantStore`

### 7.1 Datos Semilla (Compatibles al 100% con los tests de Sprint 0)
Para que `test/core/mock_tenant_store_test.dart` (`users.length == 3`, `filterActivePublications().length == 4`, `proposals.isEmpty`) pase sin modificaciones y a la vez todos los roles estén listos desde el arranque:

1. **Usuarios semilla (`users.length == 3`, contraseña semilla de todos: `DonaPlus1` con hash SHA-256):**
   - **`usr-alondra` (Activo por defecto):** `@alondra.dona` · *Guadalupe Alondra Gutiérrez Paz* · `alondra.demo@donaplus.app` · Tel: `2221234457` · `Col. Centro, CP 72000` (`distanciaKmSimulada: 0.8`) · Perfil de Confianza otorgado (`★ 4.8`, 12 donaciones, 10 reseñas) · **`esAdministrador: true`** (permite probar tanto flujos de Donante/Donatario como el panel de Administración **CU-42 a CU-51**).
   - **`usr-maria`:** `@maria.lopez` · *María López Hernández* · `maria@donaplus.app` · Tel: `2229876543` · `Col. La Paz, CP 72160` (`distanciaKmSimulada: 2.4`) · Perfil de Confianza otorgado (`★ 4.8`, 6 donaciones, 5 reseñas) · **`esIntermediario: true`** (tiene una `SolicitudRolIntermediarioMock` aprobada de *«Fundación Apoyo Comunitario Puebla»*, lista para probar **CU-46** publicar por beneficiario y **CU-45** revocar rol).
   - **`usr-diego`:** `@diego.solidario` · *Diego Ramírez Soto* · `diego@donaplus.app` · Tel: `2225550199` · `Col. San Manuel, CP 72570` (`distanciaKmSimulada: 3.1`) · Sin insignia de confianza aún (`★ 4.2`, 2 donaciones, 2 reseñas — muestra faltantes en **CU-04**: faltan 3 donaciones y 1 reseña) · `esIntermediario: false` (listo para solicitar rol en **CU-40/CU-41**).
2. **Categorías semilla (`6` categorías: `5` activas y `1` inactiva):**
   - `cat-salud` (*Salud*, activa), `cat-educacion` (*Educación*, activa), `cat-alimentacion` (*Alimentación*, activa), `cat-ropa` (*Ropa*, activa), `cat-hogar` (*Artículos para el hogar*, activa), `cat-inactiva` (*Electrónica antigua*, `activa: false`).
3. **Publicaciones semilla:**
   - **4 Activas (`filterActivePublications().length == 4`):**
     - `pub-1`: Necesidad · `cat-salud` · Urgencia Alta · *«Silla de ruedas plegable»* · Autor: `usr-maria` (`2.4 km`) · Características: `{"Tipo": "Plegable adulto"}`.
     - `pub-2`: Necesidad · `cat-educacion` · Urgencia Media · *«Libros escolares de primaria»* · Autor: `usr-diego` (`3.1 km`) · Características: `{"Grado": "3ro y 4to"}`.
     - `pub-3`: Artículo · `cat-hogar` · Como nuevo · *«Mesa de comedor para 4 personas»* · Autor: `usr-maria` (`1.1 km`) · 2 fotos.
     - `pub-4`: Artículo · `cat-ropa` · Nuevo · *«Chaqueta de invierno talla M»* · Autor: `usr-diego` (`1.3 km`) · 1 foto.
   - **1 Cerrada histórica (`estado: EstadoPublicacion.cerrada`, no afecta `filterActivePublications()`):**
     - `pub-hist-1`: Artículo · `cat-educacion` · Como nuevo · *«Mochila escolar reforzada»* · Autor: `usr-alondra`.
4. **Propuestas semilla:**
   - `proposals` inicia vacía (`[]`) para cumplir la aserción de Sprint 0 (`expect(store.proposals, isEmpty)`).
5. **Donaciones y Reseñas semilla (para visualización inmediata en CU-05, CU-35, CU-38 y CU-39):**
   - `don-hist-1`: Donación en estado `FINALIZADA` sobre `pub-hist-1` entre `donanteId: usr-alondra` y `donatarioId: usr-diego`, con su historial completo de 4 `CambioEstadoMock` (`ACEPTADA → EN_ENTREGA → ENTREGADA → FINALIZADA`).
   - 2 reseñas verificadas (`ResenaMock`) recibidas por `usr-alondra` (de `usr-maria` `★ 5` y de `usr-diego` `★ 5`) y 1 reseña recibida por `usr-maria` (de `usr-alondra` `★ 5`).

### 7.2 Métodos Públicos de `MockTenantStore` por Bloque

Además de los métodos ya especificados en `2026-11-10-mvp-base-compartida-design.md`, el store expone:

- **Control del Tenant y Reloj Simulado:**
  - `DateTime get currentTime`
  - `void advanceClock(Duration delta)`: adelanta el reloj simulado y ejecuta automáticamente `runAutomaticFinalizationCheck()` (**CU-34 2a**).
  - `void setDeviceLocationAuthorized(bool authorized)` y `bool get isDeviceLocationAuthorized` (**CU-21**).
  - `void resetToSeed()`
- **Bloque 1 — Auth, Perfil y Confianza (CU-01 a CU-10):**
  - `Future<UsuarioMock> registerUser(RegisterUserInput input)` (**CU-01**)
  - `Future<void> verifyEmailForTest(String userId)` (**CU-02**)
  - `Future<UsuarioMock> login({required String usernameOrEmail, required String password})` (**CU-07**, **CU-09**: incrementa `intentosFallidos` en fallo; al 5.º intento consecutivo fija `bloqueadaHasta = currentTime.add(Duration(minutes: 15))` y lanza `AccountLockedException`; si `correoVerificado == false` lanza `UnverifiedEmailException`; al autenticar reinicia `intentosFallidos = 0` y fija `activeUser`).
  - `Future<TokenRestablecimientoMock> requestPasswordReset(String email)` (**CU-08**: genera token válido por 30 minutos).
  - `Future<void> confirmPasswordReset({required String token, required String newPassword})` (**CU-08**: valida reglas de contraseña RF-01, que `!token.usado` y `currentTime.isBefore(token.expiraEn)`, actualiza hash e invalida el token).
  - `void logout()` (**CU-10**: fija `activeUser = null`).
  - `Future<UsuarioMock> updateProfile({String? fotoPerfil, required String telefono, String? newPassword})` (**CU-06**: valida teléfono de 10 dígitos y reglas de contraseña si se proporciona; `nombreUsuario` y `nombreLegal` son inmutables).
  - `List<ResenaMock> getReviewsForUser(String userId)` (**CU-05**).
  - `void recalculateTrustProfile(String userId)` (**CU-04**, **RF-03**: recalcula `donacionesFinalizadas`, `numeroResenas`, `promedioCalificacion` y `perfilConfianzaOtorgado = donacionesFinalizadas >= 5 && promedioCalificacion >= 4.0 && numeroResenas >= 3`).
- **Bloque 2 y 3 — Publicaciones, Cercanía, Urgencia y Coincidencias (CU-11 a CU-22, CU-46, CU-47):**
  - `Future<PublicacionMock> createNeedPublication(CreateNeedInput input)` (**CU-11 a CU-13**, **CU-46**, **CU-47**: soporta `bool gestionadaPorIntermediario = false` y `String? aliasBeneficiario` en `CreateNeedInput`; si `gestionadaPorIntermediario == true`, valida que el autor tenga `esIntermediario == true` y `aliasBeneficiario` no vacío; al publicar dispara detección de coincidencias **CU-18**).
  - `Future<PublicacionMock> createItemPublication(CreateItemInput input)` (**CU-14**, **CU-13**; al publicar dispara detección de coincidencias **CU-18**).
  - `Future<PublicacionMock> updateNeedPublication({required String publicationId, required CreateNeedInput input})` (**CU-15**: solo autor y solo si está `ACTIVA`).
  - `Future<PublicacionMock> updateItemPublication({required String publicationId, required CreateItemInput input})` (**CU-16**: solo autor y solo si está `ACTIVA`).
  - `Future<void> withdrawPublication(String publicationId)` (**CU-15**, **CU-16**: solo si está `ACTIVA`; cambia a `RETIRADA` y rechaza propuestas `PENDIENTE`).
  - `List<PublicacionMock> filterActivePublications({String? categoryId, TipoPublicacion? type, Urgencia? urgency, bool sortByUrgency = false, double? maxDistanceKm, bool sortByDistance = false})` (**CU-19**, **CU-20**, **CU-21**, **CU-22**: retrocompatible con la firma `{String? categoryId, TipoPublicacion? type}`).
  - `List<CoincidenciaMock> getMatchesForUser(String userId)` (**CU-17**: cruza publicaciones `ACTIVA` del usuario con publicaciones `ACTIVA` de otros autores en la misma categoría y de `TipoPublicacion` opuesto, ordenadas por `Urgencia` `alta -> media -> baja` y luego por `distanciaKm` ascendente).
  - `List<NotificacionMock> getNotificationsForUser(String userId)` y `void markNotificationAsRead(String notificationId)` (**CU-18**).
- **Bloque 4 — Propuestas, Donaciones, Chat, Historial y Reseñas (CU-23 a CU-39):**
  - `Future<PropuestaMock> createRequestProposal(...)` (**CU-23**)
  - `Future<PropuestaMock> createOfferProposal(...)` (**CU-24**)
  - `Future<void> withdrawProposal(String proposalId)` (**CU-25**: solo el remitente y solo si está `PENDIENTE`).
  - `List<PropuestaMock> getReceivedPendingProposals(String authorId, {String? publicationId})` (**CU-26**).
  - `List<PropuestaMock> getSentProposals(String senderId)` (**CU-25**).
  - `Future<DonacionMock> acceptProposal({required String proposalId, required String clientKey})` (**CU-27**, **CU-28**: idempotente por `proposalId` / `clientKey` **RNF-11**; valida que la propuesta esté `PENDIENTE` y la publicación `ACTIVA`; cambia la propuesta a `ACEPTADA`, la publicación a `RESERVADA`, rechaza las demás propuestas `PENDIENTE` de esa publicación, crea `DonacionMock` en estado `ACEPTADA` con su primer `CambioEstadoMock` y emite notificaciones a todos los involucrados).
  - `Future<void> rejectProposal({required String proposalId, String? reason})` (**CU-29**: cambia propuesta `PENDIENTE` a `RECHAZADA`, conserva la publicación `ACTIVA` y notifica a ambas partes).
  - `Future<DonacionMock> registerDeliverySchedule({required String donationId, required String place, required DateTime scheduledDate, required String clientKey})` (**CU-32**: desde `ACEPTADA`, cualquiera de las dos partes registra lugar y fecha; pasa a `EN_ENTREGA`, agrega `CambioEstadoMock` y notifica).
  - `Future<DonacionMock> markDonationDelivered({required String donationId, required String clientKey})` (**CU-33**: solo el `donanteId` cuando está `EN_ENTREGA`; pasa a `ENTREGADA`, registra `fechaEntregada = currentTime`, agrega `CambioEstadoMock` y notifica).
  - `Future<DonacionMock> confirmDonationReceived({required String donationId, required String clientKey})` (**CU-34**: solo el `donatarioId` / `intermediarioId` cuando está `ENTREGADA`; pasa la Donación a `FINALIZADA`, la publicación a `CERRADA`, agrega `CambioEstadoMock`, notifica y recalcula `PerfilConfianza` de ambas partes).
  - `int runAutomaticFinalizationCheck()` (**CU-34 2a**: finaliza toda donación `ENTREGADA` cuya `currentTime.difference(fechaEntregada).inDays >= 7` con `actorId: null` en `CambioEstadoMock`).
  - `Future<DonacionMock> cancelDonation({required String donationId, required String reason, required String clientKey})` (**CU-36**: cualquiera de las partes mientras esté `ACEPTADA` o `EN_ENTREGA`, con `reason.trim().isNotEmpty`; pasa la Donación a `CANCELADA`, devuelve la publicación a `ACTIVA`, cierra el chat, agrega `CambioEstadoMock` y notifica).
  - `Future<MensajeMock> sendChatMessage({required String donationId, required String content})` (**CU-31**: solo partes de la donación y solo si `chatDisponible == true`).
  - `Future<DonacionMock> toggleSharePhoneInDonation({required String donationId, required bool share})` (**CU-31**: activa o desactiva la visibilidad del teléfono propio para la contraparte en esa donación, **RNF-09**).
  - `Future<ResenaMock> submitReview({required String donationId, required int rating, String? comment})` (**CU-37**: valida `estado == EstadoDonacion.finalizada`, que el usuario sea parte de la donación, que no haya reseñado antes esa donación `1a`, que `currentTime.difference(fechaFinalizacion).inDays <= 14` `1b`, que `1 <= rating <= 5` `3a`, que `(comment?.length ?? 0) <= 500` `4a`; registra la reseña con `verificada: true` y recalcula de inmediato el `PerfilConfianza` del usuario reseñado).
  - `List<DonacionMock> getActiveDonationsForUser(String userId)` (`ACEPTADA`, `EN_ENTREGA`, `ENTREGADA`).
  - `List<DonacionMock> getDonationHistoryForUser(String userId, {PapelDonacion? role, EstadoDonacion? finalState})` (**CU-38**, **CU-39**: devuelve solo `FINALIZADA` o `CANCELADA`, filtrable por papel Donante/Donatario y por estado).
- **Bloque 5 — Intermediarios y Administración (CU-40 a CU-51):**
  - `Future<SolicitudRolIntermediarioMock> requestIntermediaryRole({required String organization, required String documentName, required int documentBytes})` (**CU-40**, **CU-41**: valida que el usuario no sea ya intermediario, que no tenga otra solicitud `PENDIENTE`, que `organization.trim().isNotEmpty`, que la extensión de `documentName` sea `.pdf/.jpg/.jpeg/.png` y `0 < documentBytes <= 5 * 1024 * 1024`).
  - `Future<void> approveIntermediaryRequest(String requestId)` (**CU-42**, **CU-43**: requiere `activeUser.esAdministrador == true`; marca solicitud `APROBADA`, actualiza `usuario.esIntermediario = true` y notifica).
  - `Future<void> rejectIntermediaryRequest(String requestId, {String? reason})` (**CU-42**, **CU-44**: requiere administrador; marca solicitud `RECHAZADA` y notifica).
  - `Future<void> revokeIntermediaryRole(String userId)` (**CU-42**, **CU-45**: requiere administrador; marca la solicitud aprobada como `REVOCADA`, fija `usuario.esIntermediario = false`, retira sus Necesidades `ACTIVA` con `gestionadaPorIntermediario == true`, mantiene en curso sus donaciones activas y notifica).
  - `Future<CategoriaMock> createCategory({required String name, String iconKey = 'category'})` (**CU-48**, **CU-49**: requiere administrador; valida nombre no vacío y único case-insensitive).
  - `Future<CategoriaMock> renameCategory({required String categoryId, required String newName})` (**CU-48**, **CU-50**: requiere administrador; valida nombre no vacío y único case-insensitive).
  - `Future<CategoriaMock> deactivateCategory(String categoryId)` (**CU-48**, **CU-51**: requiere administrador; cambia `activa = false` sin borrar las publicaciones asociadas).

---

## 8. Mapa de Navegación, Pantallas y Organización Modular

### 8.1 Rutas de `go_router` (`lib/app/router.dart`)
- **Rutas públicas / sin sesión:**
  - `/login`: `LoginScreen` (**CU-07**, **CU-09**) con enlace a restablecer contraseña (**CU-08**) y a registro (**CU-01**).
  - `/register`: `RegisterScreen` (**CU-01**, **CU-02**).
  - `/reset-password`: `ResetPasswordScreen` (**CU-08**).
- **Rutas con Shell de Barra Inferior (5 pestañas en ≤ 3 interacciones, RNF-02):**
  1. `/` (*Inicio / Explorar*): `FeedScreen` (**CU-19**, **CU-20**, **CU-21**, **CU-22**) con acceso en el encabezado a `NotificationsSheet` (**CU-18**) y `AccessibilitySheet` (**RNF-03**).
  2. `/matches` (*Coincidencias*): `MatchesScreen` (**CU-17**, **CU-18**).
  3. `/create` (*+ Publicar*): `CreatePublicationScreen` que monta `PublishItemForm` (**CU-14**, **CU-13**) o `PublishNeedForm` (**CU-11**, **CU-12**, **CU-13**, **CU-46**, **CU-47**).
  4. `/donations` (*Donaciones*): `DonationsHubScreen` con 3 sub-pestañas:
     - *Propuestas* (**CU-25**, **CU-26**, **CU-27**, **CU-28**, **CU-29**).
     - *En curso* (**CU-30 a CU-36**).
     - *Historial* (**CU-38**, **CU-39**).
  5. `/profile` (*Perfil*): `ProfileScreen` (**CU-03**, **CU-04**, **CU-05**, **CU-06**, **CU-10**), con sección *Intermediario comunitario* (**CU-40**, **CU-41**) y acceso a `/admin` cuando `activeUser.esAdministrador == true`.
- **Rutas de detalle y administración:**
  - `/publications/:id`: `PublicationDetailScreen` (invoca `RequestItemSheet` **CU-23**, `OfferItemSheet` **CU-24**, o edición/retiro **CU-15**, **CU-16** si el usuario activo es el autor).
  - `/donations/:id`: `DonationTrackingScreen` (**CU-30 a CU-37**: línea de tiempo, registro de lugar y fecha, marcar entregada, confirmar recepción, cancelar donación, historial de cambios `CambioEstadoMock`, chat con switch de compartir teléfono y formulario de reseña).
  - `/admin`: `AdminPanelScreen` (**CU-42 a CU-45**, **CU-48 a CU-51**: pestaña *Intermediarios* y pestaña *Categorías*).

### 8.2 Estructura de Archivos por Módulo (`lib/`)
```text
lib/
├── main.dart
├── app/
│   ├── router.dart
│   ├── shell_scaffold.dart
│   └── theme.dart
├── core/
│   ├── models/
│   │   ├── domain_models.dart
│   │   ├── dto_inputs.dart
│   │   └── domain_exceptions.dart
│   ├── mock/
│   │   └── mock_tenant_store.dart
│   └── widgets/
│       ├── accessibility_sheet.dart
│       ├── demo_tenant_toolbar.dart
│       ├── notifications_sheet.dart
│       └── trust_badge_chip.dart
└── features/
    ├── auth/presentation/
    │   ├── login_screen.dart                  (CU-07, CU-09)
    │   ├── register_screen.dart               (CU-01, CU-02)
    │   ├── register_controller.dart           (CU-01)
    │   └── reset_password_screen.dart         (CU-08)
    ├── profile/presentation/
    │   ├── profile_screen.dart                (CU-03, CU-04, CU-05, CU-10)
    │   └── edit_profile_sheet.dart            (CU-06)
    ├── publications/presentation/
    │   ├── feed_screen.dart                   (CU-19, CU-20, CU-21, CU-22)
    │   ├── feed_filter_controller.dart        (CU-19, CU-20, CU-21, CU-22)
    │   ├── create_publication_screen.dart     (Contenedor CU-11 / CU-14)
    │   ├── publish_need_form.dart             (CU-11, CU-12, CU-13, CU-46, CU-47)
    │   ├── publish_need_controller.dart       (CU-11)
    │   ├── publish_item_form.dart             (CU-14, CU-13)
    │   ├── publish_item_controller.dart       (CU-14)
    │   ├── publication_detail_screen.dart     (Detalle + CU-15, CU-16, CU-23, CU-24, CU-26)
    │   └── edit_publication_sheet.dart        (CU-15, CU-16)
    ├── matching/presentation/
    │   └── matches_screen.dart                (CU-17, CU-18)
    ├── proposals/presentation/
    │   ├── request_item_sheet.dart            (CU-23)
    │   ├── request_item_controller.dart       (CU-23)
    │   ├── offer_item_sheet.dart              (CU-24)
    │   └── offer_item_controller.dart         (CU-24)
    ├── donations/presentation/
    │   ├── donations_hub_screen.dart          (CU-25 a CU-29, CU-38, CU-39)
    │   └── donation_tracking_screen.dart      (CU-30 a CU-37)
    ├── intermediary/presentation/
    │   └── request_intermediary_sheet.dart    (CU-40, CU-41)
    └── admin/presentation/
        └── admin_panel_screen.dart            (CU-42 a CU-45, CU-48 a CU-51)
```

---

## 9. Qué queda a decisión del implementador y decisiones tomadas

### Decisiones tomadas en esta especificación
- **Compatibilidad total con Sprint 0 y los 6 planes previos:** Se respetan todas las rutas (`/`, `/register`, `/create`, `/publications/:id`), firmas de constructores (`PublishNeedForm`, `PublishItemForm`, `RequestItemSheet`, `OfferItemSheet`), nombres de métodos en `MockTenantStore` y conteos de datos semilla (`3` usuarios, `5` categorías activas + `1` inactiva, `4` publicaciones activas, `0` propuestas iniciales).
- **Roles asignados en los 3 usuarios semilla:** `usr-alondra` tiene `esAdministrador: true`; `usr-maria` tiene `esIntermediario: true`; `usr-diego` es usuario estándar sin insignia ni rol especial, permitiendo probar los 51 casos de uso desde `DemoTenantToolbar` sin agregar un cuarto usuario a la semilla inicial.
- **Simulación de tiempo en `DemoTenantToolbar`:** Botones de avance rápido (`+15 min`, `+7 días`, `+15 días`) conectados a `MockTenantStore.advanceClock(...)` para verificar de forma instantánea **CU-08**, **CU-09**, **CU-34 (2a)** y **CU-37 (1b)**.

### A criterio del implementador
- La distribución visual interna de los diálogos de confirmación (por ejemplo, `AlertDialog` vs `ModalBottomSheet`) en acciones destructivas como retirar publicación (**CU-15/16**), cancelar donación (**CU-36**) o revocar intermediario (**CU-45**).
- El diseño de los placeholders gráficos para fotografías de muestra del tenant (`Container` estilizado con icono y etiqueta de la foto cuando la ruta sea un identificador mock como `sample://silla_1.jpg`).

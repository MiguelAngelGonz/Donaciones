# Especificación de Diseño — CU-23 · Solicitar artículo

## 1. Intención y contexto («El porqué»)
Permitir que un usuario en papel de **Donatario** envíe una **Solicitud** a un **Artículo** publicado como `ACTIVA` por otro miembro de la comunidad, acompañándola de un mensaje breve (máximo 300 caracteres) donde explique por qué lo solicita, quedando registrada como `PENDIENTE` para que el donante pueda revisarla posteriormente.

---

## 2. Objetivos, No-objetivos y Anti-objetivos

### Objetivos
- Mostrar en la vista de detalle de un **Artículo** (`TipoPublicacion.articulo`) el botón de acción principal **«Solicitar artículo»** (estilo DonaPlus `#00A896`).
- Al pulsar «Solicitar artículo», abrir el formulario/hoja modal de **CU-23** que captura un mensaje obligatorio de **máximo 300 caracteres** con contador en vivo (`0/300`).
- Validar las precondiciones y reglas de negocio antes de registrar la Solicitud:
  1. El Artículo debe estar en estado `ACTIVA` (flujo alterno `2b`).
  2. El usuario actual no debe ser el propio autor del Artículo.
  3. El donatario no debe tener ya otra Solicitud en estado `PENDIENTE` sobre ese mismo Artículo (flujo alterno `2a`, **RF-11**).
  4. El mensaje no puede estar vacío ni superar los 300 caracteres (flujo alterno `3a`).
- Prevenir duplicados por pulsaciones repetidas mediante deshabilitación del botón durante el envío y generación de `claveCliente` única (**RNF-11**).
- Registrar la `PropuestaMock` (`tipo: TipoPropuesta.solicitud`, `estado: EstadoPropuesta.pendiente`) en el `MockTenantStore`, generar el aviso interno para el donante (decisión por defecto de `docs/Arquitectura_Donaciones.docx` sección 9) y mostrar confirmación al donatario.

### No-objetivos
- No incluye el retiro de la Solicitud (**CU-25**) ni la pantalla donde el donante acepta o rechaza la Solicitud (**CU-26**, **CU-27**, **CU-29**).

### Anti-objetivos
- Permitir que un usuario envíe dos Solicitudes pendientes al mismo Artículo (`2a`).
- Permitir mensajes de más de 300 caracteres (`3a`) o mensajes en blanco.
- Mostrar la Solicitud como enviada cuando ocurre un fallo de conexión (**RNF-12**, flujo `5a`).

---

## 3. Restricciones y Reglas de Negocio
- **RF-11:** Solo puede existir una propuesta `PENDIENTE` por usuario y publicación.
- **Límite de longitud:** `1 <= mensaje.trim().length <= 300`.
- **RNF-11 (Prevención de duplicidad):** Cada intento genera un `claveCliente` único y deshabilita el botón mientras se procesa.
- **RNF-12 (Recuperación ante errores):** Si `MockTenantStore.simulateNetworkError == true`, informa al usuario que la Solicitud no se envió y conserva el formulario sin guardar registro.

---

## 4. Enfoques Evaluados y Decisión

1. **Enfoque 1 (Elegido): Hoja modal / pantalla dedicada (`RequestItemSheet`) controlada por `Riverpod` (`RequestItemController`) e invocada desde el detalle del Artículo.**
   - *Ventaja:* Desacopla por completo el código de **CU-23** del de **CU-24** (cada uno vive en su propio archivo dentro de `lib/features/proposals/presentation/`), facilitando el trabajo en paralelo y las pruebas de widget.
   - *Compromiso:* Las Solicitudes creadas se almacenan en el `MockTenantStore` en memoria.
2. **Enfoque 2: Persistencia en disco local.**
   - *Compromiso:* Requiere reinicio manual de datos entre pruebas de duplicidad (`2a`).
3. **Enfoque 3: Unificar Solicitud y Oferta en el mismo widget con `if (isItem)`.**
   - *Compromiso:* Mezcla reglas distintas (mensaje ≤ 300 sin fotos vs descripción libre + fotografía obligatoria) y provoca conflictos entre los responsables de **CU-23** y **CU-24**.

---

## 5. Diseño de Interfaz (Alineado con `DISEÑO UI (1).pdf`, diapositiva 11)

### 5.1 Vista de Detalle de un Artículo (`PublicationDetailScreen`)
Cuando el usuario abre un Artículo (ej. *«Mesa de comedor para 4 personas»* de María López):
- Muestra carrusel de fotografías del Artículo, categoría (`HOGAR`), título, descripción, condición (`Como nuevo`), distancia (`1.1 km`) y tarjeta del donante con su insignia de Perfil de Confianza.
- En la parte inferior:
  - Si el Artículo está `ACTIVA` y el usuario no tiene Solicitud pendiente: botón **`Solicitar artículo`**.
  - Si el usuario ya envió una Solicitud pendiente (`2a`): etiqueta informativa **`Ya tienes una Solicitud pendiente para este artículo`** y botón deshabilitado.
  - Si el Artículo está `RESERVADA` o `CERRADA` (`2b`): etiqueta **`Este artículo ya no está disponible`** y botón deshabilitado.

### 5.2 Hoja Modal «Solicitar artículo» (`RequestItemSheet`)

```text
┌──────────────────────────────────────────────┐
│  Solicitar artículo                       ✕  │
│  Artículo: Mesa de comedor para 4 personas   │
├──────────────────────────────────────────────┤
│  Mensaje para el donante *                   │
│  ┌────────────────────────────────────────┐  │
│  │ Hola María, nos mudamos hace poco y    │  │
│  │ necesitamos una mesa para mi familia.  │  │
│  │ Podría pasar por ella este sábado.     │  │
│  └────────────────────────────────────────┘  │
│  118 / 300 caracteres                        │
│                                              │
│            [ Confirmar envío ]               │
└──────────────────────────────────────────────┘
```

---

## 6. Contratos e Integración en el Repositorio

### Archivos a crear por el responsable de CU-23
- `lib/features/proposals/presentation/request_item_sheet.dart`
- `lib/features/proposals/presentation/request_item_controller.dart`
- `test/features/proposals/cu23_request_item_test.dart`

### Métodos que consume de `MockTenantStore`
- `bool hasPendingProposal({required String publicationId, required String userId})`
- `Future<PropuestaMock> createRequestProposal({required String publicationId, required String senderId, required String message, required String clientKey})`:
  - Verifica que la publicación sea un `Articulo` en estado `ACTIVA` (`2b`).
  - Verifica que no exista otra Solicitud `PENDIENTE` del mismo `senderId` sobre `publicationId` (`2a`).
  - Verifica `1 <= message.trim().length <= 300` (`3a`).
  - Lanza `NetworkException` si `simulateNetworkError == true` (`5a`).

---

## 7. Diseño de Casos de Prueba (Matriz de Pruebas para CU-23)

El archivo `test/features/proposals/cu23_request_item_test.dart` debe implementar y pasar estas pruebas automatizadas:

| ID Prueba | Caso / Flujo cubierto | Entrada de prueba | Resultado esperado |
|---|---|---|---|
| **TC-CU23-01** | Flujo principal completo | Usuario `usr-alondra` abre el Artículo `pub-3` («Mesa de comedor...»), pulsa «Solicitar artículo», escribe un mensaje de 95 caracteres y confirma. | Se registra la Solicitud como `PENDIENTE` en `MockTenantStore`, se genera notificación para el donante y se muestra confirmación al donatario. |
| **TC-CU23-02** | Flujo alterno `3a`: Mensaje supera los 300 caracteres o está vacío | (a) Intentar enviar con mensaje vacío; (b) ingresar 305 caracteres e intentar enviar. | El sistema no permite enviar la Solicitud y señala la regla de longitud (máximo 300 caracteres). |
| **TC-CU23-03** | Flujo alterno `2a`: Solicitud pendiente duplicada | Enviar una primera Solicitud válida sobre `pub-3` y luego intentar enviar una segunda Solicitud con el mismo usuario sobre `pub-3`. | El sistema impide crear una segunda Solicitud pendiente e indica que ya existe una Solicitud pendiente sobre ese Artículo. |
| **TC-CU23-04** | Flujo alterno `2b`: Artículo ya no está Activo | Cambiar el estado del Artículo a `RESERVADA` o `CERRADA` e intentar solicitarlo. | El sistema no permite enviar la Solicitud e informa que el Artículo ya no está Activo. |
| **TC-CU23-05** | Flujo alterno `5a`: Pérdida de conexión (**RNF-12**) | Activar `simulateNetworkError = true` y confirmar una Solicitud válida. | El sistema informa que la operación no se realizó, no muestra la Solicitud como enviada y no queda guardada en `MockTenantStore`. |

---

## 8. Qué queda a decisión del implementador y decisiones tomadas
- **Decisiones ya tomadas en este diseño (Decisiones técnicas de arquitectura):**
  - `RequestItemSheet` tiene la firma `const RequestItemSheet({super.key, required this.publicationId})` (`final String publicationId`) para que `PublicationDetailScreen` lo invoque sin acoplamiento adicional.
  - En cumplimiento de la sección 9 de `docs/Arquitectura_Donaciones.docx` («Puntos por confirmar» de **CU-23**), al crear la Solicitud también se inserta un aviso en la lista de notificaciones internas del donante en `MockTenantStore`.
- **A criterio del implementador:**
  - Si el contador de caracteres cambia de color al acercarse a los 300 caracteres (por ejemplo a partir de 280 caracteres).

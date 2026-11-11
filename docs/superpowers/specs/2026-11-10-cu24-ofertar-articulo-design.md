# Especificación de Diseño — CU-24 · Ofertar artículo

## 1. Intención y contexto («El porqué»)
Permitir que un usuario en papel de **Donante** responda a una **Necesidad** publicada como `ACTIVA` enviando una **Oferta** para cubrirla, incluyendo la descripción del artículo que ofrece y **al menos una fotografía** de dicho artículo, quedando registrada como `PENDIENTE` para que el autor de la Necesidad pueda revisarla.

---

## 2. Objetivos, No-objetivos y Anti-objetivos

### Objetivos
- Mostrar en la vista de detalle de una **Necesidad** (`TipoPublicacion.necesidad`) el botón principal **«Ofrecer artículo»** (tal como aparece en la pantalla 2 de la diapositiva 11 de `docs/DISEÑO UI (1).pdf` para *«Silla de ruedas plegable»*).
- Al pulsar «Ofrecer artículo», abrir el formulario/hoja modal de **CU-24** que captura:
  1. **Descripción obligatoria** del artículo ofrecido (detallando su estado y características).
  2. **Al menos una fotografía obligatoria** del artículo ofrecido (permitiendo agregar desde galería o elegir del catálogo de fotos de muestra del tenant).
- Validar las precondiciones y reglas de negocio antes de registrar la Oferta:
  1. La Necesidad debe estar en estado `ACTIVA` (flujo alterno `2b`).
  2. El usuario actual no debe ser el propio autor de la Necesidad.
  3. El donante no debe tener ya otra Oferta en estado `PENDIENTE` sobre esa misma Necesidad (flujo alterno `2a`, **RF-11**).
  4. Debe existir descripción no vacía y al menos 1 fotografía (flujo alterno `3a`).
- Prevenir envíos duplicados mediante `claveCliente` única y deshabilitación del botón durante el envío (**RNF-11**).
- Registrar la `PropuestaMock` (`tipo: TipoPropuesta.oferta`, `estado: EstadoPropuesta.pendiente`) en `MockTenantStore`, generar notificación interna para el autor de la Necesidad y mostrar confirmación al donante.

### No-objetivos
- No incluye el retiro de la Oferta (**CU-25**) ni la aceptación/rechazo por parte del donatario (**CU-26**, **CU-27**, **CU-29**).

### Anti-objetivos
- Permitir enviar una Oferta sin fotografía o sin descripción (`3a`).
- Permitir que un mismo donante acumule dos Ofertas pendientes sobre la misma Necesidad (`2a`).
- Mostrar la Oferta como enviada si ocurre un fallo de conexión (**RNF-12**, flujo `5a`).

---

## 3. Restricciones y Reglas de Negocio
- **RF-11 / CU-24:** Toda Oferta sobre una Necesidad exige descripción y al menos 1 fotografía (`fotografias.isNotEmpty`).
- **Unicidad de pendiente:** Solo una Oferta `PENDIENTE` por donante y Necesidad.
- **RNF-11:** Prevención de duplicidad con `claveCliente`.
- **RNF-12:** Si `MockTenantStore.simulateNetworkError == true`, el sistema informa que la operación no se realizó y no guarda ni muestra la Oferta como enviada.

---

## 4. Enfoques Evaluados y Decisión

1. **Enfoque 1 (Elegido): Hoja modal / pantalla dedicada (`OfferItemSheet`) controlada por `Riverpod` (`OfferItemController`) con selector de fotografías híbrido (galería + fotos mock del tenant).**
   - *Ventaja:* Mantiene **CU-24** en sus propios archivos independientes de **CU-23**, se conecta directo al botón «Ofrecer artículo» del prototipo de `DISEÑO UI (1).pdf` y permite probar la validación de fotografía obligatoria en tests automatizados sin bloqueos de cámara.
   - *Compromiso:* Las Ofertas se guardan en memoria en el `MockTenantStore`.
2. **Enfoque 2: Persistencia local en disco.**
   - *Compromiso:* Requiere limpieza manual del almacenamiento entre pruebas.
3. **Enfoque 3: Compartir el mismo formulario con CU-23.**
   - *Compromiso:* Genera acoplamiento innecesario y riesgo de conflictos de código entre integrantes.

---

## 5. Diseño de Interfaz (Alineado con `DISEÑO UI (1).pdf`, diapositiva 11, pantalla 2)

### 5.1 Vista de Detalle de una Necesidad (`PublicationDetailScreen`)
Tal como se muestra en la pantalla 2 de la diapositiva 11 (*«Silla de ruedas plegable»*):
- Imagen representativa / encabezado, categoría (`SALUD`), título (`Silla de ruedas plegable`), descripción, recuadros de `Urgencia: Urgente` y `Distancia: 2.4 km`, tarjeta de autora (`María López ★ 4.8` con insignia de Perfil de Confianza) y botón principal verde azulado (`#00A896`): **`Ofrecer artículo`**.
- Si el donante actual ya tiene una Oferta pendiente sobre esa Necesidad (`2a`), el botón se reemplaza por el aviso **`Ya enviaste una Oferta pendiente para esta necesidad`**.
- Si la Necesidad está `RESERVADA` o `CERRADA` (`2b`), muestra **`Esta necesidad ya no está activa`**.

### 5.2 Hoja Modal «Ofrecer artículo» (`OfferItemSheet`)

```text
┌──────────────────────────────────────────────┐
│  Ofrecer artículo                         ✕  │
│  Para cubrir: Silla de ruedas plegable       │
├──────────────────────────────────────────────┤
│  Fotografías del artículo ofrecido (mín. 1) *│
│  ┌─────────────┐  ┌─────────────┐            │
│  │   Foto 1    │  │      +      │            │
│  │    [x]      │  │ Agregar foto│            │
│  └─────────────┘  └─────────────┘            │
│                                              │
│  Descripción del artículo ofrecido *         │
│  ┌────────────────────────────────────────┐  │
│  │ Tengo una silla de ruedas plegable de  │  │
│  │ aluminio en buen estado, con frenos    │  │
│  │ funcionando.                           │  │
│  └────────────────────────────────────────┘  │
│                                              │
│            [ Confirmar Oferta ]              │
└──────────────────────────────────────────────┘
```

---

## 6. Contratos e Integración en el Repositorio

### Archivos a crear por el responsable de CU-24
- `lib/features/proposals/presentation/offer_item_sheet.dart`
- `lib/features/proposals/presentation/offer_item_controller.dart`
- `test/features/proposals/cu24_offer_item_test.dart`

### Métodos que consume de `MockTenantStore`
- `bool hasPendingProposal({required String publicationId, required String userId})`
- `List<String> getSampleItemPhotos()`
- `Future<PropuestaMock> createOfferProposal({required String publicationId, required String senderId, required String description, required List<String> photos, required String clientKey})`:
  - Verifica que la publicación sea una `Necesidad` en estado `ACTIVA` (`2b`).
  - Verifica que no exista otra Oferta `PENDIENTE` del mismo `senderId` sobre `publicationId` (`2a`).
  - Verifica que `description.trim().isNotEmpty` y `photos.isNotEmpty` (`3a`).
  - Lanza `NetworkException` si `simulateNetworkError == true` (`5a`).

---

## 7. Diseño de Casos de Prueba (Matriz de Pruebas para CU-24)

El archivo `test/features/proposals/cu24_offer_item_test.dart` debe implementar y pasar estas pruebas automatizadas:

| ID Prueba | Caso / Flujo cubierto | Entrada de prueba | Resultado esperado |
|---|---|---|---|
| **TC-CU24-01** | Flujo principal completo | Usuario `usr-alondra` abre la Necesidad `pub-1` («Silla de ruedas plegable»), pulsa «Ofrecer artículo», escribe la descripción del artículo, adjunta 1 fotografía de muestra y confirma. | Se registra la Oferta como `PENDIENTE` en `MockTenantStore` con su fotografía, se notifica al autor de la Necesidad y se muestra confirmación al donante. |
| **TC-CU24-02** | Flujo alterno `3a` (sin fotografía): Falta fotografía obligatoria | Escribir descripción válida pero dejar 0 fotografías seleccionadas y pulsar confirmar. | El sistema no permite enviar la Oferta e indica que debe agregar al menos una fotografía. |
| **TC-CU24-03** | Flujo alterno `3a` (sin descripción): Falta descripción obligatoria | Adjuntar 1 fotografía pero dejar la descripción vacía y pulsar confirmar. | El sistema no permite enviar la Oferta e indica que la descripción del artículo ofrecido es obligatoria. |
| **TC-CU24-04** | Flujo alterno `2a`: Oferta pendiente duplicada | Enviar una primera Oferta válida sobre `pub-1` y luego intentar enviar otra Oferta con el mismo donante sobre `pub-1`. | El sistema impide enviar otra Oferta pendiente sobre esa Necesidad. |
| **TC-CU24-05** | Flujo alterno `2b`: Necesidad ya no está Activa | Cambiar el estado de `pub-1` a `RESERVADA` o `CERRADA` e intentar ofertar. | El sistema no permite la Oferta e indica que la Necesidad ya no está Activa. |
| **TC-CU24-06** | Flujo alterno `5a`: Pérdida de conexión (**RNF-12**) | Activar `simulateNetworkError = true` y confirmar una Oferta válida. | El sistema informa que la operación no se realizó y no muestra la Oferta como enviada ni la guarda en el almacén. |

---

## 8. Qué queda a decisión del implementador y decisiones tomadas
- **Decisiones ya tomadas en este diseño (Decisiones técnicas de arquitectura):**
  - `OfferItemSheet` tiene la firma `const OfferItemSheet({super.key, required this.publicationId})` (`final String publicationId`) para integrarse limpiamente con `PublicationDetailScreen`.
  - Al igual que en **CU-23**, se registra un aviso interno para el autor de la Necesidad cuando llega una Oferta nueva (sección 9 de `docs/Arquitectura_Donaciones.docx`).
  - Se permite adjuntar de 1 a 5 fotografías en la Oferta (siendo 1 el mínimo obligatorio marcado por **CU-24**).
- **A criterio del implementador:**
  - El diseño de la vista previa de las fotos adjuntas dentro de la hoja modal (`OfferItemSheet`).

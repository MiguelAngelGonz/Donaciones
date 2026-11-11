# Especificación de Diseño — CU-14 · Publicar Artículo (incluye CU-13)

## 1. Intención y contexto («El porqué»)
Permitir que un usuario en papel de **Donante** publique un **Artículo** disponible para donación dentro de **DonaPlus**, incluyendo entre 1 y 5 fotografías reales o de prueba, su categoría (**CU-13**), cantidad disponible, estado físico y ubicación aproximada, para que las personas que lo necesiten lo encuentren en el catálogo (**CU-19**) y puedan solicitarlo (**CU-23**).

---

## 2. Objetivos, No-objetivos y Anti-objetivos

### Objetivos
- Implementar el formulario **«Quiero donar»** dentro de la pantalla *Crear publicación* (diapositiva 11 de `docs/DISEÑO UI (1).pdf`).
- Capturar y validar todos los datos obligatorios de **CU-14** y **CU-13**:
  1. Nombre del artículo (`titulo`) y `descripcion`.
  2. Entre **1 y 5 fotografías** (`fotografias`): la primera es obligatoria (flujo alterno `3a`) y el sistema no permite agregar más de 5 (flujo alterno `3b`).
  3. Selección de **exactamente una categoría activa** (**CU-13**).
  4. Cantidad disponible (`>= 1`) y condición física del artículo (**RF-06**): **Nuevo**, **Como nuevo** o **Usado**.
  5. Ubicación aproximada (colonia o código postal, **RNF-09**).
- Publicar el Artículo en estado `ACTIVA` dentro del `MockTenantStore` y mostrar confirmación en máximo 5 segundos (**RNF-06**).

### No-objetivos
- No incluye la edición ni el retiro de un Artículo ya publicado (**CU-16**).
- No requiere subir archivos binarios a un bucket remoto en la nube durante este MVP mock.

### Anti-objetivos
- Permitir publicar un Artículo con `0` fotografías (`3a`) o permitir añadir una sexta fotografía (`3b`).
- Bloquear las pruebas en emulador si la galería del sistema está vacía: el selector de fotos debe permitir tanto usar `image_picker` como elegir fotografías de muestra del tenant de prueba.
- Mostrar el Artículo como publicado cuando hay un error de conexión simulado (**RNF-12**, flujo `8a`).

---

## 3. Restricciones y Reglas de Negocio
- **Precondición:** Sesión iniciada en el tenant de prueba y al menos una categoría activa.
- **Regla de fotografías (RF-06 / CU-14):** Mínimo 1 foto, máximo 5 fotos. Al llegar a 5 fotos, el botón «Agregar foto» se deshabilita o muestra aviso si se intenta agregar otra (`3b`). Cada foto agregada puede eliminarse antes de publicar.
- **CU-13 (Asignar categoría):** Solo se muestran categorías con `activa == true`.
- **Estado físico obligatorio:** `CondicionArticulo.nuevo`, `CondicionArticulo.comoNuevo` o `CondicionArticulo.usado`.
- **RNF-12:** Si `MockTenantStore.simulateNetworkError == true`, la operación falla de forma controlada e informa al usuario sin agregar el Artículo al listado.

---

## 4. Enfoques Evaluados y Decisión

1. **Enfoque 1 (Elegido): Formulario modular (`PublishItemForm`) con `Riverpod` (`PublishItemController`) y selector híbrido de fotografías (galería + catálogo mock del tenant).**
   - *Ventaja:* Permite probar de inmediato en emulador, dispositivo físico y pruebas automatizadas (`flutter test`) las reglas de 1 a 5 fotografías sin depender de permisos nativos de cámara durante los tests.
   - *Compromiso:* Las rutas de fotografías viven en memoria dentro del `MockTenantStore`.
2. **Enfoque 2: Subida obligatoria a almacenamiento remoto antes de guardar.**
   - *Compromiso:* Requiere credenciales de nube y conexión externa.
3. **Enfoque 3: Usar únicamente `image_picker` nativo sin fotos de muestra del tenant.**
   - *Compromiso:* En emuladores recién creados sin fotos en la galería resulta tedioso agregar de 1 a 5 imágenes durante una demostración en vivo.

---

## 5. Diseño de Interfaz (Alineado con `DISEÑO UI (1).pdf`, diapositivas 8 y 11)

En la pantalla **Crear publicación**, cuando está seleccionado el botón superior **`🎁 Quiero donar`**:

```text
┌──────────────────────────────────────────────┐
│  TU UBICACIÓN: Ciudad de México, México      │
│  Crear publicación                        ☰  │
│  Tu ayuda puede cambiar un día               │
│  [ ♿ Accesibilidad ]                         │
│                                              │
│  [ 🎁 Quiero donar (Activo)]  [ (!) Necesito ]│
├──────────────────────────────────────────────┤
│  Fotografías del artículo (1 a 5) *          │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐         │
│  │ Foto 1  │ │ Foto 2  │ │   +     │ (2/5)   │
│  │Principal│ │   [x]   │ │ Agregar │         │
│  └─────────┘ └─────────┘ └─────────┘         │
│                                              │
│  Nombre del artículo *                       │
│  [ Ej. Silla de ruedas / Mesa de comedor  ]  │
│                                              │
│  Descripción *                               │
│  [ Escribe los detalles importantes...    ]  │
│                                              │
│  Categoría (CU-13) *                         │
│  [ Selecciona una categoría activa      ▼ ]  │
│                                              │
│  Cantidad disponible *    Estado del artículo *│
│  [   1   ]                (•) Nuevo          │
│                           ( ) Como nuevo     │
│                           ( ) Usado          │
│                                              │
│  Ubicación aproximada (Colonia o CP) *       │
│  [ Col. Centro, CP 72000                  ]  │
│                                              │
│           [ Publicar Artículo ]              │
└──────────────────────────────────────────────┘
```

---

## 6. Contratos e Integración en el Repositorio

### Archivos a crear por el responsable de CU-14
- `lib/features/publications/presentation/publish_item_form.dart`
- `lib/features/publications/presentation/publish_item_controller.dart`
- `test/features/publications/cu14_publish_item_test.dart`

### Métodos que consume de `MockTenantStore`
- `List<CategoriaMock> getActiveCategories()`
- `List<String> getSampleItemPhotos()` (catálogo de fotos de muestra del tenant para pruebas rápidas).
- `Future<PublicacionMock> createItemPublication(CreateItemInput input)`:
  - Valida sesión iniciada, `1 <= fotografias.length <= 5`, categoría activa seleccionada, cantidad `>= 1`, condición seleccionada y campos de texto no vacíos.
  - Lanza `NetworkException` si `simulateNetworkError == true` (`8a`).

---

## 7. Diseño de Casos de Prueba (Matriz de Pruebas para CU-14 y CU-13)

El archivo `test/features/publications/cu14_publish_item_test.dart` debe implementar y pasar estas pruebas automatizadas:

| ID Prueba | Caso / Flujo cubierto | Entrada de prueba | Resultado esperado |
|---|---|---|---|
| **TC-CU14-01** | Flujo principal completo (**CU-14** + **CU-13**) | Título: `Bicicleta urbana`, Descripción: `Rodada 26 en buen estado`, 2 fotografías agregadas, Categoría: `Salud`, Cantidad: `1`, Estado: `Como nuevo`, Ubicación: `Col. Centro, CP 72000`. | Se crea el Artículo en estado `ACTIVA` en `MockTenantStore`, se muestra confirmación y aparece en el listado general. |
| **TC-CU14-02** | Flujo alterno `3a`: Sin primera fotografía | Completar título, descripción, categoría, cantidad, condición y ubicación, pero dejar 0 fotografías. | El sistema no permite publicar y muestra el mensaje indicando que la primera fotografía es obligatoria. |
| **TC-CU14-03** | Flujo alterno `3b`: Intento de agregar más de 5 fotografías | Agregar 5 fotografías válidas e intentar agregar una sexta. | El sistema impide agregar más de 5 fotografías y muestra el límite alcanzado (`5/5`). |
| **TC-CU14-04** | Flujo alterno `7a` y **CU-13** `2a`: Falta dato obligatorio o categoría | Intentar publicar con 1 foto pero sin título o sin seleccionar categoría activa. | El sistema señala el campo faltante y no crea el Artículo. |
| **TC-CU14-05** | Flujo alterno `8a`: Pérdida de conexión (**RNF-12**) | Activar `simulateNetworkError = true` y confirmar un Artículo válido. | El sistema informa que la operación no se realizó y el Artículo no aparece como publicado. |

---

## 8. Qué queda a decisión del implementador y decisiones tomadas
- **Decisiones ya tomadas en este diseño (Decisiones técnicas de arquitectura):**
  - `PublishItemForm` tiene la firma `const PublishItemForm({super.key, this.onPublished})` (`final VoidCallback? onPublished`), vive en su propio archivo y se muestra cuando el usuario elige **«Quiero donar»** en la pantalla *Crear publicación*.
  - El botón «Agregar foto» ofrece un menú corto con dos opciones: *«Elegir foto de muestra del tenant»* y *«Seleccionar desde galería del dispositivo»*.
- **A criterio del implementador:**
  - El diseño visual de las miniaturas de fotos (carrusel horizontal o cuadrícula compacta) y la forma de reordenar cuál es la primera foto.

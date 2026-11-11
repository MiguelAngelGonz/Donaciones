# Especificación de Diseño — CU-11 · Publicar Necesidad (incluye CU-12 y CU-13)

## 1. Intención y contexto («El porqué»)
Permitir que un usuario en papel de **Donatario** publique una **Necesidad** dentro de **DonaPlus** indicando qué artículo requiere, su categoría (**CU-13**), sus características, el nivel de urgencia (**CU-12**) y una ubicación aproximada, para que la comunidad de donantes la encuentre en el listado (**CU-19**) y pueda enviarle Ofertas (**CU-24**).

---

## 2. Objetivos, No-objetivos y Anti-objetivos

### Objetivos
- Implementar el formulario **«Necesito»** dentro de la pantalla *Crear publicación* (diapositiva 11 de `docs/DISEÑO UI (1).pdf`).
- Capturar y validar todos los datos obligatorios de **CU-11**, **CU-12** y **CU-13**:
  1. Nombre del artículo requerido (`titulo`) y `descripcion`.
  2. Selección de **exactamente una categoría activa** (**CU-13**), excluyendo cualquier categoría desactivada (`activa == false`).
  3. Características necesarias del artículo: cantidad requerida (`≥ 1`), condición mínima aceptable (*Nuevo*, *Como nuevo*, *Usado* o *Cualquiera*) y detalle de características (ej. talla, medida o especificaciones).
  4. Nivel de urgencia obligatorio (**CU-12**): **Alta**, **Media** o **Baja**, representado con un distintivo visual de color y texto.
  5. Ubicación aproximada (**RNF-09**): colonia o código postal (prellenada con la ubicación del perfil del usuario activo, pero editable para esa publicación).
- Publicar la Necesidad en estado `ACTIVA` dentro del `MockTenantStore` y mostrar confirmación inmediata (en menos de 5 segundos, **RNF-06**).

### No-objetivos
- No incluye en este entregable la publicación en nombre de un beneficiario por un Intermediario comunitario (**CU-46** / **CU-47**), ni la edición o retiro posterior (**CU-15**).

### Anti-objetivos
- Pedir o permitir guardar calle, número exterior o domicilio exacto (**RNF-09**, flujo alterno `6a`).
- Permitir publicar sin elegir categoría (**CU-13** flujo `2a`) o sin elegir nivel de urgencia (**CU-12** flujo `2a`).
- Ofrecer en el selector categorías desactivadas por el administrador (**CU-13** flujo `1a`).
- Mostrar la Necesidad como publicada si falla la conexión (**RNF-12**, flujo `8a`).

---

## 3. Restricciones y Reglas de Negocio
- **Precondición:** Sesión iniciada en el tenant de prueba y al menos una categoría activa en `MockTenantStore`.
- **CU-12 (Asignar nivel de urgencia):** Toda Necesidad debe tener un nivel de urgencia (`Urgencia.alta`, `Urgencia.media` o `Urgencia.baja`). Cada nivel se muestra con su distintivo de color y texto:
  - `Alta`: Rojo coral / etiqueta «Urgencia Alta»
  - `Media`: Ámbar / etiqueta «Urgencia Media»
  - `Baja`: Verde menta (`#A7E6A6`) / etiqueta «Urgencia Baja»
- **CU-13 (Asignar categoría):** Solo se listan las categorías donde `activa == true` (en la semilla: *Salud*, *Educación*, *Alimentación*, *Ropa*, *Artículos para el hogar*; la categoría inactiva *Electrónica antigua* no debe aparecer).
- **RNF-09 (Privacidad):** El campo de ubicación pide únicamente *Colonia o Código Postal*.

---

## 4. Enfoques Evaluados y Decisión

1. **Enfoque 1 (Elegido): Formulario modular (`PublishNeedForm`) con controlador `Riverpod` (`PublishNeedController`) y validación en el `MockTenantStore`.**
   - *Ventaja:* Se integra limpiamente en la pestaña **«Necesito»** de la pantalla *Crear publicación* (diapositiva 11 del PDF) sin chocar con el formulario de **CU-14** (*«Quiero donar»*), y permite probar todas las reglas de **CU-11**, **CU-12** y **CU-13** mediante pruebas de widget aisladas.
   - *Compromiso:* Las Necesidades creadas viven en memoria durante la ejecución de la app.
2. **Enfoque 2: Almacenamiento local persistente en disco.**
   - *Compromiso:* Requiere limpiar estado entre ejecuciones de prueba.
3. **Enfoque 3: Unificar el formulario de Necesidad y Artículo en un solo `StatefulWidget` con condicionales.**
   - *Compromiso:* Acopla **CU-11** y **CU-14** en el mismo archivo, provocando conflictos de Git al trabajar dos personas en paralelo.

---

## 5. Diseño de Interfaz (Alineado con `DISEÑO UI (1).pdf`, diapositiva 11)

En la pantalla **Crear publicación**, cuando está seleccionado el botón superior **`(!) Necesito`**:

```text
┌──────────────────────────────────────────────┐
│  TU UBICACIÓN: Ciudad de México, México      │
│  Crear publicación                        ☰  │
│  Tu ayuda puede cambiar un día               │
│  [ ♿ Accesibilidad ]                         │
│                                              │
│  [ 🎁 Quiero donar ]   [ (!) Necesito (Activo)]│
├──────────────────────────────────────────────┤
│  Nombre del artículo requerido *             │
│  [ Ej. Silla de ruedas plegable           ]  │
│                                              │
│  Descripción de la necesidad *               │
│  [ Explica para qué se requiere...        ]  │
│                                              │
│  Categoría (CU-13) *                         │
│  [ Selecciona una categoría activa      ▼ ]  │
│                                              │
│  Características necesarias *                │
│  • Cantidad requerida: [ 1 ]                 │
│  • Condición aceptable: [ Cualquiera    ▼ ]  │
│  • Detalles (talla, medida, modelo):         │
│    [ Ej. Talla M, adulto, plegable        ]  │
│                                              │
│  Nivel de urgencia (CU-12) *                 │
│  (•) 🔴 Alta    ( ) 🟡 Media    ( ) 🟢 Baja   │
│                                              │
│  Ubicación aproximada (Colonia o CP) *       │
│  [ Col. Centro, CP 72000                  ]  │
│  ℹ Solo colonia o CP, nunca domicilio exacto │
│                                              │
│          [ Publicar Necesidad ]              │
└──────────────────────────────────────────────┘
```

Al confirmar con éxito:
1. Se agrega la nueva `PublicacionMock` con `tipo: TipoPublicacion.necesidad` y `estado: EstadoPublicacion.activa` al `MockTenantStore`.
2. Se muestra confirmación visual (`SnackBar` / diálogo de éxito con el distintivo de urgencia asignado).
3. La Necesidad aparece de inmediato en el listado de **CU-19** y puede recibir Ofertas en **CU-24**.

---

## 6. Contratos e Integración en el Repositorio

### Archivos a crear por el responsable de CU-11
- `lib/features/publications/presentation/publish_need_form.dart`
- `lib/features/publications/presentation/publish_need_controller.dart`
- `test/features/publications/cu11_publish_need_test.dart`

### Métodos que consume de `MockTenantStore`
- `List<CategoriaMock> getActiveCategories()` (filtra `activa == true` para **CU-13**).
- `Future<PublicacionMock> createNeedPublication(CreateNeedInput input)`:
  - Valida que exista sesión activa, campos obligatorios no vacíos (`7a`), categoría activa seleccionada (`CU-13 2a`), urgencia seleccionada (`CU-12 2a`) y cantidad `>= 1`.
  - Lanza `NetworkException` si `simulateNetworkError == true` (`8a`).

---

## 7. Diseño de Casos de Prueba (Matriz de Pruebas para CU-11, CU-12 y CU-13)

El archivo `test/features/publications/cu11_publish_need_test.dart` debe implementar y pasar estas pruebas automatizadas:

| ID Prueba | Caso / Flujo cubierto | Entrada de prueba | Resultado esperado |
|---|---|---|---|
| **TC-CU11-01** | Flujo principal completo (**CU-11** + **CU-12** + **CU-13**) | Título: `Cobijas térmicas`, Descripción: `Para temporada invernal`, Categoría: `Ropa`, Cantidad: `2`, Características: `Matrimonial`, Urgencia: `Alta`, Ubicación: `Col. Centro, CP 72000`. | Se crea la Necesidad en estado `ACTIVA`, con categoría `Ropa`, urgencia `Alta`, se muestra confirmación y aparece en el feed. |
| **TC-CU11-02** | Flujo alterno `7a`: Falta un dato obligatorio | Intentar publicar dejando vacío el título o la descripción. | El sistema marca el campo obligatorio faltante y no crea la publicación. |
| **TC-CU11-03** | **CU-12** flujo alterno `2a`: Sin nivel de urgencia | Llenar los demás campos pero no seleccionar ningún nivel de urgencia (`Alta`, `Media`, `Baja`). | El sistema impide publicar e indica que toda Necesidad debe tener un nivel de urgencia. |
| **TC-CU11-04** | **CU-13** flujo alterno `2a` y `1a`: Categorías activas y obligatorias | (a) Abrir el selector de categorías; (b) intentar publicar sin elegir categoría. | (a) Solo se muestran las 5 categorías activas y NO aparece `Electrónica antigua` (`activa: false`); (b) sin categoría seleccionada no permite publicar. |
| **TC-CU11-05** | Flujo alterno `6a`: Protección de domicilio (**RNF-09**) | Revisar campos del formulario y validación de ubicación aproximada. | El formulario solo solicita colonia o código postal y rechaza/advierte si está vacío, sin pedir calle ni número exacto. |
| **TC-CU11-06** | Flujo alterno `8a`: Pérdida de conexión (**RNF-12**) | Activar `simulateNetworkError = true` y confirmar una Necesidad válida. | El sistema informa que la operación no se realizó, no muestra confirmación de éxito y la Necesidad no se guarda en `MockTenantStore`. |

---

## 8. Qué queda a decisión del implementador y decisiones tomadas
- **Decisiones ya tomadas en este diseño (Decisiones técnicas de arquitectura):**
  - `PublishNeedForm` tiene la firma `const PublishNeedForm({super.key, this.onPublished})` (`final VoidCallback? onPublished`) y se monta dentro de `CreatePublicationScreen` cuando el usuario selecciona **«Necesito»**.
  - Mapeo canónico hacia `PublicacionMock`: elegir *"Cualquiera"* en condición aceptable guarda `condicion: null`; el texto de características (`detallesCaracteristicas`) se almacena como `caracteristicas: {'Detalles': detallesCaracteristicas.trim()}` (o mapa vacío si se deja en blanco).
- **A criterio del implementador:**
  - La disposición visual del selector de urgencia (botones segmentados o tarjetas con distintivo de color).

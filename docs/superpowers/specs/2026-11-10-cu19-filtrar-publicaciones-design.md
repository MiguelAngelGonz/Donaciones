# Especificación de Diseño — CU-19 · Filtrar necesidades por categoría y tipo

## 1. Intención y contexto («El porqué»)
Permitir que cualquier usuario con sesión iniciada consulte en la pantalla principal (**Inicio / Explorar**) las publicaciones activas de la comunidad organizadas por categorías y pueda filtrarlas por **categoría**, por **tipo de publicación** (*Necesidad* o *Artículo*) o por **ambos criterios a la vez**, para encontrar rápidamente dónde ayudar o qué solicitar y abrir el detalle de la publicación (**CU-23** / **CU-24**).

---

## 2. Objetivos, No-objetivos y Anti-objetivos

### Objetivos
- Implementar la pantalla principal de exploración (**Inicio / Explorar**) siguiendo el diseño de la diapositiva 11 de `docs/DISEÑO UI (1).pdf`.
- Mostrar únicamente las publicaciones en estado `ACTIVA` del `MockTenantStore`.
- Permitir filtrar de manera combinada o individual por:
  1. **Categoría:** Tarjetas/chips de categorías (*Todas*, *Salud*, *Educación*, *Alimentación*, *Ropa*, *Artículos para el hogar*).
  2. **Tipo de publicación:** Selector (*Todos*, *Necesidades*, *Artículos*).
- Permitir quitar los filtros en un toque para volver a mostrar todas las publicaciones activas (flujo alterno `2a`).
- Mostrar un estado vacío claro cuando ninguna publicación cumpla con la combinación de filtros elegida (flujo alterno `3a`).
- Al tocar cualquier tarjeta de publicación de la lista, abrir su pantalla de detalle desde donde se ejecutan **CU-23** (si es Artículo) o **CU-24** (si es Necesidad).

### No-objetivos
- No incluye en este caso de uso el cálculo de GPS en tiempo real ni el filtro por radio de 5/10/25 km (**CU-20** y **CU-21**), ni el ordenamiento exclusivo por urgencia (**CU-22**), aunque las tarjetas sí muestran la etiqueta de urgencia y la distancia aproximada de la semilla como en el prototipo de `DISEÑO UI (1).pdf`.

### Anti-objetivos
- Mostrar en el feed publicaciones que estén en estado `RESERVADA`, `CERRADA` o `RETIRADA`.
- Hacer que el filtro por categoría borre el filtro por tipo (o viceversa): ambos filtros deben poder usarse juntos o por separado según el paso 2 de **CU-19**.

---

## 3. Restricciones y Reglas de Negocio
- **Precondición:** Sesión iniciada en el tenant de prueba.
- **RNF-02 (Navegación):** El listado y sus filtros están en la pantalla principal (1 interacción desde el inicio).
- **RNF-03 (Legibilidad):** Las tarjetas de categorías usan la paleta de `DISEÑO UI (1).pdf` (`#00A896`, `#A7E6A6`, `#FFF86A`) con contraste legible y respetan el factor de escala del panel de **Accesibilidad**.
- **RNF-04 (Tiempo de respuesta):** El filtrado se resuelve en menos de 3 segundos (instantáneo sobre el `MockTenantStore`).

---

## 4. Enfoques Evaluados y Decisión

1. **Enfoque 1 (Elegido): Estado de filtros reactivo con `Riverpod` (`FeedFilterController`) que deriva la lista filtrada desde `MockTenantStore`.**
   - *Ventaja:* Cada vez que se crea una Necesidad (**CU-11**) o un Artículo (**CU-14**) en el almacén en memoria, el listado de **CU-19** se actualiza automáticamente sin recargar manualmente la pantalla.
   - *Compromiso:* Los datos base provienen de la semilla en memoria.
2. **Enfoque 2: Consulta con almacenamiento local persistente.**
   - *Compromiso:* Sobrecarga innecesaria para un listado reactivo en modo mock.
3. **Enfoque 3: Filtrado local dentro de un `StatefulWidget` aislado.**
   - *Compromiso:* Dificulta compartir el estado de filtros o actualizar automáticamente la lista tras regresar de **CU-11** / **CU-14**.

---

## 5. Diseño de Interfaz (Alineado con `DISEÑO UI (1).pdf`, diapositivas 11 y 12)

```text
┌──────────────────────────────────────────────┐
│  TU UBICACIÓN: Ciudad de México, México      │
│  Hola, Alondra                            🔔 │
│  ¿Cómo podemos ayudarte hoy?                 │
│  [ ♿ Accesibilidad ]                         │
├──────────────────────────────────────────────┤
│  Categorías                   [Quitar filtros]│
│  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │  ♡       │  │  🎓      │  │  🍎      │    │
│  │  Salud   │  │Educación │  │Alimenta. │    │
│  └──────────┘  └──────────┘  └──────────┘    │
│                                              │
│  Tipo de publicación                         │
│  [ Todos (•) ] [ Necesidades ] [ Artículos ] │
├──────────────────────────────────────────────┤
│  Publicaciones disponibles (4)               │
│  ┌────────────────────────────────────────┐  │
│  │ [NECESIDAD · SALUD]    🔴 Urgencia Alta│  │
│  │ Silla de ruedas plegable               │  │
│  │ Silla de ruedas en buen estado...      │  │
│  │ 📍 2.4 km · María López ★ 4.8         │  │
│  └────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────┐  │
│  │ [ARTÍCULO · HOGAR]     ✨ Como nuevo   │  │
│  │ Mesa de comedor para 4 personas        │  │
│  │ 📍 1.1 km · María López ★ 4.8         │  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

- **Interacción con filtros:**
  - Tocar una tarjeta de categoría activa ese filtro; tocarla de nuevo (o pulsar *«Quitar filtros»*) desactiva el filtro de categoría.
  - Tocar un chip de tipo (*Todos*, *Necesidades*, *Artículos*) filtra por `TipoPublicacion`.
  - Si la combinación elegida (ej. Categoría *Alimentación* + Tipo *Artículos*) no tiene resultados, se muestra una ilustración/icono con el mensaje: *«Ninguna publicación cumple los filtros seleccionados»* y un botón *«Quitar filtros»* (flujos alternos `3a` y `2a`).

---

## 6. Contratos e Integración en el Repositorio

### Archivos a crear por el responsable de CU-19
- `lib/features/publications/presentation/feed_screen.dart`
- `lib/features/publications/presentation/feed_filter_controller.dart`
- `test/features/publications/cu19_filter_publications_test.dart`

### Métodos y providers que consume de `MockTenantStore`
- `List<CategoriaMock> getCategoriesForFilter()`
- `List<PublicacionMock> filterActivePublications({String? categoryId, TipoPublicacion? type})`
- Al tocar una tarjeta, navega a `/publications/:id` (`PublicationDetailScreen`).

---

## 7. Diseño de Casos de Prueba (Matriz de Pruebas para CU-19)

El archivo `test/features/publications/cu19_filter_publications_test.dart` debe implementar y pasar estas pruebas automatizadas:

| ID Prueba | Caso / Flujo cubierto | Entrada de prueba | Resultado esperado |
|---|---|---|---|
| **TC-CU19-01** | Estado inicial sin filtros | Abrir `FeedScreen` con los datos semilla del tenant. | Se muestran todas las publicaciones en estado `ACTIVA` (tanto Necesidades como Artículos) y ninguna publicación inactiva/cerrada. |
| **TC-CU19-02** | Filtrar únicamente por categoría | Seleccionar la categoría `Salud`. | El listado muestra únicamente «Silla de ruedas plegable» (`Salud`) y oculta las publicaciones de `Educación`, `Hogar` y `Ropa`. |
| **TC-CU19-03** | Filtrar únicamente por tipo de publicación | Seleccionar el chip `Artículos`. | El listado muestra solo los Artículos («Mesa de comedor...», «Chaqueta de invierno...») y oculta las Necesidades. |
| **TC-CU19-04** | Filtrar por categoría y tipo simultáneamente | Seleccionar categoría `Ropa` y tipo `Artículos`. | El listado muestra únicamente «Chaqueta de invierno talla M». |
| **TC-CU19-05** | Flujo alterno `3a`: Ninguna publicación cumple los filtros | Seleccionar categoría `Alimentación` (que en la semilla inicial tiene 0 publicaciones). | El sistema muestra el mensaje indicando que ninguna publicación cumple los filtros elegidos. |
| **TC-CU19-06** | Flujo alterno `2a`: Quitar los filtros | Estando con filtros activos, pulsar «Quitar filtros». | Se restablecen categoría y tipo, volviendo a mostrar todas las publicaciones activas. |
| **TC-CU19-07** | Paso 4 del flujo principal: Abrir una publicación de la lista | Tocar la tarjeta «Silla de ruedas plegable». | Navega a la vista de detalle de esa publicación mostrando su descripción, autor y botón de acción. |

---

## 8. Qué queda a decisión del implementador y decisiones tomadas
- **Decisiones ya tomadas en este diseño:**
  - Los filtros de categoría y tipo se aplican de forma inmediata al tocar las tarjetas/chips sin requerir un botón extra de «Aplicar», garantizando menos de 3 interacciones (**RNF-02**) y respuesta inmediata (**RNF-04**).
- **A criterio del implementador:**
  - Incluir opcionalmente la barra de búsqueda por texto en la parte superior del feed como complemento visual (como aparece en la diapositiva 11), siempre que los filtros por categoría y tipo sean los controles principales.

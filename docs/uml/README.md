# Diagramas UML

| Archivo | Contenido |
|---|---|
| `01_diagrama_clases_dominio.puml` | Diagrama de clases del dominio: entidades, atributos, operaciones, relaciones y reglas de negocio. |

Las imágenes ya generadas están en `diagrama_clases_dominio.png` y `.svg`.

Los diagramas están en [PlantUML](https://plantuml.com) y usan `!pragma layout smetana`, así que no hace falta instalar Graphviz. Para verlos:

- **VS Code:** extensión *PlantUML* (jebbs.plantuml) y `Alt+D` para la vista previa.
- **Línea de comandos:** `java -jar plantuml.jar -tsvg docs/uml/*.puml`.
- **En línea:** pegar el contenido en https://www.plantuml.com/plantuml.

## Decisiones del modelo

- **Donante y Donatario no son clases.** Un mismo usuario es donante en una Donación y donatario en otra, así que son *papeles* en la asociación `Donacion → Usuario`. Solo Administrador e Intermediario son permisos guardados (`esAdministrador`, `esIntermediario`).
- **El Beneficiario representado no es una clase.** No tiene cuenta; solo se guarda su alias en `Necesidad.aliasBeneficiario` (RF-15, RNF-09).
- **El Sistema no es una clase.** Sus acciones son operaciones (`finalizarAutomaticamente`, `PerfilConfianza.recalcular`) y en `CambioEstado` aparece como actor nulo.
- **Publicacion y Propuesta son abstractas.** `Necesidad`/`Articulo` y `Solicitud`/`Oferta` comparten estado y ciclo de vida.
- **Coincidencia es `<<calculada>>`.** Se obtiene con una consulta (RF-10) y no se guarda.
- **`EstadoPublicacion.RETIRADA`** es la decisión por defecto que propone la arquitectura para CU-15/CU-16 (punto por confirmar).

## Trazabilidad

| Clase | Requerimientos | Casos de uso |
|---|---|---|
| Usuario, CuentaAcceso, TokenRestablecimiento, Sesion | RF-01, RF-02, RF-04 | CU-01 a CU-10 |
| PerfilConfianza | RF-03 | CU-04, CU-34, CU-37 |
| Publicacion, Necesidad, Articulo, Fotografia | RF-05, RF-06, RF-09 | CU-11 a CU-16 |
| Categoria | RF-07 | CU-13, CU-19, CU-48 a CU-51 |
| Ubicacion | RF-08 | CU-20, CU-21 |
| Coincidencia | RF-10 | CU-17, CU-18 |
| Propuesta, Solicitud, Oferta | RF-11 | CU-23 a CU-29 |
| Donacion, CambioEstado, Mensaje | RF-12, RF-13 | CU-28, CU-30 a CU-36, CU-38, CU-39 |
| Resena | RF-14 | CU-05, CU-37 |
| SolicitudRolIntermediario | RF-15 | CU-40 a CU-45 |
| Notificacion | RF-10, RF-11, RF-12 | CU-18, CU-27, CU-29, CU-32 a CU-36 |

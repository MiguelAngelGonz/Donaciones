# DONATION · MVP Android (Kotlin + Jetpack Compose)

MVP de la aplicación de donaciones del Equipo 3. Cubre el ciclo mínimo
**publicar → descubrir → solicitar → coordinar → confirmar entrega**, que es lo que
permite medir la *tasa de confirmación de entrega* definida en la metodología.

## Cómo abrirlo

1. Android Studio (Koala 2024.1 o más reciente) → **File ▸ Open** → carpeta `DonationApp`.
2. Esperar la sincronización de Gradle (el proyecto usa Gradle 8.7, AGP 8.5.2, Kotlin 2.0.21).
   Si Studio propone actualizar versiones, puede aceptarlas.
3. Ejecutar en un emulador o celular con Android 8.0 (API 26) o superior.

No requiere permisos ni servidor: los datos viven en una base Room local.

## Casos de uso incluidos

| Caso de uso | Dónde está |
|---|---|
| CU-01 Registrarse (3 pasos) y CU-07 Iniciar sesión | `ui/auth/` |
| CU-14 Publicar Artículo y CU-11 Publicar Necesidad | `ui/publish/` |
| CU-19 Filtrar publicaciones por categoría y tipo | `ui/feed/` |
| CU-23 Solicitar artículo y CU-27/CU-28 Aceptar y crear Donación | `ui/post/`, `DonationRepository.acceptRequest` |
| CU-33 Marcar como Entregada y CU-34 Confirmar recepción | `ui/donation/`, `DonationRepository` |
| CU-36 Cancelar Donación (flujo alterno de CU-34) | `ui/donation/` |
| CU-10 Cerrar sesión, CU-03 perfil simplificado y métricas | `ui/profile/` |

Reglas de negocio ya aplicadas: contraseña con PBKDF2 y sal (RNF-07), una sola solicitud
pendiente por usuario y publicación, mensaje de máximo 300 caracteres, aceptar crea una sola
Donación aunque se pulse dos veces (RNF-11), al aceptar se rechazan las demás pendientes,
cada cambio de estado queda en el historial con fecha, hora y usuario, finalización
automática a los 7 días (a nombre del Sistema) y publicación que vuelve a Activa al cancelar.

## Decisiones de simplificación (alineadas con el plan de recorte)

- **Sin chat:** tras aceptar, cada parte ve el usuario y el correo de la otra. El teléfono solo se
  muestra si su dueño activa "Compartir mi teléfono" en el perfil (RF-12, RNF-09).
- **Sin EN_ENTREGA:** la Donación pasa de Aceptada a Entregada a Finalizada (no se registra lugar y fecha).
- **Sin verificación de correo ni bloqueo por intentos** (CU-02, CU-09): contradice RF-04, conviene documentarlo como excepción del MVP.
- **Sin Ofertas:** las Necesidades se publican y se ven en el feed, pero responderlas (CU-24) no está en este alcance.
- **Sin cercanía, reseñas, Perfil de Confianza, intermediarios ni administración de categorías.**
  Las categorías son fijas (`data/Models.kt`, objeto `Categories`).
- **Tasa de confirmación de entrega** (perfil ▸ métricas) = finalizadas ÷ (aceptadas − canceladas).
  Es una definición propuesta; ajústala si la metodología pide otra.

## Paleta

El fondo es `#94DEA5`. `PaletaColores.md` llegó ilegible, así que el resto de los colores se derivó
del fondo. Todos están en `ui/theme/Color.kt`; basta con cambiar ahí los valores.

## Limitaciones que conviene tener claras

- **Los datos son locales a cada teléfono.** Sirve para la presentación (varias cuentas en un mismo
  dispositivo), pero el piloto con 15 a 20 participantes en teléfonos distintos necesita el backend
  (FastAPI + PostgreSQL). Toda la lógica está detrás de `DonationRepository`, que es lo que se
  reemplazaría por llamadas a la API.
- **Este código no se compiló ni se ejecutó** en el entorno donde se escribió (no hay Android SDK).
  Es probable que Android Studio señale algún ajuste menor en el primer build.

## Guion de demostración

1. Registra `donante1` y publica un Artículo con foto.
2. Cierra sesión (Perfil), registra `donatario1`, abre el artículo y envía la solicitud.
3. Cierra sesión, entra como `donante1`, abre su publicación y acepta la solicitud.
4. En Donaciones, marca la donación como entregada.
5. Entra como `donatario1`, abre la donación y confirma la recepción.
6. En Perfil ▸ Métricas se ve la tasa de confirmación de entrega.

## Pruebas

`app/src/test/.../ValidatorsTest.kt` cubre las reglas de registro y de la solicitud
(`./gradlew test`).

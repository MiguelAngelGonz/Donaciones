# Especificación de Diseño — CU-01 · Registrarse

## 1. Intención y contexto («El porqué»)
Permitir que una persona que aún no tiene cuenta en **DonaPlus** se registre proporcionando sus datos personales verificables, su ubicación aproximada y aceptando el aviso de privacidad para integrarse a la comunidad de donaciones.

En este primer MVP (modo mock con tenant de prueba), el registro debe validar todas las reglas de negocio de **RF-01**, **RNF-01**, **RNF-07** y **RNF-12**, agregar el nuevo usuario al `MockTenantStore` y ofrecer una acción simulada para completar la verificación por correo (**CU-02**) en la misma pantalla de confirmación para poder probar de inmediato el resto del MVP.

---

## 2. Objetivos, No-objetivos y Anti-objetivos

### Objetivos
- Implementar el flujo de registro en **máximo 3 pasos principales** (**RNF-01**).
- Validar en tiempo real y al enviar:
  - Nombre de usuario único (sin distinguir mayúsculas/minúsculas).
  - Nombre legal completo obligatorio (como aparece en su acta de nacimiento).
  - Correo electrónico con formato válido y único en el tenant.
  - Teléfono de exactamente **10 dígitos numéricos**.
  - Contraseña de **al menos 8 caracteres**, con al menos **una mayúscula, una minúscula y un número**.
  - Ubicación aproximada (colonia o código postal, decisión arquitectónica de `docs/Arquitectura_Donaciones.docx` sección 8 y 9 para cubrir **CU-20** sin pedir domicilio exacto **RNF-09**).
  - Fotografía de perfil **opcional**.
  - Aceptación **obligatoria** del aviso de privacidad antes de completar el registro.
- Guardar la contraseña transformada mediante hash simulado/criptográfico (nunca en texto plano, **RNF-07**) dentro del `MockTenantStore`.
- Mostrar la pantalla de confirmación que incluye el estado «Correo pendiente de verificar (**CU-02**)» con un botón de prueba *«Simular apertura de enlace de verificación (CU-02)»* para activar la cuenta en el tenant.

### No-objetivos
- No se enviarán correos SMTP reales en esta primera versión mock.
- No se implementará en este archivo el bloqueo por 5 intentos fallidos de login (**CU-09**) ni recuperación de contraseña (**CU-08**).

### Anti-objetivos
- Pedir todos los campos en un formulario largo y confuso que supere los 3 pasos de **RNF-01**.
- Permitir completar el registro sin marcar la casilla del aviso de privacidad (flujo alterno `5a`).
- Mostrar el registro como completado cuando el interruptor de fallo de red (**RNF-12**) esté activo (flujo alterno `6c`).

---

## 3. Restricciones y Reglas de Negocio
- **RF-01 / RNF-01:** Captura distribuida en 3 pasos claros con barra de progreso.
- **RNF-07:** La contraseña no se guarda en texto plano en `CuentaAccesoMock`; se almacena como hash (`sha256` / `bcrypt` mock) y jamás se expone en la interfaz.
- **RNF-09:** El campo de ubicación solo solicita **Colonia o Código Postal**, indicando explícitamente que no debe ingresarse calle ni número exterior.
- **RNF-12:** Si `MockTenantStore.simulateNetworkError == true`, el paso final muestra un `SnackBar` / banner de error indicando que la operación no se realizó y mantiene al usuario en el Paso 3 sin crear la cuenta.

---

## 4. Enfoques Evaluados y Decisión

1. **Enfoque 1 (Elegido): `Stepper` / `PageView` controlado por `Riverpod` conectado al `MockTenantStore` en memoria.**
   - *Ventaja:* Mantiene el estado de los 3 pasos en un `RegisterController` desacoplado de la vista, valida paso por paso y permite ejecutar pruebas de widget rápidas sobre cada flujo alterno (`5a`, `6a`, `6b`, `6c`).
   - *Compromiso:* Los usuarios registrados viven en memoria durante la sesión de prueba.
2. **Enfoque 2: Persistencia del registro en almacenamiento local (`shared_preferences`).**
   - *Compromiso:* Obliga a limpiar almacenamiento local para volver a probar el mismo `@nombreUsuario`.
3. **Enfoque 3: Formulario único sin `Riverpod`.**
   - *Compromiso:* Dificulta justificar el cumplimiento explícito de los 3 pasos de **RNF-01** y rompe la consistencia arquitectónica.

---

## 5. Diseño de Pantallas y Flujo (Estilo DonaPlus)

Siguiendo la paleta de `docs/DISEÑO UI (1).pdf` (`#004D64` primario, `#00A896` secundario, `#A7E6A6` acento):

```text
┌──────────────────────────────────────────────┐
│  ← Crear cuenta en DonaPlus     [Paso 1 de 3]│
│  ██████████░░░░░░░░░░░░░░░░░░░░              │
├──────────────────────────────────────────────┤
│  PASO 1 · Datos de tu cuenta                 │
│  • Nombre de usuario (@unico)   [_________]  │
│  • Correo electrónico           [_________]  │
│  • Contraseña                   [_________]  │
│    ✓ 8+ caracteres  ✓ 1 mayús                │
│    ✓ 1 minús        ✓ 1 número               │
│                                              │
│               [ Continuar → ]                │
└──────────────────────────────────────────────┘
```

- **Paso 1 — Cuenta de acceso:**
  - `TextFormField` Nombre de usuario (valida formato y que no exista ya en `MockTenantStore`, ej. `@alondra.dona` ya existe → dispara `6a`).
  - `TextFormField` Correo electrónico (valida formato de correo y que no esté ya registrado en `MockTenantStore` mediante `isEmailTaken(email)` → dispara `6b`).
  - `TextFormField` Contraseña con indicadores visuales de cumplimiento de las 4 reglas (`≥ 8 caracteres`, `1 mayúscula`, `1 minúscula`, `1 número`).
- **Paso 2 — Datos personales y ubicación aproximada:**
  - `TextFormField` Nombre legal completo (nota: *«Tal como aparece en tu acta de nacimiento. No será editable después.»*).
  - `TextFormField` Teléfono celular (exactamente 10 dígitos numéricos).
  - `TextFormField` Colonia o Código Postal (nota de privacidad **RNF-09**: *«Solo ubicación aproximada; nunca ingreses tu domicilio exacto»*).
  - Selector de **Fotografía de perfil (Opcional)**: permite elegir un avatar/foto de muestra o galería sin bloquear el avance si se deja vacío.
- **Paso 3 — Aviso de privacidad y confirmación:**
  - Resumen de los datos capturados.
  - Tarjeta desplazable con el resumen del **Aviso de Privacidad de DonaPlus** (**RNF-09**).
  - `CheckboxListTile` obligatorio: *«He leído y acepto el aviso de privacidad»*. El botón **«Confirmar registro»** permanece deshabilitado o muestra error explícito si se intenta confirmar sin marcarlo (flujo `5a`).
- **Pantalla / Vista de Confirmación Post-Registro (Conexión con CU-02):**
  - Muestra confirmación: *«¡Cuenta creada con éxito! Enviamos un enlace de verificación a tu correo.»*
  - En modo tenant de prueba incluye dos botones claros:
    1. **«Simular verificación de correo (CU-02) y entrar»**: marca `correoVerificado = true`, selecciona al nuevo usuario como usuario activo del tenant y navega al feed principal (**CU-19**).
    2. **«Continuar sin verificar (probar restricción CU-02 2a)»**: deja `correoVerificado = false` y muestra el aviso de que sin verificar el correo no se puede iniciar sesión.

---

## 6. Contratos e Integración en el Repositorio

### Archivos a crear por el responsable de CU-01
- `lib/features/auth/presentation/register_screen.dart`
- `lib/features/auth/presentation/register_controller.dart`
- `test/features/auth/cu01_register_test.dart`

### Métodos que consume de `MockTenantStore` (`lib/core/mock/mock_tenant_store.dart`)
- `bool isUsernameTaken(String username)`
- `bool isEmailTaken(String email)`
- `Future<UsuarioMock> registerUser(RegisterUserInput input)`
  - Lanza `DuplicateUsernameException` si el nombre de usuario ya existe (`6a`).
  - Lanza `ValidationException` si algún campo incumple **RF-01** o si el correo ya está registrado en el tenant (`6b`).
  - Lanza `NetworkException` si `simulateNetworkError == true` (`6c`).
- `Future<void> verifyEmailForTest(String userId)` (para simular **CU-02** en el tenant de prueba).

---

## 7. Diseño de Casos de Prueba (Matriz de Pruebas para CU-01)

El archivo `test/features/auth/cu01_register_test.dart` debe implementar y pasar estas pruebas automatizadas:

| ID Prueba | Caso / Flujo cubierto | Entrada de prueba | Resultado esperado |
|---|---|---|---|
| **TC-CU01-01** | Flujo principal completo (con foto opcional y verificación mock) | Paso 1: `miguel_buap`, `miguel@buap.mx`, `Donar2026`. Paso 2: `Miguel Ángel González Hernández`, `2223334455`, `Col. Universidades, CP 72589`, foto seleccionada. Paso 3: acepta aviso y confirma. | Se crea el usuario en `MockTenantStore` con contraseña hasheada (**RNF-07**), `correoVerificado == false`, y se muestra la pantalla de confirmación en ≤ 3 pasos (**RNF-01**). |
| **TC-CU01-02** | Flujo principal sin fotografía opcional | Mismos datos válidos dejando la fotografía vacía. | El registro se completa sin error y el perfil queda con `fotoPerfil == null`. |
| **TC-CU01-03** | Flujo alterno `6a`: Nombre de usuario duplicado | Ingresar `alondra.dona` (ya existente en la semilla del tenant). | El sistema señala que el nombre de usuario ya existe y pide otro sin avanzar ni crear cuenta. |
| **TC-CU01-04** | Flujo alterno `6b`: Correo, teléfono o contraseña inválidos | Probar: (a) correo `invalido@`, (b) teléfono de 8 dígitos `22212345`, (c) contraseña sin mayúscula o sin número `donar2026`. | El sistema marca el campo correspondiente y muestra la regla exacta incumplida. |
| **TC-CU01-05** | Flujo alterno `5a`: No acepta aviso de privacidad | Completar Pasos 1 y 2 válidos, llegar al Paso 3 y pulsar confirmar con el checkbox desmarcado. | El sistema impide completar el registro y señala que debe aceptar el aviso de privacidad. |
| **TC-CU01-06** | Flujo alterno `6c`: Pérdida de conexión (**RNF-12**) | Activar `simulateNetworkError = true` en `MockTenantStore` y confirmar registro válido. | El sistema informa que la operación no se realizó, no muestra la pantalla de registro completado y el usuario no se agrega al almacén. |
| **TC-CU01-07** | Relación `«include» CU-02`: Verificación de correo vs flujo `2a` | Tras registrar cuenta, probar (a) intentar usar sesión sin verificar (`2a`) y (b) pulsar «Simular verificación de correo (CU-02)». | Sin verificar no permite abrir sesión activa; al verificar pasa `correoVerificado = true` y redirige al feed principal. |

---

## 8. Qué queda a decisión del implementador y decisiones tomadas
- **Decisiones ya tomadas en este diseño:**
  - La ubicación aproximada (`colonia o código postal`) se solicita en el Paso 2 del registro (siguiendo la sección 9 de `docs/Arquitectura_Donaciones.docx`).
  - En modo mock se incluye el botón para simular el clic en el enlace de verificación de **CU-02** para no depender de un servidor de correo externo.
- **A criterio del implementador:**
  - El diseño visual detallado de los avatares predeterminados cuando el usuario elige una foto de prueba en el Paso 2.
  - La redacción exacta del texto completo dentro del cuadro del Aviso de Privacidad, siempre que mencione la protección de datos personales (**RNF-09**).

# CU-01 · Registrarse (incluye verificación mock CU-02) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar el flujo de registro de usuario en 3 pasos (`CU-01`) con validación de reglas de negocio (`RF-01`, `RNF-01`, `RNF-07`, `RNF-09`, `RNF-12`) y confirmación con verificación de correo simulada (`CU-02`) sobre el `MockTenantStore`.

**Architecture:** Controlador de estado `RegisterController` (`StateNotifier` / `Notifier` en Riverpod) que administra los 3 pasos del formulario y delega la persistencia en memoria a `MockTenantStore.registerUser` y `MockTenantStore.verifyEmailForTest`.

**Tech Stack:** Flutter (`sdk: ^3.13.5`), `flutter_riverpod`, `go_router`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-11-10-cu01-registrarse-design.md`

## Global Constraints

- **Máximo 3 pasos (`RNF-01`):** Paso 1 (Cuenta), Paso 2 (Datos personales + ubicación aproximada + foto opcional), Paso 3 (Aviso de privacidad + confirmación).
- **Reglas de campos (`RF-01`):** Nombre de usuario único; correo con formato válido y único; teléfono de exactamente 10 dígitos numéricos; contraseña `>= 8` caracteres con `>= 1` mayúscula, `>= 1` minúscula y `>= 1` número; aviso de privacidad obligatorio (`5a`).
- **Privacidad (`RNF-07`, `RNF-09`):** Contraseña almacenada como hash en `CuentaAccesoMock`; ubicación aproximada (colonia o CP).
- **Recuperación ante errores (`RNF-12`):** Si `simulateNetworkError == true`, lanza `NetworkException`, muestra el mensaje de error y mantiene al usuario en el Paso 3 sin crear la cuenta (`6c`).

## Review Focus

1. **Espacios al inicio/final en nombre de usuario y correo:** Ingresar `  miguel_buap  ` o `  miguel@buap.mx  ` debe hacer `trim()` antes de validar y registrar.
2. **Teléfono con letras o símbolos de 10 caracteres:** Un valor como `222-123-45` tiene 10 caracteres pero no son 10 dígitos numéricos; debe rechazarse con mensaje claro (`6b`).
3. **Correo duplicado en el Paso 1:** Ingresar `alondra.demo@donaplus.app` (ya existente en la semilla) debe detectarse en el Paso 1 mediante `isEmailTaken` sin esperar hasta el Paso 3.
4. **Doble toque en «Confirmar registro»:** Mientras `isSubmitting == true`, el botón debe deshabilitarse para no disparar `DuplicateUsernameException` en el segundo toque.
5. **Restricción de `CU-02` (`2a`):** Si el usuario pulsa «Continuar sin verificar», `correoVerificado` permanece `false` y el sistema informa que no puede abrir sesión activa hasta verificar el correo.

---

### Task 1: `RegisterController` y Validaciones de Pasos 1, 2 y 3

**Files:**
- Create: `lib/features/auth/presentation/register_controller.dart`
- Create: `test/features/auth/cu01_register_test.dart`

**Interfaces:**
- Consumes: `mockTenantStoreProvider`, `RegisterUserInput`, `DuplicateUsernameException`, `ValidationException`, `NetworkException`.
- Produces:
  - `RegisterState` (`currentStep`, `usernameError`, `emailError`, `passwordError`, `legalNameError`, `phoneError`, `locationError`, `privacyError`, `submissionError`, `registeredUser`, `unverifiedLoginBlockedMessage`).
  - `RegisterController` (`validateStep1`, `validateStep2`, `submitRegistration`, `simulateVerifyEmail`, `tryContinueUnverified`).

- [ ] **Step 1: Write failing unit/controller tests for `TC-CU01-03`, `TC-CU01-04`, and `TC-CU01-05` in `test/features/auth/cu01_register_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/features/auth/presentation/register_controller.dart';

void main() {
  test('TC-CU01-03 & duplicate email: Step 1 blocks existing username or email', () {
    final store = MockTenantStore();
    final controller = RegisterController(store);
    expect(
      controller.validateStep1(
        username: 'alondra.dona',
        email: 'nuevo@buap.mx',
        password: 'Password1',
      ),
      isFalse,
    );
    expect(controller.state.usernameError, isNotNull);
  });

  test('TC-CU01-04: rejects invalid email, non-10-digit phone, and weak password', () {
    final store = MockTenantStore();
    final controller = RegisterController(store);
    expect(
      controller.validateStep1(
        username: 'nuevo_usr',
        email: 'invalido@',
        password: 'donar2026',
      ),
      isFalse,
    );
    expect(controller.state.emailError, isNotNull);
    expect(controller.state.passwordError, isNotNull);

    expect(
      controller.validateStep2(
        legalName: 'Miguel Ángel González',
        phone: '222-123-45',
        location: 'Col. Centro, CP 72000',
      ),
      isFalse,
    );
    expect(controller.state.phoneError, isNotNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/cu01_register_test.dart`
Expected: FAIL (`register_controller.dart` does not exist).

- [ ] **Step 3: Implement `RegisterState` and `RegisterController` in `lib/features/auth/presentation/register_controller.dart`**

Implement step-by-step validation rules (`RF-01`), password strength flags (`hasMinLength`, `hasUppercase`, `hasLowercase`, `hasDigit`), privacy check (`5a`), and `submitRegistration` handling `DuplicateUsernameException`, `ValidationException`, and `NetworkException` (`6c`).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/auth/cu01_register_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/presentation/register_controller.dart test/features/auth/cu01_register_test.dart
git commit -m "feat(cu01): add RegisterController with RF-01 step validations"
```

---

### Task 2: Pantalla `RegisterScreen` en 3 Pasos y Confirmación `CU-02` (`TC-CU01-01` a `TC-CU01-07`)

**Files:**
- Modify: `lib/features/auth/presentation/register_screen.dart`
- Modify: `test/features/auth/cu01_register_test.dart`

**Interfaces:**
- Consumes: `RegisterController`, `mockTenantStoreProvider`.
- Produces: `const RegisterScreen({super.key})` con barra de progreso de 3 pasos y vista post-registro para `CU-02`.

- [ ] **Step 1: Add widget tests for `TC-CU01-01`, `TC-CU01-02`, `TC-CU01-05`, `TC-CU01-06`, and `TC-CU01-07` in `test/features/auth/cu01_register_test.dart`**

```dart
testWidgets('TC-CU01-01, TC-CU01-05, TC-CU01-06 & TC-CU01-07 full 3-step widget flow', (tester) async {
  // Completes Step 1 (miguel_buap, miguel@buap.mx, Donar2026),
  // Step 2 (Miguel Ángel González Hernández, 2223334455, Col. Universidades, CP 72589),
  // checks Step 3 privacy block (5a), network error recovery (6c),
  // then completes registration and tests CU-02 email verification buttons.
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/cu01_register_test.dart`
Expected: FAIL (stub `RegisterScreen` does not render the 3-step form).

- [ ] **Step 3: Implement `RegisterScreen` in `lib/features/auth/presentation/register_screen.dart`**

Render the 3 steps with progress indicator (`Paso X de 3`), real-time password checklist, optional profile photo selector in Step 2, privacy notice card + mandatory `CheckboxListTile` in Step 3, and post-registration view with buttons `Simular verificación de correo (CU-02) y entrar` and `Continuar sin verificar (probar restricción CU-02 2a)`.

- [ ] **Step 4: Run test to verify all 7 test cases (`TC-CU01-01` to `TC-CU01-07`) pass**

Run: `flutter test test/features/auth/cu01_register_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/presentation/register_screen.dart test/features/auth/cu01_register_test.dart
git commit -m "feat(cu01): implement 3-step RegisterScreen and CU-02 mock verification"
```

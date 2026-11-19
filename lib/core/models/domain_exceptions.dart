/// Thrown when simulated network failure is enabled (RNF-12).
class NetworkException implements Exception {
  final String message;

  const NetworkException([
    this.message = 'No se pudo completar la operación por pérdida de conexión',
  ]);

  @override
  String toString() => message;
}

/// Thrown when registering with an already taken username (CU-01 6a).
class DuplicateUsernameException implements Exception {
  final String message;

  const DuplicateUsernameException([
    this.message = 'El nombre de usuario ya existe',
  ]);

  @override
  String toString() => message;
}

/// Thrown when domain or input validation fails.
class ValidationException implements Exception {
  final String message;

  const ValidationException(this.message);

  @override
  String toString() => message;
}

/// Thrown on failed email/username + password authentication (CU-07).
class InvalidCredentialsException implements Exception {
  final String message;

  const InvalidCredentialsException([
    this.message = 'Credenciales inválidas. Verifica tus datos.',
  ]);

  @override
  String toString() => message;
}

/// Thrown when an account is temporarily locked after 5 failed attempts (CU-09).
class AccountLockedException implements Exception {
  final String message;

  const AccountLockedException([
    this.message =
        'Acceso bloqueado temporalmente por 15 minutos tras 5 intentos fallidos.',
  ]);

  @override
  String toString() => message;
}

/// Thrown when attempting login before verifying email (CU-02, CU-07).
class UnverifiedEmailException implements Exception {
  final String message;

  const UnverifiedEmailException([
    this.message =
        'Debes verificar tu correo electrónico antes de iniciar sesión.',
  ]);

  @override
  String toString() => message;
}

/// Thrown when a password reset token is expired, invalid, or already used (CU-08).
class ExpiredOrUsedTokenException implements Exception {
  final String message;

  const ExpiredOrUsedTokenException([
    this.message = 'El enlace de restablecimiento ya venció o ya fue utilizado.',
  ]);

  @override
  String toString() => message;
}

/// Thrown when an unauthenticated or unauthorized user attempts an action.
class UnauthorizedActionException implements Exception {
  final String message;

  const UnauthorizedActionException([
    this.message = 'No tienes permiso para realizar esta acción.',
  ]);

  @override
  String toString() => message;
}

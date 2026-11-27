import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_exceptions.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/core/models/dto_inputs.dart';
import 'package:donaciones/features/auth/presentation/auth_form_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immutable state for the 3-step registration flow (CU-01 & CU-02).
class RegisterState {
  static const Object _unset = Object();

  final int currentStep;
  final String username;
  final String email;
  final String password;
  final String legalName;
  final String phone;
  final String location;
  final String? photoPerfil;
  final bool privacyAccepted;
  final String? usernameError;
  final String? emailError;
  final String? passwordError;
  final String? legalNameError;
  final String? phoneError;
  final String? locationError;
  final String? privacyError;
  final String? submissionError;
  final bool isSubmitting;
  final UsuarioMock? registeredUser;
  final String? unverifiedLoginBlockedMessage;

  const RegisterState({
    this.currentStep = 0,
    this.username = '',
    this.email = '',
    this.password = '',
    this.legalName = '',
    this.phone = '',
    this.location = '',
    this.photoPerfil,
    this.privacyAccepted = false,
    this.usernameError,
    this.emailError,
    this.passwordError,
    this.legalNameError,
    this.phoneError,
    this.locationError,
    this.privacyError,
    this.submissionError,
    this.isSubmitting = false,
    this.registeredUser,
    this.unverifiedLoginBlockedMessage,
  });

  PasswordRuleStatus get passwordStatus =>
      PasswordRuleStatus.fromPassword(password);

  RegisterState copyWith({
    int? currentStep,
    String? username,
    String? email,
    String? password,
    String? legalName,
    String? phone,
    String? location,
    Object? photoPerfil = _unset,
    bool? privacyAccepted,
    Object? usernameError = _unset,
    Object? emailError = _unset,
    Object? passwordError = _unset,
    Object? legalNameError = _unset,
    Object? phoneError = _unset,
    Object? locationError = _unset,
    Object? privacyError = _unset,
    Object? submissionError = _unset,
    bool? isSubmitting,
    Object? registeredUser = _unset,
    Object? unverifiedLoginBlockedMessage = _unset,
  }) {
    return RegisterState(
      currentStep: currentStep ?? this.currentStep,
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      legalName: legalName ?? this.legalName,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      photoPerfil: identical(photoPerfil, _unset)
          ? this.photoPerfil
          : photoPerfil as String?,
      privacyAccepted: privacyAccepted ?? this.privacyAccepted,
      usernameError: identical(usernameError, _unset)
          ? this.usernameError
          : usernameError as String?,
      emailError: identical(emailError, _unset)
          ? this.emailError
          : emailError as String?,
      passwordError: identical(passwordError, _unset)
          ? this.passwordError
          : passwordError as String?,
      legalNameError: identical(legalNameError, _unset)
          ? this.legalNameError
          : legalNameError as String?,
      phoneError: identical(phoneError, _unset)
          ? this.phoneError
          : phoneError as String?,
      locationError: identical(locationError, _unset)
          ? this.locationError
          : locationError as String?,
      privacyError: identical(privacyError, _unset)
          ? this.privacyError
          : privacyError as String?,
      submissionError: identical(submissionError, _unset)
          ? this.submissionError
          : submissionError as String?,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      registeredUser: identical(registeredUser, _unset)
          ? this.registeredUser
          : registeredUser as UsuarioMock?,
      unverifiedLoginBlockedMessage:
          identical(unverifiedLoginBlockedMessage, _unset)
          ? this.unverifiedLoginBlockedMessage
          : unverifiedLoginBlockedMessage as String?,
    );
  }
}

/// Auto-disposed provider managing the 3-step registration state.
final registerControllerProvider =
    StateNotifierProvider.autoDispose<RegisterController, RegisterState>(
      (ref) => RegisterController(ref.read(mockTenantStoreProvider)),
    );

/// StateNotifier driving CU-01 validations and CU-02 simulated verification.
class RegisterController extends StateNotifier<RegisterState> {
  final MockTenantStore _store;

  RegisterController(this._store) : super(const RegisterState());

  @override
  RegisterState get state => super.state;

  String _stripLeadingAt(String value) {
    var result = value;
    while (result.startsWith('@')) {
      result = result.substring(1);
    }
    return result;
  }

  void updatePasswordDraft(String value) {
    state = state.copyWith(
      password: value,
      passwordError: state.passwordError == null
          ? null
          : validatePasswordError(value),
    );
  }

  void setPhotoPerfil(String? path) {
    final normalized = (path != null && path.trim().isNotEmpty)
        ? path.trim()
        : null;
    state = state.copyWith(photoPerfil: normalized);
  }

  void setPrivacyAccepted(bool accepted) {
    state = state.copyWith(
      privacyAccepted: accepted,
      privacyError: accepted ? null : state.privacyError,
    );
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(
        currentStep: state.currentStep - 1,
        submissionError: null,
        privacyError: null,
      );
    }
  }

  /// Validates Step 1 (username, email, password) and advances to Step 2 if valid.
  bool validateStep1({
    required String username,
    required String email,
    required String password,
  }) {
    final cleanUsername = _stripLeadingAt(username.trim());
    final cleanEmail = email.trim();

    String? usernameError;
    if (cleanUsername.isEmpty) {
      usernameError = 'El nombre de usuario es obligatorio.';
    } else if (cleanUsername.contains(RegExp(r'\s'))) {
      usernameError = 'El nombre de usuario no puede contener espacios.';
    } else if (_store.isUsernameTaken(cleanUsername)) {
      usernameError = 'El nombre de usuario ya existe. Elige otro.';
    }

    String? emailError = validateEmailError(cleanEmail);
    if (emailError == null && _store.isEmailTaken(cleanEmail)) {
      emailError = 'El correo electrónico ya está registrado.';
    }

    final passwordError = validatePasswordError(password);

    final isValid =
        usernameError == null && emailError == null && passwordError == null;
    state = state.copyWith(
      username: cleanUsername,
      email: cleanEmail,
      password: password,
      usernameError: usernameError,
      emailError: emailError,
      passwordError: passwordError,
      currentStep: isValid ? 1 : state.currentStep,
    );
    return isValid;
  }

  /// Validates Step 2 (legal name, 10-digit phone, approximate location) and advances to Step 3.
  bool validateStep2({
    required String legalName,
    required String phone,
    required String location,
  }) {
    final cleanName = legalName.trim();
    final cleanPhone = phone.trim();
    final cleanLocation = location.trim();

    final legalNameError = cleanName.isEmpty
        ? 'El nombre legal completo es obligatorio.'
        : null;
    final phoneError = validatePhoneError(cleanPhone);
    final locationError = cleanLocation.isEmpty
        ? 'La ubicación aproximada (colonia o código postal) es obligatoria.'
        : null;

    final isValid =
        legalNameError == null && phoneError == null && locationError == null;
    state = state.copyWith(
      legalName: cleanName,
      phone: cleanPhone,
      location: cleanLocation,
      legalNameError: legalNameError,
      phoneError: phoneError,
      locationError: locationError,
      currentStep: isValid ? 2 : state.currentStep,
    );
    return isValid;
  }

  /// Submits registration on Step 3 respecting privacy consent (5a) and network errors (6c).
  Future<UsuarioMock?> submitRegistration({bool? privacyAccepted}) async {
    if (state.isSubmitting) return null;

    final accepted = privacyAccepted ?? state.privacyAccepted;
    if (!accepted) {
      state = state.copyWith(
        privacyAccepted: false,
        privacyError:
            'Debes aceptar el aviso de privacidad para completar el registro.',
        submissionError: null,
      );
      return null;
    }

    state = state.copyWith(
      privacyAccepted: true,
      privacyError: null,
      submissionError: null,
      isSubmitting: true,
    );

    try {
      final user = await _store.registerUser(
        RegisterUserInput(
          nombreUsuario: state.username,
          nombreLegal: state.legalName,
          correo: state.email,
          telefono: state.phone,
          password: state.password,
          ubicacionEtiqueta: state.location,
          fotoPerfil: state.photoPerfil,
          avisoPrivacidadAceptado: true,
        ),
      );
      if (!mounted) return null;
      state = state.copyWith(
        isSubmitting: false,
        registeredUser: user,
        submissionError: null,
        unverifiedLoginBlockedMessage: null,
      );
      return user;
    } catch (error) {
      if (!mounted) return null;
      final message = switch (error) {
        DuplicateUsernameException(:final message) => message,
        ValidationException(:final message) => message,
        NetworkException(:final message) => message,
        _ => 'No se pudo completar el registro. Inténtalo de nuevo.',
      };
      state = state.copyWith(
        isSubmitting: false,
        usernameError: error is DuplicateUsernameException
            ? message
            : state.usernameError,
        submissionError: message,
      );
      return null;
    }
  }

  /// Simulates CU-02 email verification and activates the user's session.
  Future<bool> simulateVerifyEmail() async {
    final user = state.registeredUser;
    if (user == null || state.isSubmitting) return false;

    state = state.copyWith(isSubmitting: true, submissionError: null);
    try {
      await _store.verifyEmailForTest(user.id);
      _store.setActiveUser(user.id);
      final verified = _store.findUserById(user.id) ?? user;
      state = state.copyWith(
        isSubmitting: false,
        registeredUser: verified,
        unverifiedLoginBlockedMessage: null,
        submissionError: null,
      );
      return true;
    } on NetworkException catch (e) {
      state = state.copyWith(isSubmitting: false, submissionError: e.message);
      return false;
    } on ValidationException catch (e) {
      state = state.copyWith(isSubmitting: false, submissionError: e.message);
      return false;
    }
  }

  /// Demonstrates CU-02 (2a) restriction when continuing without verifying email.
  void tryContinueUnverified() {
    final user = state.registeredUser;
    if (user == null) return;
    if (_store.activeUser?.id == user.id) {
      _store.logout();
    }
    state = state.copyWith(
      unverifiedLoginBlockedMessage:
          'Debes verificar tu correo electrónico antes de iniciar sesión. Sin verificar el correo no se permite abrir sesión activa (CU-02 2a).',
    );
  }
}

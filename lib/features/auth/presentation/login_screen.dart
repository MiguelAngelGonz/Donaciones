import 'package:donaciones/core/auth/password_recovery.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_exceptions.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/core/widgets/demo_tenant_toolbar.dart';
import 'package:donaciones/features/auth/presentation/auth_form_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// User sign-in screen covering CU-07, CU-09 lockouts, and CU-02 unverified guard.
class LoginScreen extends ConsumerStatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginScreen({super.key, this.onLoginSuccess});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;
  AuthBannerTone _errorTone = AuthBannerTone.error;
  String? _unverifiedUserId;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _normalizeUsername(String value) {
    var result = value.trim().toLowerCase();
    while (result.startsWith('@')) {
      result = result.substring(1);
    }
    return result;
  }

  UsuarioMock? _findMatchingUser(MockTenantStore store, String query) {
    final normalizedEmail = query.trim().toLowerCase();
    final normalizedUser = _normalizeUsername(query);
    for (final user in store.users) {
      if (user.correo.trim().toLowerCase() == normalizedEmail ||
          _normalizeUsername(user.nombreUsuario) == normalizedUser) {
        return user;
      }
    }
    return null;
  }

  void _navigateBackOrHome() {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _navigateTo(String route, {bool push = false}) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      if (push) {
        context.push(route);
      } else {
        context.go(route);
      }
    }
  }

  Future<void> _submitLogin() async {
    if (_isSubmitting) return;
    final store = ref.read(mockTenantStoreProvider);

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
      _unverifiedUserId = null;
    });

    try {
      await store.login(
        usernameOrEmail: _identifierController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      widget.onLoginSuccess?.call();
      _navigateTo('/');
    } on UnverifiedEmailException catch (e) {
      final matched = _findMatchingUser(store, _identifierController.text);
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message;
        _errorTone = AuthBannerTone.warning;
        _unverifiedUserId = matched?.id;
      });
    } on AccountLockedException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message;
        _errorTone = AuthBannerTone.error;
      });
    } on InvalidCredentialsException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message;
        _errorTone = AuthBannerTone.error;
      });
    } on ValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message;
        _errorTone = AuthBannerTone.error;
      });
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message;
        _errorTone = AuthBannerTone.error;
      });
    }
  }

  Future<void> _simulateEmailVerification() async {
    final userId = _unverifiedUserId;
    if (userId == null || _isSubmitting) return;
    final store = ref.read(mockTenantStoreProvider);
    setState(() => _isSubmitting = true);

    try {
      await store.verifyEmailForTest(userId);
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = null;
        _unverifiedUserId = null;
        _successMessage = 'Correo verificado. Ya puedes iniciar sesión.';
      });
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message;
        _errorTone = AuthBannerTone.error;
      });
    } on ValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message;
        _errorTone = AuthBannerTone.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final online = ref.watch(mockTenantStoreProvider).isOnline;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigateBackOrHome,
        ),
        title: const Text('Iniciar sesión'),
      ),
      body: Column(
        children: [
          const DemoTenantToolbar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Image.asset(
                              'assets/komuna_logo.jpeg',
                              width: 64,
                              height: 64,
                              cacheWidth: 192,
                              excludeFromSemantics: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Bienvenido a Komuna',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            online ? 'Ingresa con el correo de tu cuenta.' : 'Ingresa con tu nombre de usuario o correo electrónico.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            key: const Key('login_identifier_field'),
                            controller: _identifierController,
                            textInputAction: TextInputAction.next,
                            keyboardType: online
                                ? TextInputType.emailAddress
                                : null,
                            decoration: InputDecoration(
                              labelText: online
                                  ? 'Correo electrónico'
                                  : 'Nombre de usuario o correo',
                              hintText: online
                                  ? 'correo@ejemplo.com'
                                  : '@usuario o correo@ejemplo.com',
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            key: const Key('login_password_field'),
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            onFieldSubmitted: (_) => _submitLogin(),
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Mostrar'
                                    : 'Ocultar',
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 14),
                            AuthFeedbackBanner(
                              message: _errorMessage!,
                              tone: _errorTone,
                            ),
                          ],
                          if (!online && _unverifiedUserId != null) ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _isSubmitting
                                  ? null
                                  : _simulateEmailVerification,
                              icon: const Icon(Icons.mark_email_read_outlined),
                              label: const Text(
                                'Simular verificación de correo (CU-02)',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                          if (_successMessage != null) ...[
                            const SizedBox(height: 14),
                            AuthFeedbackBanner(
                              message: _successMessage!,
                              tone: AuthBannerTone.success,
                            ),
                          ],
                          const SizedBox(height: 18),
                          FilledButton(
                            key: const Key('login_submit_button'),
                            onPressed: _isSubmitting ? null : _submitLogin,
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Iniciar sesión'),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (!online ||
                                  ref.watch(passwordRecoveryProvider) != null)
                                TextButton(
                                  onPressed: () => _navigateTo(
                                    '/reset-password',
                                    push: true,
                                  ),
                                  child: const Text(
                                    '¿Olvidaste tu contraseña?',
                                  ),
                                ),
                              TextButton(
                                onPressed: () =>
                                    _navigateTo('/register', push: true),
                                child: const Text('Crear cuenta'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

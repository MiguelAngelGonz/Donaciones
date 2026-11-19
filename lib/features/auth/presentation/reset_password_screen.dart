import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_exceptions.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/core/widgets/demo_tenant_toolbar.dart';
import 'package:donaciones/features/auth/presentation/auth_form_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Password reset screen implementing CU-08 (30-min single-use token flow).
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmittingRequest = false;
  bool _isSubmittingConfirm = false;
  TokenRestablecimientoMock? _generatedToken;
  String? _requestError;
  String? _confirmError;
  String? _confirmSuccess;

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void _navigateBackOrLogin() {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/login');
      }
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _goToLogin() {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      context.go('/login');
    }
  }

  Future<void> _requestToken() async {
    if (_isSubmittingRequest) return;
    final store = ref.read(mockTenantStoreProvider);

    setState(() {
      _isSubmittingRequest = true;
      _generatedToken = null;
      _requestError = null;
      _confirmError = null;
      _confirmSuccess = null;
    });

    try {
      final token = await store.requestPasswordReset(_emailController.text);
      if (!mounted) return;
      _tokenController.text = token.token;
      setState(() {
        _isSubmittingRequest = false;
        _generatedToken = token;
      });
    } on ValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmittingRequest = false;
        _requestError = e.message;
      });
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmittingRequest = false;
        _requestError = e.message;
      });
    }
  }

  Future<void> _confirmReset() async {
    if (_isSubmittingConfirm) return;
    final store = ref.read(mockTenantStoreProvider);

    setState(() {
      _isSubmittingConfirm = true;
      _confirmError = null;
      _confirmSuccess = null;
    });

    try {
      await store.confirmPasswordReset(
        token: _tokenController.text,
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      setState(() {
        _isSubmittingConfirm = false;
        _confirmSuccess =
            'Contraseña actualizada correctamente. Ya puedes iniciar sesión.';
      });
    } on ExpiredOrUsedTokenException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmittingConfirm = false;
        _confirmError = e.message;
      });
    } on ValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmittingConfirm = false;
        _confirmError = e.message;
      });
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmittingConfirm = false;
        _confirmError = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigateBackOrLogin,
        ),
        title: const Text('Restablecer contraseña'),
      ),
      body: Column(
        children: [
          const DemoTenantToolbar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '1. Solicitar enlace de restablecimiento',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                key: const Key('reset_email_field'),
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Correo electrónico registrado',
                                  hintText: 'usuario@correo.com',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                              ),
                              if (_requestError != null) ...[
                                const SizedBox(height: 12),
                                AuthFeedbackBanner(
                                  message: _requestError!,
                                  tone: AuthBannerTone.error,
                                ),
                              ],
                              if (_generatedToken != null) ...[
                                const SizedBox(height: 12),
                                AuthFeedbackBanner(
                                  message:
                                      'Token generado (modo prueba): ${_generatedToken!.token}\n'
                                      'Válido por 30 minutos y de un solo uso.',
                                  tone: AuthBannerTone.info,
                                ),
                              ],
                              const SizedBox(height: 14),
                              FilledButton(
                                onPressed:
                                    _isSubmittingRequest ? null : _requestToken,
                                child: const Text(
                                  'Enviar enlace de restablecimiento',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '2. Aplicar nueva contraseña',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                key: const Key('reset_token_field'),
                                controller: _tokenController,
                                decoration: const InputDecoration(
                                  labelText: 'Token de restablecimiento',
                                  hintText: 'rst-1-usr-diego',
                                  prefixIcon: Icon(Icons.key_outlined),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                key: const Key('reset_new_password_field'),
                                controller: _newPasswordController,
                                obscureText: _obscurePassword,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: 'Nueva contraseña',
                                  prefixIcon: const Icon(Icons.lock_reset),
                                  suffixIcon: IconButton(
                                    tooltip:
                                        _obscurePassword ? 'Mostrar' : 'Ocultar',
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
                              const SizedBox(height: 10),
                              PasswordRulesChecklist(
                                password: _newPasswordController.text,
                              ),
                              if (_confirmError != null) ...[
                                const SizedBox(height: 12),
                                AuthFeedbackBanner(
                                  message: _confirmError!,
                                  tone: AuthBannerTone.error,
                                ),
                              ],
                              if (_confirmSuccess != null) ...[
                                const SizedBox(height: 12),
                                AuthFeedbackBanner(
                                  message: _confirmSuccess!,
                                  tone: AuthBannerTone.success,
                                ),
                              ],
                              const SizedBox(height: 14),
                              FilledButton(
                                onPressed:
                                    _isSubmittingConfirm ? null : _confirmReset,
                                child: const Text('Actualizar contraseña'),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton(
                                onPressed: _goToLogin,
                                child: const Text('Ir a iniciar sesión'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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

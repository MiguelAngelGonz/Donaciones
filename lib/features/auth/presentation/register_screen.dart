import 'package:donaciones/app/theme.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/core/widgets/demo_tenant_toolbar.dart';
import 'package:donaciones/features/auth/presentation/auth_form_widgets.dart';
import 'package:donaciones/features/auth/presentation/register_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 3-step user registration screen (CU-01, RNF-01) with CU-02 mock verification.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _legalNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _legalNameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
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

  void _goRoute(String route) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      context.go(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerControllerProvider);
    final controller = ref.read(registerControllerProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigateBackOrHome,
        ),
        title: const Text('Crear cuenta en DonaPlus'),
      ),
      body: Column(
        children: [
          const DemoTenantToolbar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: state.registeredUser != null
                      ? _PostRegistrationView(
                          user: state.registeredUser!,
                          state: state,
                          onVerifyAndEnter: () async {
                            final ok = await controller.simulateVerifyEmail();
                            if (ok && context.mounted) {
                              _goRoute('/');
                            }
                          },
                          onContinueUnverified: controller.tryContinueUnverified,
                          onGoToLogin: () => _goRoute('/login'),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _StepProgressHeader(currentStep: state.currentStep),
                            const SizedBox(height: 16),
                            if (state.currentStep == 0)
                              _buildStep1(context, state, controller, theme)
                            else if (state.currentStep == 1)
                              _buildStep2(context, state, controller, theme)
                            else
                              _buildStep3(context, state, controller, theme),
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

  Widget _buildStep1(
    BuildContext context,
    RegisterState state,
    RegisterController controller,
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'PASO 1 · Datos de tu cuenta',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('register_username_field'),
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Nombre de usuario (@unico)',
                hintText: 'Ej. miguel_buap',
                prefixIcon: const Icon(Icons.alternate_email),
                errorText: state.usernameError,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('register_email_field'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Correo electrónico',
                hintText: 'nombre@correo.com',
                prefixIcon: const Icon(Icons.email_outlined),
                errorText: state.emailError,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('register_password_field'),
              controller: _passwordController,
              obscureText: _obscurePassword,
              onChanged: controller.updatePasswordDraft,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline),
                errorText: state.passwordError,
                errorMaxLines: 2,
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Mostrar' : 'Ocultar',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 10),
            PasswordRulesChecklist(password: state.password),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => controller.validateStep1(
                username: _usernameController.text,
                email: _emailController.text,
                password: _passwordController.text,
              ),
              child: const Text('Continuar'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _goRoute('/login'),
              child: const Text('¿Ya tienes cuenta? Iniciar sesión'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2(
    BuildContext context,
    RegisterState state,
    RegisterController controller,
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'PASO 2 · Datos personales y ubicación aproximada',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('register_legal_name_field'),
              controller: _legalNameController,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Nombre legal completo',
                helperText:
                    'Tal como aparece en tu acta de nacimiento. No será editable después.',
                helperMaxLines: 2,
                prefixIcon: const Icon(Icons.person_outline),
                errorText: state.legalNameError,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('register_phone_field'),
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Teléfono celular (10 dígitos)',
                hintText: '2223334455',
                prefixIcon: const Icon(Icons.phone_outlined),
                errorText: state.phoneError,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('register_location_field'),
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Colonia o Código Postal',
                hintText: 'Ej. Col. Universidades, CP 72589',
                helperText:
                    'Solo ubicación aproximada; nunca ingreses tu domicilio exacto (RNF-09).',
                helperMaxLines: 2,
                prefixIcon: const Icon(Icons.location_on_outlined),
                errorText: state.locationError,
              ),
            ),
            const SizedBox(height: 16),
            ProfileAvatarSelector(
              selectedPhoto: state.photoPerfil,
              previewName: _legalNameController.text,
              onChanged: controller.setPhotoPerfil,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: controller.previousStep,
                    child: const Text('Atrás'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => controller.validateStep2(
                      legalName: _legalNameController.text,
                      phone: _phoneController.text,
                      location: _locationController.text,
                    ),
                    child: const Text('Continuar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3(
    BuildContext context,
    RegisterState state,
    RegisterController controller,
    ThemeData theme,
  ) {
    final avatarLabel = state.photoPerfil == null
        ? 'Sin fotografía'
        : sampleProfileAvatars
            .where((a) => a.path == state.photoPerfil)
            .map((a) => a.label)
            .firstOrNull ??
            'Foto seleccionada';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'PASO 3 · Aviso de privacidad y confirmación',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumen de registro',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Usuario: @${state.username}'),
                  Text('Correo: ${state.email}'),
                  Text('Nombre legal: ${state.legalName}'),
                  Text('Teléfono: ${state.phone}'),
                  Text('Ubicación aproximada: ${state.location}'),
                  Text('Foto de perfil: $avatarLabel'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 130,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aviso de Privacidad de DonaPlus',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'DonaPlus protege tus datos personales conforme al principio de minimización (RNF-09). '
                      'Tu ubicación se limita únicamente a colonia o código postal y nunca solicitamos ni mostramos tu domicilio exacto. '
                      'Tu teléfono permanece oculto en las conversaciones salvo que decidas compartirlo explícitamente durante una donación. '
                      'Tu contraseña se transforma mediante resumen criptográfico SHA-256 (RNF-07) y nunca se almacena en texto plano.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: state.privacyAccepted,
              onChanged: state.isSubmitting
                  ? null
                  : (checked) => controller.setPrivacyAccepted(checked ?? false),
              title: const Text('He leído y acepto el aviso de privacidad'),
            ),
            if (state.privacyError != null) ...[
              const SizedBox(height: 6),
              AuthFeedbackBanner(
                message: state.privacyError!,
                tone: AuthBannerTone.error,
              ),
            ],
            if (state.submissionError != null) ...[
              const SizedBox(height: 8),
              AuthFeedbackBanner(
                message: state.submissionError!,
                tone: AuthBannerTone.error,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: state.isSubmitting ? null : controller.previousStep,
                    child: const Text('Atrás'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: state.isSubmitting
                        ? null
                        : () => controller.submitRegistration(),
                    child: state.isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Confirmar registro',
                            textAlign: TextAlign.center,
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepProgressHeader extends StatelessWidget {
  final int currentStep;

  const _StepProgressHeader({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Registro rápido',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(
                'Paso ${currentStep + 1} de 3',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: (currentStep + 1) / 3,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: theme.colorScheme.secondary,
          ),
        ),
      ],
    );
  }
}

class _PostRegistrationView extends StatelessWidget {
  final UsuarioMock user;
  final RegisterState state;
  final VoidCallback onVerifyAndEnter;
  final VoidCallback onContinueUnverified;
  final VoidCallback onGoToLogin;

  const _PostRegistrationView({
    required this.user,
    required this.state,
    required this.onVerifyAndEnter,
    required this.onContinueUnverified,
    required this.onGoToLogin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.mark_email_unread_outlined,
              size: 52,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(height: 12),
            Text(
              '¡Cuenta creada con éxito! Enviamos un enlace de verificación a tu correo.',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: DonaPlusColors.accentYellow.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: Text(
                  user.correoVerificado
                      ? 'Correo verificado'
                      : 'Correo pendiente de verificar (CU-02)',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '@${user.nombreUsuario} · ${user.correo}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (state.unverifiedLoginBlockedMessage != null) ...[
              const SizedBox(height: 14),
              AuthFeedbackBanner(
                message: state.unverifiedLoginBlockedMessage!,
                tone: AuthBannerTone.warning,
              ),
            ],
            if (state.submissionError != null) ...[
              const SizedBox(height: 14),
              AuthFeedbackBanner(
                message: state.submissionError!,
                tone: AuthBannerTone.error,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: state.isSubmitting ? null : onVerifyAndEnter,
              icon: const Icon(Icons.verified_outlined),
              label: const Text(
                'Simular verificación de correo (CU-02) y entrar',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: state.isSubmitting ? null : onContinueUnverified,
              child: const Text(
                'Continuar sin verificar (probar restricción CU-02 2a)',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onGoToLogin,
              child: const Text('Ir a iniciar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}

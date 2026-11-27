import 'package:donaciones/core/auth/password_recovery.dart';
import 'package:donaciones/core/models/domain_exceptions.dart';
import 'package:donaciones/features/auth/presentation/auth_form_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OnlinePasswordRecoveryScreen extends ConsumerStatefulWidget {
  final Uri? callback;

  const OnlinePasswordRecoveryScreen({super.key, this.callback});

  @override
  ConsumerState<OnlinePasswordRecoveryScreen> createState() =>
      _OnlinePasswordRecoveryScreenState();
}

class _OnlinePasswordRecoveryScreenState
    extends ConsumerState<OnlinePasswordRecoveryScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  PasswordRecoverySession? _session;
  String? _error;
  String? _success;
  bool _busy = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    if (widget.callback != null) {
      _busy = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openLink();
      });
    }
  }

  Future<void> _openLink() async {
    final recovery = ref.read(passwordRecoveryProvider);
    try {
      if (recovery == null || !await recovery.hasPendingLink()) {
        if (mounted) context.go('/login');
        return;
      }
      final code = widget.callback!.queryParameters['code'];
      if (code == null || code.isEmpty)
        throw const ExpiredOrUsedTokenException();
      final session = await recovery.openLink(code);
      if (!mounted) {
        session.close();
        return;
      }
      setState(() => _session = session);
    } on ExpiredOrUsedTokenException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Exception {
      if (mounted) {
        setState(
          () => _error = 'No se pudo verificar el enlace. Solicita uno nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    final recovery = ref.read(passwordRecoveryProvider);
    if (recovery == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final session = _session;
      if (session == null) {
        await recovery.sendLink(_email.text);
        if (!mounted) return;
        setState(() {
          _success = 'Si existe una cuenta con ese correo, recibirás un enlace. Ábrelo en este mismo teléfono.';
        });
      } else {
        if (_password.text != _confirmation.text) {
          throw const ValidationException('Las contraseñas no coinciden.');
        }
        await session.updatePassword(_password.text);
        if (!mounted) return;
        _password.clear();
        _confirmation.clear();
        setState(() {
          _completed = true;
          _success = 'Contraseña actualizada. Ya puedes iniciar sesión.';
        });
      }
    } on ValidationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on NetworkException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on ExpiredOrUsedTokenException catch (error) {
      if (!mounted) return;
      _session?.close();
      setState(() {
        _session = null;
        _error = error.message;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    _session?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enteringPassword = _session != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          enteringPassword ? 'Cambiar contraseña' : 'Recuperar contraseña',
        ),
        leading: IconButton(
          tooltip: 'Volver a iniciar sesión',
          onPressed: _busy ? null : () => context.go('/login'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: AutofillGroup(
              child: ListView(
                padding: const EdgeInsets.all(20),
                shrinkWrap: true,
                children: [
                  if (_busy) const LinearProgressIndicator(),
                  if (!_completed && enteringPassword) ...[
                    TextField(
                      controller: _password,
                      enabled: !_busy,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        labelText: 'Nueva contraseña',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmation,
                      enabled: !_busy,
                      obscureText: true,
                      onSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Confirmar contraseña',
                      ),
                    ),
                  ] else if (!_completed)
                    TextField(
                      controller: _email,
                      enabled: !_busy,
                      autofillHints: const [AutofillHints.email],
                      keyboardType: TextInputType.emailAddress,
                      onSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Correo registrado',
                      ),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    AuthFeedbackBanner(
                      message: _error!,
                      tone: AuthBannerTone.error,
                    ),
                  ],
                  if (_success != null) ...[
                    const SizedBox(height: 12),
                    AuthFeedbackBanner(
                      message: _success!,
                      tone: AuthBannerTone.success,
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : _completed
                        ? () => context.go('/login')
                        : _submit,
                    child: Text(
                      _completed
                          ? 'Iniciar sesión'
                          : enteringPassword
                          ? 'Guardar contraseña'
                          : 'Enviar enlace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_exceptions.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/features/auth/presentation/auth_form_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the profile editing bottom sheet (CU-06).
Future<void> showEditProfileSheet(
  BuildContext context,
  UsuarioMock usuario,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => EditProfileSheet(usuario: usuario),
  );
}

/// Modal bottom sheet allowing edits to photo, phone, and password (CU-06).
class EditProfileSheet extends ConsumerStatefulWidget {
  final UsuarioMock usuario;

  const EditProfileSheet({super.key, required this.usuario});

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  late final TextEditingController _phoneController;
  final _passwordController = TextEditingController();
  late String? _selectedPhoto;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _phoneError;
  String? _passwordError;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.usuario.telefono);
    _selectedPhoto = widget.usuario.fotoPerfil;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_isSubmitting) return;

    final phoneError = validatePhoneError(_phoneController.text);
    final newPassword = _passwordController.text;
    final passwordError =
        newPassword.isEmpty ? null : validatePasswordError(newPassword);

    if (phoneError != null || passwordError != null) {
      setState(() {
        _phoneError = phoneError;
        _passwordError = passwordError;
        _submitError = null;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _phoneError = null;
      _passwordError = null;
      _submitError = null;
    });

    final store = ref.read(mockTenantStoreProvider);
    try {
      await store.updateProfile(
        fotoPerfil: _selectedPhoto ?? '',
        telefono: _phoneController.text,
        newPassword: newPassword.isEmpty ? null : newPassword,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Perfil actualizado correctamente.')),
      );
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitError = e.message;
      });
    } on ValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitError = e.message;
      });
    } on UnauthorizedActionException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitError = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Editar perfil',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tu nombre de usuario y nombre legal no son editables.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('edit_profile_username_field'),
                initialValue: '@${widget.usuario.nombreUsuario}',
                readOnly: true,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Nombre de usuario (solo lectura)',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('edit_profile_legal_name_field'),
                initialValue: widget.usuario.nombreLegal,
                readOnly: true,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Nombre legal completo (solo lectura)',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 14),
              ProfileAvatarSelector(
                selectedPhoto: _selectedPhoto,
                showSamples: !ref.watch(mockTenantStoreProvider).isOnline,
                previewName: widget.usuario.nombreLegal,
                onChanged: (value) => setState(() => _selectedPhoto = value),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('edit_profile_phone_field'),
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Teléfono celular (10 dígitos)',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  errorText: _phoneError,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('edit_profile_password_field'),
                controller: _passwordController,
                obscureText: _obscurePassword,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Nueva contraseña (opcional)',
                  helperText:
                      'Déjalo vacío si deseas conservar tu contraseña actual.',
                  helperMaxLines: 2,
                  prefixIcon: const Icon(Icons.lock_outline),
                  errorText: _passwordError,
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
              if (_passwordController.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                PasswordRulesChecklist(password: _passwordController.text),
              ],
              if (_submitError != null) ...[
                const SizedBox(height: 12),
                AuthFeedbackBanner(
                  message: _submitError!,
                  tone: AuthBannerTone.error,
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _saveChanges,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Guardar cambios'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:donaciones/app/theme.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/features/publications/presentation/publication_ui_helpers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

/// Password rule compliance breakdown for RF-01.
class PasswordRuleStatus {
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasDigit;

  const PasswordRuleStatus({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigit,
  });

  factory PasswordRuleStatus.fromPassword(String password) {
    return PasswordRuleStatus(
      hasMinLength: password.length >= 8,
      hasUppercase: RegExp(r'[A-Z]').hasMatch(password),
      hasLowercase: RegExp(r'[a-z]').hasMatch(password),
      hasDigit: RegExp(r'[0-9]').hasMatch(password),
    );
  }

  bool get isValid => hasMinLength && hasUppercase && hasLowercase && hasDigit;
}

/// Validates email format according to RF-01.
String? validateEmailError(String email) {
  final clean = email.trim();
  if (clean.isEmpty || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(clean)) {
    return 'Ingresa un correo electrónico válido.';
  }
  return null;
}

/// Validates 10-digit numeric phone format according to RF-01.
String? validatePhoneError(String phone) {
  final clean = phone.trim();
  if (!RegExp(r'^\d{10}$').hasMatch(clean)) {
    return 'El teléfono debe tener exactamente 10 dígitos numéricos.';
  }
  return null;
}

/// Validates RF-01 password rules and lists the specific unmet rules.
String? validatePasswordError(String password) {
  final status = PasswordRuleStatus.fromPassword(password);
  if (status.isValid) return null;

  final missing = <String>[
    if (!status.hasMinLength) 'al menos 8 caracteres',
    if (!status.hasUppercase) '1 mayúscula',
    if (!status.hasLowercase) '1 minúscula',
    if (!status.hasDigit) '1 número',
  ];
  return 'La contraseña requiere ${missing.join(', ')}.';
}

/// Visual checklist showing real-time compliance with RF-01 password rules.
class PasswordRulesChecklist extends StatelessWidget {
  final String password;

  const PasswordRulesChecklist({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final status = PasswordRuleStatus.fromPassword(password);
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: [
        _RulePill(label: '≥ 8 caracteres', met: status.hasMinLength),
        _RulePill(label: '1 mayúscula', met: status.hasUppercase),
        _RulePill(label: '1 minúscula', met: status.hasLowercase),
        _RulePill(label: '1 número', met: status.hasDigit),
      ],
    );
  }
}

class _RulePill extends StatelessWidget {
  final String label;
  final bool met;

  const _RulePill({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highContrast = theme.colorScheme.outline == Colors.black;
    final bgColor = met
        ? (highContrast
              ? DonaPlusColors.accentYellow
              : DonaPlusColors.accentMint.withValues(alpha: 0.45))
        : theme.colorScheme.surfaceContainerHighest;
    final fgColor = met
        ? (highContrast ? Colors.black : DonaPlusColors.primary)
        : theme.colorScheme.onSurface.withValues(alpha: 0.78);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: met
              ? (highContrast ? Colors.black : DonaPlusColors.secondary)
              : theme.colorScheme.outline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 15,
            color: fgColor,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: fgColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Predefined sample avatar options for optional profile photos in mock mode.
class SampleAvatarOption {
  final String label;
  final String path;
  final IconData icon;

  const SampleAvatarOption({
    required this.label,
    required this.path,
    required this.icon,
  });
}

const List<SampleAvatarOption> sampleProfileAvatars = [
  SampleAvatarOption(
    label: 'Avatar Comunidad',
    path: 'sample://avatar_comunidad.png',
    icon: Icons.diversity_3,
  ),
  SampleAvatarOption(
    label: 'Avatar Solidaridad',
    path: 'sample://avatar_solidaridad.png',
    icon: Icons.volunteer_activism,
  ),
  SampleAvatarOption(
    label: 'Avatar Voluntario',
    path: 'sample://avatar_voluntario.png',
    icon: Icons.favorite,
  ),
];

/// Circular avatar rendering either user initials or a selected mock avatar.
class ProfileAvatarCircle extends StatelessWidget {
  final String nombreLegal;
  final String? fotoPerfil;
  final double radius;

  const ProfileAvatarCircle({
    super.key,
    required this.nombreLegal,
    required this.fotoPerfil,
    this.radius = 28,
  });

  SampleAvatarOption? _findAvatarOption() {
    if (fotoPerfil == null || fotoPerfil!.isEmpty) return null;
    for (final option in sampleProfileAvatars) {
      if (option.path == fotoPerfil) return option;
    }
    return null;
  }

  String _initials() {
    final parts = nombreLegal
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'DP';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  File? _tryResolveLocalFile() {
    if (kIsWeb || fotoPerfil == null || !fotoPerfil!.startsWith('file://')) {
      return null;
    }
    try {
      return File.fromUri(Uri.parse(fotoPerfil!));
    } on Object {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final option = _findAvatarOption();
    final hasCustomPhoto = fotoPerfil != null && fotoPerfil!.isNotEmpty;
    final localFile = _tryResolveLocalFile();

    final isOnlinePhoto = fotoPerfil?.startsWith('donaplus-photo:') ?? false;
    return CircleAvatar(
      radius: radius,
      backgroundColor: hasCustomPhoto
          ? DonaPlusColors.accentMint.withValues(alpha: 0.7)
          : theme.colorScheme.primary,
      foregroundColor: hasCustomPhoto
          ? DonaPlusColors.primary
          : theme.colorScheme.onPrimary,
      child: isOnlinePhoto
          ? Consumer(
              builder: (context, ref, child) {
                final store = ref.watch(mockTenantStoreProvider);
                final photo = fotoPerfil!;
                final headers = store is OnlineTenantStore
                    ? store.photoHeaders(photo)
                    : null;
                if (store is! OnlineTenantStore || headers == null) {
                  return Icon(Icons.account_circle, size: radius * 1.1);
                }
                return ClipOval(
                  child: Image.network(
                    store.photoUrl(photo),
                    headers: headers,
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    semanticLabel: 'Fotografía de perfil',
                    errorBuilder: (_, _, _) =>
                        Icon(Icons.account_circle, size: radius * 1.1),
                  ),
                );
              },
            )
          : localFile != null
          ? ClipOval(
              child: Image.file(
                localFile,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                semanticLabel: 'Fotografía de perfil',
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.account_circle,
                  size: radius * 1.1,
                ),
              ),
            )
          : option != null
          ? Icon(option.icon, size: radius * 1.05)
          : hasCustomPhoto
          ? Icon(Icons.account_circle, size: radius * 1.1)
          : Text(
              _initials(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onPrimary,
              ),
            ),
    );
  }
}

/// Optional profile photo chip selector used in registration and profile edit.
class ProfileAvatarSelector extends StatefulWidget {
  final String? selectedPhoto;
  final String previewName;
  final ValueChanged<String?> onChanged;
  final bool showSamples;

  const ProfileAvatarSelector({
    super.key,
    required this.selectedPhoto,
    required this.previewName,
    required this.onChanged,
    this.showSamples = true,
  });

  @override
  State<ProfileAvatarSelector> createState() => _ProfileAvatarSelectorState();
}

class _ProfileAvatarSelectorState extends State<ProfileAvatarSelector> {
  bool _pickingPhoto = false;

  Future<void> _pickDeviceAvatar() async {
    if (!usesAndroidDeviceAccess) {
      widget.onChanged('device://avatar_galeria.jpg');
      return;
    }
    if (_pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Tomar foto con la cámara'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Seleccionar desde galería del dispositivo'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null || !mounted) return;
      final picker = ImagePickerAndroid()..useAndroidPhotoPicker = true;
      final photo = await picker.getImageFromSource(
        source: source,
        options: const ImagePickerOptions(
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
          requestFullMetadata: false,
        ),
      );
      if (photo != null && mounted) {
        widget.onChanged(File(photo.path).uri.toString());
      }
    } on PlatformException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'camera_access_denied' =>
          'Permite el acceso a la cámara en los ajustes de Android o elige una foto de la galería.',
        'no_available_camera' => 'No hay una cámara disponible.',
        _ => 'No se pudo agregar la foto de perfil. Inténtalo de nuevo.',
      };
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedPhoto = widget.selectedPhoto;
    final hasPhoto = selectedPhoto != null && selectedPhoto.isNotEmpty;
    final isDevicePhoto =
        hasPhoto &&
        (selectedPhoto.startsWith('device://') ||
            selectedPhoto.startsWith('file://'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ProfileAvatarCircle(
              nombreLegal: widget.previewName.isEmpty
                  ? 'Komuna'
                  : widget.previewName,
              fotoPerfil: selectedPhoto,
              radius: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Fotografía de perfil (opcional)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Sin foto'),
              selected: !hasPhoto,
              onSelected: (_) => widget.onChanged(null),
            ),
            if (widget.showSamples)
              for (final option in sampleProfileAvatars)
                ChoiceChip(
                  avatar: Icon(option.icon, size: 16),
                  label: Text(option.label),
                  selected: selectedPhoto == option.path,
                  onSelected: (_) => widget.onChanged(option.path),
                ),
            ChoiceChip(
              key: const Key('profile_avatar_device_photo_chip'),
              avatar: const Icon(Icons.add_a_photo_outlined, size: 16),
              label: const Text('Cámara o galería'),
              selected: isDevicePhoto,
              onSelected: _pickingPhoto ||
                      (!widget.showSamples && !usesAndroidDeviceAccess)
                  ? null
                  : (_) => _pickDeviceAvatar(),
            ),
          ],
        ),
      ],
    );
  }
}

/// Semantic banner types for auth/profile status feedback.
enum AuthBannerTone { error, warning, success, info }

/// Reusable banner displaying errors, warnings, or confirmations cleanly.
class AuthFeedbackBanner extends StatelessWidget {
  final String message;
  final AuthBannerTone tone;

  const AuthFeedbackBanner({
    super.key,
    required this.message,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highContrast = theme.colorScheme.outline == Colors.black;

    final (Color bg, Color border, Color fg, IconData icon) = switch (tone) {
      AuthBannerTone.error => (
        theme.colorScheme.errorContainer,
        theme.colorScheme.error,
        theme.colorScheme.onErrorContainer,
        Icons.error_outline,
      ),
      AuthBannerTone.warning => (
        DonaPlusColors.accentYellow.withValues(alpha: highContrast ? 1.0 : 0.45),
        highContrast ? Colors.black : const Color(0xFF9C7A00),
        Colors.black,
        Icons.warning_amber_rounded,
      ),
      AuthBannerTone.success => (
        DonaPlusColors.accentMint.withValues(alpha: highContrast ? 0.9 : 0.4),
        highContrast ? Colors.black : DonaPlusColors.secondary,
        DonaPlusColors.primary,
        Icons.check_circle_outline,
      ),
      AuthBannerTone.info => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.primary,
        theme.colorScheme.onSurface,
        Icons.info_outline,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: highContrast ? 1.5 : 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';

import 'package:donaciones/app/theme.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

bool get usesAndroidDeviceAccess => !kIsWeb && Platform.isAndroid;

/// Maps a [CategoriaMock.iconoClave] string to a Material icon.
IconData iconForCategoryKey(String iconKey) {
  return switch (iconKey) {
    'health' => Icons.health_and_safety_outlined,
    'school' => Icons.school_outlined,
    'restaurant' => Icons.restaurant_outlined,
    'checkroom' => Icons.checkroom_outlined,
    'chair' => Icons.chair_outlined,
    'devices' => Icons.devices_outlined,
    _ => Icons.category_outlined,
  };
}

/// Human-readable label for a [Urgencia] value.
String labelForUrgencia(Urgencia urgencia) {
  return switch (urgencia) {
    Urgencia.alta => 'Urgencia Alta',
    Urgencia.media => 'Urgencia Media',
    Urgencia.baja => 'Urgencia Baja',
  };
}

/// Short label for urgency selector controls.
String shortLabelForUrgencia(Urgencia urgencia) {
  return switch (urgencia) {
    Urgencia.alta => 'Alta',
    Urgencia.media => 'Media',
    Urgencia.baja => 'Baja',
  };
}

/// Human-readable label for a [CondicionArticulo] value.
String labelForCondicion(CondicionArticulo condicion) {
  return switch (condicion) {
    CondicionArticulo.nuevo => 'Nuevo',
    CondicionArticulo.comoNuevo => 'Como nuevo',
    CondicionArticulo.usado => 'Usado',
  };
}

/// Human-readable label for a [EstadoPublicacion] value.
String labelForEstadoPublicacion(EstadoPublicacion estado) {
  return switch (estado) {
    EstadoPublicacion.activa => 'Activa',
    EstadoPublicacion.reservada => 'Reservada',
    EstadoPublicacion.cerrada => 'Cerrada',
    EstadoPublicacion.retirada => 'Retirada',
  };
}

/// Readable display name derived from a mock photo identifier or path.
String labelForMockPhoto(String path) {
  final lastSegment = path.split('/').last;
  final withoutExt = lastSegment.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
  final spaced = withoutExt.replaceAll('_', ' ').trim();
  if (spaced.isEmpty) return 'Foto del artículo';
  return spaced[0].toUpperCase() + spaced.substring(1);
}

/// Returns a distinct, accessible accent background tint for category cards.
Color categoryTintForKey(String iconKey, {required bool highContrast}) {
  if (highContrast) return DonaPlusColors.accentYellow;
  return switch (iconKey) {
    'health' => DonaPlusColors.secondary.withValues(alpha: 0.14),
    'school' => DonaPlusColors.accentMint.withValues(alpha: 0.55),
    'restaurant' => DonaPlusColors.accentYellow.withValues(alpha: 0.55),
    'checkroom' => DonaPlusColors.primary.withValues(alpha: 0.12),
    'chair' => DonaPlusColors.accentMint.withValues(alpha: 0.38),
    _ => DonaPlusColors.surfaceLight,
  };
}

/// Semantic tone for inline publication feedback banners.
enum PublicationBannerTone { error, warning, success, info }

/// Reusable status banner matching DonaPlus theme and high-contrast settings.
class PublicationStatusBanner extends StatelessWidget {
  final String message;
  final PublicationBannerTone tone;
  final Widget? trailing;

  const PublicationStatusBanner({
    super.key,
    required this.message,
    required this.tone,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highContrast = theme.colorScheme.outline == Colors.black;

    final (Color bg, Color border, Color fg, IconData icon) = switch (tone) {
      PublicationBannerTone.error => (
        theme.colorScheme.errorContainer,
        theme.colorScheme.error,
        theme.colorScheme.onErrorContainer,
        Icons.error_outline,
      ),
      PublicationBannerTone.warning => (
        DonaPlusColors.accentYellow.withValues(alpha: highContrast ? 1.0 : 0.45),
        highContrast ? Colors.black : const Color(0xFF9C7A00),
        Colors.black,
        Icons.warning_amber_rounded,
      ),
      PublicationBannerTone.success => (
        DonaPlusColors.accentMint.withValues(alpha: highContrast ? 0.9 : 0.42),
        highContrast ? Colors.black : DonaPlusColors.secondary,
        highContrast ? Colors.black : DonaPlusColors.primary,
        Icons.check_circle_outline,
      ),
      PublicationBannerTone.info => (
        theme.colorScheme.surfaceContainerHighest,
        highContrast ? Colors.black : theme.colorScheme.primary,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(height: 6),
                  trailing!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Visual badge showing Need urgency level with color and text (CU-12).
class UrgencyBadge extends StatelessWidget {
  final Urgencia urgencia;

  const UrgencyBadge({super.key, required this.urgencia});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highContrast = theme.colorScheme.outline == Colors.black;

    final (Color bg, Color border, Color fg, IconData icon) = switch (urgencia) {
      Urgencia.alta => (
        highContrast ? DonaPlusColors.accentYellow : const Color(0xFFFDEAEA),
        highContrast ? Colors.black : const Color(0xFFC62828),
        highContrast ? Colors.black : const Color(0xFF9F1B1B),
        Icons.priority_high_rounded,
      ),
      Urgencia.media => (
        highContrast ? Colors.white : const Color(0xFFFFF4DC),
        highContrast ? Colors.black : const Color(0xFFB26A00),
        highContrast ? Colors.black : const Color(0xFF8C5200),
        Icons.schedule,
      ),
      Urgencia.baja => (
        highContrast
            ? DonaPlusColors.accentMint
            : DonaPlusColors.accentMint.withValues(alpha: 0.65),
        highContrast ? Colors.black : DonaPlusColors.primary,
        highContrast ? Colors.black : DonaPlusColors.primary,
        Icons.check_circle_outline,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: highContrast ? 1.5 : 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              labelForUrgencia(urgencia),
              style: theme.textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge indicating an intermediary-managed publication and beneficiary alias (CU-46).
class IntermediaryBadge extends StatelessWidget {
  final String? aliasBeneficiario;

  const IntermediaryBadge({super.key, this.aliasBeneficiario});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highContrast = theme.colorScheme.outline == Colors.black;
    final cleanAlias = aliasBeneficiario?.trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highContrast
            ? DonaPlusColors.accentYellow
            : DonaPlusColors.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highContrast ? Colors.black : DonaPlusColors.secondary,
          width: highContrast ? 1.5 : 1.0,
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 16,
            color: highContrast ? Colors.black : DonaPlusColors.primary,
          ),
          Text(
            'Gestionada por intermediario',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: highContrast ? Colors.black : DonaPlusColors.primary,
            ),
          ),
          if (cleanAlias != null && cleanAlias.isNotEmpty)
            Text(
              '· Beneficiario: $cleanAlias',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: highContrast ? Colors.black : theme.colorScheme.onSurface,
              ),
            ),
        ],
      ),
    );
  }
}

/// Shows local item photographs and placeholders for the sample catalog.
class PublicationPhotoPlaceholder extends StatelessWidget {
  final String photoPath;
  final double width;
  final double height;
  final bool isPrimary;
  final VoidCallback? onRemove;

  const PublicationPhotoPlaceholder({
    super.key,
    required this.photoPath,
    this.width = 120,
    this.height = 104,
    this.isPrimary = false,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highContrast = theme.colorScheme.outline == Colors.black;
    final isDevice = photoPath.startsWith('device://');
    final isLocalFile = !kIsWeb && photoPath.startsWith('file://');

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: highContrast
            ? Colors.white
            : DonaPlusColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highContrast ? Colors.black : DonaPlusColors.secondary,
          width: highContrast ? 1.5 : 1.0,
        ),
      ),
      child: Stack(
        children: [
          if (isLocalFile)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                  File.fromUri(Uri.parse(photoPath)),
                  fit: BoxFit.cover,
                  semanticLabel: 'Fotografía del artículo',
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      semanticLabel: 'Fotografía no disponible',
                    ),
                  ),
                ),
              ),
            )
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDevice
                        ? Icons.photo_library_outlined
                        : Icons.image_outlined,
                    size: 28,
                    color: highContrast ? Colors.black : DonaPlusColors.primary,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labelForMockPhoto(photoPath),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: highContrast
                          ? Colors.black
                          : DonaPlusColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          if (isPrimary)
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: highContrast
                      ? DonaPlusColors.accentYellow
                      : DonaPlusColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Principal',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: highContrast ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          if (onRemove != null)
            Positioned(
              right: -6,
              top: -6,
              child: IconButton(
                tooltip: 'Eliminar foto',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: Icon(
                  Icons.cancel,
                  size: 20,
                  color: theme.colorScheme.error,
                ),
                onPressed: onRemove,
              ),
            ),
        ],
      ),
    );
  }
}

/// Shared active category dropdown (CU-13).
class ActiveCategoryDropdown extends StatelessWidget {
  final Key? fieldKey;
  final List<CategoriaMock> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onChanged;
  final String? errorText;

  const ActiveCategoryDropdown({
    super.key,
    this.fieldKey,
    required this.categories,
    required this.selectedCategoryId,
    required this.onChanged,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final validValue = categories.any((c) => c.id == selectedCategoryId)
        ? selectedCategoryId
        : null;

    return DropdownButtonFormField<String>(
      key: fieldKey,
      initialValue: validValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Categoría (CU-13) *',
        hintText: 'Selecciona una categoría activa',
        prefixIcon: const Icon(Icons.category_outlined),
        errorText: errorText,
      ),
      items: [
        for (final category in categories)
          DropdownMenuItem<String>(
            value: category.id,
            child: Row(
              children: [
                Icon(iconForCategoryKey(category.iconoClave), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    category.nombre,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

/// Shared acceptable condition dropdown for Needs.
class NeedConditionDropdown extends StatelessWidget {
  final Key? fieldKey;
  final CondicionArticulo? value;
  final ValueChanged<CondicionArticulo?> onChanged;

  const NeedConditionDropdown({
    super.key,
    this.fieldKey,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<CondicionArticulo?>(
      key: fieldKey,
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Condición aceptable',
        prefixIcon: Icon(Icons.verified_outlined),
      ),
      items: [
        const DropdownMenuItem<CondicionArticulo?>(
          value: null,
          child: Text('Cualquiera'),
        ),
        for (final cond in CondicionArticulo.values)
          DropdownMenuItem<CondicionArticulo?>(
            value: cond,
            child: Text(labelForCondicion(cond)),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

/// Shared urgency selector chips for Need creation and editing (CU-12).
class NeedUrgencySelector extends StatelessWidget {
  final Urgencia? selectedUrgency;
  final ValueChanged<Urgencia> onSelected;
  final String? errorText;
  final Key? altaKey;
  final Key? mediaKey;
  final Key? bajaKey;

  const NeedUrgencySelector({
    super.key,
    required this.selectedUrgency,
    required this.onSelected,
    this.errorText,
    this.altaKey,
    this.mediaKey,
    this.bajaKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highContrast = theme.colorScheme.outline == Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nivel de urgencia (CU-12) *',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final urgency in Urgencia.values)
              ChoiceChip(
                key: switch (urgency) {
                  Urgencia.alta => altaKey,
                  Urgencia.media => mediaKey,
                  Urgencia.baja => bajaKey,
                },
                selected: selectedUrgency == urgency,
                selectedColor: switch (urgency) {
                  Urgencia.alta => highContrast
                      ? DonaPlusColors.accentYellow
                      : const Color(0xFFFDEAEA),
                  Urgencia.media => highContrast
                      ? DonaPlusColors.accentYellow
                      : const Color(0xFFFFF4DC),
                  Urgencia.baja => DonaPlusColors.accentMint,
                },
                label: Text(shortLabelForUrgencia(urgency)),
                avatar: Icon(
                  switch (urgency) {
                    Urgencia.alta => Icons.priority_high_rounded,
                    Urgencia.media => Icons.schedule,
                    Urgencia.baja => Icons.check_circle_outline,
                  },
                  size: 16,
                  color: switch (urgency) {
                    Urgencia.alta => highContrast
                        ? Colors.black
                        : const Color(0xFFC62828),
                    Urgencia.media => highContrast
                        ? Colors.black
                        : const Color(0xFF9C5E00),
                    Urgencia.baja => DonaPlusColors.primary,
                  },
                ),
                onSelected: (_) => onSelected(urgency),
              ),
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// Shared physical condition selector for Items (CU-14).
class ItemConditionSelector extends StatelessWidget {
  final CondicionArticulo? selectedCondition;
  final ValueChanged<CondicionArticulo> onSelected;
  final String? errorText;
  final Key? nuevoKey;
  final Key? comoNuevoKey;
  final Key? usadoKey;

  const ItemConditionSelector({
    super.key,
    required this.selectedCondition,
    required this.onSelected,
    this.errorText,
    this.nuevoKey,
    this.comoNuevoKey,
    this.usadoKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estado del artículo *',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final cond in CondicionArticulo.values)
              ChoiceChip(
                key: switch (cond) {
                  CondicionArticulo.nuevo => nuevoKey,
                  CondicionArticulo.comoNuevo => comoNuevoKey,
                  CondicionArticulo.usado => usadoKey,
                },
                label: Text(labelForCondicion(cond)),
                selected: selectedCondition == cond,
                onSelected: (_) => onSelected(cond),
              ),
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// Shared 1-to-5 photographs field with sample & gallery picker (CU-14, CU-16).
class PublicationPhotosField extends StatefulWidget {
  final List<String> photos;
  final List<String> samplePhotos;
  final VoidCallback onAddQuickPhoto;
  final ValueChanged<String> onAddSpecificPhoto;
  final ValueChanged<int> onRemoveAt;
  final String? errorText;
  final Key? addButtonKey;
  final Key? sourceButtonKey;
  final bool enabled;

  const PublicationPhotosField({
    super.key,
    required this.photos,
    required this.samplePhotos,
    required this.onAddQuickPhoto,
    required this.onAddSpecificPhoto,
    required this.onRemoveAt,
    this.errorText,
    this.addButtonKey,
    this.sourceButtonKey,
    this.enabled = true,
  });

  @override
  State<PublicationPhotosField> createState() => _PublicationPhotosFieldState();
}

class _PublicationPhotosFieldState extends State<PublicationPhotosField> {
  bool _pickingPhoto = false;

  Future<void> _pickAndroidPhoto() async {
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
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 85,
          requestFullMetadata: false,
        ),
      );
      if (photo != null &&
          mounted &&
          widget.enabled &&
          widget.photos.length < 5) {
        widget.onAddSpecificPhoto(File(photo.path).uri.toString());
      }
    } on PlatformException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'camera_access_denied' => 'Permite el acceso a la cámara en los ajustes de Android o elige una foto de la galería.',
        'no_available_camera' => 'No hay una cámara disponible.',
        _ => 'No se pudo agregar la foto. Inténtalo de nuevo.',
      };
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _showPhotoSourcePicker(BuildContext context) {
    final theme = Theme.of(context);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Agregar fotografía (${widget.photos.length}/5)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Elegir foto de muestra del tenant',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (final sample in widget.samplePhotos)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.image_outlined),
                    title: Text(labelForMockPhoto(sample)),
                    subtitle: Text(sample),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      widget.onAddSpecificPhoto(sample);
                    },
                  ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text(
                    'Seleccionar desde galería del dispositivo',
                  ),
                  subtitle: const Text('Simula la selección de una foto local'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    widget.onAddSpecificPhoto(
                      'device://galeria_${widget.photos.length + 1}.jpg',
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photos = widget.photos;
    final errorText = widget.errorText;
    final atLimit = photos.length >= 5;
    final enabled = widget.enabled && !_pickingPhoto;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Fotografías del artículo (1 a 5) *',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text('${photos.length}/5'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (photos.isNotEmpty) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < photos.length; i++)
                PublicationPhotoPlaceholder(
                  photoPath: photos[i],
                  isPrimary: i == 0,
                  onRemove: enabled ? () => widget.onRemoveAt(i) : null,
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: widget.addButtonKey,
              onPressed: (!enabled || atLimit)
                  ? null
                  : usesAndroidDeviceAccess
                  ? _pickAndroidPhoto
                  : widget.onAddQuickPhoto,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Agregar foto'),
            ),
            if (!usesAndroidDeviceAccess)
              TextButton.icon(
                key: widget.sourceButtonKey,
                onPressed: (!enabled || atLimit)
                    ? null
                    : () => _showPhotoSourcePicker(context),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Elegir muestra o galería'),
              ),
          ],
        ),
        if (atLimit) ...[
          const SizedBox(height: 6),
          Text(
            'Límite máximo de 5 fotografías alcanzado (5/5).',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// Shared intermediary beneficiary switch & alias field (CU-46, CU-47).
class IntermediaryBeneficiaryFields extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final TextEditingController aliasController;
  final ValueChanged<String> onAliasChanged;
  final String? aliasError;
  final Key? switchKey;
  final Key? aliasKey;

  const IntermediaryBeneficiaryFields({
    super.key,
    required this.enabled,
    required this.onToggle,
    required this.aliasController,
    required this.onAliasChanged,
    this.aliasError,
    this.switchKey,
    this.aliasKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              key: switchKey,
              contentPadding: EdgeInsets.zero,
              title: const Text('Publicar en nombre de un beneficiario'),
              subtitle: const Text(
                'Disponible para intermediarios comunitarios autorizados (CU-46).',
              ),
              value: enabled,
              onChanged: onToggle,
            ),
            if (enabled) ...[
              const SizedBox(height: 8),
              TextFormField(
                key: aliasKey,
                controller: aliasController,
                onChanged: onAliasChanged,
                decoration: InputDecoration(
                  labelText: 'Alias del beneficiario *',
                  hintText: 'Ej. Familia López / Adulto mayor centro',
                  prefixIcon: const Icon(Icons.person_pin_outlined),
                  errorText: aliasError,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Solo alias, sin datos personales que identifiquen públicamente al beneficiario (RNF-09)',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

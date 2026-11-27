import 'dart:io';

import 'package:donaciones/app/theme.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_exceptions.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/features/publications/presentation/publication_ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

/// Opens the modal bottom sheet to request the community intermediary role (CU-40, CU-41).
Future<void> showRequestIntermediarySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const RequestIntermediarySheet(),
  );
}

class _SimulatedDocumentOption {
  final Key chipKey;
  final String name;
  final int bytes;
  final String sizeLabel;
  final bool isValidationTestOption;
  final Uint8List? data;

  const _SimulatedDocumentOption({
    required this.chipKey,
    required this.name,
    required this.bytes,
    required this.sizeLabel,
    this.isValidationTestOption = false,
    this.data,
  });
}

const List<_SimulatedDocumentOption> _simulatedDocuments = [
  _SimulatedDocumentOption(
    chipKey: Key('intermediary_doc_pdf'),
    name: 'constancia_comunitaria.pdf',
    bytes: 1258291,
    sizeLabel: '1.2 MB',
  ),
  _SimulatedDocumentOption(
    chipKey: Key('intermediary_doc_jpg'),
    name: 'credencial_asociacion.jpg',
    bytes: 870400,
    sizeLabel: '850 KB',
  ),
  _SimulatedDocumentOption(
    chipKey: Key('intermediary_doc_png'),
    name: 'acta_fundacion.png',
    bytes: 2202009,
    sizeLabel: '2.1 MB',
  ),
  _SimulatedDocumentOption(
    chipKey: Key('intermediary_doc_oversized'),
    name: 'archivo_pesado_6mb.pdf',
    bytes: 6291456,
    sizeLabel: '6.0 MB',
    isValidationTestOption: true,
  ),
  _SimulatedDocumentOption(
    chipKey: Key('intermediary_doc_invalid_ext'),
    name: 'documento_invalido.exe',
    bytes: 122880,
    sizeLabel: '120 KB',
    isValidationTestOption: true,
  ),
];

/// Modal bottom sheet capturing organization and backup document for intermediary role requests (CU-40, CU-41).
class RequestIntermediarySheet extends ConsumerStatefulWidget {
  const RequestIntermediarySheet({super.key});

  @override
  ConsumerState<RequestIntermediarySheet> createState() =>
      _RequestIntermediarySheetState();
}

class _RequestIntermediarySheetState
    extends ConsumerState<RequestIntermediarySheet> {
  static const int _maxDocumentBytes = 5 * 1024 * 1024;
  static const List<String> _allowedExtensions = [
    '.pdf',
    '.jpg',
    '.jpeg',
    '.png',
  ];

  final _organizationController = TextEditingController();
  _SimulatedDocumentOption? _selectedDoc;
  String? _orgError;
  String? _docError;
  String? _submitError;
  bool _isSubmitting = false;
  bool _pickingDeviceDoc = false;
  SolicitudRolIntermediarioMock? _submittedRequest;

  String _formatSizeBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    final kb = (bytes / 1024).round();
    return '${kb < 1 ? 1 : kb} KB';
  }

  static const _documentChannel = MethodChannel('komuna/intermediary_document');

  Future<void> _pickDeviceDocument() async {
    if (!usesAndroidDeviceAccess) {
      _selectDocument(
        const _SimulatedDocumentOption(
          chipKey: Key('intermediary_doc_device_photo'),
          name: 'constancia_camara_dispositivo.jpg',
          bytes: 942080,
          sizeLabel: '920 KB',
        ),
      );
      return;
    }
    if (_pickingDeviceDoc) return;
    setState(() => _pickingDeviceDoc = true);
    try {
      final online = ref.read(mockTenantStoreProvider).isOnline;
      final source = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Tomar foto del documento con la cámara'),
                onTap: () => Navigator.of(sheetContext).pop('camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Seleccionar imagen desde galería'),
                onTap: () => Navigator.of(sheetContext).pop('gallery'),
              ),
              if (online)
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: const Text('Elegir un archivo PDF'),
                  onTap: () => Navigator.of(sheetContext).pop('pdf'),
                ),
            ],
          ),
        ),
      );
      if (source == null || !mounted) return;
      if (source == 'pdf') {
        final document = await _documentChannel
            .invokeMapMethod<String, Object?>('pickPdf');
        if (document == null || !mounted) return;
        final data = document['data'] as Uint8List;
        _selectDocument(
          _SimulatedDocumentOption(
            chipKey: const Key('intermediary_doc_device_photo'),
            name: document['name'] as String,
            bytes: data.length,
            sizeLabel: _formatSizeBytes(data.length),
            data: data,
          ),
        );
        return;
      }
      final picker = ImagePickerAndroid()..useAndroidPhotoPicker = true;
      final photo = await picker.getImageFromSource(
        source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
        options: const ImagePickerOptions(
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 85,
          requestFullMetadata: false,
        ),
      );
      if (photo == null || !mounted) return;
      final file = File(photo.path);
      final bytes = await file.length();
      final data = online && bytes <= _maxDocumentBytes
          ? await file.readAsBytes()
          : null;
      if (!mounted) return;
      final rawName = photo.path.split(Platform.pathSeparator).last.trim();
      final docName = rawName.isEmpty ? 'documento_camara.jpg' : rawName;
      _selectDocument(
        _SimulatedDocumentOption(
          chipKey: const Key('intermediary_doc_device_photo'),
          name: docName,
          bytes: bytes,
          sizeLabel: _formatSizeBytes(bytes),
          data: data,
        ),
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'camera_access_denied' => 'Permite el acceso a la cámara en los ajustes de Android o elige una imagen de la galería.',
        'no_available_camera' => 'No hay una cámara disponible.',
        'document_size' => 'Adjunta un archivo PDF de hasta 5 MB.',
        _ => 'No se pudo adjuntar la imagen del documento.',
      };
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(message)));
    } on FileSystemException {
      if (!mounted) return;
      setState(() => _docError = 'Selecciona el documento de nuevo.');
    } finally {
      if (mounted) setState(() => _pickingDeviceDoc = false);
    }
  }

  @override
  void dispose() {
    _organizationController.dispose();
    super.dispose();
  }

  void _close() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  String? _validateDocument(_SimulatedDocumentOption? doc) {
    if (doc == null) {
      return 'Debes adjuntar un documento de respaldo (.pdf, .jpg, .png, máx. 5 MB).';
    }
    final lower = doc.name.trim().toLowerCase();
    if (lower.isEmpty ||
        !_allowedExtensions.any((ext) => lower.endsWith(ext))) {
      return 'El documento de respaldo debe ser .pdf, .jpg, .jpeg o .png.';
    }
    if (doc.bytes <= 0 || doc.bytes > _maxDocumentBytes) {
      return 'El documento de respaldo debe pesar máximo 5 MB.';
    }
    return null;
  }

  void _selectDocument(_SimulatedDocumentOption? doc) {
    setState(() {
      _selectedDoc = doc;
      _submitError = null;
      _docError = doc == null ? null : _validateDocument(doc);
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final orgError = _organizationController.text.trim().isEmpty
        ? 'El nombre de la organización o comunidad es obligatorio.'
        : null;
    final docError = _validateDocument(_selectedDoc);

    if (orgError != null || docError != null) {
      setState(() {
        _orgError = orgError;
        _docError = docError;
        _submitError = null;
      });
      return;
    }

    final doc = _selectedDoc!;
    setState(() {
      _isSubmitting = true;
      _orgError = null;
      _docError = null;
      _submitError = null;
    });

    final store = ref.read(mockTenantStoreProvider);
    try {
      final created = await store.requestIntermediaryRole(
        organization: _organizationController.text,
        documentName: doc.name,
        documentBytes: doc.bytes,
        documentData: doc.data,
      );
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submittedRequest = created;
      });
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
    final store = ref.watch(mockTenantStoreProvider);
    final activeUser = store.activeUser;
    final theme = Theme.of(context);
    final highContrast = theme.colorScheme.outline == Colors.black;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    final hasPending =
        activeUser != null &&
        store.intermediaryRequests.any(
          (r) =>
              r.usuarioId == activeUser.id &&
              r.estado == EstadoSolicitudRol.pendiente,
        );

    final isSubmitted = _submittedRequest != null;
    final String? blockingWarning;
    if (isSubmitted) {
      blockingWarning = null;
    } else if (activeUser == null) {
      blockingWarning =
          'Debes iniciar sesión para solicitar el rol de intermediario.';
    } else if (activeUser.esIntermediario) {
      blockingWarning = 'Ya cuentas con el rol de intermediario autorizado.';
    } else if (hasPending) {
      blockingWarning = 'Ya tienes una solicitud de rol pendiente.';
    } else {
      blockingWarning = null;
    }

    final formEnabled = !_isSubmitting && blockingWarning == null;
    final validDocs = _simulatedDocuments
        .where((d) => !d.isValidationTestOption)
        .toList();
    final testDocs = _simulatedDocuments
        .where((d) => d.isValidationTestOption)
        .toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Solicitar rol de intermediario',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: _close,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Indica la comunidad u organización que representas y adjunta un documento de respaldo para revisión del equipo administrador.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                if (isSubmitted) ...[
                  PublicationStatusBanner(
                    message:
                        '¡Solicitud enviada! Tu petición para "${_submittedRequest!.organizacion}" quedó pendiente de revisión por un administrador.',
                    tone: PublicationBannerTone.success,
                  ),
                  const SizedBox(height: 14),
                  if (Navigator.of(context).canPop())
                    FilledButton(
                      key: const Key('intermediary_done_close_button'),
                      onPressed: _close,
                      child: const Text('Cerrar'),
                    ),
                ] else ...[
                  if (blockingWarning != null) ...[
                    PublicationStatusBanner(
                      message: blockingWarning,
                      tone: PublicationBannerTone.warning,
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    key: const Key('intermediary_organization_field'),
                    controller: _organizationController,
                    enabled: formEnabled,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      if (_orgError != null || _submitError != null) {
                        setState(() {
                          _orgError = null;
                          _submitError = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Comunidad u organización a la que apoyas *',
                      hintText: 'Ej. Comedor Comunitario San Manuel',
                      prefixIcon: const Icon(Icons.groups_outlined),
                      errorText: _orgError,
                      errorMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Documento de respaldo (.pdf, .jpg, .png, máx. 5 MB) *',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        key: const Key('intermediary_doc_none'),
                        label: const Text('Sin documento'),
                        selected: _selectedDoc == null,
                        onSelected: formEnabled
                            ? (_) => _selectDocument(null)
                            : null,
                      ),
                      for (final doc
                          in store.isOnline
                              ? const <_SimulatedDocumentOption>[]
                              : validDocs)
                        ChoiceChip(
                          key: doc.chipKey,
                          avatar: const Icon(
                            Icons.description_outlined,
                            size: 16,
                          ),
                          label: Text('${doc.name} (${doc.sizeLabel})'),
                          selected: _selectedDoc?.name == doc.name,
                          onSelected: formEnabled
                              ? (_) => _selectDocument(doc)
                              : null,
                        ),
                      ChoiceChip(
                        key: const Key('intermediary_doc_device_photo'),
                        avatar: const Icon(
                          Icons.add_a_photo_outlined,
                          size: 16,
                        ),
                        label: Text(
                          store.isOnline
                              ? 'Adjuntar documento'
                              : 'Cámara o galería',
                        ),
                        selected:
                            _selectedDoc?.chipKey ==
                            const Key('intermediary_doc_device_photo'),
                        onSelected: (formEnabled && !_pickingDeviceDoc)
                            ? (_) => _pickDeviceDocument()
                            : null,
                      ),
                    ],
                  ),
                  if (!store.isOnline) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Opciones de prueba de validación (CU-41):',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.78,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final doc in testDocs)
                          ChoiceChip(
                            key: doc.chipKey,
                            avatar: const Icon(
                              Icons.science_outlined,
                              size: 16,
                            ),
                            label: Text('${doc.name} (${doc.sizeLabel})'),
                            selected: _selectedDoc?.name == doc.name,
                            onSelected: formEnabled
                                ? (_) => _selectDocument(doc)
                                : null,
                          ),
                      ],
                    ),
                  ],
                  if (_selectedDoc != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: highContrast
                            ? Colors.white
                            : DonaPlusColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _docError != null
                              ? theme.colorScheme.error
                              : (highContrast
                                    ? Colors.black
                                    : theme.colorScheme.outline),
                          width: highContrast ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _docError != null
                                ? Icons.warning_amber_rounded
                                : Icons.attach_file,
                            color: _docError != null
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedDoc!.name,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Tamaño simulado: ${_selectedDoc!.sizeLabel}',
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            key: const Key('intermediary_doc_clear_button'),
                            tooltip: 'Quitar documento',
                            onPressed: formEnabled
                                ? () => _selectDocument(null)
                                : null,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_docError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _docError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (_submitError != null) ...[
                    const SizedBox(height: 12),
                    PublicationStatusBanner(
                      message: _submitError!,
                      tone: PublicationBannerTone.error,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSubmitting ? null : _close,
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          key: const Key('intermediary_submit_button'),
                          onPressed: formEnabled ? _submit : null,
                          child: Text(
                            _isSubmitting ? 'Enviando...' : 'Enviar solicitud',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

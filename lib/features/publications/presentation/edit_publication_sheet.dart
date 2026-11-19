import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_exceptions.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/core/models/dto_inputs.dart';
import 'package:donaciones/features/publications/presentation/publication_form_validators.dart';
import 'package:donaciones/features/publications/presentation/publication_ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the modal bottom sheet to edit an active publication (CU-15, CU-16).
Future<void> showEditPublicationSheet(
  BuildContext context,
  PublicacionMock publication,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => EditPublicationSheet(publication: publication),
  );
}

/// Modal bottom sheet allowing authors to update an active Need or Item.
class EditPublicationSheet extends ConsumerStatefulWidget {
  final PublicacionMock publication;

  const EditPublicationSheet({super.key, required this.publication});

  @override
  ConsumerState<EditPublicationSheet> createState() =>
      _EditPublicationSheetState();
}

class _EditPublicationSheetState extends ConsumerState<EditPublicationSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _quantityController;
  late final TextEditingController _detailsController;
  late final TextEditingController _locationController;
  late final TextEditingController _aliasController;

  late String? _categoryId;
  late CondicionArticulo? _condition;
  late Urgencia? _urgency;
  late List<String> _photos;
  late bool _managedByIntermediary;

  bool _isSubmitting = false;
  String? _photosError;
  String? _tituloError;
  String? _descripcionError;
  String? _categoriaError;
  String? _cantidadError;
  String? _condicionError;
  String? _urgenciaError;
  String? _ubicacionError;
  String? _aliasError;
  String? _submitError;

  bool get _isNeed => widget.publication.tipo == TipoPublicacion.necesidad;

  @override
  void initState() {
    super.initState();
    final pub = widget.publication;
    _titleController = TextEditingController(text: pub.titulo);
    _descriptionController = TextEditingController(text: pub.descripcion);
    _quantityController = TextEditingController(text: '${pub.cantidad}');
    _detailsController = TextEditingController(
      text: pub.caracteristicas['Detalles'] ??
          pub.caracteristicas.values.join(', '),
    );
    _locationController = TextEditingController(text: pub.ubicacion.etiqueta);
    _aliasController = TextEditingController(
      text: pub.aliasBeneficiario ?? '',
    );

    _categoryId = pub.categoriaId;
    _condition = pub.condicion;
    _urgency = pub.urgencia;
    _photos = List<String>.from(pub.fotografias);
    _managedByIntermediary = pub.gestionadaPorIntermediario;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _detailsController.dispose();
    _locationController.dispose();
    _aliasController.dispose();
    super.dispose();
  }

  void _addQuickPhoto(MockTenantStore store) {
    if (_photos.length >= 5) {
      setState(() => _photosError = 'Máximo 5 fotografías permitidas (5/5).');
      return;
    }
    final next = store.getSampleItemPhotos().firstWhere(
      (s) => !_photos.contains(s),
      orElse: () => 'sample://articulo_${_photos.length + 1}.jpg',
    );
    setState(() {
      _photos = [..._photos, next];
      _photosError = null;
    });
  }

  void _addSpecificPhoto(String path) {
    if (_photos.length >= 5) {
      setState(() => _photosError = 'Máximo 5 fotografías permitidas (5/5).');
      return;
    }
    setState(() {
      _photos = [..._photos, path];
      _photosError = null;
    });
  }

  void _removePhotoAt(int index) {
    if (index < 0 || index >= _photos.length) return;
    setState(() {
      _photos = [..._photos]..removeAt(index);
      _photosError = null;
    });
  }

  Future<void> _save() async {
    if (_isSubmitting) return;
    final store = ref.read(mockTenantStoreProvider);
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;

    if (_isNeed) {
      final isIntermediary = store.activeUser?.esIntermediario == true;
      final effectiveIntermediary = isIntermediary && _managedByIntermediary;
      final errors = validateNeedFields(
        store: store,
        titulo: _titleController.text,
        descripcion: _descriptionController.text,
        categoriaId: _categoryId,
        cantidadRequerida: quantity,
        urgencia: _urgency,
        ubicacionEtiqueta: _locationController.text,
        gestionadaPorIntermediario: effectiveIntermediary,
        aliasBeneficiario: _aliasController.text,
      );
      if (errors.hasErrors) {
        setState(() {
          _tituloError = errors.tituloError;
          _descripcionError = errors.descripcionError;
          _categoriaError = errors.categoriaError;
          _cantidadError = errors.cantidadError;
          _urgenciaError = errors.urgenciaError;
          _ubicacionError = errors.ubicacionError;
          _aliasError = errors.aliasError;
          _submitError = null;
        });
        return;
      }
      await _runSave(
        () => store.updateNeedPublication(
          publicationId: widget.publication.id,
          input: CreateNeedInput(
            titulo: _titleController.text,
            descripcion: _descriptionController.text,
            categoriaId: _categoryId!,
            cantidadRequerida: quantity,
            condicionAceptable: _condition,
            detallesCaracteristicas: _detailsController.text,
            urgencia: _urgency!,
            ubicacionEtiqueta: _locationController.text,
            gestionadaPorIntermediario: effectiveIntermediary,
            aliasBeneficiario:
                effectiveIntermediary ? _aliasController.text : null,
          ),
        ),
      );
      return;
    }

    final itemErrors = validateItemFields(
      store: store,
      fotografias: _photos,
      titulo: _titleController.text,
      descripcion: _descriptionController.text,
      categoriaId: _categoryId,
      cantidad: quantity,
      condicion: _condition,
      ubicacionEtiqueta: _locationController.text,
    );
    if (itemErrors.hasErrors) {
      setState(() {
        _photosError = itemErrors.photosError;
        _tituloError = itemErrors.tituloError;
        _descripcionError = itemErrors.descripcionError;
        _categoriaError = itemErrors.categoriaError;
        _cantidadError = itemErrors.cantidadError;
        _condicionError = itemErrors.condicionError;
        _ubicacionError = itemErrors.ubicacionError;
        _submitError = null;
      });
      return;
    }

    await _runSave(
      () => store.updateItemPublication(
        publicationId: widget.publication.id,
        input: CreateItemInput(
          titulo: _titleController.text,
          descripcion: _descriptionController.text,
          categoriaId: _categoryId!,
          fotografias: _photos,
          cantidad: quantity,
          condicion: _condition!,
          ubicacionEtiqueta: _locationController.text,
        ),
      ),
    );
  }

  Future<void> _runSave(Future<PublicacionMock> Function() operation) async {
    setState(() {
      _isSubmitting = true;
      _photosError = null;
      _tituloError = null;
      _descripcionError = null;
      _categoriaError = null;
      _cantidadError = null;
      _condicionError = null;
      _urgenciaError = null;
      _ubicacionError = null;
      _aliasError = null;
      _submitError = null;
    });

    try {
      await operation();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Publicación actualizada correctamente.'),
        ),
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
    final store = ref.watch(mockTenantStoreProvider);
    final activeCategories = store.getActiveCategories();
    final isIntermediary = store.activeUser?.esIntermediario == true;
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

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
              Text(
                _isNeed ? 'Editar Necesidad' : 'Editar Artículo',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              if (!_isNeed) ...[
                PublicationPhotosField(
                  addButtonKey: const Key('edit_pub_add_photo_button'),
                  sourceButtonKey: const Key('edit_pub_photo_source_button'),
                  photos: _photos,
                  samplePhotos: store.getSampleItemPhotos(),
                  onAddQuickPhoto: () => _addQuickPhoto(store),
                  onAddSpecificPhoto: _addSpecificPhoto,
                  onRemoveAt: _removePhotoAt,
                  errorText: _photosError,
                  enabled: !_isSubmitting,
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                key: const Key('edit_pub_title_field'),
                controller: _titleController,
                onChanged: (_) => setState(() => _tituloError = null),
                decoration: InputDecoration(
                  labelText: _isNeed
                      ? 'Nombre del artículo requerido *'
                      : 'Nombre del artículo *',
                  errorText: _tituloError,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('edit_pub_description_field'),
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                onChanged: (_) => setState(() => _descripcionError = null),
                decoration: InputDecoration(
                  labelText: 'Descripción *',
                  errorText: _descripcionError,
                ),
              ),
              const SizedBox(height: 12),
              ActiveCategoryDropdown(
                fieldKey: const Key('edit_pub_category_dropdown'),
                categories: activeCategories,
                selectedCategoryId: _categoryId,
                onChanged: (value) => setState(() {
                  _categoryId = value;
                  _categoriaError = null;
                }),
                errorText: _categoriaError,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('edit_pub_quantity_field'),
                controller: _quantityController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() => _cantidadError = null),
                decoration: InputDecoration(
                  labelText:
                      _isNeed ? 'Cantidad requerida *' : 'Cantidad disponible *',
                  errorText: _cantidadError,
                ),
              ),
              const SizedBox(height: 12),
              if (_isNeed) ...[
                NeedConditionDropdown(
                  value: _condition,
                  onChanged: (value) => setState(() => _condition = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _detailsController,
                  decoration: const InputDecoration(
                    labelText: 'Detalles (talla, medida, modelo)',
                  ),
                ),
                const SizedBox(height: 14),
                NeedUrgencySelector(
                  selectedUrgency: _urgency,
                  onSelected: (value) => setState(() {
                    _urgency = value;
                    _urgenciaError = null;
                  }),
                  errorText: _urgenciaError,
                ),
              ] else ...[
                ItemConditionSelector(
                  selectedCondition: _condition,
                  onSelected: (value) => setState(() {
                    _condition = value;
                    _condicionError = null;
                  }),
                  errorText: _condicionError,
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('edit_pub_location_field'),
                controller: _locationController,
                onChanged: (_) => setState(() => _ubicacionError = null),
                decoration: InputDecoration(
                  labelText: 'Ubicación aproximada (Colonia o CP) *',
                  errorText: _ubicacionError,
                ),
              ),
              if (_isNeed && isIntermediary) ...[
                const SizedBox(height: 14),
                IntermediaryBeneficiaryFields(
                  enabled: _managedByIntermediary,
                  onToggle: (value) => setState(() {
                    _managedByIntermediary = value;
                    if (!value) _aliasError = null;
                  }),
                  aliasController: _aliasController,
                  onAliasChanged: (_) => setState(() => _aliasError = null),
                  aliasError: _aliasError,
                ),
              ],
              if (_submitError != null) ...[
                const SizedBox(height: 14),
                PublicationStatusBanner(
                  message: _submitError!,
                  tone: PublicationBannerTone.error,
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    key: const Key('edit_pub_save_button'),
                    onPressed: _isSubmitting ? null : _save,
                    child: Text(
                      _isSubmitting ? 'Guardando...' : 'Guardar cambios',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

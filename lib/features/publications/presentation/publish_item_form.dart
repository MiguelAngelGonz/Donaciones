import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/features/publications/presentation/publication_ui_helpers.dart';
import 'package:donaciones/features/publications/presentation/publish_item_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Form for publishing an available Item with 1..5 photographs (CU-14, CU-13).
class PublishItemForm extends ConsumerStatefulWidget {
  final VoidCallback? onPublished;

  const PublishItemForm({super.key, this.onPublished});

  @override
  ConsumerState<PublishItemForm> createState() => _PublishItemFormState();
}

class _PublishItemFormState extends ConsumerState<PublishItemForm> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _packageContentController = TextEditingController();
  final _expirationDateController = TextEditingController();
  final _locationController = TextEditingController();

  String? _lastUserId;
  String _lastDefaultLocation = '';

  @override
  void initState() {
    super.initState();
    final user = ref.read(mockTenantStoreProvider).activeUser;
    _lastUserId = user?.id;
    _lastDefaultLocation = user?.ubicacionAproximada.etiqueta ?? '';
    _locationController.text = _lastDefaultLocation;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _packageContentController.dispose();
    _expirationDateController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = ref.read(publishItemControllerProvider.notifier);
    final created = await controller.submit(
      titulo: _titleController.text,
      descripcion: _descriptionController.text,
      cantidadText: _quantityController.text,
      contenidoPorEnvase: _packageContentController.text,
      fechaCaducidad: _expirationDateController.text,
      ubicacion: _locationController.text,
    );
    if (created == null || !mounted) return;

    final defaultLocation =
        ref.read(mockTenantStoreProvider).activeUser?.ubicacionAproximada.etiqueta ??
        '';
    _titleController.clear();
    _descriptionController.clear();
    _quantityController.text = '1';
    _packageContentController.clear();
    _expirationDateController.clear();
    _locationController.text = defaultLocation;
    _lastDefaultLocation = defaultLocation;

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text('Artículo publicado: "${created.titulo}"'),
      ),
    );
    widget.onPublished?.call();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<MockTenantStore>(mockTenantStoreProvider, (_, next) {
      final user = next.activeUser;
      if (user?.id == _lastUserId) return;
      _lastUserId = user?.id;
      final itemController = ref.read(publishItemControllerProvider.notifier);
      itemController.clearPublishedBanner();
      final newLocation = user?.ubicacionAproximada.etiqueta ?? '';
      if (_locationController.text.trim().isEmpty ||
          _locationController.text == _lastDefaultLocation) {
        _locationController.text = newLocation;
        itemController.setUbicacionEtiqueta(newLocation);
      }
      _lastDefaultLocation = newLocation;
    });

    final store = ref.watch(mockTenantStoreProvider);
    final state = ref.watch(publishItemControllerProvider);
    final controller = ref.read(publishItemControllerProvider.notifier);
    final theme = Theme.of(context);
    final activeCategories = store.getActiveCategories();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Publicar un Artículo para donar',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            PublicationPhotosField(
              addButtonKey: const Key('item_add_photo_button'),
              sourceButtonKey: const Key('item_pick_photo_source_button'),
              photos: state.fotografias,
              samplePhotos: store.getSampleItemPhotos(),
              onAddQuickPhoto: controller.addNextSamplePhoto,
              onAddSpecificPhoto: controller.addPhoto,
              onRemoveAt: controller.removePhotoAt,
              errorText: state.photosError,
              enabled: !state.isSubmitting,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('item_title_field'),
              controller: _titleController,
              onChanged: controller.setTitulo,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Nombre del artículo *',
                hintText: 'Ej. Bicicleta urbana / Mesa de comedor',
                prefixIcon: const Icon(Icons.inventory_2_outlined),
                errorText: state.tituloError,
              ),
            ),
            const SizedBox(height: 12),
            ActiveCategoryDropdown(
              fieldKey: const Key('item_category_dropdown'),
              categories: activeCategories,
              selectedCategoryId: state.categoriaId,
              onChanged: controller.setCategoriaId,
              errorText: state.categoriaError,
            ),
            if (state.esAlimento) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<PresentacionAlimento>(
                key: const Key('item_food_package_field'),
                initialValue: state.presentacionAlimento,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Presentación del alimento *',
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                  errorText: state.presentacionError,
                ),
                items: [
                  for (final presentacion in PresentacionAlimento.values)
                    DropdownMenuItem(
                      value: presentacion,
                      child: Text(presentacion.etiqueta),
                    ),
                ],
                onChanged: controller.setPresentacionAlimento,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('item_food_package_content_field'),
                controller: _packageContentController,
                decoration: const InputDecoration(
                  labelText: 'Contenido por envase (opcional)',
                  hintText: 'Ej. 400 g o 500 ml',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('item_food_expiration_field'),
                controller: _expirationDateController,
                keyboardType: TextInputType.datetime,
                onChanged: (_) => controller.clearCaducidadError(),
                decoration: InputDecoration(
                  labelText: 'Fecha de caducidad (opcional)',
                  helperText: 'Formato DD/MM/AAAA.',
                  prefixIcon: const Icon(Icons.event_outlined),
                  errorText: state.caducidadError,
                  errorMaxLines: 2,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('item_description_field'),
              controller: _descriptionController,
              onChanged: controller.setDescripcion,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Descripción *',
                hintText: state.esAlimento
                    ? 'Ej. Atún en agua, envases cerrados'
                    : 'Describe estado, medidas o detalles importantes...',
                prefixIcon: const Icon(Icons.description_outlined),
                errorText: state.descripcionError,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('item_quantity_field'),
              controller: _quantityController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: controller.setCantidadFromText,
              decoration: InputDecoration(
                labelText: state.esAlimento
                    ? 'Número de envases *'
                    : 'Cantidad disponible *',
                prefixIcon: const Icon(Icons.numbers_outlined),
                errorText: state.cantidadError,
              ),
            ),
            if (!state.esAlimento) ...[
              const SizedBox(height: 14),
              ItemConditionSelector(
                selectedCondition: state.condicion,
                onSelected: controller.setCondicion,
                errorText: state.condicionError,
                nuevoKey: const Key('item_condition_nuevo'),
                comoNuevoKey: const Key('item_condition_comoNuevo'),
                usadoKey: const Key('item_condition_usado'),
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('item_location_field'),
              controller: _locationController,
              onChanged: controller.setUbicacionEtiqueta,
              decoration: InputDecoration(
                labelText: 'Ubicación aproximada (Colonia o CP) *',
                hintText: 'Ej. Col. Centro, CP 72000',
                prefixIcon: const Icon(Icons.location_on_outlined),
                errorText: state.ubicacionError,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Solo colonia o CP, nunca domicilio exacto (RNF-09)',
              style: theme.textTheme.bodySmall,
            ),
            if (state.submissionError != null) ...[
              const SizedBox(height: 14),
              PublicationStatusBanner(
                message: state.submissionError!,
                tone: PublicationBannerTone.error,
              ),
            ],
            if (state.publishedPublication != null) ...[
              const SizedBox(height: 14),
              PublicationStatusBanner(
                message:
                    'Artículo publicado: "${state.publishedPublication!.titulo}"',
                tone: PublicationBannerTone.success,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('item_submit_button'),
              onPressed: state.isSubmitting ? null : _submit,
              icon: const Icon(Icons.volunteer_activism_outlined),
              label: Text(
                state.isSubmitting ? 'Publicando...' : 'Publicar Artículo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

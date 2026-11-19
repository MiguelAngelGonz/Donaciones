import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/features/publications/presentation/publication_ui_helpers.dart';
import 'package:donaciones/features/publications/presentation/publish_need_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Form for publishing a Need (CU-11, CU-12, CU-13, CU-46, CU-47).
class PublishNeedForm extends ConsumerStatefulWidget {
  final VoidCallback? onPublished;

  const PublishNeedForm({super.key, this.onPublished});

  @override
  ConsumerState<PublishNeedForm> createState() => _PublishNeedFormState();
}

class _PublishNeedFormState extends ConsumerState<PublishNeedForm> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _detailsController = TextEditingController();
  final _locationController = TextEditingController();
  final _aliasController = TextEditingController();

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
    _detailsController.dispose();
    _locationController.dispose();
    _aliasController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = ref.read(publishNeedControllerProvider.notifier);
    final created = await controller.submit(
      titulo: _titleController.text,
      descripcion: _descriptionController.text,
      cantidadText: _quantityController.text,
      detalles: _detailsController.text,
      ubicacion: _locationController.text,
      aliasBeneficiario: _aliasController.text,
    );
    if (created == null || !mounted) return;

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text('Necesidad publicada: "${created.titulo}"'),
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
      final newLocation = user?.ubicacionAproximada.etiqueta ?? '';
      if (_locationController.text.trim().isEmpty ||
          _locationController.text == _lastDefaultLocation) {
        _locationController.text = newLocation;
        ref
            .read(publishNeedControllerProvider.notifier)
            .setUbicacionEtiqueta(newLocation);
      }
      _lastDefaultLocation = newLocation;
      if (user?.esIntermediario != true) {
        ref
            .read(publishNeedControllerProvider.notifier)
            .setGestionadaPorIntermediario(false);
      }
    });

    final store = ref.watch(mockTenantStoreProvider);
    final state = ref.watch(publishNeedControllerProvider);
    final controller = ref.read(publishNeedControllerProvider.notifier);
    final theme = Theme.of(context);
    final activeCategories = store.getActiveCategories();
    final isIntermediary = store.activeUser?.esIntermediario == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Publicar una Necesidad',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('need_title_field'),
              controller: _titleController,
              onChanged: controller.setTitulo,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Nombre del artículo requerido *',
                hintText: 'Ej. Silla de ruedas plegable',
                prefixIcon: const Icon(Icons.inventory_2_outlined),
                errorText: state.tituloError,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('need_description_field'),
              controller: _descriptionController,
              onChanged: controller.setDescripcion,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Descripción de la necesidad *',
                hintText: 'Explica para qué se requiere y quién lo utilizará...',
                prefixIcon: const Icon(Icons.description_outlined),
                errorText: state.descripcionError,
              ),
            ),
            const SizedBox(height: 12),
            ActiveCategoryDropdown(
              fieldKey: const Key('need_category_dropdown'),
              categories: activeCategories,
              selectedCategoryId: state.categoriaId,
              onChanged: controller.setCategoriaId,
              errorText: state.categoriaError,
            ),
            const SizedBox(height: 14),
            Text(
              'Características necesarias *',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('need_quantity_field'),
              controller: _quantityController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: controller.setCantidadFromText,
              decoration: InputDecoration(
                labelText: 'Cantidad requerida *',
                prefixIcon: const Icon(Icons.numbers_outlined),
                errorText: state.cantidadError,
              ),
            ),
            const SizedBox(height: 12),
            NeedConditionDropdown(
              fieldKey: const Key('need_condition_dropdown'),
              value: state.condicionAceptable,
              onChanged: controller.setCondicionAceptable,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('need_details_field'),
              controller: _detailsController,
              onChanged: controller.setDetallesCaracteristicas,
              decoration: const InputDecoration(
                labelText: 'Detalles (talla, medida, modelo)',
                hintText: 'Ej. Talla M, adulto, plegable',
                prefixIcon: Icon(Icons.tune_outlined),
              ),
            ),
            const SizedBox(height: 14),
            NeedUrgencySelector(
              selectedUrgency: state.urgencia,
              onSelected: controller.setUrgencia,
              errorText: state.urgenciaError,
              altaKey: const Key('need_urgency_alta'),
              mediaKey: const Key('need_urgency_media'),
              bajaKey: const Key('need_urgency_baja'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('need_location_field'),
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
            if (isIntermediary) ...[
              const SizedBox(height: 14),
              IntermediaryBeneficiaryFields(
                switchKey: const Key('need_intermediary_switch'),
                aliasKey: const Key('need_beneficiary_alias_field'),
                enabled: state.gestionadaPorIntermediario,
                onToggle: controller.setGestionadaPorIntermediario,
                aliasController: _aliasController,
                onAliasChanged: controller.setAliasBeneficiario,
                aliasError: state.aliasError,
              ),
            ],
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
                    'Necesidad publicada: "${state.publishedPublication!.titulo}"',
                tone: PublicationBannerTone.success,
                trailing: UrgencyBadge(
                  urgencia:
                      state.publishedPublication!.urgencia ?? Urgencia.baja,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('need_submit_button'),
              onPressed: state.isSubmitting ? null : _submit,
              icon: const Icon(Icons.publish_outlined),
              label: Text(
                state.isSubmitting ? 'Publicando...' : 'Publicar Necesidad',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

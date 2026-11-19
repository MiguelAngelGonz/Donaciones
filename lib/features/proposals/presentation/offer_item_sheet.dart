import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/features/proposals/presentation/offer_item_controller.dart';
import 'package:donaciones/features/publications/presentation/publication_ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modal bottom sheet allowing a donor to submit an Offer for a Need (CU-24).
class OfferItemSheet extends ConsumerStatefulWidget {
  final String publicationId;

  const OfferItemSheet({super.key, required this.publicationId});

  @override
  ConsumerState<OfferItemSheet> createState() => _OfferItemSheetState();
}

class _OfferItemSheetState extends ConsumerState<OfferItemSheet> {
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref
        .read(offerItemControllerProvider(widget.publicationId).notifier)
        .submit(_descriptionController.text);
  }

  void _close() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(mockTenantStoreProvider);
    final state = ref.watch(offerItemControllerProvider(widget.publicationId));
    final controller = ref.read(
      offerItemControllerProvider(widget.publicationId).notifier,
    );
    final pub = store.findPublicationById(widget.publicationId);
    final activeUser = store.activeUser;
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    final isNeedActive =
        pub != null &&
        pub.tipo == TipoPublicacion.necesidad &&
        pub.estado == EstadoPublicacion.activa;
    final hasPending =
        activeUser != null &&
        store.hasPendingProposal(
          publicationId: widget.publicationId,
          userId: activeUser.id,
        );
    final isSubmitted = state.submittedProposal != null;

    final String? blockingWarning;
    if (isSubmitted) {
      blockingWarning = null;
    } else if (activeUser == null) {
      blockingWarning = 'Debes iniciar sesión para enviar una oferta.';
    } else if (!isNeedActive) {
      blockingWarning = 'Esta necesidad ya no está activa.';
    } else if (activeUser.id == pub.autorId) {
      blockingWarning = 'No puedes ofertar en tu propia necesidad.';
    } else if (hasPending) {
      blockingWarning = 'Ya enviaste una oferta pendiente para esta necesidad.';
    } else {
      blockingWarning = null;
    }

    final canSubmit =
        !state.isSubmitting && !isSubmitted && blockingWarning == null;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ofrecer artículo',
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
                if (pub != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Para cubrir: ${pub.titulo}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                if (isSubmitted) ...[
                  const PublicationStatusBanner(
                    message:
                        '¡Oferta enviada! Quedó registrada como pendiente y el autor de la necesidad recibió una notificación.',
                    tone: PublicationBannerTone.success,
                  ),
                  const SizedBox(height: 14),
                  if (Navigator.of(context).canPop())
                    FilledButton(
                      key: const Key('offer_done_close_button'),
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
                  PublicationPhotosField(
                    addButtonKey: const Key('offer_add_photo_button'),
                    sourceButtonKey: const Key('offer_photo_source_button'),
                    photos: state.fotografias,
                    samplePhotos: store.getSampleItemPhotos(),
                    onAddQuickPhoto: controller.addNextSamplePhoto,
                    onAddSpecificPhoto: controller.addPhoto,
                    onRemoveAt: controller.removePhotoAt,
                    errorText: state.photosError,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const Key('offer_description_field'),
                    controller: _descriptionController,
                    enabled: !state.isSubmitting && blockingWarning == null,
                    minLines: 3,
                    maxLines: 5,
                    onChanged: controller.setDescription,
                    decoration: InputDecoration(
                      labelText: 'Descripción del artículo ofrecido *',
                      hintText:
                          'Describe el estado, características y detalles de lo que ofreces.',
                      alignLabelWithHint: true,
                      errorText: state.descriptionError,
                      errorMaxLines: 2,
                    ),
                  ),
                  if (state.submissionError != null) ...[
                    const SizedBox(height: 12),
                    PublicationStatusBanner(
                      message: state.submissionError!,
                      tone: PublicationBannerTone.error,
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('offer_submit_button'),
                    onPressed: canSubmit ? _submit : null,
                    child: Text(
                      state.isSubmitting ? 'Enviando...' : 'Confirmar Oferta',
                    ),
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

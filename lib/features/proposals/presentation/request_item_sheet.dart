import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/features/proposals/presentation/request_item_controller.dart';
import 'package:donaciones/features/publications/presentation/publication_ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modal bottom sheet allowing a recipient to submit a Request for an Item (CU-23).
class RequestItemSheet extends ConsumerStatefulWidget {
  final String publicationId;

  const RequestItemSheet({super.key, required this.publicationId});

  @override
  ConsumerState<RequestItemSheet> createState() => _RequestItemSheetState();
}

class _RequestItemSheetState extends ConsumerState<RequestItemSheet> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref
        .read(requestItemControllerProvider(widget.publicationId).notifier)
        .submit(_messageController.text);
  }

  void _close() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(mockTenantStoreProvider);
    final state = ref.watch(
      requestItemControllerProvider(widget.publicationId),
    );
    final controller = ref.read(
      requestItemControllerProvider(widget.publicationId).notifier,
    );
    final pub = store.findPublicationById(widget.publicationId);
    final activeUser = store.activeUser;
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    final isArticleActive =
        pub != null &&
        pub.tipo == TipoPublicacion.articulo &&
        pub.estado == EstadoPublicacion.activa;
    final hasPending =
        activeUser != null &&
        store.hasPendingProposal(
          publicationId: widget.publicationId,
          userId: activeUser.id,
        );
    final isSubmitted = state.submittedProposal != null;
    final charCount = _messageController.text.trim().length;
    final isOverLimit = charCount > 300;
    final isNearLimit = charCount >= 280 && !isOverLimit;

    final String? blockingWarning;
    if (isSubmitted) {
      blockingWarning = null;
    } else if (activeUser == null) {
      blockingWarning = 'Debes iniciar sesión para enviar una solicitud.';
    } else if (!isArticleActive) {
      blockingWarning = 'Este artículo ya no está activo.';
    } else if (activeUser.id == pub.autorId) {
      blockingWarning = 'No puedes solicitar tu propio artículo.';
    } else if (hasPending) {
      blockingWarning = 'Ya tienes una solicitud pendiente para este artículo.';
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
                        'Solicitar artículo',
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
                    'Artículo: ${pub.titulo}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                if (isSubmitted) ...[
                  const PublicationStatusBanner(
                    message:
                        '¡Solicitud enviada! Quedó registrada como pendiente y el donante recibió una notificación.',
                    tone: PublicationBannerTone.success,
                  ),
                  const SizedBox(height: 14),
                  if (Navigator.of(context).canPop())
                    FilledButton(
                      key: const Key('request_done_close_button'),
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
                    key: const Key('request_message_field'),
                    controller: _messageController,
                    enabled: !state.isSubmitting && blockingWarning == null,
                    minLines: 4,
                    maxLines: 6,
                    // Allow entering >300 chars so 3a length validation triggers explicitly.
                    maxLengthEnforcement: MaxLengthEnforcement.none,
                    onChanged: (value) {
                      setState(() {});
                      controller.setMessage(value);
                    },
                    decoration: InputDecoration(
                      labelText: 'Mensaje para el donante *',
                      hintText:
                          'Cuéntale al donante por qué necesitas el artículo y cuándo podrías recogerlo.',
                      alignLabelWithHint: true,
                      errorText: state.messageError,
                      errorMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$charCount / 300 caracteres',
                      key: const Key('request_message_counter'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isOverLimit
                            ? theme.colorScheme.error
                            : isNearLimit
                            ? const Color(0xFFB26A00)
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.72,
                              ),
                      ),
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
                    key: const Key('request_submit_button'),
                    onPressed: canSubmit ? _submit : null,
                    child: Text(
                      state.isSubmitting ? 'Enviando...' : 'Confirmar envío',
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

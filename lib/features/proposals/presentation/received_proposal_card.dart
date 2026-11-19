import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/core/widgets/trust_badge_chip.dart';
import 'package:donaciones/features/auth/presentation/auth_form_widgets.dart';
import 'package:donaciones/features/donations/presentation/donation_ui_helpers.dart';
import 'package:donaciones/features/publications/presentation/publication_ui_helpers.dart';
import 'package:flutter/material.dart';

/// Opens a dialog asking for an optional rejection reason (CU-29).
///
/// Returns `null` if dismissed/cancelled, or the trimmed reason (which may be `''`).
Future<String?> showRejectProposalReasonDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => const _RejectProposalDialog(),
  );
}

class _RejectProposalDialog extends StatefulWidget {
  const _RejectProposalDialog();

  @override
  State<_RejectProposalDialog> createState() => _RejectProposalDialogState();
}

class _RejectProposalDialogState extends State<_RejectProposalDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rechazar propuesta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'La publicación permanecerá activa para recibir otras propuestas. Puedes indicar un motivo opcional para el remitente.',
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('reject_proposal_reason_field'),
            controller: _reasonController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Motivo (opcional)',
              hintText: 'Ej. Ya acordamos la entrega con otro miembro.',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('confirm_reject_proposal_button'),
          onPressed: () =>
              Navigator.of(context).pop(_reasonController.text.trim()),
          child: const Text('Confirmar rechazo'),
        ),
      ],
    );
  }
}

/// Shared card displaying a pending received proposal with sender Trust Profile (CU-26..29).
class ReceivedProposalCard extends StatelessWidget {
  final PropuestaMock proposal;
  final PublicacionMock? publication;
  final UsuarioMock? sender;
  final bool showPublicationTitle;
  final bool isBusy;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback? onOpenPublication;

  const ReceivedProposalCard({
    super.key,
    required this.proposal,
    required this.publication,
    required this.sender,
    this.showPublicationTitle = true,
    this.isBusy = false,
    required this.onAccept,
    required this.onReject,
    this.onOpenPublication,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOffer = proposal.tipo == TipoPropuesta.oferta;

    return Card(
      key: Key('received_proposal_${proposal.id}'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(isOffer ? 'OFERTA' : 'SOLICITUD'),
                ),
                Text(
                  formatDonationDateTime(proposal.fechaEnvio),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
            if (showPublicationTitle && publication != null) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: onOpenPublication,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          publication!.titulo,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      if (onOpenPublication != null)
                        Icon(
                          Icons.chevron_right,
                          color: theme.colorScheme.primary,
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const Divider(height: 18),
            if (sender != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfileAvatarCircle(
                    nombreLegal: sender!.nombreLegal,
                    fotoPerfil: sender!.fotoPerfil,
                    radius: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sender!.nombreLegal,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '@${sender!.nombreUsuario}',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        TrustBadgeChip(usuario: sender!),
                        const SizedBox(height: 4),
                        Text(
                          'Calificación: ${sender!.promedioCalificacion.toStringAsFixed(1)} · '
                          '${sender!.donacionesFinalizadas} donaciones · '
                          '${sender!.numeroResenas} reseñas',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Text(proposal.texto, style: theme.textTheme.bodyMedium),
            if (proposal.fotografias.isNotEmpty) ...[
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < proposal.fotografias.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      PublicationPhotoPlaceholder(
                        photoPath: proposal.fotografias[i],
                        width: 112,
                        height: 92,
                        isPrimary: i == 0,
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: Key('accept_proposal_${proposal.id}'),
                  onPressed: isBusy ? null : onAccept,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(isBusy ? 'Procesando...' : 'Aceptar'),
                ),
                OutlinedButton.icon(
                  key: Key('reject_proposal_${proposal.id}'),
                  onPressed: isBusy ? null : onReject,
                  icon: const Icon(Icons.close),
                  label: const Text('Rechazar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

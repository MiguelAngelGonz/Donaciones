import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_exceptions.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/core/widgets/demo_tenant_toolbar.dart';
import 'package:donaciones/core/widgets/trust_badge_chip.dart';
import 'package:donaciones/features/auth/presentation/auth_form_widgets.dart';
import 'package:donaciones/features/donations/presentation/donation_ui_helpers.dart';
import 'package:donaciones/features/proposals/presentation/offer_item_sheet.dart';
import 'package:donaciones/features/proposals/presentation/received_proposal_card.dart';
import 'package:donaciones/features/proposals/presentation/request_item_sheet.dart';
import 'package:donaciones/features/publications/presentation/edit_publication_sheet.dart';
import 'package:donaciones/features/publications/presentation/publication_ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Publication detail view supporting edit/withdraw (CU-15, CU-16) and proposals (CU-23, CU-24).
class PublicationDetailScreen extends ConsumerStatefulWidget {
  final String publicationId;

  const PublicationDetailScreen({super.key, required this.publicationId});

  @override
  ConsumerState<PublicationDetailScreen> createState() =>
      _PublicationDetailScreenState();
}

class _PublicationDetailScreenState
    extends ConsumerState<PublicationDetailScreen> {
  final _pendingAcceptKeys = PendingActionKeys();
  String? _actionError;
  bool _isWithdrawing = false;
  String? _busyProposalId;
  DonacionMock? _acceptedDonation;

  @override
  void didUpdateWidget(covariant PublicationDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.publicationId != widget.publicationId) {
      _pendingAcceptKeys.clearAll();
      _actionError = null;
      _isWithdrawing = false;
      _busyProposalId = null;
      _acceptedDonation = null;
    }
  }

  void _navigateBack() {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _acceptProposal(PropuestaMock proposal) async {
    if (_busyProposalId != null) return;
    final store = ref.read(mockTenantStoreProvider);
    final opKey = 'detail-acc-${proposal.id}';
    final clientKey = _pendingAcceptKeys.getOrCreate(opKey, store);

    setState(() {
      _busyProposalId = proposal.id;
      _actionError = null;
      _acceptedDonation = null;
    });

    String? errorMsg;
    final donation = await runAcceptProposal(
      store: store,
      proposalId: proposal.id,
      clientKey: clientKey,
      onError: (msg) => errorMsg = msg,
      onClearClientKey: () => _pendingAcceptKeys.clear(opKey),
    );

    if (!mounted) return;
    setState(() {
      _busyProposalId = null;
      _actionError = errorMsg;
      _acceptedDonation = donation;
    });

    if (donation != null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: const Text('Propuesta aceptada. Donación iniciada.'),
          action: SnackBarAction(
            label: 'Ver seguimiento',
            onPressed: () =>
                GoRouter.maybeOf(context)?.push('/donations/${donation.id}'),
          ),
        ),
      );
    }
  }

  Future<void> _rejectProposal(PropuestaMock proposal) async {
    if (_busyProposalId != null) return;
    final reason = await showRejectProposalReasonDialog(context);
    if (reason == null || !mounted) return;

    final store = ref.read(mockTenantStoreProvider);
    setState(() {
      _busyProposalId = proposal.id;
      _actionError = null;
    });

    String? errorMsg;
    final ok = await runRejectProposal(
      store: store,
      proposalId: proposal.id,
      reason: reason,
      onError: (msg) => errorMsg = msg,
    );

    if (!mounted) return;
    setState(() {
      _busyProposalId = null;
      _actionError = errorMsg;
    });

    if (ok) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Propuesta rechazada. La publicación sigue activa.'),
        ),
      );
    }
  }

  Future<void> _confirmAndWithdraw(PublicacionMock pub) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Retirar esta publicación?'),
        content: const Text(
          'Dejará de aparecer en el feed y en coincidencias, y las propuestas pendientes serán rechazadas automáticamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmar retiro'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() {
      _isWithdrawing = true;
      _actionError = null;
    });

    try {
      await ref.read(mockTenantStoreProvider).withdrawPublication(pub.id);
      if (!mounted) return;
      setState(() => _isWithdrawing = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Publicación retirada correctamente.'),
        ),
      );
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        _isWithdrawing = false;
        _actionError = e.message;
      });
    } on ValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _isWithdrawing = false;
        _actionError = e.message;
      });
    } on UnauthorizedActionException catch (e) {
      if (!mounted) return;
      setState(() {
        _isWithdrawing = false;
        _actionError = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(mockTenantStoreProvider);
    final pub = store.findPublicationById(widget.publicationId);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigateBack,
        ),
        title: const Text('Detalle de publicación'),
      ),
      body: Column(
        children: [
          const DemoTenantToolbar(),
          Expanded(
            child: pub == null
                ? _MissingPublicationView(onBack: _navigateBack)
                : _DetailBody(
                    publication: pub,
                    store: store,
                    actionError: _actionError,
                    isWithdrawing: _isWithdrawing,
                    busyProposalId: _busyProposalId,
                    acceptedDonation: _acceptedDonation,
                    onEdit: () => showEditPublicationSheet(context, pub),
                    onWithdraw: () => _confirmAndWithdraw(pub),
                    onAcceptProposal: _acceptProposal,
                    onRejectProposal: _rejectProposal,
                    onOpenDonation: (donationId) =>
                        GoRouter.maybeOf(context)?.push('/donations/$donationId'),
                    onRequestItem: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => RequestItemSheet(publicationId: pub.id),
                    ),
                    onOfferItem: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => OfferItemSheet(publicationId: pub.id),
                    ),
                    onGoLogin: () => GoRouter.maybeOf(context)?.go('/login'),
                    theme: theme,
                  ),
          ),
        ],
      ),
    );
  }
}

class _MissingPublicationView extends StatelessWidget {
  final VoidCallback onBack;

  const _MissingPublicationView({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_outlined, size: 48),
            const SizedBox(height: 12),
            const Text('Publicación no encontrada'),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onBack,
              child: const Text('Volver al inicio'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final PublicacionMock publication;
  final MockTenantStore store;
  final String? actionError;
  final bool isWithdrawing;
  final String? busyProposalId;
  final DonacionMock? acceptedDonation;
  final VoidCallback onEdit;
  final VoidCallback onWithdraw;
  final ValueChanged<PropuestaMock> onAcceptProposal;
  final ValueChanged<PropuestaMock> onRejectProposal;
  final ValueChanged<String> onOpenDonation;
  final VoidCallback onRequestItem;
  final VoidCallback onOfferItem;
  final VoidCallback onGoLogin;
  final ThemeData theme;

  const _DetailBody({
    required this.publication,
    required this.store,
    required this.actionError,
    required this.isWithdrawing,
    required this.busyProposalId,
    required this.acceptedDonation,
    required this.onEdit,
    required this.onWithdraw,
    required this.onAcceptProposal,
    required this.onRejectProposal,
    required this.onOpenDonation,
    required this.onRequestItem,
    required this.onOfferItem,
    required this.onGoLogin,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final category = store.findCategoryById(publication.categoriaId);
    final author = store.findUserById(publication.autorId);
    final activeUser = store.activeUser;
    final distanceKm = store.getDistanceForPublication(publication);
    final isNeed = publication.tipo == TipoPublicacion.necesidad;
    final isAuthor = activeUser?.id == publication.autorId;
    final highContrast = theme.colorScheme.outline == Colors.black;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (publication.fotografias.isNotEmpty) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < publication.fotografias.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        PublicationPhotoPlaceholder(
                          photoPath: publication.fotografias[i],
                          width: 150,
                          height: 124,
                          isPrimary: i == 0,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: categoryTintForKey(
                      category?.iconoClave ?? 'category',
                      highContrast: highContrast,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        iconForCategoryKey(category?.iconoClave ?? 'category'),
                        size: 32,
                        color: highContrast
                            ? Colors.black
                            : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          category?.nombre ?? 'Publicación comunitaria',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: highContrast
                                ? Colors.black
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                            label: Text(
                              '${isNeed ? 'NECESIDAD' : 'ARTÍCULO'} · ${(category?.nombre ?? 'Categoría').toUpperCase()}',
                            ),
                          ),
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              'Estado: ${labelForEstadoPublicacion(publication.estado)}',
                            ),
                          ),
                          if (isNeed)
                            UrgencyBadge(
                              urgencia: publication.urgencia ?? Urgencia.baja,
                            ),
                        ],
                      ),
                      if (publication.gestionadaPorIntermediario) ...[
                        const SizedBox(height: 10),
                        IntermediaryBadge(
                          aliasBeneficiario: publication.aliasBeneficiario,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        publication.titulo,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        publication.descripcion,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const Divider(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          _DetailSpecChip(
                            icon: Icons.numbers_outlined,
                            label: isNeed
                                ? 'Cantidad requerida'
                                : 'Cantidad disponible',
                            value: '${publication.cantidad}',
                          ),
                          if (isNeed || publication.condicion != null)
                            _DetailSpecChip(
                              icon: Icons.verified_outlined,
                              label: isNeed
                                  ? 'Condición aceptable'
                                  : 'Estado físico',
                              value: publication.condicion == null
                                  ? 'Cualquiera'
                                  : labelForCondicion(publication.condicion!),
                            ),
                          _DetailSpecChip(
                            icon: Icons.location_on_outlined,
                            label: store.isDeviceLocationAuthorized
                                ? 'Distancia (dispositivo)'
                                : 'Distancia aproximada',
                            value:
                                '${distanceKm.toStringAsFixed(1)} km · ${publication.ubicacion.etiqueta}',
                          ),
                        ],
                      ),
                      if (publication.caracteristicas.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          'Características',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final entry in publication.caracteristicas.entries)
                          Text('• ${entry.key}: ${entry.value}'),
                      ],
                    ],
                  ),
                ),
              ),
              if (author != null) ...[
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isNeed ? 'Publicado por' : 'Donante',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ProfileAvatarCircle(
                              nombreLegal: author.nombreLegal,
                              fotoPerfil: author.fotoPerfil,
                              radius: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    author.nombreLegal,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    '@${author.nombreUsuario}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  TrustBadgeChip(usuario: author),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (actionError != null) ...[
                const SizedBox(height: 14),
                PublicationStatusBanner(
                  message: actionError!,
                  tone: PublicationBannerTone.error,
                ),
              ],
              if (acceptedDonation != null)
                Builder(
                  builder: (_) {
                    final liveDonation = store.findDonationById(
                      acceptedDonation!.id,
                    );
                    final showBanner =
                        liveDonation != null &&
                        liveDonation.estado != EstadoDonacion.cancelada &&
                        liveDonation.publicacionId == publication.id &&
                        (activeUser?.id == liveDonation.donanteId ||
                            activeUser?.id == liveDonation.donatarioId ||
                            activeUser?.id == liveDonation.intermediarioId);
                    if (!showBanner) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: PublicationStatusBanner(
                        message:
                            '¡Propuesta aceptada! Se inició la donación ${liveDonation.id}.',
                        tone: PublicationBannerTone.success,
                        trailing: FilledButton.icon(
                          onPressed: () => onOpenDonation(liveDonation.id),
                          icon: const Icon(Icons.local_shipping_outlined),
                          label: const Text('Ver seguimiento de donación'),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 16),
              _buildActionArea(
                activeUser: activeUser,
                isAuthor: isAuthor,
                isNeed: isNeed,
              ),
              if (isAuthor &&
                  activeUser != null &&
                  publication.estado == EstadoPublicacion.activa) ...[
                const SizedBox(height: 20),
                _buildAuthorProposalsSection(activeUser),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionArea({
    required UsuarioMock? activeUser,
    required bool isAuthor,
    required bool isNeed,
  }) {
    if (activeUser == null) {
      return PublicationStatusBanner(
        message: 'Inicia sesión para responder o administrar esta publicación.',
        tone: PublicationBannerTone.info,
        trailing: FilledButton(
          onPressed: onGoLogin,
          child: const Text('Iniciar sesión'),
        ),
      );
    }

    if (isAuthor) {
      if (publication.estado == EstadoPublicacion.activa) {
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              key: const Key('detail_edit_publication_button'),
              onPressed: isWithdrawing ? null : onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar publicación'),
            ),
            OutlinedButton.icon(
              key: const Key('detail_withdraw_publication_button'),
              onPressed: isWithdrawing ? null : onWithdraw,
              icon: const Icon(Icons.delete_outline),
              label: Text(
                isWithdrawing ? 'Retirando...' : 'Retirar publicación',
              ),
            ),
          ],
        );
      }

      if (publication.estado == EstadoPublicacion.reservada ||
          publication.estado == EstadoPublicacion.cerrada) {
        return PublicationStatusBanner(
          message:
              'Esta publicación está ${labelForEstadoPublicacion(publication.estado).toLowerCase()} y no puede editarse ni retirarse.',
          tone: PublicationBannerTone.warning,
        );
      }

      return const PublicationStatusBanner(
        message: 'Esta publicación fue retirada por su autor.',
        tone: PublicationBannerTone.info,
      );
    }

    if (publication.estado != EstadoPublicacion.activa) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PublicationStatusBanner(
            message: isNeed
                ? 'Esta necesidad ya no está activa'
                : 'Este artículo ya no está disponible',
            tone: PublicationBannerTone.warning,
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: null,
            child: Text(isNeed ? 'Ofrecer artículo' : 'Solicitar artículo'),
          ),
        ],
      );
    }

    final hasPending = store.hasPendingProposal(
      publicationId: publication.id,
      userId: activeUser.id,
    );
    if (hasPending) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PublicationStatusBanner(
            message: isNeed
                ? 'Ya enviaste una Oferta pendiente para esta necesidad'
                : 'Ya tienes una Solicitud pendiente para este artículo',
            tone: PublicationBannerTone.info,
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: null,
            child: Text(isNeed ? 'Ofrecer artículo' : 'Solicitar artículo'),
          ),
        ],
      );
    }

    if (isNeed) {
      return FilledButton.icon(
        key: const Key('detail_offer_item_button'),
        onPressed: onOfferItem,
        icon: const Icon(Icons.volunteer_activism_outlined),
        label: const Text('Ofrecer artículo'),
      );
    }

    return FilledButton.icon(
      key: const Key('detail_request_item_button'),
      onPressed: onRequestItem,
      icon: const Icon(Icons.send_outlined),
      label: const Text('Solicitar artículo'),
    );
  }

  Widget _buildAuthorProposalsSection(UsuarioMock activeUser) {
    final pending = store.getReceivedPendingProposals(
      activeUser.id,
      publicationId: publication.id,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Propuestas recibidas (${pending.length})',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        if (pending.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Aún no tienes propuestas pendientes para esta publicación.',
              ),
            ),
          )
        else
          for (final proposal in pending) ...[
            ReceivedProposalCard(
              proposal: proposal,
              publication: publication,
              sender: store.findUserById(proposal.remitenteId),
              showPublicationTitle: false,
              isBusy: busyProposalId == proposal.id,
              onAccept: () => onAcceptProposal(proposal),
              onReject: () => onRejectProposal(proposal),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _DetailSpecChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailSpecChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: theme.textTheme.labelSmall),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

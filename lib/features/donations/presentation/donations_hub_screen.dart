import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_exceptions.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/features/donations/presentation/donation_ui_helpers.dart';
import 'package:donaciones/features/proposals/presentation/received_proposal_card.dart';
import 'package:donaciones/features/publications/presentation/publication_ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Hub screen with 3 sub-tabs: Propuestas, En curso, and Historial (CU-25..CU-30, CU-38, CU-39).
class DonationsHubScreen extends ConsumerStatefulWidget {
  const DonationsHubScreen({super.key});

  @override
  ConsumerState<DonationsHubScreen> createState() => _DonationsHubScreenState();
}

class _DonationsHubScreenState extends ConsumerState<DonationsHubScreen> {
  final _pendingAcceptKeys = PendingActionKeys();
  String? _busyProposalId;
  String? _actionError;
  DonacionMock? _acceptedDonation;

  PapelDonacion? _historyRoleFilter;
  EstadoDonacion? _historyStateFilter;

  void _goRoute(String route, {bool push = false}) {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    if (push) {
      context.push(route);
    } else {
      context.go(route);
    }
  }

  Future<void> _acceptProposal(PropuestaMock proposal) async {
    if (_busyProposalId != null) return;
    final store = ref.read(mockTenantStoreProvider);
    final opKey = 'hub-acc-${proposal.id}';
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
  }

  Future<void> _rejectProposal(PropuestaMock proposal) async {
    if (_busyProposalId != null) return;
    final reason = await showRejectProposalReasonDialog(context);
    if (reason == null || !mounted) return;

    final store = ref.read(mockTenantStoreProvider);
    setState(() {
      _busyProposalId = proposal.id;
      _actionError = null;
      _acceptedDonation = null;
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

  Future<void> _withdrawProposal(PropuestaMock proposal) async {
    if (_busyProposalId != null) return;
    final store = ref.read(mockTenantStoreProvider);
    setState(() {
      _busyProposalId = proposal.id;
      _actionError = null;
      _acceptedDonation = null;
    });

    try {
      await store.withdrawProposal(proposal.id);
      if (!mounted) return;
      setState(() => _busyProposalId = null);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Propuesta retirada correctamente.')),
      );
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        _busyProposalId = null;
        _actionError = e.message;
      });
    } on ValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _busyProposalId = null;
        _actionError = e.message;
      });
    } on UnauthorizedActionException catch (e) {
      if (!mounted) return;
      setState(() {
        _busyProposalId = null;
        _actionError = e.message;
      });
    }
  }

  DonacionMock? _findDonationForProposal(
    MockTenantStore store,
    String proposalId,
  ) {
    for (final d in store.donations) {
      if (d.propuestaId == proposalId) return d;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(mockTenantStoreProvider);
    final activeUser = store.activeUser;
    final theme = Theme.of(context);

    if (activeUser == null) {
      return _LoggedOutDonationsView(
        onLogin: () => _goRoute('/login'),
        onRegister: () => _goRoute('/register'),
      );
    }

    final receivedProposals = store.getReceivedPendingProposals(activeUser.id);
    final sentProposals = store.getSentProposals(activeUser.id).reversed.toList();
    final activeDonations = store.getActiveDonationsForUser(activeUser.id);
    final historyDonations = store.getDonationHistoryForUser(
      activeUser.id,
      role: _historyRoleFilter,
      finalState: _historyStateFilter,
    );

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Material(
            color: Colors.white,
            child: TabBar(
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurface.withValues(
                alpha: 0.72,
              ),
              indicatorColor: theme.colorScheme.secondary,
              tabs: const [
                Tab(
                  key: Key('donations_tab_proposals'),
                  text: 'Propuestas',
                ),
                Tab(
                  key: Key('donations_tab_active'),
                  text: 'En curso',
                ),
                Tab(
                  key: Key('donations_tab_history'),
                  text: 'Historial',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildProposalsTab(
                  context: context,
                  store: store,
                  received: receivedProposals,
                  sent: sentProposals,
                ),
                _buildActiveDonationsTab(
                  context: context,
                  store: store,
                  activeUser: activeUser,
                  activeDonations: activeDonations,
                ),
                _buildHistoryTab(
                  context: context,
                  store: store,
                  activeUser: activeUser,
                  historyDonations: historyDonations,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProposalsTab({
    required BuildContext context,
    required MockTenantStore store,
    required List<PropuestaMock> received,
    required List<PropuestaMock> sent,
  }) {
    final theme = Theme.of(context);
    final liveAcceptedDonation = _acceptedDonation == null
        ? null
        : store.findDonationById(_acceptedDonation!.id);
    final showAcceptedBanner =
        liveAcceptedDonation != null &&
        liveAcceptedDonation.estado != EstadoDonacion.cancelada &&
        (store.activeUser?.id == liveAcceptedDonation.donanteId ||
            store.activeUser?.id == liveAcceptedDonation.donatarioId ||
            store.activeUser?.id == liveAcceptedDonation.intermediarioId);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 740),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_actionError != null) ...[
                  PublicationStatusBanner(
                    message: _actionError!,
                    tone: PublicationBannerTone.error,
                  ),
                  const SizedBox(height: 12),
                ],
                if (showAcceptedBanner) ...[
                  PublicationStatusBanner(
                    message:
                        '¡Propuesta aceptada! Se inició la donación ${liveAcceptedDonation.id}.',
                    tone: PublicationBannerTone.success,
                    trailing: FilledButton.icon(
                      key: const Key('accepted_donation_track_button'),
                      onPressed: () => _goRoute(
                        '/donations/${liveAcceptedDonation.id}',
                        push: true,
                      ),
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: const Text('Ver seguimiento'),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Text(
                  'Propuestas recibidas (${received.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                if (received.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No tienes propuestas recibidas pendientes.',
                      ),
                    ),
                  )
                else
                  for (final proposal in received) ...[
                    ReceivedProposalCard(
                      proposal: proposal,
                      publication: store.findPublicationById(
                        proposal.publicacionId,
                      ),
                      sender: store.findUserById(proposal.remitenteId),
                      isBusy: _busyProposalId == proposal.id,
                      onAccept: () => _acceptProposal(proposal),
                      onReject: () => _rejectProposal(proposal),
                      onOpenPublication: () => _goRoute(
                        '/publications/${proposal.publicacionId}',
                        push: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                const SizedBox(height: 18),
                Text(
                  'Propuestas enviadas (${sent.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                if (sent.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Aún no has enviado propuestas.'),
                    ),
                  )
                else
                  for (final proposal in sent) ...[
                    _SentProposalCard(
                      proposal: proposal,
                      publication: store.findPublicationById(
                        proposal.publicacionId,
                      ),
                      author: () {
                        final pub = store.findPublicationById(
                          proposal.publicacionId,
                        );
                        return pub == null
                            ? null
                            : store.findUserById(pub.autorId);
                      }(),
                      linkedDonation: proposal.estado == EstadoPropuesta.aceptada
                          ? _findDonationForProposal(store, proposal.id)
                          : null,
                      isBusy: _busyProposalId == proposal.id,
                      onWithdraw: () => _withdrawProposal(proposal),
                      onOpenDonation: (donationId) =>
                          _goRoute('/donations/$donationId', push: true),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveDonationsTab({
    required BuildContext context,
    required MockTenantStore store,
    required UsuarioMock activeUser,
    required List<DonacionMock> activeDonations,
  }) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 740),
            child: activeDonations.isEmpty
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(Icons.local_shipping_outlined, size: 42),
                          SizedBox(height: 10),
                          Text(
                            'No tienes donaciones en curso por ahora.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final donation in activeDonations) ...[
                        _ActiveDonationCard(
                          donation: donation,
                          publication: store.findPublicationById(
                            donation.publicacionId,
                          ),
                          counterpart: store.findUserById(
                            activeUser.id == donation.donanteId
                                ? donation.donatarioId
                                : donation.donanteId,
                          ),
                          roleLabel: activeUser.id == donation.donanteId
                              ? 'Como donante'
                              : (activeUser.id == donation.intermediarioId
                                    ? 'Como intermediario'
                                    : 'Como donatario'),
                          onOpenTracking: () => _goRoute(
                            '/donations/${donation.id}',
                            push: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab({
    required BuildContext context,
    required MockTenantStore store,
    required UsuarioMock activeUser,
    required List<DonacionMock> historyDonations,
  }) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 740),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Filtrar historial (CU-39)',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              key: const Key('history_clear_filters_button'),
                              onPressed: () => setState(() {
                                _historyRoleFilter = null;
                                _historyStateFilter = null;
                              }),
                              icon: const Icon(
                                Icons.filter_alt_off_outlined,
                                size: 18,
                              ),
                              label: const Text('Quitar filtros'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Papel',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              key: const Key('history_role_all'),
                              label: const Text('Todos los papeles'),
                              selected: _historyRoleFilter == null,
                              onSelected: (_) =>
                                  setState(() => _historyRoleFilter = null),
                            ),
                            ChoiceChip(
                              key: const Key('history_role_donante'),
                              label: const Text('Como donante'),
                              selected:
                                  _historyRoleFilter == PapelDonacion.donante,
                              onSelected: (_) => setState(
                                () =>
                                    _historyRoleFilter = PapelDonacion.donante,
                              ),
                            ),
                            ChoiceChip(
                              key: const Key('history_role_donatario'),
                              label: const Text('Como donatario'),
                              selected:
                                  _historyRoleFilter == PapelDonacion.donatario,
                              onSelected: (_) => setState(
                                () => _historyRoleFilter =
                                    PapelDonacion.donatario,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Estado',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              key: const Key('history_state_all'),
                              label: const Text('Todos los estados'),
                              selected: _historyStateFilter == null,
                              onSelected: (_) =>
                                  setState(() => _historyStateFilter = null),
                            ),
                            ChoiceChip(
                              key: const Key('history_state_finalizada'),
                              label: const Text('Finalizadas'),
                              selected:
                                  _historyStateFilter ==
                                  EstadoDonacion.finalizada,
                              onSelected: (_) => setState(
                                () => _historyStateFilter =
                                    EstadoDonacion.finalizada,
                              ),
                            ),
                            ChoiceChip(
                              key: const Key('history_state_cancelada'),
                              label: const Text('Canceladas'),
                              selected:
                                  _historyStateFilter ==
                                  EstadoDonacion.cancelada,
                              onSelected: (_) => setState(
                                () => _historyStateFilter =
                                    EstadoDonacion.cancelada,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Historial de donaciones (${historyDonations.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                if (historyDonations.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No hay donaciones en el historial con los filtros seleccionados.',
                      ),
                    ),
                  )
                else
                  for (final donation in historyDonations) ...[
                    _HistoryDonationCard(
                      donation: donation,
                      publication: store.findPublicationById(
                        donation.publicacionId,
                      ),
                      counterpart: store.findUserById(
                        activeUser.id == donation.donanteId
                            ? donation.donatarioId
                            : donation.donanteId,
                      ),
                      roleLabel: activeUser.id == donation.donanteId
                          ? 'Como donante'
                          : 'Como donatario',
                      onTap: () =>
                          _goRoute('/donations/${donation.id}', push: true),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LoggedOutDonationsView extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  const _LoggedOutDonationsView({
    required this.onLogin,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.volunteer_activism_outlined,
                    size: 52,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Inicia sesión para gestionar tus donaciones',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Consulta propuestas enviadas y recibidas, coordina entregas y revisa tu historial.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: onLogin,
                    child: const Text('Iniciar sesión'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: onRegister,
                    child: const Text('Registrarse'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SentProposalCard extends StatelessWidget {
  final PropuestaMock proposal;
  final PublicacionMock? publication;
  final UsuarioMock? author;
  final DonacionMock? linkedDonation;
  final bool isBusy;
  final VoidCallback onWithdraw;
  final ValueChanged<String> onOpenDonation;

  const _SentProposalCard({
    required this.proposal,
    required this.publication,
    required this.author,
    required this.linkedDonation,
    required this.isBusy,
    required this.onWithdraw,
    required this.onOpenDonation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOffer = proposal.tipo == TipoPropuesta.oferta;

    return Card(
      key: Key('sent_proposal_${proposal.id}'),
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
                ProposalStatusBadge(estado: proposal.estado),
                Text(
                  formatDonationDateTime(proposal.fechaEnvio),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              publication?.titulo ?? 'Publicación ${proposal.publicacionId}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (author != null) ...[
              const SizedBox(height: 2),
              Text(
                'Autor: ${author!.nombreLegal} (@${author!.nombreUsuario})',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Text(proposal.texto, style: theme.textTheme.bodyMedium),
            if (proposal.fotografias.isNotEmpty) ...[
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < proposal.fotografias.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      PublicationPhotoPlaceholder(
                        photoPath: proposal.fotografias[i],
                        width: 100,
                        height: 84,
                        isPrimary: i == 0,
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (proposal.estado == EstadoPropuesta.rechazada &&
                proposal.motivoRechazo != null) ...[
              const SizedBox(height: 8),
              Text(
                'Motivo del rechazo: ${proposal.motivoRechazo}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (proposal.estado == EstadoPropuesta.pendiente) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: Key('withdraw_proposal_${proposal.id}'),
                onPressed: isBusy ? null : onWithdraw,
                icon: const Icon(Icons.undo),
                label: Text(isBusy ? 'Retirando...' : 'Retirar'),
              ),
            ] else if (linkedDonation != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => onOpenDonation(linkedDonation!.id),
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Ver seguimiento'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActiveDonationCard extends StatelessWidget {
  final DonacionMock donation;
  final PublicacionMock? publication;
  final UsuarioMock? counterpart;
  final String roleLabel;
  final VoidCallback onOpenTracking;

  const _ActiveDonationCard({
    required this.donation,
    required this.publication,
    required this.counterpart,
    required this.roleLabel,
    required this.onOpenTracking,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: Key('active_donation_${donation.id}'),
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
                DonationStatusBadge(estado: donation.estado),
                Chip(visualDensity: VisualDensity.compact, label: Text(roleLabel)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              publication?.titulo ?? 'Donación ${donation.id}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (counterpart != null) ...[
              const SizedBox(height: 4),
              Text(
                'Contraparte: ${counterpart!.nombreLegal} (@${counterpart!.nombreUsuario})',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (donation.lugarEntrega != null &&
                donation.fechaEntregaAcordada != null) ...[
              const SizedBox(height: 6),
              Text(
                'Entrega: ${donation.lugarEntrega} · ${formatDonationDateTime(donation.fechaEntregaAcordada!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 10),
            DonationProgressTimeline(estado: donation.estado),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: Key('open_donation_${donation.id}'),
              onPressed: onOpenTracking,
              icon: const Icon(Icons.local_shipping_outlined),
              label: const Text('Ver seguimiento completo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryDonationCard extends StatelessWidget {
  final DonacionMock donation;
  final PublicacionMock? publication;
  final UsuarioMock? counterpart;
  final String roleLabel;
  final VoidCallback onTap;

  const _HistoryDonationCard({
    required this.donation,
    required this.publication,
    required this.counterpart,
    required this.roleLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final closingDate =
        donation.fechaFinalizacion ??
        (donation.historialCambios.isNotEmpty
            ? donation.historialCambios.last.fechaHora
            : null);

    return Card(
      key: Key('history_donation_${donation.id}'),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DonationStatusBadge(estado: donation.estado),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(roleLabel),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                publication?.titulo ?? 'Donación ${donation.id}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (counterpart != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Contraparte: ${counterpart!.nombreLegal} (@${counterpart!.nombreUsuario})',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (closingDate != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Fecha: ${formatDonationDateTime(closingDate)}',
                  style: theme.textTheme.labelSmall,
                ),
              ],
              if (donation.estado == EstadoDonacion.cancelada &&
                  donation.motivoCancelacion != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Motivo: ${donation.motivoCancelacion}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

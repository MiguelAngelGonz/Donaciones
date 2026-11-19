import 'package:donaciones/app/theme.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_exceptions.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/core/widgets/demo_tenant_toolbar.dart';
import 'package:donaciones/features/donations/presentation/donation_ui_helpers.dart';
import 'package:donaciones/features/publications/presentation/publication_ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Administration panel covering intermediary approvals/revocations (CU-42..45)
/// and dynamic category management (CU-48..51).
class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen> {
  final _newCategoryController = TextEditingController();
  String? _newCategoryError;
  String? _actionError;
  String? _actionSuccess;
  bool _isBusy = false;

  @override
  void dispose() {
    _newCategoryController.dispose();
    super.dispose();
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

  void _goHome() {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      context.go('/');
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).round()} KB';
    }
    return '$bytes B';
  }

  Future<void> _runAdminAction(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _actionError = null;
      _actionSuccess = null;
    });

    try {
      await action();
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _actionSuccess = successMessage;
      });
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _actionError = e.message;
      });
    } on ValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _actionError = e.message;
      });
    } on UnauthorizedActionException catch (e) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _actionError = e.message;
      });
    }
  }

  Future<void> _approveRequest(
    MockTenantStore store,
    SolicitudRolIntermediarioMock req,
  ) async {
    await _runAdminAction(
      () => store.approveIntermediaryRequest(req.id),
      successMessage:
          'Solicitud aprobada. El usuario ya es intermediario autorizado.',
    );
  }

  Future<void> _rejectRequest(
    MockTenantStore store,
    SolicitudRolIntermediarioMock req,
  ) async {
    if (_isBusy) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RejectIntermediaryDialog(organization: req.organizacion),
    );
    if (reason == null || !mounted) return;

    await _runAdminAction(
      () => store.rejectIntermediaryRequest(req.id, reason: reason),
      successMessage: 'Solicitud para "${req.organizacion}" rechazada.',
    );
  }

  Future<void> _revokeIntermediary(
    MockTenantStore store,
    UsuarioMock user,
  ) async {
    if (_isBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Revocar rol de intermediario?'),
        content: Text(
          'Se revocará el rol de intermediario de ${user.nombreLegal} (@${user.nombreUsuario}). Sus Necesidades activas gestionadas para beneficiarios pasarán a estado Retirada; las donaciones en curso continuarán normalmente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirm_revoke_intermediary_button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmar revocación'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _runAdminAction(
      () => store.revokeIntermediaryRole(user.id),
      successMessage:
          'Rol de intermediario revocado para ${user.nombreLegal}.',
    );
  }

  Future<void> _createCategory(MockTenantStore store) async {
    if (_isBusy) return;
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _newCategoryError = 'El nombre de la categoría es obligatorio.';
        _actionError = null;
        _actionSuccess = null;
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _newCategoryError = null;
      _actionError = null;
      _actionSuccess = null;
    });

    try {
      final created = await store.createCategory(name: name);
      if (!mounted) return;
      _newCategoryController.clear();
      setState(() {
        _isBusy = false;
        _actionSuccess = 'Categoría "${created.nombre}" creada correctamente.';
      });
    } on ValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _newCategoryError = e.message;
      });
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _actionError = e.message;
      });
    } on UnauthorizedActionException catch (e) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _actionError = e.message;
      });
    }
  }

  Future<void> _renameCategory(
    MockTenantStore store,
    CategoriaMock category,
  ) async {
    if (_isBusy) return;
    final renamed = await showDialog<CategoriaMock>(
      context: context,
      builder: (_) => _RenameCategoryDialog(
        initialName: category.nombre,
        onConfirm: (newName) => store.renameCategory(
          categoryId: category.id,
          newName: newName,
        ),
      ),
    );
    if (renamed == null || !mounted) return;
    setState(() {
      _actionError = null;
      _actionSuccess = 'Categoría renombrada a "${renamed.nombre}".';
    });
  }

  Future<void> _deactivateCategory(
    MockTenantStore store,
    CategoriaMock category,
  ) async {
    if (_isBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('¿Desactivar categoría "${category.nombre}"?'),
        content: const Text(
          'Dejará de ofrecerse al crear o editar publicaciones, pero las publicaciones existentes conservarán su categoría y seguirán visibles.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirm_deactivate_category_button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmar desactivación'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _runAdminAction(
      () => store.deactivateCategory(category.id),
      successMessage: 'Categoría "${category.nombre}" desactivada.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(mockTenantStoreProvider);
    final activeUser = store.activeUser;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigateBack,
        ),
        title: const Text('Panel de Administración'),
      ),
      body: Column(
        children: [
          const DemoTenantToolbar(),
          Expanded(
            child: activeUser?.esAdministrador != true
                ? _UnauthorizedAdminGuard(
                    activeUser: activeUser,
                    onGoHome: _goHome,
                  )
                : DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        Material(
                          color: Colors.white,
                          child: TabBar(
                            labelColor: theme.colorScheme.primary,
                            unselectedLabelColor: theme.colorScheme.onSurface
                                .withValues(alpha: 0.72),
                            indicatorColor: theme.colorScheme.secondary,
                            tabs: const [
                              Tab(
                                key: Key('admin_tab_intermediaries'),
                                text: 'Intermediarios',
                              ),
                              Tab(
                                key: Key('admin_tab_categories'),
                                text: 'Categorías',
                              ),
                            ],
                          ),
                        ),
                        if (_actionError != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: PublicationStatusBanner(
                              message: _actionError!,
                              tone: PublicationBannerTone.error,
                            ),
                          )
                        else if (_actionSuccess != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: PublicationStatusBanner(
                              message: _actionSuccess!,
                              tone: PublicationBannerTone.success,
                            ),
                          ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildIntermediariesTab(context, store),
                              _buildCategoriesTab(context, store),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntermediariesTab(BuildContext context, MockTenantStore store) {
    final theme = Theme.of(context);
    final pendingRequests = store.intermediaryRequests
        .where((r) => r.estado == EstadoSolicitudRol.pendiente)
        .toList()
      ..sort((a, b) => b.fechaSolicitud.compareTo(a.fechaSolicitud));

    final authorizedUsers = store.users
        .where((u) => u.esIntermediario)
        .toList();

    final resolvedRequests = store.intermediaryRequests
        .where((r) => r.estado != EstadoSolicitudRol.pendiente)
        .toList()
      ..sort((a, b) {
        final dateA = a.fechaDecision ?? a.fechaSolicitud;
        final dateB = b.fechaDecision ?? b.fechaSolicitud;
        return dateB.compareTo(dateA);
      });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 740),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Solicitudes pendientes (${pendingRequests.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                if (pendingRequests.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No hay solicitudes de intermediario pendientes.',
                      ),
                    ),
                  )
                else
                  for (final req in pendingRequests) ...[
                    _PendingRequestCard(
                      request: req,
                      applicant: store.findUserById(req.usuarioId),
                      documentSizeLabel: _formatBytes(
                        req.documentoBytesSimulados,
                      ),
                      isBusy: _isBusy,
                      onApprove: () => _approveRequest(store, req),
                      onReject: () => _rejectRequest(store, req),
                    ),
                    const SizedBox(height: 10),
                  ],
                const SizedBox(height: 16),
                Text(
                  'Intermediarios autorizados (${authorizedUsers.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                if (authorizedUsers.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No hay intermediarios autorizados actualmente.',
                      ),
                    ),
                  )
                else
                  for (final user in authorizedUsers) ...[
                    _AuthorizedIntermediaryCard(
                      user: user,
                      organization: _latestApprovedOrgFor(store, user.id),
                      managedActiveNeedsCount: store.publications
                          .where(
                            (p) =>
                                p.autorId == user.id &&
                                p.tipo == TipoPublicacion.necesidad &&
                                p.gestionadaPorIntermediario &&
                                p.estado == EstadoPublicacion.activa,
                          )
                          .length,
                      isBusy: _isBusy,
                      onRevoke: () => _revokeIntermediary(store, user),
                    ),
                    const SizedBox(height: 10),
                  ],
                if (resolvedRequests.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Historial de decisiones (${resolvedRequests.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final req in resolvedRequests) ...[
                    _ResolvedRequestCard(
                      request: req,
                      applicant: store.findUserById(req.usuarioId),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _latestApprovedOrgFor(MockTenantStore store, String userId) {
    final approved = store.intermediaryRequests.where(
      (r) =>
          r.usuarioId == userId && r.estado == EstadoSolicitudRol.aprobada,
    );
    if (approved.isEmpty) return 'Organización comunitaria verificada';
    return approved.last.organizacion;
  }

  Widget _buildCategoriesTab(BuildContext context, MockTenantStore store) {
    final theme = Theme.of(context);
    final categories = store.categories;

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
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Crear nueva categoría (CU-49)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          key: const Key('admin_new_category_field'),
                          controller: _newCategoryController,
                          enabled: !_isBusy,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) {
                            if (_newCategoryError != null) {
                              setState(() => _newCategoryError = null);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Nombre de la nueva categoría',
                            hintText: 'Ej. Tecnología Escolar',
                            prefixIcon: const Icon(Icons.category_outlined),
                            errorText: _newCategoryError,
                            errorMaxLines: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            key: const Key('admin_create_category_button'),
                            onPressed: _isBusy
                                ? null
                                : () => _createCategory(store),
                            icon: const Icon(Icons.add),
                            label: const Text('Crear categoría'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Categorías registradas (${categories.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                for (final category in categories) ...[
                  _CategoryAdminCard(
                    category: category,
                    associatedPublicationsCount: store.publications
                        .where((p) => p.categoriaId == category.id)
                        .length,
                    isBusy: _isBusy,
                    onRename: () => _renameCategory(store, category),
                    onDeactivate: () => _deactivateCategory(store, category),
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

class _UnauthorizedAdminGuard extends StatelessWidget {
  final UsuarioMock? activeUser;
  final VoidCallback onGoHome;

  const _UnauthorizedAdminGuard({
    required this.activeUser,
    required this.onGoHome,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 52,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Acceso restringido a administradores',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    activeUser == null
                        ? 'Inicia sesión con una cuenta de administrador para gestionar intermediarios y categorías.'
                        : 'La cuenta @${activeUser!.nombreUsuario} no cuenta con permisos de administrador.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    key: const Key('admin_unauthorized_home_button'),
                    onPressed: onGoHome,
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('Volver al inicio'),
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

class _PendingRequestCard extends StatelessWidget {
  final SolicitudRolIntermediarioMock request;
  final UsuarioMock? applicant;
  final String documentSizeLabel;
  final bool isBusy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingRequestCard({
    required this.request,
    required this.applicant,
    required this.documentSizeLabel,
    required this.isBusy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final applicantName = applicant?.nombreLegal ?? request.usuarioId;
    final applicantHandle =
        applicant != null ? '@${applicant!.nombreUsuario}' : request.usuarioId;

    return Card(
      key: Key('pending_request_${request.id}'),
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
                const _RoleStatusPill(estado: EstadoSolicitudRol.pendiente),
                Text(
                  formatDonationDateTime(request.fechaSolicitud),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              applicantName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(applicantHandle, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.groups_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    request.organizacion,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.attach_file,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${request.documentoNombre} · $documentSizeLabel',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: Key('approve_request_${request.id}'),
                  onPressed: isBusy ? null : onApprove,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Aprobar'),
                ),
                OutlinedButton.icon(
                  key: Key('reject_request_${request.id}'),
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

class _AuthorizedIntermediaryCard extends StatelessWidget {
  final UsuarioMock user;
  final String organization;
  final int managedActiveNeedsCount;
  final bool isBusy;
  final VoidCallback onRevoke;

  const _AuthorizedIntermediaryCard({
    required this.user,
    required this.organization,
    required this.managedActiveNeedsCount,
    required this.isBusy,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: Key('authorized_intermediary_${user.id}'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.nombreLegal,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '@${user.nombreUsuario} · ${user.ubicacionAproximada.etiqueta}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              organization,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Necesidades activas por beneficiario: $managedActiveNeedsCount',
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                key: Key('revoke_intermediary_${user.id}'),
                onPressed: isBusy ? null : onRevoke,
                icon: const Icon(Icons.remove_moderator_outlined),
                label: const Text('Revocar rol'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResolvedRequestCard extends StatelessWidget {
  final SolicitudRolIntermediarioMock request;
  final UsuarioMock? applicant;

  const _ResolvedRequestCard({required this.request, required this.applicant});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = applicant?.nombreLegal ?? request.usuarioId;
    final date = request.fechaDecision ?? request.fechaSolicitud;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _RoleStatusPill(estado: request.estado),
                Text(
                  formatDonationDateTime(date),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$name — ${request.organizacion}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (request.motivoDecision != null &&
                request.motivoDecision!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Motivo: ${request.motivoDecision}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoleStatusPill extends StatelessWidget {
  final EstadoSolicitudRol estado;

  const _RoleStatusPill({required this.estado});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highContrast = theme.colorScheme.outline == Colors.black;

    final (String label, Color bg, Color border, Color fg) = switch (estado) {
      EstadoSolicitudRol.pendiente => (
        'Pendiente',
        highContrast ? DonaPlusColors.accentYellow : const Color(0xFFFFF4DC),
        highContrast ? Colors.black : const Color(0xFFB26A00),
        highContrast ? Colors.black : const Color(0xFF8C5200),
      ),
      EstadoSolicitudRol.aprobada => (
        'Aprobada',
        highContrast
            ? DonaPlusColors.accentMint
            : DonaPlusColors.accentMint.withValues(alpha: 0.55),
        highContrast ? Colors.black : DonaPlusColors.primary,
        highContrast ? Colors.black : DonaPlusColors.primary,
      ),
      EstadoSolicitudRol.rechazada => (
        'Rechazada',
        theme.colorScheme.errorContainer,
        highContrast ? Colors.black : theme.colorScheme.error,
        highContrast ? Colors.black : theme.colorScheme.onErrorContainer,
      ),
      EstadoSolicitudRol.revocada => (
        'Revocada',
        theme.colorScheme.surfaceContainerHighest,
        highContrast ? Colors.black : theme.colorScheme.outline,
        theme.colorScheme.onSurface,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: highContrast ? 1.5 : 1.0),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CategoryAdminCard extends StatelessWidget {
  final CategoriaMock category;
  final int associatedPublicationsCount;
  final bool isBusy;
  final VoidCallback onRename;
  final VoidCallback onDeactivate;

  const _CategoryAdminCard({
    required this.category,
    required this.associatedPublicationsCount,
    required this.isBusy,
    required this.onRename,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highContrast = theme.colorScheme.outline == Colors.black;

    return Card(
      key: Key('admin_category_${category.id}'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: categoryTintForKey(
                      category.iconoClave,
                      highContrast: highContrast,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: highContrast
                          ? Colors.black
                          : theme.colorScheme.outline,
                    ),
                  ),
                  child: Icon(
                    iconForCategoryKey(category.iconoClave),
                    size: 20,
                    color: highContrast ? Colors.black : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            category.nombre,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          _CategoryStatusPill(active: category.activa),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$associatedPublicationsCount ${associatedPublicationsCount == 1 ? 'publicación asociada' : 'publicaciones asociadas'}',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: Key('rename_category_${category.id}'),
                  onPressed: isBusy ? null : onRename,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Renombrar'),
                ),
                if (category.activa)
                  OutlinedButton.icon(
                    key: Key('deactivate_category_${category.id}'),
                    onPressed: isBusy ? null : onDeactivate,
                    icon: const Icon(Icons.visibility_off_outlined),
                    label: const Text('Desactivar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryStatusPill extends StatelessWidget {
  final bool active;

  const _CategoryStatusPill({required this.active});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highContrast = theme.colorScheme.outline == Colors.black;

    final bg = active
        ? (highContrast
              ? DonaPlusColors.accentMint
              : DonaPlusColors.accentMint.withValues(alpha: 0.55))
        : theme.colorScheme.surfaceContainerHighest;
    final border = active
        ? (highContrast ? Colors.black : DonaPlusColors.primary)
        : (highContrast ? Colors.black : theme.colorScheme.outline);
    final fg = active
        ? (highContrast ? Colors.black : DonaPlusColors.primary)
        : theme.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: highContrast ? 1.5 : 1.0),
      ),
      child: Text(
        active ? 'Activa' : 'Inactiva',
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RejectIntermediaryDialog extends StatefulWidget {
  final String organization;

  const _RejectIntermediaryDialog({required this.organization});

  @override
  State<_RejectIntermediaryDialog> createState() =>
      _RejectIntermediaryDialogState();
}

class _RejectIntermediaryDialogState extends State<_RejectIntermediaryDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rechazar solicitud'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Puedes indicar un motivo opcional para rechazar la solicitud de "${widget.organization}".',
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('reject_intermediary_reason_field'),
            controller: _reasonController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Motivo (opcional)',
              hintText: 'Ej. El documento adjunto es ilegible.',
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
          key: const Key('confirm_reject_intermediary_button'),
          onPressed: () =>
              Navigator.of(context).pop(_reasonController.text.trim()),
          child: const Text('Confirmar rechazo'),
        ),
      ],
    );
  }
}

class _RenameCategoryDialog extends StatefulWidget {
  final String initialName;
  final Future<CategoriaMock> Function(String newName) onConfirm;

  const _RenameCategoryDialog({
    required this.initialName,
    required this.onConfirm,
  });

  @override
  State<_RenameCategoryDialog> createState() => _RenameCategoryDialogState();
}

class _RenameCategoryDialogState extends State<_RenameCategoryDialog> {
  late final TextEditingController _nameController;
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final cleanName = _nameController.text.trim();
    if (cleanName.isEmpty) {
      setState(() => _errorText = 'El nombre de la categoría es obligatorio.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final updated = await widget.onConfirm(cleanName);
      if (mounted) Navigator.of(context).pop(updated);
    } on ValidationException catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorText = e.message;
        });
      }
    } on NetworkException catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorText = e.message;
        });
      }
    } on UnauthorizedActionException catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorText = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Renombrar categoría'),
      content: TextField(
        key: const Key('rename_category_field'),
        controller: _nameController,
        enabled: !_isSubmitting,
        autofocus: true,
        onChanged: (_) {
          if (_errorText != null) {
            setState(() => _errorText = null);
          }
        },
        decoration: InputDecoration(
          labelText: 'Nuevo nombre *',
          errorText: _errorText,
          errorMaxLines: 2,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('confirm_rename_category_button'),
          onPressed: _isSubmitting ? null : _submit,
          child: Text(_isSubmitting ? 'Guardando...' : 'Guardar nombre'),
        ),
      ],
    );
  }
}

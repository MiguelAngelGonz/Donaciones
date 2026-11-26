import 'package:donaciones/app/theme.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/core/widgets/legal_documents_sheet.dart';
import 'package:donaciones/core/widgets/trust_badge_chip.dart';
import 'package:donaciones/features/auth/presentation/auth_form_widgets.dart';
import 'package:donaciones/features/intermediary/presentation/request_intermediary_sheet.dart';
import 'package:donaciones/features/profile/presentation/edit_profile_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// User profile screen covering CU-03 to CU-06, CU-10, and CU-40 / CU-42 hooks.
class ProfileScreen extends ConsumerWidget {
  final VoidCallback? onRequestIntermediary;

  const ProfileScreen({super.key, this.onRequestIntermediary});

  String _formatDate(DateTime dt) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(dt.day)}/${twoDigits(dt.month)}/${dt.year}';
  }

  void _goRoute(BuildContext context, String route, {bool push = false}) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      if (push) {
        context.push(route);
      } else {
        context.go(route);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(mockTenantStoreProvider);
    final activeUser = store.activeUser;

    if (activeUser == null) {
      return _LoggedOutProfileView(
        onLogin: () => _goRoute(context, '/login'),
        onRegister: () => _goRoute(context, '/register'),
      );
    }

    final reviews = store.getReviewsForUser(activeUser.id);
    final intermediaryRequests = store.intermediaryRequests.reversed
        .where((r) => r.usuarioId == activeUser.id)
        .toList()
      ..sort((a, b) => b.fechaSolicitud.compareTo(a.fechaSolicitud));
    final latestIntermediaryRequest =
        intermediaryRequests.isEmpty ? null : intermediaryRequests.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _UserInfoCard(
                user: activeUser,
                onEdit: () => showEditProfileSheet(context, activeUser),
              ),
              const SizedBox(height: 14),
              _TrustProfileCard(user: activeUser),
              const SizedBox(height: 14),
              _ReviewsCard(
                reviews: reviews,
                store: store,
                formatDate: _formatDate,
              ),
              const SizedBox(height: 14),
              _IntermediarySectionCard(
                user: activeUser,
                latestRequest: latestIntermediaryRequest,
                onRequestIntermediary: onRequestIntermediary ??
                    () => showRequestIntermediarySheet(context),
              ),
              if (activeUser.esAdministrador) ...[
                const SizedBox(height: 14),
                _AdminAccessCard(
                  onOpenAdmin: () => _goRoute(context, '/admin', push: true),
                ),
              ],
              const SizedBox(height: 14),
              const LegalAndPermissionsCard(),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () {
                  store.logout();
                  _goRoute(context, '/login');
                },
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoggedOutProfileView extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  const _LoggedOutProfileView({
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 52,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No has iniciado sesión',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Inicia sesión o crea una cuenta para consultar tu perfil, tu Perfil de Confianza y tus reseñas.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
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
              const SizedBox(height: 14),
              const LegalAndPermissionsCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserInfoCard extends StatelessWidget {
  final UsuarioMock user;
  final VoidCallback onEdit;

  const _UserInfoCard({required this.user, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfileAvatarCircle(
                  nombreLegal: user.nombreLegal,
                  fotoPerfil: user.fotoPerfil,
                  radius: 30,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.nombreLegal,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${user.nombreUsuario}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: Icon(
                              user.correoVerificado
                                  ? Icons.verified_outlined
                                  : Icons.mark_email_unread_outlined,
                              size: 16,
                            ),
                            label: Text(
                              user.correoVerificado
                                  ? 'Correo verificado'
                                  : 'Correo sin verificar',
                            ),
                          ),
                          if (user.esAdministrador)
                            const Chip(
                              visualDensity: VisualDensity.compact,
                              avatar: Icon(
                                Icons.admin_panel_settings_outlined,
                                size: 16,
                              ),
                              label: Text('Administrador'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _InfoRow(
              icon: Icons.email_outlined,
              label: 'Correo electrónico',
              value: user.correo,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Teléfono celular',
              value: user.telefono,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Ubicación aproximada',
              value: user.ubicacionAproximada.etiqueta,
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar perfil'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrustProfileCard extends StatelessWidget {
  final UsuarioMock user;

  const _TrustProfileCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missingItems = <String>[
      if (user.faltantesDonaciones > 0)
        'Te falta${user.faltantesDonaciones == 1 ? '' : 'n'} ${user.faltantesDonaciones} ${user.faltantesDonaciones == 1 ? 'donación finalizada' : 'donaciones finalizadas'} (meta: 5).',
      if (user.faltantesResenas > 0)
        'Te falta${user.faltantesResenas == 1 ? '' : 'n'} ${user.faltantesResenas} ${user.faltantesResenas == 1 ? 'reseña' : 'reseñas'} (meta: 3).',
      if (user.faltantePromedio > 0)
        'Necesitas +${user.faltantePromedio.toStringAsFixed(1)} en promedio de calificación (meta: 4.0).',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Perfil de Confianza',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TrustBadgeChip(usuario: user),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricTile(
                  label: 'Donaciones finalizadas',
                  value: '${user.donacionesFinalizadas}',
                  target: 'Meta: 5',
                ),
                _MetricTile(
                  label: 'Promedio calificación',
                  value: user.promedioCalificacion.toStringAsFixed(1),
                  target: 'Meta: 4.0',
                ),
                _MetricTile(
                  label: 'Reseñas recibidas',
                  value: '${user.numeroResenas}',
                  target: 'Meta: 3',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (user.perfilConfianzaOtorgado)
              const AuthFeedbackBanner(
                message:
                    'Cumples con los requisitos del Perfil de Confianza (≥ 5 donaciones finalizadas, promedio ≥ 4.0 y ≥ 3 reseñas).',
                tone: AuthBannerTone.success,
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Requisitos pendientes para obtener la insignia:',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (missingItems.isEmpty)
                      const Text(
                        'Completa 5 donaciones finalizadas, 3 reseñas y promedio ≥ 4.0.',
                      )
                    else
                      for (final item in missingItems)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text('• $item'),
                        ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String target;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: DonaPlusColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            target,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewsCard extends StatelessWidget {
  final List<ResenaMock> reviews;
  final MockTenantStore store;
  final String Function(DateTime) formatDate;

  const _ReviewsCard({
    required this.reviews,
    required this.store,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.reviews_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reseñas recibidas (${reviews.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (reviews.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('Aún no has recibido reseñas'),
              )
            else
              Column(
                children: [
                  for (var i = 0; i < reviews.length; i++) ...[
                    if (i > 0) const Divider(height: 18),
                    _ReviewItem(
                      review: reviews[i],
                      authorName: store.findUserById(reviews[i].autorId)?.nombreLegal ??
                          'Miembro DonaPlus',
                      dateLabel: formatDate(reviews[i].fecha),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final ResenaMock review;
  final String authorName;
  final String dateLabel;

  const _ReviewItem({
    required this.review,
    required this.authorName,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highContrast = theme.colorScheme.outline == Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                authorName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              dateLabel,
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var star = 1; star <= 5; star++)
                  Icon(
                    star <= review.calificacion
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 18,
                    color: highContrast
                        ? Colors.black
                        : const Color(0xFFB26A00),
                  ),
              ],
            ),
            if (review.verificada)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: highContrast
                      ? DonaPlusColors.accentYellow
                      : DonaPlusColors.accentMint.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: highContrast ? Colors.black : DonaPlusColors.primary,
                  ),
                ),
                child: Text(
                  'Donación verificada',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: highContrast ? Colors.black : DonaPlusColors.primary,
                  ),
                ),
              ),
          ],
        ),
        if (review.comentario != null &&
            review.comentario!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(review.comentario!, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _IntermediarySectionCard extends StatelessWidget {
  final UsuarioMock user;
  final SolicitudRolIntermediarioMock? latestRequest;
  final VoidCallback onRequestIntermediary;

  const _IntermediarySectionCard({
    required this.user,
    required this.latestRequest,
    required this.onRequestIntermediary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPending = latestRequest?.estado == EstadoSolicitudRol.pendiente;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Intermediario comunitario',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (user.esIntermediario) ...[
              AuthFeedbackBanner(
                message: latestRequest != null &&
                        latestRequest!.estado == EstadoSolicitudRol.aprobada
                    ? 'Intermediario comunitario autorizado (${latestRequest!.organizacion}).'
                    : 'Intermediario comunitario autorizado.',
                tone: AuthBannerTone.success,
              ),
            ] else if (isPending) ...[
              AuthFeedbackBanner(
                message:
                    'Solicitud pendiente de revisión para "${latestRequest!.organizacion}" (${latestRequest!.documentoNombre}).',
                tone: AuthBannerTone.info,
              ),
            ] else ...[
              if (latestRequest != null &&
                  (latestRequest!.estado == EstadoSolicitudRol.rechazada ||
                      latestRequest!.estado == EstadoSolicitudRol.revocada)) ...[
                AuthFeedbackBanner(
                  message: latestRequest!.estado == EstadoSolicitudRol.rechazada
                      ? 'Tu solicitud anterior fue rechazada${latestRequest!.motivoDecision != null ? ': ${latestRequest!.motivoDecision}' : '.'}'
                      : 'Tu rol de intermediario anterior fue revocado.',
                  tone: AuthBannerTone.warning,
                ),
                const SizedBox(height: 10),
              ],
              Text(
                'Si representas a una organización o comunidad, solicita el rol de intermediario para publicar necesidades en nombre de beneficiarios.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRequestIntermediary,
                icon: const Icon(Icons.assignment_ind_outlined),
                label: const Text('Solicitar rol de intermediario'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdminAccessCard extends StatelessWidget {
  final VoidCallback onOpenAdmin;

  const _AdminAccessCard({required this.onOpenAdmin});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Administración de la plataforma',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Gestiona solicitudes de intermediarios y categorías de publicación.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onOpenAdmin,
              icon: const Icon(Icons.dashboard_customize_outlined),
              label: const Text('Panel de Administración'),
            ),
          ],
        ),
      ),
    );
  }
}

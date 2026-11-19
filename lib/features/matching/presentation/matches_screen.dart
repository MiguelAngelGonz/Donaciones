import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/core/widgets/notifications_sheet.dart';
import 'package:donaciones/core/widgets/trust_badge_chip.dart';
import 'package:donaciones/features/publications/presentation/publication_ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Displays automatic matches ordered by urgency and distance (CU-17, CU-18).
class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(mockTenantStoreProvider);
    final activeUser = store.activeUser;
    final theme = Theme.of(context);

    if (activeUser == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                      Icons.handshake_outlined,
                      size: 48,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Inicia sesión para ver tus coincidencias',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => GoRouter.maybeOf(context)?.go('/login'),
                      child: const Text('Iniciar sesión'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final matches = store.getMatchesForUser(activeUser.id);
    final unreadMatchNotifications = store
        .getNotificationsForUser(activeUser.id)
        .where(
          (n) => !n.leida && n.tipo == TipoNotificacion.nuevaCoincidencia,
        )
        .length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Coincidencias (${matches.length})',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (unreadMatchNotifications > 0)
                      ActionChip(
                        avatar: const Icon(Icons.notifications_active_outlined, size: 16),
                        label: Text('$unreadMatchNotifications avisos nuevos'),
                        onPressed: () => showNotificationsSheet(context),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Cruce automático de tus publicaciones activas por categoría, urgencia y cercanía.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                if (matches.isEmpty)
                  _EmptyMatchesCard(
                    onCreatePublication: () =>
                        GoRouter.maybeOf(context)?.go('/create'),
                  )
                else
                  for (final match in matches) ...[
                    _MatchCard(
                      match: match,
                      ownPub: store.findPublicationById(
                        match.publicacionPropiaId,
                      ),
                      otherPub: store.findPublicationById(
                        match.publicacionParId,
                      ),
                      category: store.findCategoryById(match.categoriaId),
                      otherAuthor: (() {
                        final other = store.findPublicationById(
                          match.publicacionParId,
                        );
                        return other == null
                            ? null
                            : store.findUserById(other.autorId);
                      })(),
                      onOpenCounterpart: () => GoRouter.maybeOf(context)?.push(
                        '/publications/${match.publicacionParId}',
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyMatchesCard extends StatelessWidget {
  final VoidCallback onCreatePublication;

  const _EmptyMatchesCard({required this.onCreatePublication});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.handshake_outlined,
              size: 48,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(height: 12),
            Text(
              'No tienes coincidencias activas en este momento',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Publica una necesidad o un artículo para encontrar coincidencias compatibles automáticamente.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreatePublication,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Crear publicación'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final CoincidenciaMock match;
  final PublicacionMock? ownPub;
  final PublicacionMock? otherPub;
  final CategoriaMock? category;
  final UsuarioMock? otherAuthor;
  final VoidCallback onOpenCounterpart;

  const _MatchCard({
    required this.match,
    required this.ownPub,
    required this.otherPub,
    required this.category,
    required this.otherAuthor,
    required this.onOpenCounterpart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counterpartIsNeed = otherPub?.tipo == TipoPublicacion.necesidad;

    return Card(
      key: Key('match_card_${match.id}'),
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
                  avatar: Icon(
                    iconForCategoryKey(category?.iconoClave ?? 'category'),
                    size: 16,
                  ),
                  label: Text(category?.nombre ?? 'Categoría'),
                ),
                UrgencyBadge(urgencia: match.urgencia),
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.near_me_outlined, size: 15),
                  label: Text('${match.distanciaKm.toStringAsFixed(1)} km'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Tu publicación: ${ownPub?.titulo ?? match.publicacionPropiaId}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Coincidencia: ${otherPub?.titulo ?? match.publicacionParId}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
            if (otherPub?.gestionadaPorIntermediario == true) ...[
              const SizedBox(height: 8),
              IntermediaryBadge(
                aliasBeneficiario: otherPub?.aliasBeneficiario,
              ),
            ],
            if (otherAuthor != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    otherAuthor!.nombreLegal,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TrustBadgeChip(usuario: otherAuthor!, compact: true),
                ],
              ),
            ],
            if (match.caracteristicasCumplidas.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final item in match.caracteristicasCumplidas)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check,
                            size: 14,
                            color: theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: Key('match_action_${match.id}'),
                onPressed: onOpenCounterpart,
                icon: const Icon(Icons.open_in_new),
                label: Text(
                  counterpartIsNeed ? 'Ver y ofertar' : 'Ver y solicitar',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

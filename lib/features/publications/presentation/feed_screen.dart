import 'package:donaciones/app/theme.dart';
import 'package:donaciones/core/location/android_device_location.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/core/widgets/trust_badge_chip.dart';
import 'package:donaciones/features/publications/presentation/feed_filter_controller.dart';
import 'package:donaciones/features/publications/presentation/publication_ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:go_router/go_router.dart';

/// Main community feed with category, type, proximity, and urgency filters (CU-19..22).
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  bool _requestingLocation = false;

  Future<void> _handleDeviceLocationToggle(MockTenantStore store) async {
    if (_requestingLocation) return;
    if (store.isDeviceLocationAuthorized) {
      store.setDeviceLocationAuthorized(false);
      return;
    }

    final allowed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Autorizar ubicación del dispositivo'),
        content: const Text(
          '¿Permites que Komuna use la ubicación aproximada de tu dispositivo '
          'para mostrar el código postal y calcular distancias?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Denegar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Permitir'),
          ),
        ],
      ),
    );

    if (!mounted || allowed == null || _requestingLocation) return;
    if (!allowed) {
      _showLocationMessage(
        'Permiso denegado. Se utilizará la ubicación aproximada registrada en tu perfil.',
      );
      return;
    }
    if (!usesAndroidDeviceAccess) {
      store.setDeviceLocationAuthorized(true);
      return;
    }

    setState(() => _requestingLocation = true);
    try {
      final locator = GeolocatorAndroid();
      var permission = await locator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await locator.requestPermission();
      }
      if (!mounted) return;
      if (permission == LocationPermission.deniedForever) {
        _showLocationMessage(
          'Puedes habilitar el permiso de ubicación de Komuna en los ajustes de Android.',
          action: SnackBarAction(
            label: 'Ajustes',
            onPressed: () => locator.openAppSettings(),
          ),
        );
        return;
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        _showLocationMessage(
          'Permiso denegado. Se utilizará la ubicación aproximada registrada en tu perfil.',
        );
        return;
      }
      final location = await readAndroidDeviceLocation(locator);
      if (!mounted) return;
      store.setDeviceLocationAuthorized(true, location: location);
    } on LocationServiceDisabledException {
      if (mounted) {
        _showLocationMessage(
          'Activa la ubicación en Android para calcular las distancias con tu dispositivo.',
        );
      }
    } on Exception {
      if (mounted) {
        _showLocationMessage(
          'No se pudo obtener la ubicación. Se utilizará la ubicación aproximada de tu perfil.',
        );
      }
    } finally {
      if (mounted) setState(() => _requestingLocation = false);
    }
  }

  void _showLocationMessage(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message), action: action));
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(mockTenantStoreProvider);
    final filterState = ref.watch(feedFilterControllerProvider);
    final filterController = ref.read(feedFilterControllerProvider.notifier);
    final theme = Theme.of(context);
    final highContrast = theme.colorScheme.outline == Colors.black;

    final categories = store.getCategoriesForFilter();
    final publications = store.filterActivePublications(
      categoryId: filterState.selectedCategoryId,
      type: filterState.selectedType,
      urgency: filterState.selectedUrgency,
      sortByUrgency: filterState.sortByUrgency,
      maxDistanceKm: store.canFilterByDistance
          ? filterState.maxDistanceKm
          : null,
      sortByDistance: store.canFilterByDistance && filterState.sortByDistance,
    );
    final activeUser = store.activeUser;

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
                  '¿Cómo podemos ayudarte hoy?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 10),
                ExpansionTile(
                  key: const PageStorageKey('feed_filters_panel'),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  collapsedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  collapsedBackgroundColor:
                      theme.colorScheme.surfaceContainerLow,
                  backgroundColor: theme.colorScheme.surfaceContainerLow,
                  leading: const Icon(Icons.tune),
                  title: Text(
                    filterState.hasActiveFilters
                        ? 'Filtros activos'
                        : 'Filtros',
                  ),
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Categorías',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              key: const Key('feed_clear_filters_button'),
                              onPressed: filterController.clearFilters,
                              icon: const Icon(
                                Icons.filter_alt_off_outlined,
                                size: 18,
                              ),
                              label: const Text('Quitar filtros'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          key: const PageStorageKey('feed_categories_scroll'),
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _CategoryFilterTile(
                                key: const Key('feed_cat_all'),
                                label: 'Todas',
                                icon: Icons.apps_outlined,
                                selected:
                                    filterState.selectedCategoryId == null,
                                backgroundTint: highContrast
                                    ? Colors.white
                                    : DonaPlusColors.surfaceLight,
                                onTap: () =>
                                    filterController.selectCategory(null),
                              ),
                              for (final category in categories) ...[
                                const SizedBox(width: 8),
                                _CategoryFilterTile(
                                  key: Key('feed_cat_${category.id}'),
                                  label: category.nombre,
                                  icon: iconForCategoryKey(category.iconoClave),
                                  selected:
                                      filterState.selectedCategoryId ==
                                      category.id,
                                  backgroundTint: categoryTintForKey(
                                    category.iconoClave,
                                    highContrast: highContrast,
                                  ),
                                  onTap: () => filterController.selectCategory(
                                    category.id,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Tipo de publicación',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              key: const Key('feed_type_all'),
                              label: const Text('Todos'),
                              selected: filterState.selectedType == null,
                              onSelected: (_) =>
                                  filterController.selectType(null),
                            ),
                            ChoiceChip(
                              key: const Key('feed_type_necesidad'),
                              label: const Text('Necesidades'),
                              selected:
                                  filterState.selectedType ==
                                  TipoPublicacion.necesidad,
                              onSelected: (_) => filterController.selectType(
                                TipoPublicacion.necesidad,
                              ),
                            ),
                            ChoiceChip(
                              key: const Key('feed_type_articulo'),
                              label: const Text('Artículos'),
                              selected:
                                  filterState.selectedType ==
                                  TipoPublicacion.articulo,
                              onSelected: (_) => filterController.selectType(
                                TipoPublicacion.articulo,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _ProximityControlsCard(
                          isAuthorized: store.isDeviceLocationAuthorized,
                          canFilterByDistance: store.canFilterByDistance,
                          registeredLocationLabel:
                              activeUser?.ubicacionAproximada.etiqueta ?? '',
                          maxDistanceKm: filterState.maxDistanceKm,
                          sortByDistance: filterState.sortByDistance,
                          onToggleDeviceLocation:
                              _requestingLocation ||
                                  (store.isOnline && !usesAndroidDeviceAccess)
                              ? null
                              : () => _handleDeviceLocationToggle(store),
                          onSelectMaxDistance:
                              filterController.selectMaxDistance,
                          onToggleSortDistance:
                              filterController.toggleSortByDistance,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Urgencia',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              key: const Key('feed_urgency_all'),
                              label: const Text('Todas las urgencias'),
                              selected: filterState.selectedUrgency == null,
                              onSelected: (_) =>
                                  filterController.selectUrgency(null),
                            ),
                            for (final urg in Urgencia.values)
                              ChoiceChip(
                                key: Key('feed_urgency_${urg.name}'),
                                label: Text(labelForUrgencia(urg)),
                                selected: filterState.selectedUrgency == urg,
                                onSelected: (_) =>
                                    filterController.selectUrgency(urg),
                              ),
                            FilterChip(
                              key: const Key('feed_sort_urgency'),
                              avatar: const Icon(Icons.sort, size: 16),
                              label: const Text('Ordenar por urgencia'),
                              selected: filterState.sortByUrgency,
                              onSelected: (_) =>
                                  filterController.toggleSortByUrgency(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Publicaciones disponibles (${publications.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 10),
                if (publications.isEmpty)
                  _FeedEmptyState(onClearFilters: filterController.clearFilters)
                else
                  for (final pub in publications) ...[
                    _PublicationFeedCard(
                      publication: pub,
                      category: store.findCategoryById(pub.categoriaId),
                      author: store.findUserById(pub.autorId),
                      distanceKm: store.getDistanceForPublication(pub),
                      onTap: () =>
                          GoRouter.maybeOf(context)
                              ?.push('/publications/${pub.id}'),
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

class _CategoryFilterTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color backgroundTint;
  final VoidCallback onTap;

  const _CategoryFilterTile({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.backgroundTint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highContrast = theme.colorScheme.outline == Colors.black;
    final bgColor = selected
        ? (highContrast
              ? DonaPlusColors.accentYellow
              : theme.colorScheme.primary)
        : backgroundTint;
    final fgColor = selected
        ? (highContrast ? Colors.black : Colors.white)
        : (highContrast ? Colors.black : DonaPlusColors.primary);

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 88, maxWidth: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? (highContrast ? Colors.black : theme.colorScheme.primary)
                  : theme.colorScheme.outline,
              width: selected ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: fgColor),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProximityControlsCard extends StatelessWidget {
  final bool isAuthorized;
  final bool canFilterByDistance;
  final String registeredLocationLabel;
  final double? maxDistanceKm;
  final bool sortByDistance;
  final VoidCallback? onToggleDeviceLocation;
  final ValueChanged<double?> onSelectMaxDistance;
  final VoidCallback onToggleSortDistance;

  const _ProximityControlsCard({
    required this.isAuthorized,
    required this.canFilterByDistance,
    required this.registeredLocationLabel,
    required this.maxDistanceKm,
    required this.sortByDistance,
    required this.onToggleDeviceLocation,
    required this.onSelectMaxDistance,
    required this.onToggleSortDistance,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                  isAuthorized ? Icons.my_location : Icons.location_on_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                Text(
                  'Distancia',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('feed_device_location_button'),
                  onPressed: onToggleDeviceLocation,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                  icon: Icon(
                    isAuthorized ? Icons.gps_fixed : Icons.gps_not_fixed,
                    size: 16,
                  ),
                  label: Text(
                    isAuthorized
                        ? 'Ubicación del dispositivo activa'
                        : 'Usar ubicación del dispositivo',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              !canFilterByDistance
                  ? 'Activa la ubicación o revisa el código postal de tu perfil.'
                  : isAuthorized
                  ? 'Usando la ubicación del dispositivo.'
                  : 'Usando la ubicación de tu perfil ($registeredLocationLabel).',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('feed_dist_all'),
                  label: const Text('Cualquier distancia'),
                  selected: maxDistanceKm == null,
                  onSelected: (_) => onSelectMaxDistance(null),
                ),
                ChoiceChip(
                  key: const Key('feed_dist_5'),
                  label: const Text('≤ 5 km'),
                  selected: maxDistanceKm == 5.0,
                  onSelected: canFilterByDistance
                      ? (_) => onSelectMaxDistance(5.0)
                      : null,
                ),
                ChoiceChip(
                  key: const Key('feed_dist_10'),
                  label: const Text('≤ 10 km'),
                  selected: maxDistanceKm == 10.0,
                  onSelected: canFilterByDistance
                      ? (_) => onSelectMaxDistance(10.0)
                      : null,
                ),
                ChoiceChip(
                  key: const Key('feed_dist_25'),
                  label: const Text('≤ 25 km'),
                  selected: maxDistanceKm == 25.0,
                  onSelected: canFilterByDistance
                      ? (_) => onSelectMaxDistance(25.0)
                      : null,
                ),
                FilterChip(
                  key: const Key('feed_sort_distance'),
                  avatar: const Icon(Icons.near_me_outlined, size: 16),
                  label: const Text('Ordenar por distancia'),
                  selected: sortByDistance,
                  onSelected: canFilterByDistance
                      ? (_) => onToggleSortDistance()
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedEmptyState extends StatelessWidget {
  final VoidCallback onClearFilters;

  const _FeedEmptyState({required this.onClearFilters});

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
              Icons.search_off_outlined,
              size: 44,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(height: 10),
            Text(
              'Ninguna publicación cumple los filtros seleccionados',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.refresh),
              label: const Text('Restablecer filtros'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicationFeedCard extends StatelessWidget {
  final PublicacionMock publication;
  final CategoriaMock? category;
  final UsuarioMock? author;
  final double? distanceKm;
  final VoidCallback onTap;

  const _PublicationFeedCard({
    required this.publication,
    required this.category,
    required this.author,
    required this.distanceKm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNeed = publication.tipo == TipoPublicacion.necesidad;
    final categoryLabel = (category?.nombre ?? 'Categoría').toUpperCase();
    final typeLabel = isNeed ? 'NECESIDAD' : 'ARTÍCULO';

    return Card(
      key: Key('feed_pub_${publication.id}'),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$typeLabel · $categoryLabel',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  if (isNeed)
                    UrgencyBadge(
                      urgencia: publication.urgencia ?? Urgencia.baja,
                    )
                  else if (publication.condicion != null)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.auto_awesome, size: 14),
                      label: Text(labelForCondicion(publication.condicion!)),
                    ),
                ],
              ),
              if (publication.gestionadaPorIntermediario) ...[
                const SizedBox(height: 8),
                IntermediaryBadge(
                  aliasBeneficiario: publication.aliasBeneficiario,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                publication.titulo,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                publication.descripcion,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          distanceKm == null
                              ? publication.ubicacion.etiqueta
                              : '${distanceKm!.toStringAsFixed(1)} km · ${publication.ubicacion.etiqueta}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (author != null) ...[
                    Text(
                      author!.nombreLegal,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TrustBadgeChip(usuario: author!, compact: true),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

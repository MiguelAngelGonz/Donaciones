import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stub sheet for offering an item to a Need (CU-24); replaced in Task 5.
class OfferItemSheet extends ConsumerWidget {
  final String publicationId;

  const OfferItemSheet({super.key, required this.publicationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(mockTenantStoreProvider);
    final pub = store.findPublicationById(publicationId);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
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
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (pub != null) ...[
              const SizedBox(height: 6),
              Text(
                'Para cubrir: ${pub.titulo}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'El envío de ofertas para cubrir necesidades (CU-24) se completa en el módulo de propuestas.',
            ),
          ],
        ),
      ),
    );
  }
}

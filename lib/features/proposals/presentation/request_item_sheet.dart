import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stub sheet for requesting an Item (CU-23); replaced with full flow in Task 5.
class RequestItemSheet extends ConsumerWidget {
  final String publicationId;

  const RequestItemSheet({super.key, required this.publicationId});

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
                    'Solicitar artículo',
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
                'Artículo: ${pub.titulo}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'El envío de solicitudes de artículo (CU-23) se completa en el módulo de propuestas.',
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:donaciones/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the live accessibility controls bottom sheet (RNF-03).
Future<void> showAccessibilitySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const AccessibilitySheet(),
  );
}

/// Bottom sheet allowing users to adjust text scale, high contrast, and motion.
class AccessibilitySheet extends ConsumerWidget {
  const AccessibilitySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(accessibilityProvider);
    final notifier = ref.read(accessibilityProvider.notifier);
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.accessibility_new, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Accesibilidad',
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
            const SizedBox(height: 12),
            Text(
              'Tamaño de texto',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Normal (1.0x)'),
                  selected: !settings.isLargeText,
                  onSelected: (_) => notifier.setTextScaleFactor(1.0),
                ),
                ChoiceChip(
                  label: const Text('Ampliado (1.25x)'),
                  selected: settings.isLargeText,
                  onSelected: (_) => notifier.setTextScaleFactor(1.25),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Alto contraste'),
              subtitle: const Text(
                'Aumenta el contraste de colores y grosor de bordes',
              ),
              value: settings.highContrast,
              onChanged: notifier.setHighContrast,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reducir animaciones'),
              subtitle: const Text('Usa transiciones instantáneas en pantalla'),
              value: settings.reduceMotion,
              onChanged: notifier.setReduceMotion,
            ),
            if (settings != const AccessibilitySettings()) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: notifier.reset,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Restablecer ajustes'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

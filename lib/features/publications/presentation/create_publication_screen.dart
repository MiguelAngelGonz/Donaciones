import 'package:donaciones/app/theme.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/features/publications/presentation/publish_item_form.dart';
import 'package:donaciones/features/publications/presentation/publish_need_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Publication mode toggled at the top of [CreatePublicationScreen].
enum PublicationCreateMode { item, need }

/// Container screen toggling between Item (CU-14) and Need (CU-11) publishing.
class CreatePublicationScreen extends ConsumerStatefulWidget {
  final PublicationCreateMode initialMode;

  const CreatePublicationScreen({
    super.key,
    this.initialMode = PublicationCreateMode.item,
  });

  @override
  ConsumerState<CreatePublicationScreen> createState() =>
      _CreatePublicationScreenState();
}

class _CreatePublicationScreenState
    extends ConsumerState<CreatePublicationScreen> {
  late PublicationCreateMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(mockTenantStoreProvider);
    final activeUser = store.activeUser;
    final theme = Theme.of(context);
    final highContrast = theme.colorScheme.outline == Colors.black;

    if (activeUser == null) {
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
                      Icons.add_circle_outline,
                      size: 48,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Inicia sesión para publicar',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Debes iniciar sesión para publicar artículos o necesidades en la comunidad.',
                      textAlign: TextAlign.center,
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Crear publicación',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Tu ayuda puede cambiar un día',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _ModeToggleButton(
                      key: const Key('create_mode_item'),
                      icon: Icons.card_giftcard_outlined,
                      label: 'Quiero donar',
                      selected: _mode == PublicationCreateMode.item,
                      highContrast: highContrast,
                      onTap: () =>
                          setState(() => _mode = PublicationCreateMode.item),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ModeToggleButton(
                      key: const Key('create_mode_need'),
                      icon: Icons.campaign_outlined,
                      label: 'Necesito',
                      selected: _mode == PublicationCreateMode.need,
                      highContrast: highContrast,
                      onTap: () =>
                          setState(() => _mode = PublicationCreateMode.need),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_mode == PublicationCreateMode.item)
                const PublishItemForm()
              else
                const PublishNeedForm(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeToggleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool highContrast;
  final VoidCallback onTap;

  const _ModeToggleButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.highContrast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = selected
        ? (highContrast ? DonaPlusColors.accentYellow : theme.colorScheme.primary)
        : Colors.white;
    final fgColor = selected
        ? (highContrast ? Colors.black : Colors.white)
        : theme.colorScheme.primary;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: highContrast ? Colors.black : theme.colorScheme.primary,
              width: selected ? 2.0 : 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fgColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fgColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

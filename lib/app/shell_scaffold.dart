import 'package:donaciones/app/theme.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:donaciones/core/models/domain_models.dart';
import 'package:donaciones/core/widgets/accessibility_sheet.dart';
import 'package:donaciones/core/widgets/demo_tenant_toolbar.dart';
import 'package:donaciones/core/widgets/notifications_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Main application shell wrapping the 5 primary navigation destinations (RNF-02).
class ShellScaffold extends ConsumerWidget {
  final Widget child;
  final String location;

  const ShellScaffold({super.key, required this.child, required this.location});

  static int _selectedIndexForLocation(String location) {
    if (location.startsWith('/matches')) return 1;
    if (location.startsWith('/create')) return 2;
    if (location.startsWith('/donations')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  static void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
      case 1:
        context.go('/matches');
      case 2:
        context.go('/create');
      case 3:
        context.go('/donations');
      case 4:
        context.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(mockTenantStoreProvider);
    final activeUser = store.activeUser;

    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const DemoTenantToolbar(),
                _ShellHeaderBar(
                  activeUser: activeUser,
                  devicePostalCode: store.devicePostalCode,
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndexForLocation(location),
        onDestinationSelected: (index) =>
            _onDestinationSelected(context, index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.handshake_outlined),
            selectedIcon: Icon(Icons.handshake),
            label: 'Coincidencias',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Publicar',
          ),
          NavigationDestination(
            icon: Icon(Icons.volunteer_activism_outlined),
            selectedIcon: Icon(Icons.volunteer_activism),
            label: 'Donaciones',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class _ShellHeaderBar extends StatelessWidget {
  final UsuarioMock? activeUser;
  final String? devicePostalCode;

  const _ShellHeaderBar({
    required this.activeUser,
    required this.devicePostalCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = activeUser;
    final greeting = user == null
        ? 'Komuna · Sin sesión'
        : 'Hola, ${user.nombreLegal.split(' ').first}';
    final postalCode = devicePostalCode;
    final locationLabel = postalCode == null
        ? user?.ubicacionAproximada.etiqueta ??
              'Inicia sesión o regístrate para participar'
        : 'CP $postalCode';

    return Material(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    greeting,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: DonaPlusColors.accentMint,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          locationLabel,
                          key: const Key('shell_location_label'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimary.withValues(
                              alpha: 0.9,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ActionChip(
              avatar: Icon(
                Icons.accessibility_new,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              label: const Text('Accesibilidad'),
              backgroundColor: Colors.white,
              labelStyle: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
              visualDensity: VisualDensity.compact,
              onPressed: () => showAccessibilitySheet(context),
            ),
            IconButtonTheme(
              data: IconButtonThemeData(
                style: IconButton.styleFrom(
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
              ),
              child: const NotificationsBellButton(),
            ),
          ],
        ),
      ),
    );
  }
}

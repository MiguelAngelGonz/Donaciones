import 'package:donaciones/app/shell_scaffold.dart';
import 'package:donaciones/core/widgets/demo_tenant_toolbar.dart';
import 'package:donaciones/features/auth/presentation/login_screen.dart';
import 'package:donaciones/features/auth/presentation/register_screen.dart';
import 'package:donaciones/features/auth/presentation/reset_password_screen.dart';
import 'package:donaciones/features/matching/presentation/matches_screen.dart';
import 'package:donaciones/features/profile/presentation/profile_screen.dart';
import 'package:donaciones/features/publications/presentation/create_publication_screen.dart';
import 'package:donaciones/features/publications/presentation/feed_screen.dart';
import 'package:donaciones/features/publications/presentation/publication_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Shared GoRouter instance provider for DonaPlusApp.
final appRouterProvider = Provider<GoRouter>((ref) => createAppRouter());

/// Builds the declarative GoRouter configuration covering all MVP routes.
GoRouter createAppRouter({String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            ShellScaffold(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const FeedScreen(),
          ),
          GoRoute(
            path: '/matches',
            builder: (context, state) => const MatchesScreen(),
          ),
          GoRoute(
            path: '/create',
            builder: (context, state) => const CreatePublicationScreen(),
          ),
          GoRoute(
            path: '/donations',
            builder: (context, state) => const _TabPlaceholderScreen(
              icon: Icons.volunteer_activism_outlined,
              title: 'Donaciones',
              subtitle: 'Propuestas, entregas en curso e historial.',
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/publications/:id',
        builder: (context, state) => PublicationDetailScreen(
          publicationId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/donations/:id',
        builder: (context, state) => _StandalonePlaceholderScreen(
          title: 'Seguimiento de donación',
          subtitle: 'Donación ${state.pathParameters['id'] ?? ''}',
        ),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const _StandalonePlaceholderScreen(
          title: 'Panel de Administración',
          subtitle: 'Gestión de intermediarios y categorías (CU-42 a CU-51).',
        ),
      ),
    ],
  );
}

class _TabPlaceholderScreen extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _TabPlaceholderScreen({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.secondary),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StandalonePlaceholderScreen extends StatelessWidget {
  final String title;
  final String subtitle;

  const _StandalonePlaceholderScreen({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Text(title),
      ),
      body: Column(
        children: [
          const DemoTenantToolbar(),
          Expanded(
            child: _TabPlaceholderScreen(
              icon: Icons.layers_outlined,
              title: title,
              subtitle: subtitle,
            ),
          ),
        ],
      ),
    );
  }
}
